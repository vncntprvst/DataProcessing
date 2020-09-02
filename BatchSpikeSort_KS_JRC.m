%% Export .dat files with BatchExport
% start from data session's root directory
[dataFiles,allRecInfo]=BatchExport;
save('fileInfo','dataFiles','allRecInfo');
%
%% generate config and channel map files. Create batch file
if ~exist('dataFiles','var'); load('fileInfo.mat'); end
% open batch file to save generated parameter files' name and directory
upDirs=regexp(cd,['(?<=\' filesep ').+?(?=\' filesep ')'],'match');
batchFileID = fopen([upDirs{end} '.batch'],'w');
% loop through all session's recordings
for fileNum=1:size(dataFiles,1)
    %% get recording's info
    recInfo = allRecInfo{fileNum};
    if isempty(recInfo); continue; end
    
    %% create ChannelMap file for KiloSort
    % load probe file
    dirListing = dir(cd);
    %     exportFolder=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,allRecInfo{fileNum}.recordingName),...
    %         {dirListing.name},'UniformOutput',false))).name;
    try
        probeFileName=dirListing(cellfun(@(x) contains(x,'Probe') ||...
            contains(x,'.prb') || contains(x,'.json'),{dirListing(:).name})).name;
    catch
        % ask where the probe file is
        filePath  = mfilename('fullpath');
        filePath = regexp(filePath,['.+(?=\' filesep '.+\' filesep '.+$)'],'match','once'); %removes filename
        [probeFileName,probePathName] = uigetfile('*.json','Select the probe file',...
            fullfile(filePath,'DataExport', 'probemaps'));
        copyfile(fullfile(probePathName,probeFileName),fullfile(cd,probeFileName));
    end
    if contains(probeFileName,'.json') %|| contains(probeFileName,'.prb')
        probeLayout = fileread(probeFileName);
        recInfo.probeLayout = jsondecode(probeLayout);
    else
        probeLayout=load(probeFileName);
        flnm=fieldnames(probeLayout);
        recInfo.probeLayout=probeLayout.(flnm{1});
    end
    remapped=false;
    probeParams.probeFileName=probeFileName(1:end-4);
    try %non generic probe
        probeParams.probeFileName=replace(regexp(probeParams.probeFileName,'\w+(?=Probe)','match','once'),'_','');
    catch
    end
    if isempty(probeParams.probeFileName); probeParams.probeFileName=probeFileName; end
    probeParams.numChannels=numel({recInfo.probeLayout.Electrode}); %or check recInfo.signals.channelInfo.channelName %number of channels
    
    if isfield(recInfo,'probeLayout')
        if isfield(recInfo.probeLayout,'surfaceDim')
            probeParams.pads=recInfo.probeLayout.surfaceDim;
        end
        if isfield(recInfo.probeLayout,'maxSite')
            probeParams.maxSite=recInfo.probeLayout.maxSite;
        end
        % Channel map
        if remapped==true
            probeParams.chanMap=1:probeParams.numChannels;
        else
            switch recInfo.sys
                case 'OpenEphys'
                    probeParams.chanMap={recInfo.probeLayout.OEChannel};
                case 'Blackrock'
                    probeParams.chanMap={recInfo.probeLayout.BlackrockChannel};
            end
            % check for unconnected / bad channels
            if isfield(recInfo.probeLayout,'connected')
                probeParams.connected=logical(recInfo.probeLayout.connected);
                probeParams.chanMap=probeParams.chanMap{:}(probeParams.connected);
            else
                probeParams.connected=~cellfun(@isempty, probeParams.chanMap);
                probeParams.chanMap=[probeParams.chanMap{:}];
            end
        end
        probeParams.shanks=[recInfo.probeLayout.Shank];
        probeParams.shanks=probeParams.shanks(probeParams.connected);
        % probeParams.shanks=probeParams.shanks(~isnan([recInfo.probeLayout.Shank]));
        
        %now adjust
        probeParams.numChannels=sum(probeParams.connected);
        probeParams.connected=logical(probeParams.chanMap);
        
        if max(probeParams.chanMap)>probeParams.numChannels
            if  numel(probeParams.chanMap)==probeParams.numChannels
                %fine, just need adjusting channel numbers
                [~,probeParams.chanMap]=sort(probeParams.chanMap);
                [~,probeParams.chanMap]=sort(probeParams.chanMap);                
            else
                disp('There''s an issue with the channel map')
            end
        end
        
        %geometry:
        %         Location of each site in micrometers. The first column corresponds
        %         to the width dimension and the second column corresponds to the depth
        %         dimension (parallel to the probe shank).
        
        
        if isfield(recInfo.probeLayout,'geometry')
            probeParams.geometry=recInfo.probeLayout.geometry;
        else
            if isfield(recInfo.probeLayout,'x_geom')
                xcoords=[recInfo.probeLayout.x_geom];
                ycoords=[recInfo.probeLayout.y_geom];
            else
                xcoords = zeros(1,probeParams.numChannels);
                ycoords = 200 * ones(1,probeParams.numChannels);
                groups=unique(probeParams.shanks);
                for elGroup=1:length(groups)
                    if isnan(groups(elGroup)) || groups(elGroup)==0
                        continue;
                    end
                    groupIdx=find(probeParams.shanks==groups(elGroup));
                    xcoords(groupIdx(2:2:end))=20;
                    xcoords(groupIdx)=xcoords(groupIdx)+(0:length(groupIdx)-1);
                    ycoords(groupIdx)=...
                        ycoords(groupIdx)*(elGroup-1);
                    ycoords(groupIdx(round(end/2)+1:end))=...
                        ycoords(groupIdx(round(end/2)+1:end))+20;
                end
            end
            probeParams.geometry=[xcoords;ycoords]';
        end
    else
        if sum(~cellfun(@isempty, cellfun(@(pattern)...
                strfind(probeParams.probeFileName,pattern),...
                {'cnt','CNT'},'UniformOutput',false)))
            probeParams.pads=[15 11]; % Dimensions of the recording pad (height by width in micrometers).
        else
            probeParams.pads=[16 10];
        end
        
        probeParams.maxSite=4; % Max number of sites to consider for merging
        
    end
    
    %move to export folder
    exportFolder=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,allRecInfo{fileNum}.recordingName),...
        {dirListing.name},'UniformOutput',false))).name;
    cd(exportFolder);
    probeParams.probeFileName=regexp(probeFileName,'\w+(?=\W)','match','once');
    
    % Generate JRClust probe file
    GenerateJRClustProbeFile(probeParams);
    
    % Generate KS channel map file
    [cmdout,status,chMapFName]=GenerateKSChannelMap(probeParams.probeFileName,...
        cd,probeParams,recInfo.samplingRate);
    if status~=1
        disp('problem generating the channel map file')
    else
        disp(cmdout)
        
        %% create configuration file for KiloSort
        userParams.chanMap = fullfile(cd,chMapFName);   % channel map path
        userParams.fs = recInfo.samplingRate;           % sample rate
        userParams.useGPU = true;                       % has to be true in KS2
        userParams.exportDir = cd;
        userParams.tempDir = 'V:\Temp';
        userParams.fbinary = fullfile(userParams.exportDir, [recInfo.recordingName '_export.bin']);
        userParams.NchanTOT = numel(probeParams.chanMap);
        userParams.trange = [0 Inf];
        [status,cmdout,configFName]=GenerateKSConfigFile(recInfo.recordingName,cd,userParams);
        
        %% save KS config file name to batch list
        fprintf(batchFileID,'%s\r',fullfile(cd,configFName));
        
        %% Generate .meta file (will be used later for import of KS result into JRClust)
        % find data and probe files
        dirListing=dir(cd);
        exportFileName=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'export.bin'),...
            {dirListing.name},'UniformOutput',false))).name;
        exportFileName=exportFileName(1:end-4);
        probeFileName=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'.prb'),...
            {dirListing.name},'UniformOutput',false))).name;
        
        % fill values
        if contains(allRecInfo{1, 1}.sys,'OpenEphys')
            voltRange=0.00639;
        elseif contains(allRecInfo{1, 1}.sys,'BlackRock)')
            voltRange=0.0082;
        else
            voltRange=0.0082;
        end
        if isfield(recInfo,'channelMapping')
            nChans= numel(recInfo.channelMapping);
        elseif isfield(recInfo,'probeLayout')
            nChans= size(recInfo.probeLayout,1);
        elseif isfield(recInfo,'numRecChan')
            nChans=recInfo.numRecChan;
        end
        
        % create file
        fileID = fopen([exportFileName '.meta'],'w');
        fprintf(fileID,'nChans = %d\r',nChans);
        fprintf(fileID,'sampleRate = %d\r',30000);
        fprintf(fileID,'bitScaling = %1.3f\r',allRecInfo{fileNum}.bitResolution );
        fprintf(fileID,'rangeMax = %d\r',voltRange);
        fprintf(fileID,'rangeMin = %d\r',-voltRange);
        fprintf(fileID,'adcBits = %d\r',16);
        fprintf(fileID,'gain = %d\r',1);
        fprintf(fileID,'dataType = %s\r', 'int16');
        fprintf(fileID,'probe_file = %s\r', probeFileName(1:end-4));
        fprintf(fileID,'paramDlg = %d\r',0);
        fprintf(fileID,'advancedParam = %s\r', 'Yes');
        fclose(fileID);
        
    end
    % go back to root dir
    cd ..
end
fclose(batchFileID);
clearvars -except fileNum; clearvars -global; % if more crashes on Linux, start Matlab with software opengl (./matlab -softwareopengl)

%% Run KiloSort on batch file
% open batch file
upDirs=regexp(cd,['(?<=\' filesep ').+?(?=\' filesep ')'],'match');
batchFileID = fopen([upDirs{end} '.batch'],'r');
delimiter = {''};formatSpec = '%s%[^\n\r]';
prmFiles = textscan(batchFileID, formatSpec, 'Delimiter', delimiter,...
    'TextType', 'string',  'ReturnOnError', false);
fclose(batchFileID);
prmFiles = [prmFiles{1}];
% Run KS2
for fileNum=1:size(prmFiles,1)
    try
        RunKS(prmFiles{fileNum});
    catch
        close all; continue
    end
    close all
end

%% import results into JRC
if ~exist('dataFiles','var'); load('fileInfo.mat'); end
for fileNum=1:size(dataFiles,1)
    try
        recInfo = allRecInfo{fileNum};
        cd([recInfo.recordingName])
        jrc('import-ksort',cd,false);
        cd ..
    catch
        continue
    end
end


