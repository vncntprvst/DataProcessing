%% saccade detection
function [saccadeInfo, saccadeIdx]=SaccadeDetection(h,v,minwidth)
% Calculate velocity and acceleration
% Input horizontal and vertical velocity vectors, plus saccade duration
% window in ms. 
% Output filtered position, velocity and acceleration plus unfiltered velocity.
% Unfiltered velocity (nativevel) is used for noise detection.
%------------------------------------

[filth, filtv, filtvel, filtacc, nativevel, nativeacc] = cal_velacc(h,v,minwidth);

% Detect noise
% Vestigial processing from eye tracking data analysis. (=no blinks for eye
% coil)
% Might come in handy for future setups
% For the moment, only minimal processing to remove noise
%-------------------------------------

VelocityThreshold = 1.5;     %peak velocity is almost never more than 1000deg/s, so if vel > 1.5 deg/ms, it is noise (or blinks for eye tracker)
AccThreshold = 0.1;          %if acc > 100000 degrees/s^2, that is 0.1 deg/ms^2, it is noise (or blinks)

    noisebg= median(nativevel)*2;
    
    % Detect possible noise (if the eyes move too fast)
    noiseIdx = nativevel> VelocityThreshold | abs(filtacc) > AccThreshold;
    %label groups of noisy data
    noiselabels = bwlabel(noiseIdx);
    
    % Process one noise period at the time
    for k = 1:max(noiselabels)

        % The samples related to the current event
        noisyperiod = find(noiselabels == k);

        % Go back in time to see where the noise started
        sEventIdx = find(nativevel(noisyperiod(1):-1:1) <= noisebg);
        if isempty(sEventIdx), continue, end
        sEventIdx = noisyperiod(1) - sEventIdx(1) + 1;
        noiseIdx(sEventIdx:noisyperiod(1)) = 1;      

        % Go forward in time to see where the noise ended    
        eEventIdx = find(nativevel(noisyperiod(end):end) <= noisebg);
        if isempty(eEventIdx), continue, end    
        eEventIdx = (noisyperiod(end) + eEventIdx(1) - 1);
        noiseIdx(noisyperiod(end):eEventIdx) = 1;

    end

    %then correct if possible
     noiselabels = bwlabel(noiseIdx);

        str = sprintf('found %d noise periods in trial #%d', max(noiselabels), next);
        disp(str);
     
    % Process one noise period at the time
    for k = 1:max(noiselabels)

        % The samples related to the current event
        noisyperiod = find(noiselabels == k);
        
        % in case it's only filtvel that has outliers, correct them
        if median(filtvel(noisyperiod(1):noisyperiod(end)))> VelocityThreshold && median(nativevel(noisyperiod(1):noisyperiod(end)))< VelocityThreshold
            filtvel(noisyperiod(1):noisyperiod(end)) = median(nativevel(noisyperiod(1):noisyperiod(end)));
            noiseIdx(noisyperiod(1):noisyperiod(end)) = 0;
            disp('noise was in filtered velocity data, corrected');
        else
            disp('noise in  data, left uncorrected');
        end
    end        
      
%     if logical(sum(noiseIdx))
%     snoisearea = find(diff(noiseIdx) > 0);
%     enoisearea = find(diff(noiseIdx) < 0);
%     if isempty(snoisearea) || snoisearea(1) > enoisearea(1) % plot is shaded from start
%         snoisearea = [1 snoisearea];
%     end
%     if isempty(enoisearea) || snoisearea(end) > enoisearea(end) % plot is shaded until end
%         enoisearea = [enoisearea length(noiseIdx)];
%     end
%     end
%     
% iteratively find the optimal noise threshold
%---------------------------------------------
    minfixwidth = 40; %minimum fixation duration

    peakDetectionThreshold = 0.1;     % Initial value of the peak detection threshold. Final value typically around 0.47
    oldPeakT = inf;
    while abs(peakDetectionThreshold -  oldPeakT) > 1 % will iterate until reach consensus value

            oldPeakT  = peakDetectionThreshold;

            % Detect velocity peaks larger than a threshold ('peakDetectionThreshold')
            % Sets a '1' where the velocity is larger than the threshold and '0' otherwise
            
            InitialVelPeakIdx  = (filtvel > peakDetectionThreshold);
 
            % Find fixation noise level and calculate peak velocity threshold
            [peakDetectionThreshold, saccadeVelocityTreshold, velPeakIdx] = rex_detectFixationNoiseLevel(minfixwidth,InitialVelPeakIdx,filtvel);   

    end

% New saccade detection methode (with peak detection threshold (v <
% v_avg_noise + 3*v_std_noise)) (original code also detected glissades)
%-------------------------------------            
%  s = sprintf('trial %d',next);
%   disp(s);
    %note that the trial number given to find_saccades_3 is 'next', not
    %'trialnumber'
   [saccadeInfo, saccadeIdx] = find_saccades_3(next,filtvel,filtacc,velPeakIdx,minwidth,minfixwidth,saccadeVelocityTreshold,peakDetectionThreshold,filth,filtv);
   