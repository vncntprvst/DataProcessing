classdef WhiskingFun
    methods(Static)
        
        %% Filter whisking traces
        %%%%%%%%%%%%%%%%%%%%%%%%%
        function LP_whiskerTrace=LowPassBehavData(whiskerTrace,samplingRate,threshold)
            if nargin==1
                samplingRate=1000;
            elseif nargin==2
                threshold=20;
            end
            for whiskerTraceNum=1:size(whiskerTrace,1)
                LP_whiskerTrace(whiskerTraceNum,:)=...
                    FilterTrace(whiskerTrace(whiskerTraceNum,:),samplingRate,threshold,'low'); %set-point
            end
            % figure; hold on
            % plot(whiskerTrace_ms(whiskerTraceNum,:)); plot(LP_whiskerTrace_ms(whiskerTraceNum,:),'LineWidth',2)
        end
        
        function BP_whiskerTrace=BandPassBehavData(whiskerTrace,samplingRate,threshold)
            if nargin==1
                samplingRate=1000; threshold=[4 30];
            elseif nargin==2
                threshold=[4 30];
            end
            for whiskerTraceNum=1:size(whiskerTrace,1)
                BP_whiskerTrace(whiskerTraceNum,:)=...
                    FilterTrace(whiskerTrace(whiskerTraceNum,:),samplingRate,threshold,'bandpass'); %whisking
                % figure; hold on %plot(foo) % plot(whiskerTrace_ms(whiskerTraceNum,:))
                % plot(whiskerTrace_ms(whiskerTraceNum,:)-mean(whiskerTrace_ms(whiskerTraceNum,:))); plot(BP_whiskerTrace_ms(whiskerTraceNum,:),'LineWidth',1)
            end
        end
        
        function HP_whiskerTrace=HighPassBehavData(whiskerTrace,samplingRate,threshold)
            if nargin==1
                samplingRate=1000;
            elseif nargin==2
                threshold=0.3;
            end
            for whiskerTraceNum=1:size(whiskerTrace,1)
                HP_whiskerTrace(whiskerTraceNum,:)=...
                    FilterTrace(whiskerTrace(whiskerTraceNum,:),samplingRate,threshold,'high')'; %whisking
                % plot(HP_whiskerTrace_ms(whiskerTraceNum,:),'LineWidth',1)
            end
        end
        
        %% ResampleBehavData
        %%%%%%%%%%%%%%%%%%%%
        function whiskerTrace_ms=ResampleBehavData(whiskerTrackingData,vidTimes,samplingRate)
            %resample to 1ms precision
            vidTimes_ms=vidTimes/samplingRate*1000;
            for whiskerTraceNum=1:size(whiskerTrackingData,1)
                % Create array with angle values and time points
                whiskerTrace_ms(whiskerTraceNum,:)=interp1(vidTimes_ms,whiskerTrackingData(whiskerTraceNum,:),...
                    vidTimes_ms(1):vidTimes_ms(end));
                % [whiskerTrace(:,1),whiskerTrace(:,2)] = resample(whiskerTrace(:,1),whiskerTrace(:,2),'pchip');
            end
            % figure; plot(whiskerTrace_ms(whiskerTraceNum,:));
        end
        
        %% FindPeakWhisking
        %%%%%%%%%%%%%%%%%%%
        function peakWhisking=FindPeakWhisking(whiskerTrace_ms)
            % Find a period with whisking bouts
            % no need to keep periods with no whisking
            % figure; plot(whiskerTrace); % select data point and export cursor info
            % whiskingPeriod=1:cursor_info.Position(1); %in ms
            for whiskerTraceNum=1:size(whiskerTrace_ms,1)
                peakWhisking(whiskerTraceNum,:)=[0 0 diff(cummax(abs(diff(whiskerTrace_ms(whiskerTraceNum,:)))))];
                % peakWhiskingIdx=find(peakWhisking_ms==max(peakWhisking_ms));
                % whiskingPeriod=peakWhiskingIdx-5000:peakWhiskingIdx+4999; %in ms
            end
        end
                
        %% GetAmplitude
        %%%%%%%%%%%%%%%
        function wAmplitude=GetAmplitude(wTraces,wPhase)
            % Use function from J. Aljadeff, B.J. Lansdell, A.L. Fairhall and D. Kleinfeld (2016) Neuron, 91
            % link to manuscript: http://dx.doi.org/10.1016/j.neuron.2016.05.039
                % define functions
                Amp_Fun  = @range ; % function describing the magnitude of amplitude
                % get values
                wAmplitude = WhiskingFun.FindExtrema(wTraces,wPhase,Amp_Fun);
        end
        
        %% GetSetPoint
        %%%%%%%%%%%%%%
        function setPoint=GetSetPoint(wTraces,wPhase)
            % Use function from J. Aljadeff, B.J. Lansdell, A.L. Fairhall and D. Kleinfeld (2016) Neuron, 91
            % link to manuscript: http://dx.doi.org/10.1016/j.neuron.2016.05.039
                % define functions
                SetPoint_Fun =  @(x) (max(x) + min (x)) / 2'; % function describing the setpoint location
                % get values
                setPoint = WhiskingFun.FindExtrema(wTraces,wPhase,SetPoint_Fun);
        end
        
        %% FindExtrema
        %%%%%%%%%%%%%%
        function [interpSig, peakIdx, troughIdx] = FindExtrema(whiskerTrace, whiskerPhase, operation)
        % Use the phase (p) to find the turning points of the whisks (tops and
        % bottoms), and calculate a value on each consecutive whisk using the
        % function handle (operation, e.g. for amplitude, Amp_Fun  = @range)
        % The values are calculated twice per whisk cycle using both 
        % bottom-to-bottom and top-to-top.  The values are linearly 
        % interpolated between whisks.
        % From Primer code > get_slow_var
        % https://github.com/NeuroInfoPrimer/primer.git
            % find crossings
            peakIdx = find(whiskerPhase(1:end-1)<0 & whiskerPhase(2:end)>=0);
            troughIdx = find(whiskerPhase(1:end-1)>=pi/2 & whiskerPhase(2:end)<=-pi/2);

            % evaluate at transitions
            temp = []; pos = [];
            for valNum = 2:length(peakIdx)
                vals =  whiskerTrace( peakIdx(valNum-1):peakIdx(valNum) );
                temp(end+1)  =  operation(vals);
            end
            if length(peakIdx) > 1
                pos =    round( peakIdx(1:end-1) + diff(peakIdx)/2);
            end
            for valNum = 2:length(troughIdx)
                vals =  whiskerTrace( troughIdx(valNum-1):troughIdx(valNum) );
                temp(end+1)  =  operation(vals);
            end
            if length(troughIdx) > 1
                pos   = [pos round(troughIdx(1:end-1) + diff(troughIdx)/2)];
            end
            
            % sort everything
            [pos,i] = sort(pos);
            pos = [1 pos length(whiskerTrace)];
            
            if isempty(temp)
                temp = operation( whiskerTrace ) * [1 1] ;
            else
                temp = [temp(i(1)) temp(i) temp(i(end))];
            end
            
            % make piecewise linear signal
            interpSig = zeros( [1 length(whiskerTrace)] );
            for valNum = 2:length(pos)
                in = pos(valNum-1):pos(valNum);
                interpSig(in) = linspace( temp(valNum-1), temp(valNum), length(in) );
            end   
        end
        
        %% Compute Phase
        %%%%%%%%%%%%%%%%%%
        % Current code based on Whisker.WhiskerTrialLite (part of WhiskerPipeline)
        %                       > get_hilbert_transform
        %                       > get_phase
        function [whiskerPhase,whiskerFreq,whiskerAmplitude]=...
                ComputePhase(whiskerTrace,sampleRate,whiskingPeriodIdx)
            if nargin<3 %% compute phase over whole trace
                whiskingPeriodIdx=ones(1,size(whiskerTrace,2));
            end
            if nargin<2 || isempty(sampleRate)
                sampleRate=500; %default video acquisition frame rate
            end
            [whiskerPhase,whiskerFreq,whiskerAmplitude]=deal(nan(size(whiskerTrace)));
            for whiskerTraceNum=1:size(whiskerTrace,1)
                % bandpass filter 8 Hz lower to 30 Hz upper
                bandPassCutOffsInHz = [ 8 30 ];
                W1 = bandPassCutOffsInHz(1) / (sampleRate/2);
                W2 = bandPassCutOffsInHz(2) / (sampleRate/2);
                [ filtVectB, filtVectA ] = butter(2, [ W1 W2 ], 'bandpass');
                thetaNoNan = MMath.InterpNaN(whiskerTrace);
                filteredSignal = filtfilt(filtVectB, filtVectA, thetaNoNan);
                % Hilbert transform
                HTangleTrace = hilbert(filteredSignal)';
                % get phase from angle of complex-valued time series
                whiskerPhase(whiskerTraceNum,:) = -angle(HTangleTrace); % use -pi / pi convention
                whiskerFreq(whiskerTraceNum,:) = [0 sampleRate/(2*pi)*diff(unwrap(whiskerPhase(whiskerTraceNum,:)))];
                whiskerAmplitude(whiskerTraceNum,:) = abs(HTangleTrace);
            end
            whiskerPhase(:,~whiskingPeriodIdx)=nan;
            % numBins=32; % each bin = pi/16 radians
            % edges = linspace(min(whiskerPhase), max(whiskerPhase), numBins+1);
            % centers = mean([ edges(1:end-1); edges(2:end) ]);
            % [ ~, ~, phaseBins ] = histcounts(whiskerPhase, edges);
            % phaseBinCount=histcounts(phaseBins,[1 1+unique(phaseBins)]);
            % bar(unique(phaseBins),phaseBinCount)
        end
        
        % Legacy Phase calculation: fairly similar results, with overide of
        % small interwhisks, but biased toward retraction phase (rises more
        % slowly on average). See also Hill et al. 2011
        function [whiskerPhase,protractionIdx,retractionIdx]=ComputePhase_Legacy(whiskerTrace,whiskingPeriodIdx)
            if nargin==1 %% compute phase over whole trace
                whiskingPeriodIdx=ones(1,size(whiskerTrace,2));
            end
            [whiskerPhase,protractionIdx,retractionIdx]=deal(nan(size(whiskerTrace)));
            for whiskerTraceNum=1:size(whiskerTrace,1)
                % Hilbert transform NEEDS ANGLE TO BE ZERO CENTERED !
                angleTrace=whiskerTrace(whiskerTraceNum,:)-...
                    mean(whiskerTrace(whiskerTraceNum,:));
                % convert to radian if needed
                if max(abs(angleTrace))>pi
                    angleTrace=angleTrace*pi/180;
                end
                % Hilbert transform
                %                 HTangleTrace=hilbert(angleTrace); % doesn't work as expected
                % compute Fourier transform
                fftTrace=fft(angleTrace);
                % set power at negative frequencies to zero
                fftTrace(((size(fftTrace,2)+mod(size(fftTrace,2),2))/2):end)=0;
                % generate complex-valued time series via inverse Fourier transform
                HTangleTrace=ifft(fftTrace);
                % get phase from angle of complex-valued time series
                whiskerPhase(whiskerTraceNum,:)=angle(HTangleTrace);
                % identify protraction and retraction epochs
                protractionIdx(whiskerTraceNum,:)=whiskerPhase(whiskerTraceNum,:)<0;
                retractionIdx(whiskerTraceNum,:)=whiskerPhase(whiskerTraceNum,:)>0;
            end
            whiskerPhase(:,~whiskingPeriodIdx)=nan;
            %             figure; hold on; whiskerTraceNum=1;
            %             plot(whiskerTrace(whiskerTraceNum,1:100000))
            % %             plot(whiskingPeriodIdx(whiskerTraceNum,1:100000))
            %             plot(whiskerPhase_ms(whiskerTraceNum,1:100000))
            %             plot(1:100000,zeros(1,100000),'--k')
            %             protractionAngle=whiskerTrace(whiskerTraceNum,:)*pi/180;
            %             protractionAngle(~protractionIdx(whiskerTraceNum,:))=NaN;
            %             plot(protractionAngle(whiskerTraceNum,1:100000),'k')
            %             retractionAngle=whiskerTrace(whiskerTraceNum,:)*pi/180;
            %             retractionAngle(~retractionIdx(whiskerTraceNum,:))=NaN;
            %             plot(retractionAngle(whiskerTraceNum,1:100000),'r')
        end
        
        %% Find instantaneous frequency
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function instantFreq=ComputeInstFreq(whiskerTrace)
            % see also instfreq (e.g., ifq = instfreq(whiskerTrace,1000,'Method','hilbert') )
            Nfft = 1024;
            % [Pxx,f] = pwelch(BP_whiskerTrace,gausswin(Nfft),Nfft/2,Nfft,1000);
            % figure; plot(f,Pxx); ylabel('PSD'); xlabel('Frequency (Hz)'); grid on;
            for whiskerTraceNum=1:size(whiskerTrace,1)
                [~,sgFreq(:,whiskerTraceNum),sgTime(whiskerTraceNum,:),sgPower(whiskerTraceNum,:,:)] =...
                    spectrogram(whiskerTrace(whiskerTraceNum,:),gausswin(Nfft),Nfft/2,Nfft,1);
                instantFreq(whiskerTraceNum,:) = medfreq(squeeze(sgPower(whiskerTraceNum,:,:)),sgFreq(:,whiskerTraceNum));
                % figure; plot(sgTime(whiskerTraceNum,:),round(instantFreq(whiskerTraceNum,:)*1000),'linewidth',2)
            end
        end
        
        %% FindWhiskingEpochs
        %%%%%%%%%%%%%%%%%%%%%
        function whiskingEpochsIdx=FindWhiskingEpochs(wAmplitude,wFrequency,...
                                        ampThreshold,freqThreshold,minDur)
            if nargin<5; minDur=100; end
            if nargin<4; freqThreshold=1; end
            if nargin<3; ampThreshold=2.5; end % (degrees)
            wAmplitude(isnan(wAmplitude))=0;
            ampSmoothFiltParam = 0.005 ; % parameter for amplitude smoothing filter such that whisking bout 'cutouts' are not too short
            ampFilter = filtfilt(ampSmoothFiltParam, [1 ampSmoothFiltParam-1],wAmplitude) ; % filtered amplitude variable
            % threshold by amplitude
            ampEpochsIdx = logical(heaviside(ampFilter-ampThreshold));
            % threshold by frequency
            freqEpochsIdx = wFrequency>freqThreshold;
            whiskingEpochsIdx = ampEpochsIdx & freqEpochsIdx;
            if exist('minDur','var') %remove periods shorter than minimum duration
                whiskBoutList = bwconncomp(whiskingEpochsIdx) ;
                properWhiskBoutIdx=cellfun(@(wBout) numel(wBout)>=minDur, whiskBoutList.PixelIdxList);
                whiskingEpochsIdx(vertcat(whiskBoutList.PixelIdxList{~properWhiskBoutIdx}))=false;
            end
        end
        
        %% FindWhiskingModes
        %%%%%%%%%%%%%%%%%%%
        function whiskingEpochsIdx=FindWhiskingModes(wAmplitude,wFrequency,thdParams)
            % For whisking modes definition, see Berg and Kleinfeld 2003 (in rat)
            % https://physiology.org/doi/full/10.1152/jn.00600.2002
        % if thresholds are specified, need to be structure with values for each mode
            if nargin==2
                thdParams(1).type='foveal';thdParams(2).type='exploratory';thdParams(3).type='twitching';
                thdParams(1).amp=2.5;thdParams(2).amp=10;thdParams(3).amp=2.5;
                thdParams(1).freq=15;thdParams(2).freq=5;thdParams(3).freq=1; % Expl.: 5–15 Hz. Foveal 15–25 Hz
                thdParams(1).dur=500;thdParams(2).dur=500;thdParams(3).dur=100;
            end
            wAmplitude(isnan(wAmplitude))=0;
            ampSmoothFiltParam = 0.005 ; % parameter for amplitude smoothing filter such that whisking bout 'cutouts' are not too short
            ampFilter = filtfilt(ampSmoothFiltParam, [1 ampSmoothFiltParam-1],wAmplitude) ; % filtered amplitude variable
            % threshold by amplitude
            ampEpochsIdx = logical(heaviside(ampFilter-ampThreshold));
            % threshold by frequency
            freqEpochsIdx = wFrequency>freqThreshold;
            whiskingEpochsIdx = ampEpochsIdx & freqEpochsIdx;
            if exist('minDur','var') %remove periods shorter than minimum duration
                whiskBoutList = bwconncomp(whiskingEpochsIdx) ;
                properWhiskBoutIdx=cellfun(@(wBout) numel(wBout)>=minDur, whiskBoutList.PixelIdxList);
                whiskingEpochsIdx(vertcat(whiskBoutList.PixelIdxList{~properWhiskBoutIdx}))=false;
            end
        end

        %% Compute spectral coherence
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
    end
end

