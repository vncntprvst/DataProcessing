function taggedCells = FindPhototagged(ephysData,pulses)

%% variables
TTLs.start=pulses.TTLTimes; %(1,:); TTLs.end=pulses.TTLTimes(2,:);
if ~isfield(pulses,'duration')
    pulses.duration=0.010;
end
pulseDur=pulses.duration; %  min(mode(TTLs.end-TTLs.start));
preAlignWindow=0; %0.050;
postAlignWindow=0.050;

%% compute rasters
spikeRasters=ephysData.rasters(ephysData.selectedUnits,:); %  EphysFun.MakeRasters(ephysData.timestamps,ephysData.spikes.unitID,...
%     1,int32(size(ephysData.traces,2)/ephysData.spikes.samplingRate*1000)); %ephysData.spikes.samplingRate
% spikeRasters=spikeRasters(ephysData.selectedUnits,:);
pulseRasters=EphysFun.AlignRasters(spikeRasters,TTLs.start,preAlignWindow,postAlignWindow,1000);

samplingPoints=[preAlignWindow:preAlignWindow+postAlignWindow:TTLs.start(1)];
samplingPoints=samplingPoints(round(linspace(1,numel(samplingPoints),400)));

baselineRasters =EphysFun.AlignRasters(spikeRasters,...
    samplingPoints,...
    0.5,0.5,1000);

if ~iscell(pulseRasters) % just one cell
    pulseRasters={pulseRasters};
    baselineRasters={baselineRasters};
end

taggedCells = ones(size(spikeRasters,1),1);
for cellNum=1:size(spikeRasters,1) %ephysData.selectedUnits,1)
    %'vIRt47_0803_5900 unit54 - rasters looks better in JRC
    % SALT test
    p = salt(baselineRasters{cellNum},...
        pulseRasters{cellNum},0.001,0.010);
    taggedCells(cellNum) = p;
%     if p < 0.05 %&& ...
% %             (sum(sum(pulseRasters{cellNum}(:,1:pulseDur*1000))) >... 
% %             size(pulseRasters{cellNum},1)/2 ||... % response
% %             sum(sum(pulseRasters{cellNum}(:,1:pulseDur*1000))) < ...
% %             (sum(sum(baselineRasters{cellNum}(:,1:pulseDur*1000)))/size(baselineRasters{cellNum},1)))
%              figure; imagesc(pulseRasters{cellNum});
%              ylabel('pulse #')
%              xlabel('Time from pulse onset (ms)')
%              title([ephysData.recInfo.sessionName ' Unit ' num2str(cellNum)],'interpreter','None')
% %              if ~exist(fullfile(cd, 'Figures'),'dir')
% %                  mkdir('Figures')
% %              end
% %              savefig(gcf,fullfile(cd, 'Figures',...
% %                  [ephysData.recInfo.sessionName '_Unit' num2str(cellNum) '_PT.fig']))
% %              close(gcf)
% 
%     end
end

%if need to load ephys data:
% spikeSortingDir=[ephysData.recInfo.dirName filesep 'SpikeSorting' filesep ephysData.recInfo.sessionName];
% LoadSpikeData(fullfile(spikeSortingDir, [ephysData.recInfo.sessionName '_export_res.mat'])) ;
%
