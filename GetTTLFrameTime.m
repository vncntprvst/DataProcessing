function frameCaptureTime=GetTTLFrameTime(fileName)
%% get high speed camera frame capture times from TTLs

if contains(fileName,'channel_states.npy')
    % Numpy array of Nevents int16. 
% Each event will be written as +CH_number for rising events and -CH_number for falling events
%     currentDir=cd;
    % go to directory first
%     cd(['..' filesep '..' filesep 'events' filesep 'Rhythm_FPGA-100.0' filesep 'TTL_1']);
    TTL_edge= double(readNPY(fileName));
    TTL_ID = readNPY('channels.npy');
    TTL_times = double(readNPY('timestamps.npy'));
    %%%% ASSUMING TTLs OF INTEREST ON TTL CH2, here TTL_ID 2 %%%%
    TTL_edge=TTL_edge(TTL_ID==2); 
    TTL_times=TTL_times(TTL_ID==2); 
elseif strfind(fileName,'events')
%     [~, Trials.TTL_times, info] = load_open_ephys_data(fileName);
%     TTLevents=info.eventType==3;
%     TTL_edge=info.eventId(TTLevents);
%     Trials.TTL_times=Trials.TTL_times(TTLevents); %convert to ms scale later
%     disp('Trials sampling rate?')
     return
elseif contains(fileName,'kw')
    if contains(fileName,'raw.kwd')
        %get the kwe file
    end
    % h5disp('experiment1.kwe','/event_types/TTL')
    % TTLinfo=h5info('experiment1.kwe','/event_types/TTL');
    TTL_edge = h5read(fileName,'/event_types/TTL/events/user_data/eventID');
    TTL_ID = h5read(fileName,'/event_types/TTL/events/user_data/event_channels');
    TTL_times = h5read(fileName,'/event_types/TTL/events/time_samples');
    %%%% ASSUMING TTLs OF INTEREST ON TTL CH2 i.e. TTL_ID 1 %%%%
    TTL_edge=TTL_edge(TTL_ID==1); 
    TTL_times=TTL_times(TTL_ID==1); 
end

frameCaptureTime=[TTL_times,TTL_edge]';