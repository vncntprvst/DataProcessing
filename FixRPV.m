function FixRPV(spikes,RPVIndex)
unitIDs=unique(spikes.unitID);
for unitNum=1:numel(unitIDs)
    RPVspikes=[find(RPVIndex{unitNum})-1;find(RPVIndex{unitNum})];
    unitIndex=find(spikes.unitID==unitIDs(unitNum));
    waveforms=spikes.waveforms(unitIndex(RPVspikes),:);
    figure; hold on 
    for spikeNum=1:numel(RPVspikes)
        plot(waveforms(spikeNum,:));
    end
    
    %% PCA
    
    %% sort in 2 clusters (K-means), or optimal cluster number
    
    %% seed and attribute
    
    
end