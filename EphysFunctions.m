classdef EphysFunctions
    methods(Static)
        function bestUnits=FindBestUnits(unitIDs,pctThreshold)
            if nargin<2
                pctThreshold=5; %default 5% threshold
            end
            %% Find best units
            unitIDs=double(unitIDs);
            % find most frequent units
            [unitFreq,uniqueUnitIDs]=hist(unitIDs,unique(unitIDs));
            keepUnits=uniqueUnitIDs>0;uniqueUnitIDs=uniqueUnitIDs(keepUnits);
            [unitFreq,freqIdx]=sort(unitFreq(keepUnits),'descend');
            uniqueUnitIDs=uniqueUnitIDs(freqIdx);
            unitFreq=unitFreq./sum(unitFreq)*100; 
            bestUnitsIdx=unitFreq>pctThreshold;
            bestUnits=uniqueUnitIDs(bestUnitsIdx); bestUnits=sort(bestUnits);
        end
        function [spikes,recordingTraces,keepTraces]=KeepBestUnits(bestUnits,spikes,allTraces)
            if isfield(spikes,'preferredElectrode')
                try
                    titularChannels = unique(spikes.preferredElectrode(ismember(spikes.unitID,bestUnits)));
                catch
                    titularChannels =find(~cellfun('isempty',spikes.preferredElectrode));
                end
            end
            % keepUnits=[1 2 3];
            % titularChannels=[10 10 10];
            keepTraces=titularChannels; %14; %[10 14 15];% keepTraces=1:16; %[10 14 15];
            % keepTraces=1:size(allTraces,1);
            
            %% Keep selected recording trace and spike times,
            recordingTraces=allTraces(keepTraces,:); %select the trace to keep
            try
                keepUnitsIdx=ismember(spikes.preferredElectrode,keepTraces);
                spikes.unitID=spikes.unitID(keepUnitsIdx);
                spikes.preferredElectrode=spikes.preferredElectrode(keepUnitsIdx);
                try
                    spikes.waveforms=spikes.waveforms(keepUnitsIdx,:);
                catch
                    spikes.waveforms=[];
                end
                spikes.times=spikes.times(keepUnitsIdx);
            catch
                %     unitID=spikes.unitID;
                %     spikeTimes=spikes.times;
                %     waveForms=spikes.waveforms;
                %     preferredElectrode=spikes.preferredElectrode;
            end
        end
        function [spikeRasters_ms,unitList]=MakeRasters(spikeTimes,unitID,samplingRate,traceLength)
            %% Bin spike counts in 1ms bins
            % with Chronux' binning function
            % foo=binspikes(spikeTimes/double(samplingRate),Fs);
            % foo=[zeros(round(spikeTimes(1)/double(samplingRate)*Fs)-1,1);foo]; %need to padd with zeroes
            % With home-made function. Same result, but takes care of the padding
            binSize=1;
            if nargin<3
                samplingRate=30000;
            end
            if nargin<4
                traceLength=int32(double(max(spikeTimes))/samplingRate*1000);
            end
            unitList=unique(unitID); unitList=unitList(unitList>0);
            unitNum=numel(unitList);
            spikeRasters_ms=zeros(unitNum,ceil(traceLength));
            for clusterNum=1:unitNum
                unitIdx=unitID==unitList(clusterNum);
                try
                    lengthUnitTimeArray=ceil(spikeTimes(find(unitIdx,1,'last'))/int32(samplingRate/1000));
                catch
                    lengthUnitTimeArray=ceil(spikeTimes(find(unitIdx,1,'last'))/int64(samplingRate/1000));
                end
                spikeRasters_ms(clusterNum,1:lengthUnitTimeArray)=...
                    EphysFunctions.DownSampleToMilliseconds(...
                    spikeTimes(unitIdx),binSize,samplingRate);          
            end
        end
        function binnedSpikeTime=DownSampleToMilliseconds(spikeTimeArray,binSize,samplingRate) 
            numBin=ceil(max(spikeTimeArray)/(samplingRate/1000)/binSize);
            binEdges=linspace(0,double(max(spikeTimeArray)),numBin+1);
            binnedSpikeTime = histcounts(double(spikeTimeArray), binEdges);
            binnedSpikeTime(binnedSpikeTime>1)=1;
        end
        % figure; hold on
        % % plot(dsrecordingTrace)
        % plot(find(binSpikeTimes),ones(length(find(binSpikeTimes)),1)*-250,'r*')
        % plot(find(foo),ones(length(find(foo)),1)*-200,'g*')
        function SDFs_ms=MakeSDF(spikeRasters_ms)
            %% Compute sdfs
            SDFs_ms=nan(size(spikeRasters_ms)); %length(unitNum), ceil(size(spikeRasters_ms,2)/samplingRate*1000));
            for clusterNum=1:size(SDFs_ms,1)
                SDFs_ms(clusterNum,:)=EphysFunctions.GaussConv...
                    (spikeRasters_ms(clusterNum,:),5)*1000;
            end
            % figure; hold on
            % plot(SDFs{1})
            % plot(find(binSpikeTimes{1}),ones(length(find(binSpikeTimes{1})),1)*-10,'r*')
        end
        function convTrace=GaussConv(data,sigma)
            % sigma=1;
            size = 6*sigma;
            width = linspace(-size / 2, size / 2, size);
            gaussFilter = exp(-width .^ 2 / (2 * sigma ^ 2));
            gaussFilter = gaussFilter / sum (gaussFilter); % normalize
            
            convTrace = conv (data, gaussFilter, 'same');
        end
        function [rasterYInd_ms, rasterXInd_ms]=FindRasterIndices(spikeRasters_ms,unitNum)
            %% Compute raster indices
            [rasterYInd_ms, rasterXInd_ms]=deal(cell(length(unitNum),1));
            for clusterNum=1:length(unitNum)
                [rasterYInd_ms{clusterNum}, rasterXInd_ms{clusterNum}] =...
                    ind2sub(size(spikeRasters_ms(clusterNum,:)),find(spikeRasters_ms(clusterNum,:))); %find row and column coordinates of spikes
            end
            % rasters=[indx indy;indx indy+1];
        end
    end
end