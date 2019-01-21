%% Export .dat file with BatchExport
% go to data session's root directory
rootDir=cd;
[dataFiles,allRecInfo]=BatchExport;
% then move to spike sorting folder
%cd(fullfile(rootDir,'SpikeSortingFolder'));
save('fileInfo','dataFiles','allRecInfo');
for fileNum=1:size(dataFiles,1)
    
    %% get recording's info
    recInfo = allRecInfo{fileNum}; %[recordingName '_recInfo'];
    %% create probe and parameter files for JRClust
    % load probe file
    %     currentDir=cd;  cd ..
    dirlisting = dir(cd);
    dirlisting = {dirlisting(:).name};
    probeFileName=dirlisting{cellfun(@(x) contains(x,'Probe'),dirlisting)};
    if ~isempty(dirlisting)
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
        
        probeParams.geometry=[xcoords;ycoords]';
        
    else
    end
    
    %move to export folder
    exportFolder=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,allRecInfo{fileNum}.recordingName),...
        {dirListing.name},'UniformOutput',false))).name;
    cd(exportFolder);
    
    [status,cmdout]=GenerateJRClustProbeFile(probeParams); %recInfo.exportname
    
    if status~=1
        disp('problem generating the probe file')
    else
        disp(cmdout)
        disp('creating parameter file for JRClust')
        % keep the GUI's directory because JRClust will revert the
        % environment to its native state
        exportGUIDir=mfilename('fullpath');
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
        %For Open Ephys
        oeAiRangeMax = 1.225;%allRecInfo{fileNum}.bitResolution; %0.195 OE; %0.25 for BR
        oeAiRangeMin = -1.225; % total range 2.45
        oeroTbl=[192,192];
        
        fileID = fopen([exportFileName(1:end-4) '.meta'],'w');
        fprintf(fileID,'oeSampRate = %d\r',imSampRate );
        fprintf(fileID,'nSavedChans = %d\r',nSavedChans );
        fprintf(fileID,'oeAiRangeMax = %1.3f\r',imAiRangeMax );
        fprintf(fileID,'oeAiRangeMin = %1.3f\r',imAiRangeMin );
        fprintf(fileID,'oeroTbl = %d, %d\r',oeroTbl );
        fclose(fileID);
        global fDebug_ui
        fDebug_ui=1; % so that fAsk =0 (removes warnings and prompts)
        jrc('makeprm',exportFileName,probeFileName);
        clear global 
        % set the GUI's path back
%         addpath(cell2mat(regexp(exportGUIDir,['.+(?=\' filesep ')'],'match')));
    end
    
end

%% Batch file for JRCust
% jrc batch myparam123.batch
% Content of myparam123.batch:
%
%     myparam1.prm
%     myparam2.prm
%     myparam3.prm
%
% Alternatively, a user can supply a list of .bin files in the batch file using a parameter file "myparam.prm" by running
%
%     jrc batch mybin123.batch myparam.prm
%
% Content of mybin123.batch:
%
%     mybin1.bin
%     mybin2.bin
%     mybin3.bin


for fileNum=1:size(dataFiles,1)
    %% get recording's info
    recInfo = allRecInfo{fileNum}; %[recordingName '_recInfo'];
    cd([recInfo.recordingName])
    %% run JRClust (kilosort branch)
    % jrc import-ksort /path/to/your/rez.mat sessionName % sessionName is the name typically given to the .prm file
    eval(['jrc import-ksort ' recInfo.recordingName '_rez.mat ' recInfo.recordingName])
    cd ..
end