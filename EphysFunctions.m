classdef EphysFunctions
    methods(Static)      
        function bestUnits=FindBestUnits(unitIDs)
            %% Find best units
            unitIDs=double(unitIDs);
            %spikeTimes=double(spikeTimes);
            % find most frequent units
            [unitFreq,uniqueUnitIDs]=hist(unitIDs,unique(unitIDs));
            [unitFreq,freqIdx]=sort(unitFreq','descend');
            unitFreq=unitFreq./sum(unitFreq)*100; uniqueUnitIDs=uniqueUnitIDs(freqIdx);
            bestUnitsIdx=find(unitFreq>0.1);
            bestUnits=uniqueUnitIDs(bestUnitsIdx); bestUnits=sort(bestUnits(bestUnits~=0));
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
        function spikeRasters_ms=MakeRasters(spikeTimes,unitID,samplingRate,traceLength)
            %% Bin spike counts in 1ms bins
            % with Chronux' binning function
            % foo=binspikes(spikeTimes/double(samplingRate),Fs);
            % foo=[zeros(round(spikeTimes(1)/double(samplingRate)*Fs)-1,1);foo]; %need to padd with zeroes
            % With home-made function. Same result, but takes care of the padding
            binSize=1;
            if nargin<4
                traceLength=max(max(spikeTimes))/samplingRate*1000;
            end
            unitNum=numel(unique(unitID));
            spikeRasters_ms=zeros(unitNum,ceil(traceLength));
            for clusterNum=1:length(unitNum)
                unitIdx=unitID==unitNum(clusterNum);
                lengthUnitTimeArray=ceil(spikeTimes(find(unitIdx,1,'last'))/samplingRate*1000);
                spikeRasters_ms(clusterNum,1:lengthUnitTimeArray)=DownSampleToMilliseconds(...
                    spikeTimes(unitIdx),binSize,samplingRate);
            end
        end
        % figure; hold on
        % % plot(dsrecordingTrace)
        % plot(find(binSpikeTimes),ones(length(find(binSpikeTimes)),1)*-250,'r*')
        % plot(find(foo),ones(length(find(foo)),1)*-200,'g*')        
        function SDFs_ms=MakeSDF(spikeRasters_ms,unitNum)
            %% Compute sdfs
            SDFs_ms=nan(length(unitNum), ceil(size(spikeRasters_ms,2)/samplingRate*1000));
            for clusterNum=1:length(unitNum)
                SDFs_ms(clusterNum,:)=GaussConv(spikeRasters_ms(clusterNum,:),5)*1000;
            end
            % figure; hold on
            % plot(SDFs{1})
            % plot(find(binSpikeTimes{1}),ones(length(find(binSpikeTimes{1})),1)*-10,'r*')
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