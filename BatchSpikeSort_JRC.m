%% Export .dat files with BatchExport
% start from data session's root directory
[dataFiles,allRecInfo]=BatchExport;
save('fileInfo','dataFiles','allRecInfo');

%% generate prb, meta and prm files. Create batch file
% open batch file
upDirs=regexp(cd,'(?<=\/).+?(?=\/)','match');
batchFileID = fopen([upDirs{end} '.batch'],'w');
% loop through all session's recordings
for fileNum=1:size(dataFiles,1)
    
    %% get recording's info
    recInfo = allRecInfo{fileNum}; %[recordingName '_recInfo'];
    if isempty(recInfo)
        continue
    end
    %% create probe and parameter files for JRClust
    % load probe file
    %     currentDir=cd;  cd ..
    dirListing = dir(cd);
    dirListing = {dirListing(:).name};
    probeFileName=dirListing{cellfun(@(x) contains(x,'Probe'),dirListing)};
    if ~isempty(dirListing)
        probeLayout=load(probeFileName);
    else
        % ask where the probe file is
    end
    flnm=fieldnames(probeLayout);
    recInfo.probeLayout=probeLayout.(flnm{1});
    remapped=false;
    
    probeParams.numChannels=numel({recInfo.probeLayout.Electrode}); %or check recInfo.signals.channelInfo.channelName %number of channels
    probeParams.pads=[15 15];% Dimensions of the recording pad (height by width in micrometers).
    probeParams.maxSite=4; % Max number of sites to consider for merging
    if isfield(recInfo,'probeLayout')
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
    dirListing = dir(cd);
    exportFolder=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,allRecInfo{fileNum}.recordingName),...
        {dirListing.name},'UniformOutput',false))).name;
    cd(exportFolder);
    % Generate probe file
    [status,cmdout]=GenerateJRClustProbeFile(probeParams); %recInfo.exportname
    
    if status~=1
        disp('problem generating the probe file')
    else
        disp(cmdout)
        
        % find data and probe files
        dirListing=dir(cd);
        exportFileName=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'export.dat'),...
            {dirListing.name},'UniformOutput',false))).name;
        probeFileName=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'.prb'),...
            {dirListing.name},'UniformOutput',false))).name;
        
        %% Generate .meta file
        %Sampling rate (Hz): read from imSampRate (or niSampRate for NI recordings) in .meta file
        % # channels saved: read from nSavedChans in .meta file
        % Microvolts per bit (uV/bit): computed from imAiRangeMax, imAiRangeMin and vnIMRO (or niMNGain for NI recordings) in .meta file
        % Header offset (in bytes): 0 for SpikeGLX, since no header is stored in the binary file (.bin).
        % Data Type: select from {'int16', 'uint16', 'single', 'double'}; 'int16' for SpikeGLX format
        % Neuropixels probe option: 0 if N/A; read from imroTbl in .meta file
        
        %
        % P = struct('sRateHz', S_meta.sRateHz, 'uV_per_bit', S_meta.scale, 'nChans',...
        %     S_meta.nChans, 'vcDataType', S_meta.vcDataType);
        % S.scale = ((S.rangeMax-S.rangeMin)/(2^S.ADC_bits))/S.auxGain * 1e6; %uVolts
        
        oeSampRate = 30000;
        nSavedChans = probeParams.numChannels;
        %For Open Ephys %0.195 OE; %0.25 for BR
        oeAiRangeMax = 1.225;%allRecInfo{fileNum}.bitResolution;
        oeAiRangeMin = -1.225; % total range 2.45
        oeroTbl=[192,192];
        
        fileID = fopen([exportFileName(1:end-4) '.meta'],'w');
        fprintf(fileID,'oeSampRate = %d\r',oeSampRate );
        fprintf(fileID,'nSavedChans = %d\r',nSavedChans );
        fprintf(fileID,'oeAiRangeMax = %1.3f\r',oeAiRangeMax );
        fprintf(fileID,'oeAiRangeMin = %1.3f\r',oeAiRangeMin );
        fprintf(fileID,'oeroTbl = %d, %d\r',oeroTbl );
        fclose(fileID);
        
        %% make parameter file
        % get name of TTL file, to edit params file
        vcFile_trial = cellfun(@(fileFormat) dir([cd filesep fileFormat]),...
            {'*.csv'},'UniformOutput', false);
        if isempty(vcFile_trial{:})
            vcFile_trial='';
        else
            vcFile_trial=vcFile_trial{1}.name;
        end
        [paramFStatus,cmdout]=GenerateJRCParamFile(exportFileName,...
            probeFileName,{'vcFile_trial',vcFile_trial});
        
        %edit param file to include sync file
        
        %% save prm file name to batch list
        fprintf(batchFileID,'%s\r',fullfile(cd,...
            [exportFileName(1:end-4) '_' probeFileName(1:end-4) '.prm']));
        
    end
    % go back to root dir
    cd ..
end
fclose(batchFileID);

%% run JRClust on batch file
clearvars; clearvars -global;
upDirs=regexp(cd,'(?<=\/).+?(?=\/)','match');
jrc('batch',[upDirs{end} '.batch']);
