classdef WhiskingAnalysisFunctions
    methods(Static)
        function periodBehavData_ms=ResampleBehavData(whiskerTrackingData,vidTimes,samplingRate)
            %resample to 1ms precision
            vidTimes_ms=vidTimes/samplingRate*1000;
            for whiskerTraceNum=1:size(whiskerTrackingData,1)
                % Create array with angle values and time points
                periodBehavData_ms(whiskerTraceNum,:)=interp1(vidTimes_ms,whiskerTrackingData(whiskerTraceNum,:),...
                    vidTimes_ms(1):vidTimes_ms(end));
                % [periodBehavData(:,1),periodBehavData(:,2)] = resample(periodBehavData(:,1),periodBehavData(:,2),'pchip');
            end
            % figure; plot(periodBehavData_ms(whiskerTraceNum,:));
        end
        function peakWhisking_ms=FindWhiskingBouts(periodBehavData_ms)
            % Find a period with whisking bouts
            % no need to keep periods with no whisking
            % figure; plot(periodBehavData); % select data point and export cursor info
            % whiskingPeriod=1:cursor_info.Position(1); %in ms
            for whiskerTraceNum=1:size(periodBehavData_ms,1)
                peakWhisking_ms(whiskerTraceNum,:)=[0 0 diff(cummax(abs(diff(periodBehavData_ms(whiskerTraceNum,:)))))];
                % peakWhiskingIdx=find(peakWhisking_ms==max(peakWhisking_ms));
                % whiskingPeriod=peakWhiskingIdx-5000:peakWhiskingIdx+4999; %in ms
            end
        end        
        function whiskingPeriodIdx=FindWhiskingPeriods(periodBehavData)
            whiskingPeriodIdx=[0 abs(diff(periodBehavData(1,:)))>=3*mad(diff(periodBehavData(1,:)))] &...
                abs(periodBehavData(1,:))>=3*mad(periodBehavData(1,:));
            whiskingPeriodIdx=movsum(whiskingPeriodIdx,500)>0;
        end
        %% Filter periodic behavior traces
        function LP_periodBehavData_ms=LowPassBehavData(periodBehavData,samplingRate)
            if nargin==1
                samplingRate=1000;
            elseif nargin==2
                threshold=0.3;
            end
            for whiskerTraceNum=1:size(periodBehavData,1)
                LP_periodBehavData_ms(whiskerTraceNum,:)=...
                    FilterTrace(periodBehavData(whiskerTraceNum,:),samplingRate,threshold,'low'); %set-point
            end
            % figure; hold on
            % plot(periodBehavData_ms(whiskerTraceNum,:)); plot(LP_periodBehavData_ms(whiskerTraceNum,:),'LineWidth',2)
        end
        function BP_periodBehavData_ms=BandPassBehavData(periodBehavData,samplingRate,threshold)
            if nargin==1
                samplingRate=1000; threshold=[4 25];
            elseif nargin==2
                threshold=[4 25];
            end
            for whiskerTraceNum=1:size(periodBehavData,1)
                BP_periodBehavData_ms(whiskerTraceNum,:)=...
                    FilterTrace(periodBehavData(whiskerTraceNum,:),samplingRate,threshold,'bandpass'); %whisking
                % figure; hold on %plot(foo) % plot(periodBehavData_ms(whiskerTraceNum,:))
                % plot(periodBehavData_ms(whiskerTraceNum,:)-mean(periodBehavData_ms(whiskerTraceNum,:))); plot(BP_periodBehavData_ms(whiskerTraceNum,:),'LineWidth',1)
            end
        end
        function HP_periodBehavData_ms=HighPassBehavData(periodBehavData,samplingRate)
            if nargin==1
                samplingRate=1000;
            elseif nargin==2
                threshold=0.3;
            end
            for whiskerTraceNum=1:size(periodBehavData,1)
                HP_periodBehavData_ms(whiskerTraceNum,:)=...
                    FilterTrace(periodBehavData(whiskerTraceNum,:),samplingRate,threshold,'high')'; %whisking
                % plot(HP_periodBehavData_ms(whiskerTraceNum,:),'LineWidth',1)
            end
        end
        %% Calculate Phase
        function [whiskingPhase_ms,protractionIdx,retractionIdx]=ComputePhase(periodBehavData,whiskingPeriodIdx)  
            % See Hill et al. 2011
            if nargin==1 %% compute phase over whole trace
                whiskingPeriodIdx=ones(1,size(periodBehavData,2));
            end
            [whiskingPhase_ms,protractionIdx,retractionIdx]=deal(nan(size(periodBehavData))); 
            for whiskerTraceNum=1:size(periodBehavData,1)                         
                % Hilbert transform NEEDS ANGLE TO BE ZERO CENTERED !
                angleTrace=periodBehavData(whiskerTraceNum,:)-...
                    mean(periodBehavData(whiskerTraceNum,:));
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
                whiskingPhase_ms(whiskerTraceNum,:)=angle(HTangleTrace);
                % identify protraction and retraction epochs
                protractionIdx(whiskerTraceNum,:)=whiskingPhase_ms(whiskerTraceNum,:)<0;
                retractionIdx(whiskerTraceNum,:)=whiskingPhase_ms(whiskerTraceNum,:)>0;
            end
            whiskingPhase_ms(:,~whiskingPeriodIdx)=nan;
%             figure; hold on; whiskerTraceNum=1;
%             plot(periodBehavData(whiskerTraceNum,1:100000))
% %             plot(whiskingPeriodIdx(whiskerTraceNum,1:100000))
%             plot(whiskingPhase_ms(whiskerTraceNum,1:100000))
%             plot(1:100000,zeros(1,100000),'--k')
%             protractionAngle=periodBehavData(whiskerTraceNum,:)*pi/180; 
%             protractionAngle(~protractionIdx(whiskerTraceNum,:))=NaN;
%             plot(protractionAngle(whiskerTraceNum,1:100000),'k')
%             retractionAngle=periodBehavData(whiskerTraceNum,:)*pi/180;  
%             retractionAngle(~retractionIdx(whiskerTraceNum,:))=NaN;
%             plot(retractionAngle(whiskerTraceNum,1:100000),'r')
        end        
        %% Find instantaneous frequency
        function instantFreq_ms=ComputeInstFreq(periodBehavData)
            Nfft = 1024;
            % [Pxx,f] = pwelch(BP_periodBehavData,gausswin(Nfft),Nfft/2,Nfft,1000);
            % figure; plot(f,Pxx); ylabel('PSD'); xlabel('Frequency (Hz)'); grid on;
            for whiskerTraceNum=1:size(periodBehavData,1)
                [~,sgFreq(:,whiskerTraceNum),sgTime(whiskerTraceNum,:),sgPower(whiskerTraceNum,:,:)] =...
                    spectrogram(periodBehavData(whiskerTraceNum,:),gausswin(Nfft),Nfft/2,Nfft,1);
                instantFreq_ms(whiskerTraceNum,:) = medfreq(squeeze(sgPower(whiskerTraceNum,:,:)),sgFreq(:,whiskerTraceNum));
                % figure; plot(sgTime(whiskerTraceNum,:),round(instantFreq(whiskerTraceNum,:)*1000),'linewidth',2)
            end
        end
        %% Compute spectral coherence
        
    end
end

