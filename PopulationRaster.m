function spikeRasters=PopulationRaster(spikeTimes,TTLtimes,selectedUnits,...
    unitsIdx,samplingRate,preAlignWindow,postAlignWindow)

%% get spike times and convert to binary array
for clusNum=1:size(selectedUnits,1)
    %% convert to 1 millisecond bins and plot excerpt
    binSize=1;
    numBin=ceil((max(spikeTimes(unitsIdx==selectedUnits(clusNum)))+1)/...
        (samplingRate/1000)/binSize);
    
    [spikeCount,spikeTime]=histcounts(double(spikeTimes(unitsIdx==selectedUnits(clusNum)))/...
        double(samplingRate/1000), numBin);
    
    %% spike density function
    spikeArray = zeros(1,ceil(max(spikeTime))+1);
    spikeArray(ceil(spikeTime(1:end-1)))=spikeCount;
    
    %% create rasters aligned to TTL
    %define parameters
    TTLtimes=uint32(TTLtimes); %/(samplingRate/1000);
    raster=nan(numel(TTLtimes),preAlignWindow+postAlignWindow+1);
    for trialNum=1:numel(TTLtimes)
        try
            raster(trialNum,:)=spikeArray(...
                TTLtimes(trialNum)-preAlignWindow:...
                TTLtimes(trialNum)+postAlignWindow);
            %smoothed:
            %             spikeRasters(trialNum,:)=convSpikeTime(...
            %                 TTLtimes(trialNum)-preAlignWindow:...
            %                 TTLtimes(trialNum)+postAlignWindow);
        catch
            continue
        end
    end
    spikeRasters{clusNum}=raster(~isnan(sum(raster,2)),:);
    %     figure; imagesc(spikeRasters{clusNum})
end
