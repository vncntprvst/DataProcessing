function [status,cmdout]=RunSpykingCircus(exportDir,exportFile,option)
% Run Spyking Circus from Matlab. 
% (see http://spyking-circus.readthedocs.io/ for info)
% 
% INPUTS 
%   exportDir: directory to export generated files
%   exportFile: exported file name(s)
%   option: contains instruction in field structure
%       option{1}: string describing the call passed to Spyking Circus
%             'runspkc': runs pyking Circus
%             'paramsfile' or 'paramsfile_noInputdlg': generates parameter file
%             'previewspkc': launches preview GUI
%             'launcherGUI': launches launcher GUI
%             'exportspikes': converts spikes
%             'startVisGUI': launches Matalab spike visualization GUI
%       option{2}: user parameters to be written in parameter file 
% 
% OUTPUTS
%   returns process status and command outputs if any
% 
% EXAMPLES
%   % To generate a parameter file for a single recording, without input dialog: 
%   % define parameters to pass (if any)
%   userParams={'raw_binary';num2str(samplingRate);'int16';...
%       num2str(length(exportedChan));probeID;...
%       '2';'8';'both';'True';'10000';'0.002';'True';'0.98';'2, 5';'0.8';'True';'True'};
%   % call function
%   [status,cmdout]=RunSpykingCircus(directory_containing_files,exportName,...
%                       {'paramsfile_noInputdlg';userParams});
% 
%   % To create a batch processing file (and all .params files):
%   go to 
%   RunSpykingCircus(directory_containing_files)
%
% Environment variables (defined in "userInfo" structure), as well as 
% processing parameters ("userParams") can be adjusted by user.
% 
% Runs on Windows 7, may require modifications on other platforms
% Written by Vincent Prevosto, May 2016

switch nargin
    case 0
        [exportDir,exportDirList]=deal(cd);
        %select most recent .dat file
        exportFile=dir;
        [~,fDateIdx]=sort([exportFile.datenum],'descend');
        exportFile=exportFile(fDateIdx);
        try
            exportFile=exportFile(~cellfun('isempty',cellfun(@(x) strfind(x,'.dat'),...
                {exportFile.name},'UniformOutput', false))).name;
            option{1}='runspkc';
        catch
            batchProc=true; %create batch processing file
        end
    case 1 %create batch processing file
        batchProc=true;
    case 2
        option{1}='runspkc';
    case 3
    otherwise
        disp('wrong argument number')
        return
end

%% if batch processing, list all directories and data files
if exist('batchProc','var') && batchProc==true
    cd(exportDir)
    dataFiles = dir([cd filesep '**' filesep '*.dat']); 
    %% Need to make a better naming system. This is stupid
    dataFiles=dataFiles(cellfun(@(flnm) contains(flnm,'_export'),{dataFiles.name}));
    exportDirList = {dataFiles.folder};
    exportFile =  {dataFiles.name};
    option{1}='paramsfile_noInputdlg';
    option{2}= struct('parameterNames',{'file_format';'sampling_rate';...
        'data_dtype';'nb_channels';'mapping';'overwrite';'output_dir';...
        'N_t';'spike_thresh';'peaks';'isolation';'remove_median';...
        'max_clusters';'smart_search';'smart_select';'cc_merge';...
        'dispersion';'noise_thr';'make_plots';'gpu_only';...
        'collect_all';'correct_lag';'auto_mode'},... %'max_elts','nclus_min'
        'userParams',{'raw_binary';'30000';'int16';'32';'';'False';... %False to keep original binary file as is
        '';'3';'7';'both';'True';'True';'15';'True';'True';...
         '0.975';'2, 5';'0.9';'True';'False';'True';'True';'0.1'}); 
     
     % write batch file
     fullFileNames=cellfun(@(dirName, fileName) [dirName filesep fileName],...
         exportDirList,exportFile,'UniformOutput',false);    
     fid  = fopen('SC_batch.txt','w'); 
     formatSpec = '%s --method filtering,whitening,clustering,fitting --cpu 8\n';
     for rowNum = 1:size(fullFileNames,2)
         fprintf(fid,formatSpec,fullFileNames{1,rowNum});
     end
     fclose(fid); 
end

%% declarations
try 
    userInfo=UserDirInfo('simple pyEnv');
catch 
    userInfo=[];
end
if isempty(userInfo)
    try
        if contains(getenv('OS'),'Windows')
    system(['runas /user:' getenv('computername') '\' getenv('username') ...
        ' spyking-circus-launcher & exit &']); %
        else 
            system(['sudo �u ' getenv('username') ...
        ' spyking-circus-launcher & exit &']); %UNTESTED !
        end
    catch
            system('spyking-circus-launcher & exit &'); %  will only be able to edit params, not run spike sorting
    end
    status=1;
    cmdout='please generate .params file manually through GUI';
    return
end

%environment path directories
envDirs=[userInfo.envRootDir ';' userInfo.envScriptDir ';' userInfo.envLibDir];

%% create parameter file
if strcmp(option{1},'paramsfile') | strcmp(option{1},'paramsfile_noInputdlg')
%     {'raw_binary';'30000';'int16';'32';'';'3';'8';'both';'True';'10000';...
%         '0.002';'True';'1';'2, 5';'0.8';'True';'True'};
    if ~strcmp(option{1},'paramsfile_noInputdlg')
        parameterNames={'file_format';'sampling_rate';...
        'data_dtype';'nb_channels';'mapping';'overwrite';'output_dir';...
        'N_t';'spike_thresh';'peaks';'isolation';'remove_median';...
        'max_clusters';'smart_search';'smart_select';'cc_merge';...
        'dispersion';'noise_thr';'make_plots';'gpu_only';...
        'collect_all';'correct_lag';'auto_mode'};
        dlgTitle='Parameters file options';
        numLines=1;
        dims = [0.7 35];
        userParams=inputdlg(parameterNames,dlgTitle,dims,{option{2}.userParams});
        [option{2}.userParams]=deal(userParams{:});
    end
    option{2}(5).userParams=''; inputParams=option{2}; 
    %% fix mapping directory
    %% fix .prb file not being the remapped one
    [status,cmdout]=GenerateSCParamFile(exportFile,exportDirList,inputParams,userInfo);
end

if strfind(option{1},'previewspkc')
    % check MPI status and start if needed
    checkMPIstatus(userInfo);
    status=0;
    %% run preview
    system(['cd /d ' userInfo.envScriptDir ' &'...
        'activate ' userInfo.circusEnv ' &'...
        'SETLOCAL &'...
        'set PATH="' envDirs ';' userInfo.MPIDir ';' userInfo.WinDirs '" &'...
        'spyking-circus ' ...
        exportDir filesep exportFile '.dat -p &'...
        'exit &']);
end

if strfind(option{1},'launcherGUI')
    % check MPI status and start if needed
%     checkMPIstatus(userinfo);
    status=0;
if exist('userinfo','var') && isfield(userInfo,'circusEnv')
    activation=['activate ' userInfo.circusEnv ' & '];
else
    activation='';
end
    %% run preview
    system(['cd /d ' userInfo.envScriptDir ' &'...
        activation ...
        'SETLOCAL &'...
        'set PATH="' envDirs ';' userInfo.MPIDir ';' userInfo.WinDirs '" &'...
        'spyking-circus-launcher &'...
        'exit &']);
end

if strfind(option{1},'runspkc')
    %% run process
    % check MPI status and start if needed
    checkMPIstatus(userInfo);
    if ~isnan(str2double(option{1}(end)))
        NumCPU=['-c ' option{1}(end)];
    else
        NumCPU='';
    end
    status=NaN;
    [status,cmdout] = system(['cd /d ' userInfo.envScriptDir ' &'...
        'activate ' userInfo.circusEnv ' &'...
        'SETLOCAL &'...
        'set PATH="' envDirs ';' userInfo.MPIDir ';' userInfo.WinDirs '" &'...
        'spyking-circus ' ...
        exportDir filesep exportFile '.dat -m filtering,whitening,clustering ' NumCPU ' &'...
        'exit'],'-echo');
    
    if status==0
        % finish fitting
        [status,cmdout] = system(['cd /d ' userInfo.envScriptDir ' &'...
            'activate ' userInfo.circusEnv ' &'...
            'SETLOCAL &'...
            'set PATH="' envDirs ';' userInfo.MPIDir ';' userInfo.WinDirs '" &'...
            'spyking-circus ' ...
            exportDir filesep exportFile '.dat -m fitting &'...
            'exit &']);
    else
        % try running on less stringent parameters and with less clusters
        paramFReady=0;
        while paramFReady==0
            disp('generating less stringent parameter file');
            inputParams={'0';'';'int16';'0';'30000';'2';'8';'both';'True';'10000';...
        '0.01';'True';'1';'1, 1';'0.8';'True';'True'};
            paramFReady=GenerateParamFile(exportFile,exportDir,inputParams,userInfo);
            pause(1) % give it 1 second
        end
        [status,cmdout] = system(['cd /d ' userInfo.envScriptDir ' &'...
            'activate ' userInfo.circusEnv ' &'...
            'SETLOCAL &'...
            'set PATH="' envDirs ';' userInfo.MPIDir ';' userInfo.WinDirs '" &'...
            'spyking-circus ' ...
            exportDir filesep exportFile '.dat -m filtering,whitening,clustering ' NumCPU ' &'...
            'exit'],'-echo');
        if status~=0 %if fails again
            NumCPU=''; %no clusters
            [status,cmdout] = system(['cd /d ' userInfo.envScriptDir ' &'...
                'activate ' userInfo.circusEnv ' &'...
                'SETLOCAL &'...
                'set PATH="' envDirs ';' userInfo.MPIDir ';' userInfo.WinDirs '" &'...
                'spyking-circus ' ...
                exportDir filesep exportFile '.dat -m filtering,whitening,clustering ' NumCPU ' &'...
                'exit'],'-echo');
        end
    end
end

%% exporting
if strfind(option{1},'exportspikes')
    [status,cmdout] = system(['cd /d ' userInfo.envScriptDir ' &'...
        'activate ' userInfo.circusEnv ' &'...
        'SETLOCAL &'...
        'set PATH="' envDirs ';' userInfo.MPIDir ';' userInfo.WinDirs '" &'...
        'spyking-circus ' ...
        exportDir filesep exportFile '.dat -m converting ' NumCPU ' &'...
        'exit &']);
end

%% run visualization GUI (no need for clusters here)
if strfind(option{1},'startVisGUI')
    if strfind(option{1},'matlab')
        [status,cmdout] = system(['cd /d ' userInfo.envScriptDir ' &'...
            'activate ' userInfo.circusEnv ' &'...
            'circus-gui-matlab ' ...
            exportDir filesep exportFile '.dat &'...
            'exit &']);
    elseif strfind(option{1},'python')
        [status,cmdout] = system(['cd /d ' userInfo.envScriptDir ' &'...
            'activate ' userInfo.circusEnv ' &'...
            'circus-gui-python ' ...
            exportDir filesep exportFile '.dat &'...
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