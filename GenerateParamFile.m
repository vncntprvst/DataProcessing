function [paramFStatus,cmdout]=GenerateParamFile(exportFile,exportDir,userParams,userinfo)

% Creates parameter file for Spyking Circus 
% (see http://spyking-circus.readthedocs.io/ for info)
% Environement variables (defined in "userinfo" structure), as well as 
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
        userParams={'0';'';'int16';'0';'30000';'2';'8';'both';'True';'10000';...
        '0.005';'True';'1';'1, 1';'0.9';'True'};
    case 2
        userinfo=UserDirInfo;
        userParams={'0';'';'int16';'0';'30000';'2';'8';'both';'True';'10000';...
        '0.005';'True';'1';'1, 1';'0.9';'True'};
    case 3
        userinfo=UserDirInfo;
    case 4
    otherwise
        disp('missing argument for GenerateParamFile')
        return
end

% load implant list and find probe file name
if strcmp(userParams{2},'')
    subjectName=regexp(strrep(exportFile,'_','-'),'^\w+\d+(?=-)','match');
    if isempty(subjectName) % different naming convention
        subjectName=regexp(strrep(exportFile,'_','-'),'^\w+(?=-)','match');
    end
    load([userinfo.probemap userinfo.slash 'ImplantList.mat']);
    try
        probeID=implantList(~cellfun('isempty',...
            strfind(strrep({implantList.Mouse},'-',''),subjectName{:}))).Probe;
    catch
        probeID=implantList(~cellfun('isempty',...
            strfind(strrep({implantList.Mouse},'-',''),'default'))).Probe;
    end
    probeFile=['C:\\Users\\' userinfo.user '\\spyking-circus\\probes\\' probeID '.prb'];
    userParams{2}=probeFile;
end

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
dftParams = regexprep(dftParams,'(?<=data_offset    = )\w+(?= )',userParams{1});
dftParams = regexprep(dftParams,'(?<=mapping        = )\w+.\w+.\w+(?= )', probeFile);
dftParams = regexprep(dftParams,'(?<=data_dtype     = )\w+(?= )',userParams{3});
dftParams = regexprep(dftParams,'(?<=dtype_offset   = )\w+(?= )',userParams{4});
dftParams = regexprep(dftParams,'(?<=sampling_rate  = )\w+(?= )',userParams{5});
dftParams = regexprep(dftParams,'(?<=N_t            = )\w+(?= )',userParams{6});
dftParams = regexprep(dftParams,'(?<=spike_thresh   = )\w+(?= )',userParams{7});
dftParams = regexprep(dftParams,'(?<=peaks          = )\w+(?= )',userParams{8});
dftParams = regexprep(dftParams,'(?<=remove_median  = )\w+(?= )',userParams{9});
dftParams = regexprep(dftParams,'(?<=max_elts       = )\w+(?= )',userParams{10}); %20000 10000
dftParams = regexprep(dftParams,'(?<=nclus_min      = )\w.\w+(?= )',userParams{11}); %0.0001 0.01
dftParams = regexprep(dftParams,'(?<=smart_search   = )\w+(?= )',userParams{12}); %0.01 0
dftParams = regexprep(dftParams,'(?<=cc_merge       = )\w.\w+(?= )',userParams{13}); 
dftParams = regexprep(dftParams,'(?<=dispersion     = \()\w+, \w+(?=\) )',userParams{14});
dftParams = regexprep(dftParams,'(?<=noise_thr      = )\w.\w+(?= )',userParams{15});
dftParams = regexprep(dftParams,'(?<=correct_lag    = )\w+(?= )',userParams{16});

% write new params file
fid  = fopen([exportFile '.params'],'w');
fprintf(fid,'%s',dftParams);
fclose(fid);

cmdout='parameter file generated';
paramFStatus=1;