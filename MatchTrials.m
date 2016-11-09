function [ephysCommonTrials, behaviorCommonTrials]=MatchTrials(ephysTrials,Behavior)

if size(ephysTrials.start,2)>1
ephysTrials.start=ephysTrials.start(:,1);
ephysTrials.end=ephysTrials.end(:,1);
end

Behav_TrialStart=uint64(Behavior.trials.trialStartTime);%[Behavior.trialTime{Behavior.trialStartIdx}];
% Behav_TrialStart=Behav_TrialStart(1:end); %(2:end) if missed first trial
% msBehav_TrialStart=[Behavior.trialTime{1:end}]; %plot all timestamps for comparison purposes
zeroed_Behav_TrialStart=Behav_TrialStart-Behav_TrialStart(1)+1;

TTL_TrialStart=ephysTrials.start;
zeroed_TTL_TrialStart=TTL_TrialStart-TTL_TrialStart(1)+1;
if mode(zeroed_TTL_TrialStart./zeroed_Behav_TrialStart)==30 %TTL still at 30kHz
    TTL_TrialStart=TTL_TrialStart/30;
    zeroed_TTL_TrialStart=TTL_TrialStart-TTL_TrialStart(1)+1;
    ephysTrials.end=ephysTrials.end/30;
end
zeroed_TTL_TrialStartIdx=false(1,ceil(zeroed_TTL_TrialStart(end)));
zeroed_TTL_TrialStartIdx(int32(round(zeroed_TTL_TrialStart)))=true;

% msTTL_TrialEnd=double(Trials.end)/double(downSamplingRatio);
TTL_TrialEnd=ephysTrials.end;
zeroed_TTL_TrialEnd=TTL_TrialEnd-TTL_TrialStart(1)+1;
zeroed_TTL_TrialEndIdx=false(1,ceil(zeroed_TTL_TrialEnd(end)));
zeroed_TTL_TrialEndIdx(int32(round(zeroed_TTL_TrialEnd)))=true;

zeroed_Behav_TrialStartIdx=false(1,max([ceil(zeroed_TTL_TrialStart(end)) ceil(zeroed_Behav_TrialStart(end))]));
zeroed_Behav_TrialStartIdx(int32(round(zeroed_Behav_TrialStart)))=true;



% figure;hold on
% plot(zeroed_TTL_TrialStartIdx)
% plot(zeroed_TTL_TrialEndIdx)
% plot(zeroed_Behav_TrialStartIdx*0.5)

%% find common trials
% bin to 30ms bins
binSize=30;
numBin=ceil(size(zeroed_TTL_TrialStartIdx,2)/binSize);
[zeroed_TTL_TrialStartIdx_binned] = histcounts(double(find(zeroed_TTL_TrialStartIdx)), linspace(0,size(zeroed_TTL_TrialStartIdx,2),numBin));
[zeroed_Behav_TrialStartIdx_binned] = histcounts(double(find(zeroed_Behav_TrialStartIdx)), linspace(0,size(zeroed_Behav_TrialStartIdx,2),numBin));

% figure;hold on
% plot(zeroed_TTL_TrialStartIdx_binned)
% plot(zeroed_Behav_TrialStartIdx_binned*0.5)

% find(zeroed_TTL_TrialStartIdx_binned,10);
% find(zeroed_Behav_TrialStartIdx_binned,10);

behaviorCommonTrials=ismember(find(zeroed_Behav_TrialStartIdx_binned),find(zeroed_TTL_TrialStartIdx_binned)) |...
ismember(find(zeroed_Behav_TrialStartIdx_binned),find(zeroed_TTL_TrialStartIdx_binned)+1) |...
ismember(find(zeroed_Behav_TrialStartIdx_binned),find(zeroed_TTL_TrialStartIdx_binned)-1);

ephysCommonTrials=ismember(find(zeroed_TTL_TrialStartIdx_binned),find(zeroed_Behav_TrialStartIdx_binned)) |...
ismember(find(zeroed_TTL_TrialStartIdx_binned),find(zeroed_Behav_TrialStartIdx_binned)+1) |...
ismember(find(zeroed_TTL_TrialStartIdx_binned),find(zeroed_Behav_TrialStartIdx_binned)-1);

legend('behaviorCommonTrials','ephysCommonTrials')

end
