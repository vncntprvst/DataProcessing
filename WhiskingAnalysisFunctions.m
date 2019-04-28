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
                peakWhisking_ms(whiskerTraceNum,:)=diff(cummax(abs(diff(periodBehavData_ms(whiskerTraceNum,:)))));
                % peakWhiskingIdx=find(peakWhisking_ms==max(peakWhisking_ms));
                % whiskingPeriod=peakWhiskingIdx-5000:peakWhiskingIdx+4999; %in ms
            end
        end        
        %% Filter periodic behavior traces
        function LP_periodBehavData_ms=LowPassBehavData(periodBehavData_ms)
            for whiskerTraceNum=1:size(periodBehavData_ms,1)
                LP_periodBehavData_ms(whiskerTraceNum,:)=...
                    FilterTrace(periodBehavData_ms(whiskerTraceNum,:),1000,0.3,'low'); %set-point
            end
            % figure; hold on
            % plot(periodBehavData_ms(whiskerTraceNum,:)); plot(LP_periodBehavData_ms(whiskerTraceNum,:),'LineWidth',2)
        end
        function BP_periodBehavData_ms=BandPassBehavData(periodBehavData_ms)
            for whiskerTraceNum=1:size(periodBehavData_ms,1)
                BP_periodBehavData_ms(whiskerTraceNum,:)=...
                    FilterTrace(periodBehavData_ms(whiskerTraceNum,:),1000,[0.3 20],'bandpass'); %whisking
                % figure; hold on %plot(foo) % plot(periodBehavData_ms(whiskerTraceNum,:))
                % plot(periodBehavData_ms(whiskerTraceNum,:)-mean(periodBehavData_ms(whiskerTraceNum,:))); plot(BP_periodBehavData_ms(whiskerTraceNum,:),'LineWidth',1)
            end
        end
        function HP_periodBehavData_ms=HighPassBehavData(periodBehavData_ms)
            for whiskerTraceNum=1:size(periodBehavData_ms,1)
                HP_periodBehavData_ms(whiskerTraceNum,:)=...
                    FilterTrace(periodBehavData_ms(whiskerTraceNum,:),1000,0.3,'high')'; %whisking
                % plot(HP_periodBehavData_ms(whiskerTraceNum,:),'LineWidth',1)
            end
        end
        %% Calculate Phase
        function whiskingPhase_ms=ComputePhase(BP_periodBehavData_ms)
            %% Hilbert transform
            % Hilbert transform NEEDS ANGLE TO BE ZERO CENTERED !!!
            % periodicSignal=smoothdata(BP_periodBehavData_ms(whiskerTraceNum,:),'robustfit');
            % -mean(BP_periodBehavData_ms(whiskerTraceNum,:));
            % baseSignal=FilterTrace(periodicSignal,1000,0.3,'low');
            % baseSignal=LP_periodBehavData_ms(whiskerTraceNum,:)-mean(LP_periodBehavData_ms(whiskerTraceNum,:));
            % figure; hold on; plot(periodicSignal);
            % periodicSignal(abs(periodicSignal)<2*std(abs(periodicSignal)))=0;plot(baseSignal);
            for whiskerTraceNum=1:size(BP_periodBehavData_ms,1)
                HTBP_periodBehavData_ms(whiskerTraceNum,:)=hilbert(BP_periodBehavData_ms(whiskerTraceNum,:));
                % figure; plot(imag(HTBP_periodBehavData_ms(whiskerTraceNum,:)));
                % foo=abs(imag(HTBP_periodBehavData_ms(whiskerTraceNum,:)))<mad((imag(HTBP_periodBehavData_ms(whiskerTraceNum,:))));
                % bla=imag(HTBP_periodBehavData_ms(whiskerTraceNum,:)); bla(foo)=0; plot(bla)
                % plot(imag(HTBP_periodBehavData_ms(whiskerTraceNum,:)));
                whiskingPhase_ms(whiskerTraceNum,:)=angle(HTBP_periodBehavData_ms(whiskerTraceNum,:));
            end
            % whiskingPhase_ms(foo)=0;
            % plot(whiskingPhase_ms)
            % figure; hold on
            % plot(SDFs); plot(whiskingPhase*10 + max(SDFs))
        end        
        %% Find instantaneous frequency
        function instantFreq_ms=ComputeInstFreq(BP_periodBehavData_ms)
            Nfft = 1024;
            % [Pxx,f] = pwelch(BP_periodBehavData,gausswin(Nfft),Nfft/2,Nfft,1000);
            % figure; plot(f,Pxx); ylabel('PSD'); xlabel('Frequency (Hz)'); grid on;
            for whiskerTraceNum=1:size(BP_periodBehavData_ms,1)
                [~,sgFreq(:,whiskerTraceNum),sgTime(whiskerTraceNum,:),sgPower(whiskerTraceNum,:,:)] =...
                    spectrogram(BP_periodBehavData_ms(whiskerTraceNum,:),gausswin(Nfft),Nfft/2,Nfft,1);
                instantFreq_ms(whiskerTraceNum,:) = medfreq(squeeze(sgPower(whiskerTraceNum,:,:)),sgFreq(:,whiskerTraceNum));
                % figure; plot(sgTime(whiskerTraceNum,:),round(instantFreq(whiskerTraceNum,:)*1000),'linewidth',2)
            end
        end
    end
end