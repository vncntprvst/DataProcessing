classdef EphysFun
    methods(Static)
        
        %% FindBestUnits
        %%%%%%%%%%%%%%%%
        function bestUnits=FindBestUnits(unitIDs,pctThreshold)
            if nargin<2
                pctThreshold=5; %default 5% threshold
            end
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
        
        %% KeepBestUnits
        %%%%%%%%%%%%%%%%
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
        
        %% MakeRasters
        %%%%%%%%%%%%%%
        function [spikeRasters,unitList]=MakeRasters(spikeTimes,unitID,samplingRate,traceLength)
            %% Bin spike counts in 1ms bins
            % with Chronux' binning function
            % foo=binspikes(spikeTimes/double(samplingRate),Fs);
            % foo=[zeros(round(spikeTimes(1)/double(samplingRate)*Fs)-1,1);foo]; %need to padd with zeroes
            % With home-made function. Same result, but takes care of the padding.
            binSize=1;
            if nargin<3
                samplingRate=30000;
            end
            if nargin<4
                traceLength=int32(double(max(spikeTimes))/samplingRate*1000);
            end
            unitList=unique(unitID); unitList=unitList(unitList>0);
            numUnit=numel(unitList);
            spikeRasters=zeros(numUnit,ceil(traceLength));
            for unitNum=1:numUnit
                unitIdx=unitID==unitList(unitNum);
                try
                    lengthUnitTimeArray=ceil(spikeTimes(find(unitIdx,1,'last'))/int32(samplingRate/1000));
                catch
                    lengthUnitTimeArray=ceil(spikeTimes(find(unitIdx,1,'last'))/int64(samplingRate/1000));
                end
                spikeRasters(unitNum,1:lengthUnitTimeArray)=...
                    EphysFun.DownSampleToMilliseconds(...
                    spikeTimes(unitIdx),binSize,samplingRate);
            end
        end
        
        %% AlignRasters
        %%%%%%%%%%%%%%%
        function alignedRasters=AlignRasters(binnedSpikes,eventTimes,preAlignWindow,postAlignWindow)
            %% create event aligned rasters 
            if nargin==2 %define time window limits
                preAlignWindow=100; postAlignWindow=400;
            end
            alignedRasters=cell(size(binnedSpikes,1),1);
            for cellNum=1:size(binnedSpikes,1)
                cellRasters=nan(numel(eventTimes),preAlignWindow+postAlignWindow);
                for trialNum=1:numel(eventTimes)
                    try
                        cellRasters(trialNum,:)=binnedSpikes(cellNum,...
                            int32(eventTimes(trialNum)-preAlignWindow:...
                            eventTimes(trialNum)+postAlignWindow-1));
                        %smoothed:
                        %             alignedRasters(trialNum,:)=convSpikeTime(...
                        %                 eventTimes(trialNum)-preAlignWindow:...
                        %                 eventTimes(trialNum)+postAlignWindow);
                    catch
                        continue
                    end
                end
                alignedRasters{cellNum}=cellRasters(~isnan(sum(cellRasters,2)),:);
            end
            if size(binnedSpikes,1)==1
                alignedRasters=alignedRasters{:};
            end
            %     figure; imagesc(alignedRasters)
        end
        
        %% DownSampleToMilliseconds
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        function binnedSpikeTime=DownSampleToMilliseconds(spikeTimeArray,binSize,samplingRate)
            numBin=ceil(max(spikeTimeArray)/(samplingRate/1000)/binSize);
            binEdges=linspace(0,double(max(spikeTimeArray)),numBin+1);
            binnedSpikeTime = histcounts(double(spikeTimeArray), binEdges);
            binnedSpikeTime(binnedSpikeTime>1)=1;
        end
        
