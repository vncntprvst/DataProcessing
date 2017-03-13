function REXData=LoadRex_MergeSpk2(rexName)

% Given the name of some Rex data files (the A and E files,
% without the ‘A’ or ‘E’ on the end), attempts a conversion of this data
% into a Matlab file that contains all spike, code, saccade, and other
% data.
% Loads data exported from Spike2 and adds/replaces spike times, unit IDs and waveforms

%% Load Rex data
REXData = mrdr('-a','-d', rexName);

%% get data from Spike2

load([rexName 's.mat']);
load([rexName 't.mat']);
% find which channel contains the Spike data, and which the Sync triggers
varlist=who; %list variables
varlist=varlist(~cellfun(@isempty,strfind(varlist,rexName))); %restrict to the ones that start with the file name (the ones just loaded)
chName = cellfun(@(x) eval([x '.title']), varlist,'UniformOutput',false);
chName(strcmp(chName, 'trig')) = cellstr('trigger'); % rename trigs to triggers
chName(strcmp(chName, '')) = cellstr('trigger'); % rename blanks to triggers
eval(['Spk2Data = ' cell2mat(varlist(cellfun(@isempty,strfind(chName,'trigger'))))]);
eval(['Spk2Trig = ' cell2mat(varlist(~cellfun(@isempty,strfind(chName,'trigger'))))]);

% find which triggers are the trial starts
SyncTrigs=int32(round((Spk2Trig.times-Spk2Trig.times(1))*1000));
% TrialTimes=sort([[REXData.aStartTime] [REXData.aEndTime]]);
TrialTimes=sort([REXData.tStartTime]);
TrialTimes=TrialTimes-TrialTimes(1);
% find trigger pattern (e.g., Start / Stop)
trigSeqStep=mode(diff(find(ismember(floor(SyncTrigs/10),floor(TrialTimes/10)))));
firstTrig=find(ismember(floor(SyncTrigs/10),floor(TrialTimes/10)),1);
startTrigs=Spk2Trig.times(firstTrig:trigSeqStep:end);
endTrigs=Spk2Trig.times(firstTrig+1:trigSeqStep:end);

% if length(startTrigs)<size(TrialTimes,2) %misssing some trials
%     maxDiv=min(diff(TrialTimes));
%     for trialSeek=1:round(maxDiv/50-1)
%         startTrigs=sort(unique([startTrigs; ...
%         find(ismember(floor(SyncTrigs/int32(50*trialSeek)),...
%         floor(TrialTimes/int32(50*trialSeek))))]));
%     end
% end

for  trialNumber = 1:min([length(startTrigs) REXData(end).trialNumber])
    REXData(trialNumber).Units=Spk2Data.codes(Spk2Data.times>=startTrigs(trialNumber) &...
        Spk2Data.times<=endTrigs(trialNumber),1);
    REXData(trialNumber).SpikeTimes=round((Spk2Data.times(Spk2Data.times>=startTrigs(trialNumber) &...
        Spk2Data.times<=endTrigs(trialNumber))-startTrigs(trialNumber))*1000);
    REXData(trialNumber).Waveforms=Spk2Data.values(Spk2Data.times>=startTrigs(trialNumber) &...
        Spk2Data.times<=endTrigs(trialNumber),:);
end

