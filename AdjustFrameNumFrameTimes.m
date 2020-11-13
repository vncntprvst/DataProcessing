function [wtData,vidTimes]=AdjustFrameNumFrameTimes(wtData,vidTimes,unitBase)

% If there are more vSync TTLS than video frames, fix it.
% Assuming that video recording strictly occured within boundaries of ephys
% recording (see below otherwise). Any discrepancy will be due to closing
% video recording file, with the camera's last TTLs being recorded by the
% ephys acquisition system, but the corresponding frames not recorded in
% the video file. Adjust behavior data accordingly
if isfield(wtData.whiskers,'Angle')
    if ~isstruct(wtData.whiskers(1).Angle)
        behavTraceLength=numel(wtData.whiskers(1).Angle);
    else
        wtFld=fieldnames(wtData.whiskers(1).Angle);
        behavTraceLength=numel(wtData.whiskers(1).Angle.(wtFld{1})); %Assuming trace is first field here
    end
else
    wtFld=fieldnames(wtData.whiskers);
    behavTraceLength=numel(wtData.whiskers(1).(wtFld{1}));
end
frameNumDiff= behavTraceLength-(numel(vidTimes)*mode(diff(vidTimes))*unitBase);
if frameNumDiff <0 % more TTLs recorded than video frames (see scenario above)
    vidTimes=vidTimes(vidTimes*unitBase<behavTraceLength+vidTimes(1)*unitBase);
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
    if isfield(wtData.whiskers,'Angle')&& isstruct(wtData.whiskers.Angle)
        wtData.whiskers.Angle.(wtFld{1})=wtData.whiskers.Angle.(wtFld{1})(reIndex);
        wtFld=fieldnames(wtData.whiskers.velocity);
        wtData.whiskers.velocity.(wtFld{1})=wtData.whiskers.velocity.(wtFld{1})(reIndex);
        wtFld=fieldnames(wtData.whiskers.phase);
        wtData.whiskers.phase.(wtFld{1})=wtData.whiskers.phase.(wtFld{1})(reIndex);
    else
        wtFld=fieldnames(wtData.whiskers);
        try
            for fldNum=1:numel(wtFld)
                wtData.whiskers.(wtFld{fldNum})=wtData.whiskers.(wtFld{fldNum})(reIndex);
            end
        catch
        end
    end
end
