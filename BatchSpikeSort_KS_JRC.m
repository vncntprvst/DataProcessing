%% Export .dat file with BatchExport
% go to data session's root directory
rootDir=cd;
[dataFiles,allRecInfo]=BatchExport;
save('fileInfo','dataFiles','allRecInfo');
% then move to spike sorting folder
%cd(fullfile(rootDir,'SpikeSortingFolder'));
for fileNum=1:size(dataFiles,1)
    %% get recording's info
    recInfo = allRecInfo{fileNum}; %[recordingName '_recInfo'];
    %% create configuration file for KiloSort
    useGPU=1;
    userParams.useGPU=num2str(useGPU);
    [status,cmdout]=GenerateKSConfigFile([recInfo.recordingName '_export'],...
        [cd filesep recInfo.recordingName],userParams);
    if status~=1
        disp('problem generating the configuration file')
    else
        disp(cmdout)
    end
    
    %% create ChannelMap file for KiloSort
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
    probeInfo.numChannels=numel({recInfo.probeLayout.Electrode}); %or check recInfo.signals.channelInfo.channelName
    remapped=false;
    if isfield(recInfo,'probeLayout')
        switch recInfo.sys
            case 'OpenEphys'
                probeInfo.chanMap=[recInfo.probeLayout.OEChannel];
            case 'Blackrock'
                probeInfo.chanMap=[recInfo.probeLayout.BlackrockChannel];
        end
        if remapped==true
            [~,chSortIdx]=sort(probeInfo.chanMap);
            recInfo.probeLayout=recInfo.probeLayout(chSortIdx);
            probeInfo.chanMap=probeInfo.chanMap(chSortIdx);
        else
            probeInfo.chanMap=1:probeInfo.numChannels;
        end
        probeInfo.connected=true(probeInfo.numChannels,1);
        probeInfo.connected(isnan([recInfo.probeLayout.Shank]))=0;
        probeInfo.kcoords=[recInfo.probeLayout.Shank];
        probeInfo.kcoords=probeInfo.kcoords(~isnan([recInfo.probeLayout.Shank]));
        if isfield(recInfo.probeLayout,'x_geom')
            probeInfo.xcoords = [recInfo.probeLayout.x_geom];
            probeInfo.ycoords = [recInfo.probeLayout.y_geom];
        else
            probeInfo.xcoords = zeros(1,probeInfo.numChannels);
            probeInfo.ycoords = 200 * ones(1,probeInfo.numChannels);
            groups=unique(probeInfo.kcoords);
            for elGroup=1:length(groups)
                if isnan(groups(elGroup))
                    continue;
                end
                groupIdx=find(probeInfo.kcoords==groups(elGroup));
                probeInfo.xcoords(groupIdx(2:2:end))=20;
                probeInfo.xcoords(groupIdx)=probeInfo.xcoords(groupIdx)+(0:length(groupIdx)-1);
                probeInfo.ycoords(groupIdx)=...
                    probeInfo.ycoords(groupIdx)*(elGroup-1);
                probeInfo.ycoords(groupIdx(round(end/2)+1:end))=...
                    probeInfo.ycoords(groupIdx(round(end/2)+1:end))+20;
            end
        end
    end
    
%     cd(currentDir)
    [cmdout,status]=GenerateKSChannelMap(recInfo.recordingName,...
        [cd filesep recInfo.recordingName],probeInfo,recInfo.samplingRate);
    if status~=1
        disp('problem generating the configuration file')
    else
        disp(cmdout)
    end
    
    %% Run KiloSort
    % First run generated configuration file to instantiate 'ops'
    cd(recInfo.recordingName)
    run(['config_' recInfo.recordingName '_export.m']) 
    RunKS(ops,recInfo.recordingName);
    cd ..
end

for fileNum=1:size(dataFiles,1)
    %% get recording's info
    recInfo = allRecInfo{fileNum}; %[recordingName '_recInfo'];
    cd([recInfo.recordingName])
    %% run JRClust (kilosort branch)
    % jrc import-ksort /path/to/your/rez.mat sessionName % sessionName is the name typically given to the .prm file
    eval(['jrc import-ksort ' recInfo.recordingName '_rez.mat ' recInfo.recordingName])
    cd ..
end