function [whiskerTrackingData,vidTimes]=AdjustFrameNumFrameTimes(whiskerTrackingData,vidTimes)

% If there are more vSync TTLS than video frames, fix it.
% Assuming that video recording strictly occured within boundaries of ephys
% recording (see below otherwise). Any discrepancy will be due to closing 
% video recording file, with the camera's last TTLs being recorded by the
% ephys acquisition system, but the corresponding frames not recorded in
% the video file. Adjust behavior data accordingly
wtFld=fieldnames(whiskerTrackingData.angle);
behavTraceLength=numel(whiskerTrackingData.angle.(wtFld{1})); %Assuming trace is first field here
frameNumDiff= behavTraceLength-(numel(vidTimes)*mode(diff(vidTimes)));
if frameNumDiff <0 % more TTLs recorded than video frames (see scenario above)
	vidTimes=vidTimes(vidTimes<behavTraceLength+vidTimes(1));
elseif frameNumDiff > 0 % More problematic case
    % Video recording started earlier, or stopped later, than the ephys recording
    % In that case, we need to cut the behavior traces, not the video frame times
    if vidTimes(1)<=mode(diff(vidTimes)) &&...
        numel(allTraces(1,:))/recInfo.SRratio-vidTimes(end)>vidTimes(1) %started earlier
        reIndex=frameNumDiff:behavTraceLength;
    elseif numel(allTraces(1,:))/recInfo.SRratio-vidTimes(end)<vidTimes(1) %stopped later
        reIndex=1:behavTraceLength-frameNumDiff+1;
    else % really screwed up, assuming started earlier AND stopped later than ephys...
        % could estimate base on frame timestamps
        disp(mfilename('fullpath'))
        disp('Need to cut behavior trace')
        return
    end
    whiskerTrackingData.angle.(wtFld{1})=whiskerTrackingData.angle.(wtFld{1})(reIndex);
    wtFld=fieldnames(whiskerTrackingData.velocity);
    whiskerTrackingData.velocity.(wtFld{1})=whiskerTrackingData.velocity.(wtFld{1})(reIndex);
    wtFld=fieldnames(whiskerTrackingData.phase);
    whiskerTrackingData.phase.(wtFld{1})=whiskerTrackingData.phase.(wtFld{1})(reIndex);
%     vidTimes=linspace(1,double(vidTimes(end)+1),size(whiskerTrackingData,2));
end
