function SaveProcessedData %processedDir

[ephys,behav,pulses,targetDir]=NeuronBehaviorCorrelation_LoadData;
% cd(fullfile('../../Analysis',ephys.recInfo.sessionName))
cd(targetDir);

%% whisker data
whisker=behav.whiskers;
% whisker.Angle=behav.whiskers.Angle; %whisker.Angle=fillmissing(behav.whiskers.Angle_BP,'nearest');
% whisker.Velocity=behav.whiskers.Velocity;
% whisker.Phase=behav.whiskers.Phase;
% whisker.Amplitude=behav.whiskers.Amplitude;
% whisker.Frequency=behav.whiskers.Freq;
% whisker.SetPoint=behav.whiskers.SetPoint;
% whisker.Timestamps=behav.whiskers.Timestamp;
%% compute whisking frequency (different from instantaneous frequency
for whiskNum=1:size(whisker,2)
    whisksIdx = bwconncomp(diff(whisker(whiskNum).phase)>0);
    peakIdx = zeros(1,length(whisker(whiskNum).velocity));
    peakIdx(cellfun(@(whisk) whisk(1), whisksIdx.PixelIdxList))=1;
    whisker(whiskNum).Frequency=movsum(peakIdx,behav.whiskerTrackingData.samplingRate);
end

bestWhiskerIdx=behav.whiskerTrackingData.keepWhiskerIDs==behav.whiskerTrackingData.bestWhisker;
%% compute rasters
[ephys.rasters,ephys.unitList]=EphysFun.MakeRasters(ephys.spikes.times,ephys.spikes.unitID,...
    1,size(whisker(bestWhiskerIdx).angle,2));
%% compute spike density functions
ephys.spikeRate=EphysFun.MakeSDF(ephys.rasters);
%create timeline
ephys.timestamps = 0:0.001:ephys.recInfo.duration_sec;

%extract traces
traces=single(ephys.traces);
ephys=rmfield(ephys,'traces');

%% save data
save([ephys.recInfo.sessionName '_ephys'],'ephys','-v7.3');
fileID = fopen([ephys.recInfo.sessionName '_traces.bin'],'w');
fwrite(fileID,traces,'single');
fclose(fileID);
save([ephys.recInfo.sessionName '_whisker'],'whisker','-v7.3');
save([ephys.recInfo.sessionName '_pulses'],'pulses','-v7.3');
save([ephys.recInfo.sessionName '_processedData'],'ephys','behav','pulses','-v7.3');

%% other behavior data
if ~isempty(behav.breathing)
    breathing.data=double(behav.breathing');
    breathing.data=breathing.data*(range(whisker(bestWhiskerIdx).setPoint)/range(breathing.data));
    breathing.ts=linspace(0,ephys.recInfo.duration_sec,numel(behav.breathing));
    save([ephys.recInfo.sessionName '_breathing'],'breathing','-v7.3');
end
