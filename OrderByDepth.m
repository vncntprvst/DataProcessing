function ephys = OrderByDepth(ephys)

%% organize selectedUnits by depth
if size(ephys.recInfo.probeGeometry,2)>size(ephys.recInfo.probeGeometry,1)
    ephys.recInfo.probeGeometry=ephys.recInfo.probeGeometry';
end
unitLoc=nan(numel(ephys.selectedUnits),2);
for unitNum=1:numel(ephys.selectedUnits)
    unitID=ephys.selectedUnits(unitNum);
    %     [foo,faa]=hist(double(ephys.spikes.preferredElectrode(ephys.spikes.unitID==unitID)),...
    %         double(unique(ephys.spikes.preferredElectrode(ephys.spikes.unitID==unitID))))
    prefElec=mode(ephys.spikes.preferredElectrode(ephys.spikes.unitID==unitID));
    unitLoc(unitNum,:)=ephys.recInfo.probeGeometry(prefElec,:);
end
[~,unitDepthOrder]=sort(unitLoc(:,2));
ephys.selectedUnits=ephys.selectedUnits(unitDepthOrder);
ephys.unitCoordinates=unitLoc(unitDepthOrder,:);
