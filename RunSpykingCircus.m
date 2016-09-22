function [status,cmdout]=RunSpykingCircus(exportDir,exportFile,option)
% Run Spyking Circus from Matlab. 
% (see http://spyking-circus.readthedocs.io/ for info)
% Environement variables (defined in "userinfo" structure), as well as 
% processing parameters ("userParams") need to be adjusted by user.
% Runs on Windows 7, may require modifications on other platforms
% Written by Vincent Prevosto, May 2016

switch nargin
    case 0
        exportDir=cd;
        %select most recent .dat file
        exportFile=dir;
        [~,fDateIdx]=sort([exportFile.datenum],'descend');
        exportFile=exportFile(fDateIdx);
        exportFile=exportFile(~cellfun('isempty',cellfun(@(x) strfind(x,'.dat'),...
            {exportFile.name},'UniformOutput', false))).name;
        option='runspkc';
    case 2
        option='runspkc';
    case 3
    otherwise
        disp('missing argument for RunSpykingCircus')
        return
end

%% declarations
userinfo=UserDirInfo;
%environment path directories
envDirs=[userinfo.envRootDir ';' userinfo.envScriptDir ';' userinfo.envLibDir];

%% create parameter file
if strcmp(option,'paramsfile')
    userParams={'0';'';'int16';'0';'30000';'2';'8';'both';'True';'10000';...
        '0.005';'True';'1';'1, 1';'0.9';'True'};
    parameterNames={'data_offset','mapping','data_dtype','dtype_offset','sampling_rate',...
        'N_t','spike_thresh','peaks','remove_median','max_elts','nclus_min',...
        'smart_search','cc_merge','dispersion','noise_thr','correct_lag'};
    dlgTitle='Parameters file options';
    numLines=1;
    userParams=inputdlg(parameterNames,dlgTitle,numLines,userParams);
    [status,cmdout]=GenerateParamFile(exportFile,exportDir,userParams,userinfo);
end

if strfind(option,'previewspkc')
    % check MPI status and start if needed
    checkMPIstatus(userinfo);
    status=0;
    %% run preview
    system(['cd /d ' userinfo.envScriptDir ' &'...
        'activate spykc &'...
        'SETLOCAL &'...
        'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
        'spyking-circus ' ...
        exportDir userinfo.slash exportFile '.dat -p &'...
        'exit &']);
end

if strfind(option,'launcherGUI')
    % check MPI status and start if needed
    checkMPIstatus(userinfo);
    status=0;
    %% run preview
    system(['cd /d ' userinfo.envScriptDir ' &'...
        'activate ' userinfo.circusEnv ' &'...
        'SETLOCAL &'...
        'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
        'spyking-circus-launcher &'...
        'exit &']);
end

if strfind(option,'runspkc')
    %% run process
    % check MPI status and start if needed
    checkMPIstatus(userinfo);
    if ~isnan(str2double(option(end)))
        NumCPU=['-c ' option(end)];
    else
        NumCPU='';
    end
    status=NaN;
    [status,cmdout] = system(['cd /d ' userinfo.envScriptDir ' &'...
        'activate spykc &'...
        'SETLOCAL &'...
        'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
        'spyking-circus ' ...
        exportDir userinfo.slash exportFile '.dat -m filtering,whitening,clustering ' NumCPU ' &'...
        'exit'],'-echo');
    
    if status==0
        % finish fitting
        [status,cmdout] = system(['cd /d ' userinfo.envScriptDir ' &'...
            'activate spykc &'...
            'SETLOCAL &'...
            'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
            'spyking-circus ' ...
            exportDir userinfo.slash exportFile '.dat -m fitting &'...
            'exit &']);
    else
        % try running on less stringent parameters and with less clusters
        paramFReady=0;
        while paramFReady==0
            disp('generating less stringent parameter file');
            userParams={'0';'';'int16';'0';'30000';'2';'8';'both';'True';'10000';...
        '0.01';'True';'1';'1, 1';'0.8';'True'};
            paramFReady=GenerateParamFile(exportFile,exportDir,userParams,userinfo);
            pause(1) % give it 1 second
        end
        [status,cmdout] = system(['cd /d ' userinfo.envScriptDir ' &'...
            'activate spykc &'...
            'SETLOCAL &'...
            'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
            'spyking-circus ' ...
            exportDir userinfo.slash exportFile '.dat -m filtering,whitening,clustering ' NumCPU ' &'...
            'exit'],'-echo');
        if status~=0 %if fails again
            NumCPU=''; %no clusters
            [status,cmdout] = system(['cd /d ' userinfo.envScriptDir ' &'...
                'activate spykc &'...
                'SETLOCAL &'...
                'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
                'spyking-circus ' ...
                exportDir userinfo.slash exportFile '.dat -m filtering,whitening,clustering ' NumCPU ' &'...
                'exit'],'-echo');
        end
    end
end

%% exporting
if strfind(option,'exportspikes')
    [status,cmdout] = system(['cd /d ' userinfo.envScriptDir ' &'...
        'activate spykc &'...
        'SETLOCAL &'...
        'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
        'spyking-circus ' ...
        exportDir userinfo.slash exportFile '.dat -m converting ' NumCPU ' &'...
        'exit &']);
end

%% run visualization GUI (no need for clusters here)
if strfind(option,'startVisGUI')
    if strfind(option,'matlab')
        [status,cmdout] = system(['cd /d ' userinfo.envScriptDir ' &'...
            'activate spykc &'...
            'circus-gui-matlab ' ...
            exportDir userinfo.slash exportFile '.dat &'...
            'exit &']);
    elseif strfind(option,'python')
        [status,cmdout] = system(['cd /d ' userinfo.envScriptDir ' &'...
            'activate spykc &'...
            'circus-gui-python ' ...
            exportDir userinfo.slash exportFile '.dat &'...
            'exit &']);
    end
end
end

function checkMPIstatus(userinfo) %tested only in Windows !
envDirs=[userinfo.envRootDir ';' userinfo.envScriptDir ';' userinfo.envLibDir];

[MPIstatus,~] = system(['cd /d ' userinfo.circusHomeDir ' &'...
    'SETLOCAL &'...
    'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
    '"' userinfo.MPIDir 'mpiexec.exe" -gmachinefile circus.hosts hostname ']);

if MPIstatus==-1
    system(['SETLOCAL &'...
        'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
        '"' userinfo.MPIDir 'smpd.exe" -d 1 &']);
end
end