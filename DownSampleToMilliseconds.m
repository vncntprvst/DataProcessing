function binSpikeTime=DownSampleToMilliseconds(spikeTimeArray,binSize,samplingRate)

numBin=ceil(max(spikeTimeArray)/(samplingRate/1000)/binSize);
binEdges=linspace(0,max(spikeTimeArray),numBin+1);
binSpikeTime = histcounts(double(spikeTimeArray), binEdges);
binSpikeTime(binSpikeTime>1)=1;

end