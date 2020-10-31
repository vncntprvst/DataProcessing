function SaveProcessedData %processedDir

[ephys,behav,pulses]=NeuronBehaviorCorrelation_LoadData;
cd(fullfile('../../Analysis',ephys.recInfo.sessionName))

%% whisker data
whisker.Angle=behav.whiskerTrackingData.Angle; %whisker.Angle=fillmissing(behav.whiskerTrackingData.Angle_BP,'nearest');
whisker.Velocity=behav.whiskerTrackingData.Velocity;
whisker.Phase=behav.whiskerTrackingData.Phase;
whisker.Amplitude=behav.whiskerTrackingData.Amplitude;
whisker.Frequency=behav.whiskerTrackingData.Freq;
whisker.SetPoint=behav.whiskerTrackingData.SetPoint;
whisker.Timestamps=behav.whiskerTrackingData.Timestamp;
%% compute whisking frequency (different from instantaneous frequency
whisksIdx = bwconncomp(diff(whisker.Phase)>0);
peakIdx = zeros(1,length(whisker.Velocity));
peakIdx(cellfun(@(whisk) whisk(1), whisksIdx.PixelIdxList))=1;
whisker.Frequency=movsum(peakIdx,behav.whiskerTrackingData.samplingRate);

%% compute rasters
[ephys.rasters,ephys.unitList]=EphysFun.MakeRasters(ephys.spikes.times,ephys.spikes.unitID,...
    1,size(whisker.Angle,2));
%% compute spike density functions
ephys.spikeRate=EphysFun.MakeSDF(ephys.rasters);
%create timeline
ephys.timestamps = 0:0.001:ephys.recInfo.duration_sec;

%extract traces
traces=single(ephys.traces);
ephys=rmfield(ephys,'traces');

save([ephys.recInfo.sessionName '_ephys'],'ephys','-v7.3');
fileID = fopen([ephys.recInfo.sessionName '_traces.bin'],'w');
fwrite(fileID,traces,'single');
fclose(fileID);
save([ephys.recInfo.sessionName '_whisker'],'whisker','-v7.3');
save([ephys.recInfo.sessionName '_pulses'],'pulses','-v7.3');

%% other behavior data
if ~isempty(behav.breathing)
    breathing.data=double(behav.breathing');
    breathing.data=breathing.data*(range(whisker.SetPoint)/range(breathing.data));
    breathing.ts=linspace(0,ephys.recInfo.duration_sec,numel(behav.breathing));
    save([ephys.recInfo.sessionName '_breathing'],'breathing','-v7.3');
end