%         spikeTimeIdx=zeros(1,unitST(end));
%         spikeTimeIdx(unitST)=1;
%         numBin=ceil(size(spikeTimeIdx,2)/binSize);
%         binUnits = histcounts(double(unitST), linspace(0,size(spikeTimeIdx,2),numBin));
%         binUnits(binUnits>1)=1; %no more than 1 spike per ms
        
        % figure; hold on
        % % plot(dsrecordingTrace)
        % plot(find(binSpikeTimes),ones(length(find(binSpikeTimes)),1)*-250,'r*')
        % plot(find(foo),ones(length(find(foo)),1)*-200,'g*')
        
        %% MakeSDF
        %%%%%%%%%%
        function SDFs_ms=MakeSDF(spikeRasters,sigma)
            %% Compute sdfs
            if nargin<2;sigma=5;end
            SDFs_ms=nan(size(spikeRasters)); %length(unitNum), ceil(size(spikeRasters_ms,2)/samplingRate*1000));
            for clusterNum=1:size(SDFs_ms,1)
                SDFs_ms(clusterNum,:)=EphysFun.GaussConv...
                    (spikeRasters(clusterNum,:),sigma)*1000;
            end
            % figure; hold on
            % plot(SDFs{1})
            % plot(find(binSpikeTimes{1}),ones(length(find(binSpikeTimes{1})),1)*-10,'r*')
        end
        
        %% GaussConv
        %%%%%%%%%%%%
        function convTrace=GaussConv(data,sigma,causal)
            %% Convolve trace with gaussian kernel
            if nargin<2;sigma=5;end 
            if nargin<3;causal=false;end
            size = 6*sigma;
            width = linspace(-size / 2, size / 2, size);
            gaussFilter = exp(-width .^ 2 / (2 * sigma ^ 2));
            gaussFilter = gaussFilter / sum (gaussFilter); % normalize
            if causal; gaussFilter(x<0)=0; end % causal kernel
            convTrace = conv(data, gaussFilter, 'same');
        end
        
        %% FindRasterIndices
        %%%%%%%%%%%%%%%%%%%%
        function [rasterYInd_ms, rasterXInd_ms]=FindRasterIndices(spikeRasters,unitNum)
            %% Compute raster indices
            [rasterYInd_ms, rasterXInd_ms]=deal(cell(length(unitNum),1));
            for clusterNum=1:length(unitNum)
                [rasterYInd_ms{clusterNum}, rasterXInd_ms{clusterNum}] =...
                    ind2sub(size(spikeRasters(clusterNum,:)),find(spikeRasters(clusterNum,:))); %find row and column coordinates of spikes
            end
            % rasters=[indx indy;indx indy+1];
        end
        
        %% PlotRaster
        %%%%%%%%%%%%%
        function PlotRaster(spikeRasters,plotType,plotShift,plotCmap)
            if nargin<4 || isempty(plotCmap); plotCmap='k'; end
            if nargin<3 || isempty(plotShift); plotShift = 0; end
            if nargin<2 || isempty(plotType); plotType='diamonds'; end
            switch plotType
                case 'lines' 
                    [indy, indx] = ind2sub(size(spikeRasters),find(spikeRasters));                          % find row and column coordinates of spikes
                    indy=indy+plotShift;                                                                    % add placement value
                    if size(indx,2) > size(indx,1); indx=permute(indx,[2 1]); indy=permute(indy,[2 1]); end % need columns
                    rs_indx=reshape([indx';indx';nan(size(indx'))],1,numel(indx)*3);                        % reshape x indices double them and intersperce with nans
                    rs_indy=reshape([indy'-1;indy';nan(size(indy'))],1,numel(indx)*3);                      % reshape y indices double them and intersperce with nans
                    line(rs_indx,rs_indy,'color',plotCmap,'LineWidth',1.2);                                 % plot rasters
                case 'bars' %(deprecated - too heavy on memory)
                    %find row and column coordinates of spikes
                    [indy, indx] = ind2sub(size(spikeRasters),find(spikeRasters));
                    plot([indx';indx'],[indy'-1;indy']+plotShift,'color',plotCmap,'LineStyle','-');% plot rasters
                case 'diamonds'
                    plot(gca,find(spikeRasters),...
                        ones(1,numel(find(spikeRasters)))*...
                        plotShift,'LineStyle','none',...
                        'Marker','d','MarkerEdgeColor','none',...
                        'MarkerFaceColor',plotCmap,'MarkerSize',4);
                case 'image'
                    imagesc(gca,0,plotShift,spikeRasters);
                    colormap(gca,plotCmap);
                case 'stems' % for a single line, otherwise baseline moves every iteration
                    rastH=stem(gca,find(spikeRasters),ones(1,numel(find(spikeRasters)))*plotShift,...
                        'BaseValue',plotShift-1,'Color', plotCmap,'Marker','none');
                    rastBaseH=rastH.BaseLine; rastBaseH.Visible = 'off';
            end
        end
        
        %% PlotACG
        %%%%%%%%%%
        function PlotACG(unitsIDs,spikeTimes,selectedUnits,samplingRate,axesH,cmap)
            if nargin<5; figure; axesH=gca; end            
            axes(axesH); hold on; cla(axesH,'reset'); set(axesH,'Visible','on');
            binSize=1/2;
            for unitNum=numel(selectedUnits)
                unitST=spikeTimes(unitsIDs==selectedUnits(unitNum));%get unit spike times                
                unitST=int32(unitST/(samplingRate/1000*binSize));% change to 1/2ms timescale
                % ISI=diff(unitST)/(samplingRate/1000);%get ISI
                
                %% bin spikes                
                spikeTimeIdx=zeros(1,unitST(end));
                spikeTimeIdx(unitST)=1;
                numBin=ceil(size(spikeTimeIdx,2)/binSize);
                binUnits = histcounts(double(unitST), linspace(0,size(spikeTimeIdx,2),numBin));
                binUnits(binUnits>1)=1; %no more than 1 spike per bin
                
                %% compute autocorrelogram
                [ACG,lags]=xcorr(double(binUnits),200,'unbiased');  %'coeff'
                ACG(lags==0)=0;
                ACGh=bar(lags,ACG,'BarWidth', 1.6);
                ACGh.FaceColor = cmap(selectedUnits,:);
                ACGh.EdgeColor = cmap(selectedUnits,:); %'none'; 
            end
            % axis('tight');
            box off; grid('on'); %set(gca,'yscale','log','GridAlpha',0.25,'MinorGridAlpha',1);
            xlabel(['Autocorrelogram (ms )']);% num2str(binSize) ' ms bins)']
            set(gca,'xlim',[-25 25]/binSize,... %'ylim',[0 max([max(get(gca,'ylim')) 10^1])]
                'xtick',-25/binSize:10:25/binSize,'xticklabel',-25:10*binSize:25,...
                'Color','white','FontSize',10,'FontName','Calibri','TickDir','out');
            hold off
        end
        
        %% PLotISI
        %%%%%%%%%%
        function PLotISI(unitsIDs,spikeTimes,selectedUnits,samplingRate,axesH,cmap)
            if nargin<5; figure; axesH=gca; end            
            axes(axesH); hold on; cla(axesH,'reset'); set(axesH,'Visible','on');
            for unitNum=numel(selectedUnits)
                %spike times for that unit
                unitST=spikeTimes(unitsIDs==selectedUnits);
                % compute interspike interval
                if ~isempty(diff(unitST))
                    ISI=diff(unitST)/(samplingRate/1000);
                    ISIhist=histogram(double(ISI),logspace(0, 4, 50),'LineWidth',1.5);  %'DisplayStyle','stairs','Normalization','probability'
                    ISIhist.FaceColor = cmap(selectedUnits,:);
                    ISIhist.EdgeColor = cmap(selectedUnits,:); %'k';
                end
                xlabel('Interspike Interval (ms)') ; %axis('tight');
                box off; grid('on'); set(gca,'xscale','log','GridAlpha',0.25,'MinorGridAlpha',1);
                set(gca,'xlim',[0 10^4],... %'XTick',linspace(0,40,5),'XTickLabel',linspace(0,40,5),...
                    'TickDir','out','Color','white','FontSize',10,'FontName','Calibri');
                hold off
            end
        end
    end
end