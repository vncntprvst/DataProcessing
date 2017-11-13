function [paramFStatus,cmdout]=GenerateParamFile(exportFile,exportDir,userParams,userinfo)

% Creates parameter file for Spyking Circus 
% (see http://spyking-circus.readthedocs.io/ for info)
% Environment variables (defined in "userinfo" structure), as well as 
% processing parameters ("userParams") need to be adjusted by user.
% Data file (exportFile) naming convention is as follow: 
% {Subject}_{Session}_{[opt]Condition}_{RecordingSystem}_{ChannelNumber}_{PreProcessing}
% e.g.: PrV77_63_ManualStim_Bet_BR_16Ch_nopp. Can be changed when defining
% "subjectName". subjectName=regexp(strrep(exportFile,'_','-'),'^\w+\d+(?=-)','match');
% See also https://github.com/vncntprvst/DataExport for DataExportGUI, to
% export data files from Matlab.
% Probe IDs are listed with their respective subject in a implant list
% ("ImplantList.mat"). Adapt "probeID" and "probeFile" to your own needs
% accordingly.
% Runs on Windows 7, may require modifications on other platforms
% Written by Vincent Prevosto, May 2016

paramFStatus=0;
switch nargin
    case 0
        exportDir=cd;
        %select most recent .dat file
        exportFile=dir;
        [~,fDateIdx]=sort([exportFile.datenum],'descend');
        exportFile=exportFile(fDateIdx);
        exportFile=exportFile(~cellfun('isempty',cellfun(@(x) strfind(x,'.dat'),...
            {exportFile.name},'UniformOutput', false))).name;
        userinfo=UserDirInfo;
        userParams={'raw_binary';'30000';'int16';'32';'';'3';'8';'both';'True';'10000';...
        '0.002';'True';'1';'2, 5';'0.8';'True';'True'};
    case 2
        userinfo=UserDirInfo;
        userParams={'raw_binary';'30000';'int16';'32';'';'3';'8';'both';'True';'10000';...
        '0.002';'True';'1';'2, 5';'0.8';'True';'True'};
    case 3
        userinfo=UserDirInfo;
    case 4
    otherwise
        disp('missing argument for GenerateParamFile')
        return
end

% load implant list and find probe file name
if strcmp(userParams{5},'')
    subjectName=regexp(exportFile,'^\S+?(?=\W)','match');
    if isempty(subjectName) % different naming convention
        subjectName=regexp(strrep(exportFile,'_','-'),'^\w+(?=-)','match');
    end
    load([userinfo.probemap filesep 'ImplantList.mat']);
    try 
        probeID=implantList(contains(strrep({implantList.Mouse},'-',''),subjectName,'IgnoreCase',true)).Probe;
    catch %'default'
        probeID=implantList(contains(strrep({implantList.Mouse},'-',''),'default','IgnoreCase',true)).Probe;
    end
%     probeFile=['C:\\Users\\' userinfo.user '\\spyking-circus\\probes\\' probeID '.prb'];
    [~,scDirectory]=system('conda info -e');
    scDirectory=cell2mat(regexp(scDirectory,['(?<=' userinfo.circusEnv '                   ).+?(?=\n)'],'match'));
    if isempty(scDirectory)
        scDirectory=cell2mat(regexp(scDirectory,'(?<=root                  \*  ).+?(?=\n)','match'));
    end
    % find probes directory
    dSep=[filesep filesep];
    if exist([scDirectory filesep 'data' filesep 'spyking-circus' filesep 'probes'],'dir') 
        probeFile=[regexprep(scDirectory,['\' filesep],['\' dSep]) dSep 'data' dSep 'spyking-circus' dSep 'probes' dSep probeID '.prb'];
    elseif exist([userinfo.circusHomeDir filesep 'probes'],'dir')
        probeFile=[regexprep(userinfo.circusHomeDir,['\' filesep],['\' dSep]) dSep 'probes' dSep probeID '.prb'];
    else
        probesDir= uigetdir(cd,'Select folder where probe mapings are located');
        probeFile=[probesDir dSep probeID '.prb'];
    end
    userParams{5}=probeFile;
end

if ~isdir(exportDir)
    %create export directory
    mkdir(exportDir);
end
cd(exportDir);
    
if exist([exportFile '.params'],'file')==2
    %remove pre-existing parameter file
    delete([exportFile '.params'])
end

% generate template params file
[status,cmdout] = system(['cd ' userinfo.envScriptDir ' &'...
    'activate ' userinfo.circusEnv ' &'...
    'spyking-circus ' ...
    exportDir filesep exportFile '.dat <' userinfo.ypipe ' &'...
     'exit &']); %  final ' &' makes command run in background outside Matlab

if status~=0
    return
end
tic;
accuDelay=0;
disp('Writing generic parameter file')
while ~exist([exportFile '.params'],'file')
    timeElapsed=toc;
    if timeElapsed-accuDelay>1
       accuDelay=timeElapsed;
        fprintf('%s ', '*'); 
    end
end     
    
% read parameters and delete file
fid  = fopen([exportFile '.params'],'r');
dftParams=fread(fid,'*char')';
fclose(fid);
delete([exportFile '.params'])

% replace parameters with user values
% dftParams = regexprep(dftParams,'(?<=data_offset\s+=\s)\w+(?=\s)',userParams{1});
dftParams = regexprep(dftParams,'(?<=file_format\s+=\s)\s+(?=#)',[userParams{1} '\r\n'...
'sampling_rate  = ' userParams{2} '\r\n'...
'data_dtype     = ' userParams{3} '\r\n'...
'nb_channels    = ' userParams{4} ' ']);
dftParams = regexprep(dftParams,'(?<=mapping\s+=\s)~/probes/mea_252.prb(?=\s)', userParams{5});
% dftParams = regexprep(dftParams,'(?<=data_dtype \s+=\s)\w+(?=\s)',userParams{3});
% dftParams = regexprep(dftParams,'(?<=dtype_offset  \s+=\s)\w+(?=\s)',userParams{4});
% dftParams = regexprep(dftParams,'(?<=sampling_rate \s+=\s)\w+(?=\s)',userParams{5});
dftParams = regexprep(dftParams,'(?<=N_t\s+=\s)\w+(?=\s)',userParams{6}); %Default: 5; Try: 2
dftParams = regexprep(dftParams,'(?<=spike_thresh\s+=\s)\w+(?=\s)',userParams{7}); %Default: 6; Try: 8
dftParams = regexprep(dftParams,'(?<=peaks\s+=\s)\w+(?=\s)',userParams{8}); %Default: negative; Try: both
dftParams = regexprep(dftParams,'(?<=remove_median\s+=\s)\w+(?=\s)',userParams{9}); %Default: False; Try: True
dftParams = regexprep(dftParams,'(?<=max_elts\s+=\s)\w+(?=\s)',userParams{10}); %Default: 10000; Try: 10000 (20000)
dftParams = regexprep(dftParams,'(?<=nclus_min\s+=\s)\w.\w+(?=\s)',userParams{11}); %Default: 0.002; Try 0.005 (0.0001 0.01)
dftParams = regexprep(dftParams,'(?<=smart_search\s+=\s)\w+(?=\s)',userParams{12}); %Default: True; Try: True
dftParams = regexprep(dftParams,'(?<=cc_merge\s+=\s)\w.\w+(?=\s)',userParams{13}); %Default: 0.975; Try: 1
dftParams = regexprep(dftParams,'(?<=dispersion\s+=\s\()\w+, \w+(?=\) )',userParams{14}); %Default: (5, 5); Try: 5, 5
dftParams = regexprep(dftParams,'(?<=noise_thr\s+=\s)\w.\w+(?=\s)',userParams{15}); %Default: 0.8; Try: 0.9
dftParams = regexprep(dftParams,'(?<=collect_all\s+=\s)\w+(?=\s)',userParams{16}); %Default: False; Try: True
dftParams = regexprep(dftParams,'(?<=correct_lag\s+=\s)\w+(?=\s)',userParams{17}); %Default: True; Try: True

% write new params file
fid  = fopen([exportFile '.params'],'w');
fprintf(fid,'%s',dftParams);
fclose(fid);

cmdout='parameter file generated';
paramFStatus=1;