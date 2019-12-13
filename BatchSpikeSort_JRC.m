%% Export .dat files with BatchExport
% start from data session's root directory
[dataFiles,allRecInfo]=BatchExport;
save('fileInfo','dataFiles','allRecInfo');

%% generate prb, meta and prm files. Create batch file
% open batch file
upDirs=regexp(cd,['(?<=\' filesep ').+?(?=\' filesep ')'],'match');
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
    exportFolder=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,allRecInfo{fileNum}.recordingName),...
        {dirListing.name},'UniformOutput',false))).name;
    dirListing = {dirListing(:).name};
    try
        probeFileName=dirListing{cellfun(@(x) contains(x,'Probe') || contains(x,'.prb'),dirListing)};
    catch
        % ask where the probe file is
    end
    JRCprobesDir=dir(fullfile(jrclust.utils.basedir(), 'probes'));
    JRCprobesNames={JRCprobesDir.name};
    JRCProbe=cellfun(@(x) contains(x,...
        replace(regexp(probeFileName,'\w+(?=Probe)','match','once'),'_','')),...
        JRCprobesNames );
    
    if logical(sum(JRCProbe))
        %copy it
        copyfile(fullfile(jrclust.utils.basedir(), 'probes',JRCprobesNames{JRCProbe}),...
            fullfile(cd,exportFolder,JRCprobesNames{JRCProbe}));
        %move to export folder
        cd(exportFolder);
        status=1;cmdout='copied probe file to directory';
    else
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
        dirListing = dir(cd);
        exportFolder=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,allRecInfo{fileNum}.recordingName),...
            {dirListing.name},'UniformOutput',false))).name;
        cd(exportFolder);
        % Generate probe file
        [status,cmdout]=GenerateJRClustProbeFile(probeParams); %recInfo.exportname
    end
    
    if status~=1
        disp('problem generating the probe file')
    else
        disp(cmdout)
        
        % find data and probe files
        dirListing=dir(cd);
        exportFileName=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'export.bin'),...
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
        
        %         oeSampRate = 30000;
        %         nSavedChans = probeParams.numChannels;
        %         %For Open Ephys %0.195 OE; %0.25 for BR
        %         oeAiRangeMax = 1.225;%allRecInfo{fileNum}.bitResolution;
        %         oeAiRangeMin = -1.225; % total range 2.45
        %         oeroTbl=[192,192];
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
        fileID = fopen([exportFileName(1:end-4) '.meta'],'w');
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
        
        %% make parameter file
        % set parameters (e.g., name of TTL file), to edit params file
        % #Trial (used for plotting PSTH for each unit after clustering)
        
        trialFile = cellfun(@(fileFormat) dir([cd filesep fileFormat]),...
            {'*.csv'},'UniformOutput', false);
        if isempty(trialFile{:})
            inputParams={'CARMode','''median''';...
                'qqFactor','4';};
        else
            trialFile=fullfile(trialFile{1}.folder,trialFile{1}.name);
            trialFile=strrep(trialFile,filesep,[filesep filesep]);
            inputParams={'CARMode','''median''';...
                'qqFactor','4';...
                'trialFile',['''' trialFile ''''];...
                'psthTimeLimits','[-0.2, 0.2]';...% [-1, 5]; % Time range to display PSTH (in seconds)
                'psthTimeBin','0.001'; ... %0.01;% Time bin for the PSTH histogram (in seconds)
                'psthXTick','0.01';... % 0.2;			% PSTH time tick mark spacing
                'nSmooth_ms_psth','10'}; % 50;			% PSTH smoothing time window (in milliseconds)
        end
        [paramFStatus,cmdout]=GenerateJRCParamFile(exportFileName,...
            probeFileName,inputParams);

        %% save prm file name to batch list
        fprintf(batchFileID,'%s\r',fullfile(cd,...
            [exportFileName(1:end-3) 'prm']));
        
    end
    % go back to root dir
    cd ..
end
fclose(batchFileID);
% cd ..
%% run JRClust on batch file
clearvars -except fileNum; clearvars -global; % if more crashes on Linux, start Matlab with software opengl (./matlab -softwareopengl)
upDirs=regexp(cd,['(?<=\' filesep ').+?(?=\' filesep ')'],'match');
% jrc('batch',[upDirs{end} '.batch']);
batchFileID = fopen([upDirs{end} '.batch'],'r');
delimiter = {''};formatSpec = '%s%[^\n\r]';
prmFiles = textscan(batchFileID, formatSpec, 'Delimiter', delimiter,...
    'TextType', 'string',  'ReturnOnError', false);
fclose(batchFileID);
prmFiles = [prmFiles{1}];

for fileNum=1:size(prmFiles,1)
    jrc('detect-sort',prmFiles{fileNum});
end

% jrc('manual',prmFiles{5});
% 
% jrc('manual',fullfile(cd,'vIRt41_0815_5300_10Hz_10ms_20mW',...
%     ['vIRt41_0815_5300_10Hz_10ms_20mW' '_export.prm']))