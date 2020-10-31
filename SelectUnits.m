function ephys=SelectUnits(ephys,mode,handpick)

%% decide which units to keep
switch mode
    case 'all'
        %all of them
        ephys.selectedUnits=ephys.unitList; %all units
    case 'frequency'
        %most frequent units
        mostFrqUnits=EphysFun.FindBestUnits(ephys.spikes.unitID,1);%keep ones over x% spikes
    case 'mostinwhisking'
        %most frequent units during whisking periods
        reconstrUnits=ephys.rasters(:,whiskingEpochs).*(1:size(ephys.rasters,1))';
        reconstrUnits=reshape(reconstrUnits,[1,size(reconstrUnits,1)*size(reconstrUnits,2)]);
        reconstrUnits=reconstrUnits(reconstrUnits>0);
        mostFrqUnits=EphysFun.FindBestUnits(reconstrUnits,1);
        keepUnits=ismember(unitList,mostFrqUnits);
        keepTraces=unique(ephys.spikes.preferredElectrode(ismember(ephys.spikes.unitID,unitList(keepUnits))));
        ephys.selectedUnits=find(keepUnits);
    case 'quality'
        % only SU
        [unitQuality,RPVIndex]=SSQualityMetrics(ephys.spikes);
        unitQuality=[unique(double(ephys.spikes.unitID)),unitQuality];
        unitIdx=ismember(ephys.spikes.unitID,unitQuality(unitQuality(:,2)>0.6,1));
        unitQuality(unitQuality(:,2)>0.6,3)=hist(double(ephys.spikes.unitID(unitIdx)),...
            unique(double(ephys.spikes.unitID(unitIdx))))/sum(unitIdx);
        qualityUnits=unitQuality(unitQuality(:,2)>0.6 & unitQuality(:,3)>0.01,:);
        ephys.selectedUnits=qualityUnits(:,1);
    otherwise
        % set manually
        ephys.selectedUnits=handpick;
        return
end

if exist('handpick','var')
    % add to selection, e.g.,
    ephys.selectedUnits=[ephys.selectedUnits;handpick]; %54  1;2;19];
end
