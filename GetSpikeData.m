function [spikeData,fileInfo]=GetSpikeData(varargin)
% Get spike clusters, times, waveforms from specified channels

if nargin==1
    KeepChans=varargin{1};
    %% Get file path
    [fName,dirName] = uigetfile({'*.mat; *.hdf5; *.npy; *.nev','Processed data';...
        '*.dat','Flat data';'*.*','All Files' },'Select processed spike data','C:\Data\export');
    cd(dirName);
else
    fName=varargin{1};
    dirName=varargin{2};
    KeepChans=varargin{3};
end

%% load file data
if contains(fName,'.mat')
    load(fName);
    %load other data
    fName=regexp(fName,'.+(?=_\w+.\w+$)','match');
    try
        load([fName{:} '_raw.mat']);
    catch
    end
    if ~contains(fName,'_spikesResorted')
        load([fName{:} '_spikes.mat']);
    end
    load([fName{:} '_info.mat']);
elseif contains(fName,'.nev')
    NEV=openNEV('read', [dirName '\' fName]);
    
    % select channel to plot
    % channels=unique(NEV.Data.Spikes.Electrode);
    % str= num2str(linspace(1,double(max(NEV.Data.Spikes.Unit)),max(NEV.Data.Spikes.Unit))');
    % chSelected = listdlg('PromptString','select channel to plot:',...
    %                 'SelectionMode','single',...
    %                 'ListString',num2str(channels'));
    % chSelected=channels(chSelected);
    
elseif contains(fName,'.hdf5')
    fName=regexp(fName,'\w+(?=\.\w+\.)','match','once');
elseif contains(fName,'.npy') %output from phy GUI
    spikeData=Load_phyResults(dirName);
    cd('..\..'); %check two folders up, original export/process data folder
    exportDirListing=dir(cd); %regexp(cd,'\w+$','match')
    fileInfo=importdata(exportDirListing(~cellfun('isempty',cellfun(@(x) contains(x,'_info.'),...
        {exportDirListing.name},'UniformOutput',false))).name);
    return
end

%Select channels
if ~exist('KeepChans','var') || isempty(KeepChans)
    KeepChans=numal(Spikes.HandSort.Units);
end

% KeepChans=Spikes.Offline_Threshold.channel;
% KeepChans=10;

spikeData=struct('channelID',[],'clusterID',[],'spikeTimes',[],'waveForms',[]);
clusterID=1;
for ChNum=1:length(KeepChans)
    %% load spike data
    if contains(fName,'_spikesResorted')
            clusters=unique(Spikes.HandSort.Units{KeepChans(ChNum),1});
        % get clusters spiketimes
        for clusNum=1:length(clusters)
            spikeData(clusterID).channelID=KeepChans(ChNum);
            spikeData(clusterID).clusterID=clusters(clusNum);
            spikeData(clusterID).spikeTimes=Spikes.HandSort.spikeTimes{KeepChans(ChNum),1}(Spikes.HandSort.Units{KeepChans(ChNum),1}==clusters(clusNum));
            spikeData(clusterID).waveForms=Spikes.HandSort.waveForms{KeepChans(ChNum),1}(:,Spikes.HandSort.Units{KeepChans(ChNum),1}==clusters(clusNum));
            clusterID=clusterID+1;
        end
        exportDirListing=dir(cd);
        if sum(~cellfun('isempty',cellfun(@(x) contains(x,'.phy'),{exportDirListing.name},'UniformOutput',false)))
            try
                phyData=Load_phyResults([dirName fName{:} '\' fName{:} '.GUI']);
            catch
            end
        end
    elseif contains(fName,'.mat')
            clusters=unique(Spikes.HandSort.Units{KeepChans(ChNum),1});
        % from Spike2
        Spikes.Offline_Sorting.Units{KeepChans(ChNum),1}=nw_401.codes(:,1);
        Spikes.Offline_Sorting.spikeTimes{3,1}=uint32(nw_401.times*rec_info.samplingRate);
        Spikes.Offline_Sorting.waveForms{3,1}=nw_401.values;
        % get clusters spiketimes
        for clusNum=1:length(clusters)
            spikeData(clusterID).channelID=KeepChans(ChNum);
            spikeData(clusterID).clusterID=clusNum;
            spikeData(clusterID).spikeTimes=Spikes.Offline_Sorting.spikeTimes{KeepChans(ChNum),1}(Spikes.Offline_Sorting.Units{KeepChans(ChNum),1}==clusters(clusNum));
            spikeData(clusterID).waveForms=Spikes.Offline_Sorting.waveForms{KeepChans(ChNum),1}(Spikes.Offline_Sorting.Units{KeepChans(ChNum),1}==clusters(clusNum),:);
            clusterID=clusterID+1;
        end
    elseif contains(fName,'.hdf5')
%         clusters ? 
        fName=regexp(fName,'\w+(?=\.\w+\.)','match','once');
        Spikes.Offline_Sorting.Units{KeepChans(ChNum),1}=h5read([fName '.clusters.hdf5'],'/clusters_2');
        Spikes.Offline_Sorting.spikeTimes{3,1}=h5read([fName '.clusters.hdf5'],'/times_2');
        Spikes.Offline_Sorting.waveForms{3,1}=h5read([fName '.clusters.hdf5'],'/data_2');
        Spikes.Offline_Sorting.waveForms=h5read([fName '.templates.hdf5'],'/temp_data');
        Spikes.Offline_Sorting.templates{10,1}.spikeTimes=h5read([fName '.result.hdf5'],'/spiketimes/temp_10');
        Spikes.Offline_Sorting.templates{10,1}.amplitudes=h5read([fName '.result.hdf5'],'/amplitudes/temp_10');
        % get clusters spiketimes
        for clusNum=1:length(clusters)
            spikeData(clusterID).channelID=KeepChans(ChNum);
            spikeData(clusterID).clusterID=clusNum;
            spikeData(clusterID).spikeTimes=Spikes.Offline_Sorting.spikeTimes{KeepChans(ChNum),1}(Spikes.Offline_Sorting.Units{KeepChans(ChNum),1}==clusters(clusNum));
            spikeData(clusterID).waveForms=Spikes.Offline_Sorting.waveForms{KeepChans(ChNum),1}(Spikes.Offline_Sorting.Units{KeepChans(ChNum),1}==clusters(clusNum),:);
            clusterID=clusterID+1;
        end
        % for clusNum=min(unique(ResortedSpikes.Spikes.inGUI.Units{KeepChans(ChNum),1})):max(unique(ResortedSpikes.Spikes.inGUI.Units{KeepChans(ChNum),1}))
        %     Data.(['Clus' num2str(clusters(clusNum)+1)]).spikeTimes=ResortedSpikes.Spikes.inGUI.spikeTimes{KeepChans(ChNum),1}(ResortedSpikes.Spikes.inGUI.Units{KeepChans(ChNum),1}==clusters(clusNum));
        %     Data.(['Clus' num2str(clusters(clusNum)+1)]).waveForms=ResortedSpikes.Spikes.inGUI.waveForms{KeepChans(ChNum),1}(:,ResortedSpikes.Spikes.inGUI.Units{KeepChans(ChNum),1}==clusters(clusNum))';
        %end
        % Data.Clus1.waveForms=ExtractChunks(rawData(3,:),Data.Clus1.spikeTimes,82,'tzero');    
    elseif contains(fName,'.nev')
        % from Blackrock
        %select unit to plot
        units=unique(NEV.Data.Spikes.Unit(NEV.Data.Spikes.Electrode==KeepChans));
        if length(units) > 1
            unitSelected = listdlg('PromptString','select unit(s) to plot:',...
                'SelectionMode','multiple',...
                'ListString',num2str(units'));
            unitSelected=units(unitSelected);
        end
        fileInfo=NEV.MetaTags;
        for clusNum=1:length(unitSelected)
            spikeData(clusterID).channelID=KeepChans(ChNum);
            spikeData(clusterID).clusterID=unitSelected(clusNum);
            logicalUnitSelected=NEV.Data.Spikes.Unit==unitSelected(clusNum) &...
                NEV.Data.Spikes.Electrode==KeepChans(ChNum);
            spikeData(clusterID).spikeTimes=NEV.Data.Spikes.TimeStamp(logicalUnitSelected);
            spikeData(clusterID).waveForms=NEV.Data.Spikes.Waveform(:,logicalUnitSelected);
            clusterID=clusterID+1;
        end    
    end
end