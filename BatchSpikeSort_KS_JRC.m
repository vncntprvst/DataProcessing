%% Export .dat files with BatchExport
% start from data session's root directory
[dataFiles,allRecInfo]=BatchExport;
save('fileInfo','dataFiles','allRecInfo');

%% generate config and channel map files. Create batch file
% open batch file
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
            contains(x,'.prb'),{dirListing(:).name})).name;
    catch
        % ask where the probe file is
    end
    probeLayout=load(probeFileName);
    flnm=fieldnames(probeLayout);
    recInfo.probeLayout=probeLayout.(flnm{1});
    remapped=false;
    probeParams.probeFileName=replace(regexp(probeFileName,'\w+(?=Probe)','match','once'),'_','');
    probeParams.numChannels=numel({recInfo.probeLayout.Electrode}); %or check recInfo.signals.channelInfo.channelName %number of channels
    if sum(~cellfun(@isempty, cellfun(@(pattern)...
            strfind(probeParams.probeFileName,pattern),...
            {'cnt','CNT'},'UniformOutput',false)))
        probeParams.pads=[11 15]; % Dimensions of the recording pad (height by width in micrometers).
    else
        probeParams.pads=[11 15];
    end
    probeParams.maxSite=4; % Max number of sites to consider for merging
    if isfield(recInfo,'probeLayout')
        % Channel map
        if remapped==true
            probeParams.chanMap=1:probeParams.numChannels;
        else
            switch recInfo.sys
                case 'OpenEphys'
                    probeParams.chanMap=[recInfo.probeLayout.OEChannel];
                case 'Blackrock'
                    probeParams.chanMap=[recInfo.probeLayout.BlackrockChannel];
            end
        end
        
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
        
        probeParams.shanks=[recInfo.probeLayout.Shank];
        probeParams.shanks=probeParams.shanks(~cellfun('isempty',{recInfo.probeLayout.Electrode}) &...
            ~isnan([recInfo.probeLayout.Shank]));
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
    else
    end
    
    %move to export folder
    exportFolder=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,allRecInfo{fileNum}.recordingName),...
        {dirListing.name},'UniformOutput',false))).name;
    cd(exportFolder);
    % Generate channel map file
    probeFileName=regexp(probeFileName,'\w+(?=\W)','match','once');
    [cmdout,status,chMapFName]=GenerateKSChannelMap(probeFileName,cd,probeParams,recInfo.samplingRate);
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
        
        %% save config file name to batch list
        fprintf(batchFileID,'%s\r',fullfile(cd,configFName));
    end
    % go back to root dir
    cd ..
end
fclose(batchFileID);
%% Run KiloSort on batch file
clearvars -except fileNum; clearvars -global; % if more crashes on Linux, start Matlab with software opengl (./matlab -softwareopengl)
upDirs=regexp(cd,['(?<=\' filesep ').+?(?=\' filesep ')'],'match');
batchFileID = fopen([upDirs{end} '.batch'],'r');
delimiter = {''};formatSpec = '%s%[^\n\r]';
prmFiles = textscan(batchFileID, formatSpec, 'Delimiter', delimiter,...
    'TextType', 'string',  'ReturnOnError', false);
fclose(batchFileID);
prmFiles = [prmFiles{1}];

for fileNum=1:size(prmFiles,1)
    RunKS(prmFiles{fileNum});
end

% for fileNum=1:size(dataFiles,1)
%     %% get recording's info
%     recInfo = allRecInfo{fileNum}; %[recordingName '_recInfo'];
%     cd([recInfo.recordingName])
%     %% run JRClust (kilosort branch)
%     % jrc import-ksort /path/to/your/rez.mat sessionName % sessionName is the name typically given to the .prm file
    eval(['jrc import-ksort ' recInfo.recordingName '_rez.mat ' recInfo.recordingName])
%     cd ..
% end

    eval(['jrc import-ksort ' cd]); %[cd filesep 'rez.mat ']])

