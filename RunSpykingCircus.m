function [status,cmdout]=RunSpykingCircus(exportDir,exportFile,option)

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
    
    % load implant list and find probe file name
    subjectName=regexp(strrep(exportFile,'_','-'),'^\w+\d+(?=-)','match');
    load([userinfo.probemap userinfo.slash 'ImplantList.mat']);
    probeID=implantList(~cellfun('isempty',...
        strfind(strrep({implantList.Mouse},'-',''),subjectName{:}))).Probe;
    probeFile=['C:\\Users\\' userinfo.user '\\spyking-circus\\probes\\' probeID '.prb'];
    
    if ~isdir(exportDir)
        %move to export directory 
        mkdir(exportDir);
        cd(exportDir);
    end
    
    if exist([exportFile '.params'],'file')==2
        %remove pre-existing parameter file
        delete([exportFile '.params'])
    end
    
    % generate template params file
    [status,cmdout] = system(['cd ' userinfo.envScriptDir ' &'...
        'activate spykc &'...
        'spyking-circus ' ...
        exportDir userinfo.slash exportFile '.dat <' userinfo.ypipe ' &'...
        'exit &']); %  final ' &' makes command run in background outside Matlab
    
    if status~=0
        return
    end
    
    % read parameters and delete file
    fid  = fopen([exportFile '.params'],'r');
    params=fread(fid,'*char')';
    fclose(fid);
    delete([exportFile '.params'])
    
    % replace parameters with user values
    params = regexprep(params,'(?<=data_offset    = )\w+(?= )','0');
    params = regexprep(params,'(?<=mapping        = )\w+.\w+.\w+(?= )', probeFile);
    params = regexprep(params,'(?<=data_dtype     = )\w+(?= )','int16');
    params = regexprep(params,'(?<=dtype_offset   = )\w+(?= )','0');
    params = regexprep(params,'(?<=sampling_rate  = )\w+(?= )','30000');
    params = regexprep(params,'(?<=N_t            = )\w+(?= )','2');
    params = regexprep(params,'(?<=spike_thresh   = )\w+(?= )','7');
    params = regexprep(params,'(?<=peaks          = )\w+(?= )','both');
    params = regexprep(params,'(?<=remove_median  = )\w+(?= )','True');
    params = regexprep(params,'(?<=max_elts       = )\w+(?= )','20000'); %20000 10000
    params = regexprep(params,'(?<=nclus_min      = )\w.\w+(?= )','0.0001'); %0.0001 0.01
    params = regexprep(params,'(?<=max_elts       = )\w+(?= )','20000'); %20000 10000
    params = regexprep(params,'(?<=smart_search   = )\w+(?= )','0.01'); %0.01 0
    params = regexprep(params,'(?<=noise_thr      = )\w.\w+(?= )','0.9');
    
    % write new params file
    fid  = fopen([exportFile '.params'],'w');
    fprintf(fid,'%s',params);
    fclose(fid);
    
    cmdout='parameter file generated';
end

if strfind(option,'previewspkc')
    % check MPI status and start if needed
    checkMPIstatus(userinfo);
    
    %% run preview
    system(['cd ' userinfo.envScriptDir ' &'...
        'activate spykc &'...
        'SETLOCAL &'...
        'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
        'spyking-circus ' ...
        exportDir userinfo.slash exportFile '.dat -p &'...
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
    [status,cmdout] = system(['cd ' userinfo.envScriptDir ' &'...
        'activate spykc &'...
        'SETLOCAL &'...
        'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
        'spyking-circus ' ...
        exportDir userinfo.slash exportFile '.dat -m filtering,whitening,clustering ' NumCPU ' &'...
        'exit'],'-echo');
    
    if status==0
        % finish fitting
        [status,cmdout] = system(['cd ' userinfo.envScriptDir ' &'...
            'activate spykc &'...
            'SETLOCAL &'...
            'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
            'spyking-circus ' ...
            exportDir userinfo.slash exportFile '.dat -m fitting &'...
            'exit &']);
    else 
        % try running on less stringent parameters and with less clusters
    end
end

%% exporting
if strfind(option,'exportspikes')
    [status,cmdout] = system(['cd ' userinfo.envScriptDir ' &'...
        'activate spykc &'...
        'SETLOCAL &'...
        'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
        'spyking-circus ' ...
        exportDir userinfo.slash exportFile '.dat -m converting ' NumCPU ' &'...
        'exit &']);
end

%% run GUI (no need for clusters here)
if strfind(option,'startGUI')
    if strfind(option,'matlab')
        [status,cmdout] = system(['cd ' userinfo.envScriptDir ' &'...
            'activate spykc &'...
            'circus-gui-matlab ' ...
            exportDir userinfo.slash exportFile '.dat &'...
            'exit &']);
    elseif strfind(option,'python')
        [status,cmdout] = system(['cd ' userinfo.envScriptDir ' &'...
            'activate spykc &'...
            'circus-gui-python ' ...
            exportDir userinfo.slash exportFile '.dat &'...
            'exit &']);
    end
end
end

function checkMPIstatus(userinfo)
envDirs=[userinfo.envRootDir ';' userinfo.envScriptDir ';' userinfo.envLibDir];

[MPIstatus,~] = system(['cd C:\Users\Vincent\spyking-circus &'...
    'SETLOCAL &'...
    'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
    '"' userinfo.MPIDir 'mpiexec.exe" -gmachinefile circus.hosts hostname']);

if MPIstatus==-1
    system(['SETLOCAL &'...
        'set PATH="' envDirs ';' userinfo.MPIDir ';' userinfo.WinDirs '" &'...
        '"' userinfo.MPIDir 'smpd.exe" -d 1 &']);
end
end