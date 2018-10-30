function Trials=getOE_Trials(fileName)
%% get Trial structure from TTLs

switch nargin
    case 0
        [fileName,dname] = uigetfile({'*.kwe','.Kwik Files';...
            '*.events','OE format Files'; '*.*','All Files'},'Events Data');
        cd(dname)
    case 1
        % fine
end

if contains(fileName,'channel_states.npy')
    currentDir=cd;
    % go to directory first
    try
        cd(['..' filesep '..' filesep 'events' filesep 'Rhythm_FPGA-100.0' filesep 'TTL_1']);
    catch %%may already be there
    end
    TTL_edge= readNPY(fileName);
    TTL_ID = readNPY('channels.npy');
    TTL_times = double(readNPY('timestamps.npy'));
    %%%% ASSUMING TTLs OF INTEREST ON TTL CH1, here TTL_ID 1 %%%%
    TTL_edge=TTL_edge(TTL_ID==1); 
    TTL_times=TTL_times(TTL_ID==1); 
    Trials.TTL_times=TTL_times;
    Trials.samplingRate{1} = 30000; %change when XML reader is done
    cd(currentDir)
elseif contains(fileName,'events')
    [~, Trials.TTL_times, info] = load_open_ephys_data(fileName);
    TTLevents=info.eventType==3;
    TTL_edge=info.eventId(TTLevents);
    Trials.TTL_times=Trials.TTL_times(TTLevents); %convert to ms scale later
    disp('Trials sampling rate?')
    return
elseif contains(fileName,'.kw')
    % h5disp('experiment1.kwe','/event_types/TTL')
    % TTLinfo=h5info('experiment1.kwe','/event_types/TTL');
    TTL_edge = h5read(fileName,'/event_types/TTL/events/user_data/eventID');
    TTL_ID = h5read(fileName,'/event_types/TTL/events/user_data/event_channels');
    TTL_times = double(h5read(fileName,'/event_types/TTL/events/time_samples'));
    %%%% ASSUMING TTLs OF INTEREST ON TTL CH1, here TTL_ID 0 %%%%
    TTL_edge=TTL_edge(TTL_ID==0); 
    TTL_times=TTL_times(TTL_ID==0); 
    Trials.TTL_times=TTL_times;
    Trials.samplingRate{1} = h5readatt(fileName,'/recordings/0/','sample_rate');
    %     Trials.TTL_times = Trials.TTL_times./uint64(Trials.samplingRate{1}/Trials.samplingRate{2}); %convert to ms scale
end

% keep absolute time of TTL onset
% Trials.TTL_times=Trials.TTL_times(diff([0;TTL_ID])>0);
% TTL sequence (in ms)
Trials.samplingRate{2} = 1000;
if ~isempty(Trials.TTL_times)
    TTL_seq=diff(Trials.TTL_times)./(Trials.samplingRate{1}/Trials.samplingRate{2}); % convert to ms
    TTLlength=mode(TTL_seq); %in ms
    
    onTTL_seq=diff(Trials.TTL_times(diff([0;TTL_edge])>0))./(Trials.samplingRate{1}/Trials.samplingRate{2});
    
    % In behavioral recordings, task starts with double TTL (e.g., two 10ms
    % TTLs, with 10ms interval). These pulses are sent at the begining of
    % each trial(e.g.,head through front panel). One pulse is sent at the
    % end of each trial. With sampling rate of 30kHz, that interval should
    % be 601 samples (20ms*30+1). Or 602 accounting for jitter.
    % onTTL_seq at native sampling rate should thus read as:
    %   601
    %   end of trial time
    %   inter-trial interval
    %   601 ... etc
    
    % In Stimulation recordings, there are only Pulse onsets, i.e., not
    % double TTL to start, followed TTL to end. There may be pulse trains with 
    % intertrain interval
    
    if TTL_seq(1)>=TTLlength+10 %missed first trial initiation, discard times
        TTL_seq(1)=TTLlength+300;
        onTTL_seq(1)=TTLlength+300;
    end
    if TTL_seq(end-1)<=TTLlength+10 %unfinished last trial
        TTL_seq(end)=TTLlength+300;
        onTTL_seq(end)=TTLlength+300;
    end
    
    allTrialTimes=Trials.TTL_times([1; find(bwlabel([0;diff(TTL_seq)]))+1]);
    if  size(unique(onTTL_seq),1)>=10 %behavioral recordings start: ON/OFF ON/OFF .... end: ON/OFF
                                      % with varying delay within trials
        Trials.start=allTrialTimes(1:2:end);
        Trials.end=allTrialTimes(2:2:end);
        try
            Trials.interval=Trials.end(1:end-1)-Trials.start(2:end);
        catch
            Trials.interval=mode(diff(allTrialTimes)); %
        end
        if numel(Trials.end)<numel(Trials.start)
            if diff([numel(Trials.end),numel(Trials.start)])==1
                Trials.end(end+1)=Trials.end(end)+Trials.interval(end);
            else %problem
                return
            end
        end
    elseif size(unique(onTTL_seq),1)<10 %stimulation recordings: trial ends when stimulation ends start: ON, end: OFF
        Trials.start=Trials.TTL_times([TTL_seq<=TTLlength*2+10;false]);%Trials.start=Trials.start./uint64(SamplingRate/1000)
        Trials.end=Trials.TTL_times([false;TTL_seq<=TTLlength*2+10]);
        Trials.interval=onTTL_seq; %
    end
    
    %convert to ms
    Trials.start(:,2)=Trials.start(:,1)./(Trials.samplingRate{1}/Trials.samplingRate{2});
    Trials.end(:,2)=Trials.end(:,1)./(Trials.samplingRate{1}/Trials.samplingRate{2});
    if ~isempty(Trials.interval)
        Trials.interval(:,2)=Trials.interval./(Trials.samplingRate{1}/Trials.samplingRate{2});
    end
else
    Trials.start=[];
    Trials.end=[];
    Trials.interval=[];
end
