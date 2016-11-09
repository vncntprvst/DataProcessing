%% Get spike clusters, times, waveforms
function [spikeData,Trials]=GetSpikeData(KeepChans)

%% Get file path
[fName,dirName] = uigetfile({'*.mat; *.hdf5; *.npy','Processed data';'*.dat','Flat data';...
    '*.*','All Files' },'Select processed spike data','C:\Data\export');
cd(dirName);

%% load file data

if strfind(fName,'.mat')
    load(fName);
    %load other data
    fileName=regexp(fName,'.+(?=_\w+.\w+$)','match');
    try
        load([fileName{:} '_raw.mat']);
    catch
    end
    try
        load([fileName{:} '_trials.mat']);
    catch
        Trials=[];
    end
    if ~strfind(fName,'_spikesResorted')
        load([fileName{:} '_spikes.mat']);
    end
    load([fileName{:} '_info.mat']);
    
elseif strfind(fName,'.hdf5')
    fileName=regexp(fName,'\w+(?=\.\w+\.)','match','once')
elseif strfind(fName,'.npy') %output from phy GUI
    spikeData=Load_phyResults(dirName);
    cd('..\..'); %check two folders up, original export/process data folder
    exportDirListing=dir(cd); %regexp(cd,'\w+$','match')
    Trials=importdata(exportDirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'_trials.'),...
        {exportDirListing.name},'UniformOutput',false))).name);
    return
end

%Select channels

if ~exist('KeepChans','var') || isempty(KeepChans)
    KeepChans=numal(Spikes.HandSort.Units);
end

% KeepChans=Spikes.Offline_Threshold.channel;
% KeepChans=10;

for ChNum=1:length(KeepChans)
    %% load spike data
    clusters=unique(Spikes.HandSort.Units{KeepChans(ChNum),1});
    if strfind(fName,'_spikesResorted')
        % get clusters spiketimes
        for clusNum=1:length(clusters)
            spikeData.(['Clus' num2str(clusters(clusNum))]).Cluster=clusters(clusNum);
            spikeData.(['Clus' num2str(clusters(clusNum))]).SpikeTimes=Spikes.HandSort.SpikeTimes{KeepChans(ChNum),1}(Spikes.HandSort.Units{KeepChans(ChNum),1}==clusters(clusNum));
            spikeData.(['Clus' num2str(clusters(clusNum))]).Waveforms=Spikes.HandSort.Waveforms{KeepChans(ChNum),1}(:,Spikes.HandSort.Units{KeepChans(ChNum),1}==clusters(clusNum));
        end
        
        if sum(~cellfun('isempty',cellfun(@(x) strfind(x,'.phy'),{dataDirListing.name},'UniformOutput',false)))
            phyData=Load_phyResults([dirName fileName{:} '\' fileName{:} '.GUI']);
        end
        
    elseif strfind(fileName,'.mat')
        % from Spike2
        Spikes.Offline_Sorting.Units{KeepChans(ChNum),1}=nw_401.codes(:,1);
        Spikes.Offline_Sorting.SpikeTimes{3,1}=uint32(nw_401.times*rec_info.samplingRate);
        Spikes.Offline_Sorting.Waveforms{3,1}=nw_401.values;
        % get clusters spiketimes
        for clusNum=1:length(clusters)
            spikeData.(['Clus' num2str(clusters(clusNum))])=clusNum;
            spikeData.(['Clus' num2str(clusters(clusNum))]).SpikeTimes=Spikes.Offline_Sorting.SpikeTimes{KeepChans(ChNum),1}(Spikes.Offline_Sorting.Units{KeepChans(ChNum),1}==clusters(clusNum));
            spikeData.(['Clus' num2str(clusters(clusNum))]).Waveforms=Spikes.Offline_Sorting.Waveforms{KeepChans(ChNum),1}(Spikes.Offline_Sorting.Units{KeepChans(ChNum),1}==clusters(clusNum),:);
        end
    elseif strfind(fileName,'.hdf5')
        fileName=regexp(fName,'\w+(?=\.\w+\.)','match','once');
        Spikes.Offline_Sorting.Units{KeepChans(ChNum),1}=h5read([fileName '.clusters.hdf5'],'/clusters_2');
        Spikes.Offline_Sorting.SpikeTimes{3,1}=h5read([fileName '.clusters.hdf5'],'/times_2');
        Spikes.Offline_Sorting.Waveforms{3,1}=h5read([fileName '.clusters.hdf5'],'/data_2');
        Spikes.Offline_Sorting.Waveforms=h5read([fileName '.templates.hdf5'],'/temp_data');
        Spikes.Offline_Sorting.templates{10,1}.spiketimes=h5read([fileName '.result.hdf5'],'/spiketimes/temp_10');
        Spikes.Offline_Sorting.templates{10,1}.amplitudes=h5read([fileName '.result.hdf5'],'/amplitudes/temp_10');
        % get clusters spiketimes
        for clusNum=1:length(clusters)
            spikeData.(['Clus' num2str(clusters(clusNum))])=clusNum;
            spikeData.(['Clus' num2str(clusters(clusNum))]).SpikeTimes=Spikes.Offline_Sorting.SpikeTimes{KeepChans(ChNum),1}(Spikes.Offline_Sorting.Units{KeepChans(ChNum),1}==clusters(clusNum));
            spikeData.(['Clus' num2str(clusters(clusNum))]).Waveforms=Spikes.Offline_Sorting.Waveforms{KeepChans(ChNum),1}(Spikes.Offline_Sorting.Units{KeepChans(ChNum),1}==clusters(clusNum),:);
        end
        % for clusNum=min(unique(ResortedSpikes.Spikes.inGUI.Units{KeepChans(ChNum),1})):max(unique(ResortedSpikes.Spikes.inGUI.Units{KeepChans(ChNum),1}))
        %     Data.(['Clus' num2str(clusters(clusNum)+1)]).SpikeTimes=ResortedSpikes.Spikes.inGUI.SpikeTimes{KeepChans(ChNum),1}(ResortedSpikes.Spikes.inGUI.Units{KeepChans(ChNum),1}==clusters(clusNum));
        %     Data.(['Clus' num2str(clusters(clusNum)+1)]).Waveforms=ResortedSpikes.Spikes.inGUI.Waveforms{KeepChans(ChNum),1}(:,ResortedSpikes.Spikes.inGUI.Units{KeepChans(ChNum),1}==clusters(clusNum))';
        %end
        % Data.Clus1.Waveforms=ExtractChunks(rawData(3,:),Data.Clus1.SpikeTimes,82,'tzero');
    end
end