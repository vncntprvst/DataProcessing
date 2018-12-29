function TTLsignal=demuxTTLchannel(TTLsignal,TTLChannels)
% Works for 2 TTL channels. Not tested, and likely unadequate for more; 

% TTLsignal=[0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3];
if ~exist('TTLChannels','var')
    TTLChannels=[1, 2];
end
%% initialize
logicalChannels=2.^TTLChannels/2; %logical levels are 2 to the power of their channel number, halved, and summed for all channels. 
uniqueLogicalLevels=unique(TTLsignal)'; % e.g., [0 1 2 3]
modIdx=bsxfun(@mod,uniqueLogicalLevels,logicalChannels);
%% index
for chanMum=1:numel(TTLChannels)
    logicalIdx=(logical(sum(modIdx,2)) |... 
    uniqueLogicalLevels == logicalChannels(chanMum)) &...
    ~ismember(uniqueLogicalLevels,TTLChannels(~ismember(TTLChannels,TTLChannels(chanMum))));
    TTLsignal(chanMum+1,:)=0;
    TTLsignal(chanMum+1,ismember(TTLsignal(1,:),uniqueLogicalLevels(logicalIdx)))=...
        TTLChannels(chanMum);
end
%% remove muxed signal
TTLsignal=TTLsignal(2:end,:);
    