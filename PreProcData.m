function [data,channelSelection]=PreProcData(data,samplingRate,filterOption)

% channel string
chStr= num2str(linspace(1,size(data,1),size(data,1))');
channelSelection=[];
%adjust dialogs position
defaultFigPos=get(0, 'defaultfigureposition');
diagPos=[1631 437 defaultFigPos(3:4)];
set(0,'defaultfigureposition',diagPos);

if ~isa(data,'double') & ~strcmp(filterOption{1},'nopp')
    data=double(data);
end

%% Pre-processing options
if strcmp(filterOption{1},'lowpass')
    %% butterworth low-pass
    tic
    [b,a] = butter(3,6000/(samplingRate/2),'low');
    % delay = round(max(grpdelay(b,a)));
    for chNm=1:size(data,1)
        data(chNm,:)= filtfilt(b, a, data(chNm,:));
    end
    disp(['lowpass done in ' num2str(toc) 'seconds']);
elseif strcmp(filterOption{1},'highpass')
    %% butterworth high-pass
    tic
    [b,a] = butter(3,500/(samplingRate/2),'high');
    % delay = round(max(grpdelay(b,a)));
    for chNm=1:size(data,1)
%         data(chNm,:)= filter(b,a,single(data(chNm,:)));
          data(chNm,:)= filtfilt(b, a, data(chNm,:));
    end
    disp(['highpass done in ' num2str(toc) 'seconds']);
elseif strcmp(filterOption{1},'bandpass')
    %% butterworth high-pass
     if size(filterOption,2)==2
        promptFields={'Enter highpass value','Enter lowpass value'};
        promptName='Butterworth IIR filter parameters';
        promptNumlines=1;
        promptDefaultanswer={'500','10000'};
        filtValues=inputdlg(promptFields,promptName,promptNumlines,promptDefaultanswer);
        filtHP=str2double(filtValues{1});
        filtLP=str2double(filtValues{2});
     else
         filtHP=500;
         filtLP=6000;
     end
    tic
    [b,a] = butter(3,[filtHP/(samplingRate/2) filtLP/(samplingRate/2)]);
    % delay = round(max(grpdelay(b,a)));
    for chNm=1:size(data,1)
        data(chNm,:)= filtfilt(b, a, data(chNm,:));
    end
    disp(['bandpass done in ' num2str(toc) 'seconds']);
elseif strcmp(filterOption{1},'movav_sub')
    %% substract moving average
    % mvaData=nans(size(data,1),size(data,2));
    avOver=5; %ms
    windowSize=avOver*(samplingRate/1000);
    meanDelay = round(mean(grpdelay((1/windowSize)*ones(1,windowSize),1)));
    for chNm=1:size(data,1)
        movAverage = filtfilt((1/windowSize)*ones(1,windowSize),1,data(chNm,:));
        movAverageTail=filtfilt((1/windowSize)*ones(1,windowSize),1,data(chNm,end-meanDelay+1:end));
        movAverage = [movAverage(meanDelay+1:end) movAverageTail(avOver+2:end)] ;
        movAverageHeadLim=find((diff(diff((movAverage))))>1,1)+1;
        [b,a] = butter(3,3000/(samplingRate/2),'low');
        movAverageHead=filtfilt(b,a,...
            [data(chNm,movAverageHeadLim:-1:1) data(chNm,1:movAverageHeadLim)]);
        movAverageHead=movAverageHead(movAverageHeadLim+1:end);%+...
%             (movAverage(movAverageHeadLim)-movAverageHead(movAverageHeadLim));
        movAverageTailLim=find((diff(diff((movAverage))))>1,1,'last');
        movAverageTail=filtfilt(b,a,...
            [data(chNm,movAverageTailLim:end) data(chNm,end:-1:movAverageTailLim)]);
        movAverageTail=movAverageTail(end:-1:size(data(chNm,movAverageTailLim:end),2)+1);
        movAverage = [movAverageHead...
            movAverage(movAverageHeadLim+1:movAverageTailLim-1)...
            movAverageTail] ;
        data(chNm,:)=data(chNm,:)-int16(movAverage);
    end
elseif  strcmp(filterOption{1},'CAR')
    %% common average referencing   
    if size(filterOption,2)>1 & strcmp(filterOption{2},'LP')
        % butterworth low-pass
        [b,a] = butter(3,10000/(samplingRate/2),'low');
    else
        % butterworth band-pass
        [b,a] = butter(3,[500 10000]/(samplingRate/2),'bandpass');
    end
    for chNm=1:size(data,1)
        data(chNm,:)= filtfilt(b,a,data(chNm,:));
    end
    % select channels to use for CAR
    if size(filterOption,2)>1 & strcmp(filterOption{2},'all')
        channelSelection=linspace(1,size(data,1),size(data,1));
    elseif size(filterOption,2)>1 & ~strcmp(filterOption{2},'all')
        channelSelection= str2num(filterOption{2});
    else
        channelSelection= listdlg('PromptString',...
        'select channels to use for CAR to plot:','ListString',chStr);
    end
    data=(data-repmat(median(data(channelSelection,:),1),[size(data,1),1]));%./mad(faa,1);
    
elseif  strcmp(filterOption{1},'norm')
    %% normalization following Pouzat's method
% data is high-passed filtered with a cutoff frequency between 200 and 500 Hz
% each channel is then median subtracted and divided by its median absolute deviation (MAD).
% The MAD provides a robust estimate of the standard deviation of the recording noise. After this
% normalisation, detection thresholds are comparable on the different electrode.
    tic
    
    % for LY 
%     data=[foo{:}];
%     data=data([1,3,5,7,11,13,15,17],:); % 9 and 10 were floating, and channels were duplicated
    % butterworth high-pass
    [b,a] = butter(3,500/(samplingRate/2),'high');
    % delay = round(max(grpdelay(b,a)));
    for chNm=1:size(data,1)
        data(chNm,:)= filtfilt(b,a,data(chNm,:));
    end
    data=(data-repmat(median(data,1),[size(data,1),1]));%./mad(faa,1);

    timewindow=1800000;
    figure; hold on
    for chNm=1:size(data,1)
%         subplot(8,1,chNm)
        plot(data(chNm,timewindow:2*timewindow)+(max(max(data)/4)*(chNm-1)))
    end
    
    set(gca,'xtick',linspace(0,1800000,4),'xticklabel',linspace(60,120,4),'TickDir','out');
    set(gca,'ytick',linspace(-1000,10000,10),'yticklabel',...
        {'','Chan 1','Chan 2','Chan 3','Chan 4','Chan 5','Chan 6','Chan 7','Chan 8',''})
    set(gca,'ylim',[-1000,10000],'xlim',[0,1800000])
    axis('tight');box off;
    xlabel('Time (s.)')
    ylabel('Norm. Firing rate')
    set(gca,'Color','white','FontSize',18,'FontName','calibri');


%     faa=data(:,1:30000);
%     % median substraction and MAD division
%     faa=(double(faa)-repmat(median(double(faa),1),[size(double(faa),1),1]));%./mad(faa,1);
%     daat===(double(faa)-repmat(median(double(faa),1),[size(double(faa),1),1]));%./mad(faa,1);

    % for further spike detection
    % detect valleys
%     filtFaa=smooth(double(faa));
%     filtFaa=filtFaa-median(filtFaa);
%     filtFaa=filtFaa./mad(filtFaa,1);
%     filtFaa(filtFaa>-3)=0;
    
    disp(['normalization done in ' num2str(toc) 'seconds']);
elseif  strcmp(filterOption{1},'difffilt')
    %% multi-stage filter / amplification
    tic;
    disp('diff started');
    for chNm=1:size(data,1)
        disp(['Channel ' num2str(chNm) ' of ' num2str(size(data,1))]);
        
        %start with fairly high HP for a basis
        [b,a] = butter(3,500/(samplingRate/2),'high'); %'bandpass' is the default when Wn has two elements.
        HPfiltSample = filtfilt(b,a,data(chNm,:));
        
        % get the underlying low-frequency baseline
        [b,a] = butter(3,1000/(samplingRate/2),'low'); %'bandpass' is the default when Wn has two elements.
        filtSampleDelay= round(max(grpdelay(b,a)));
        LPfiltSample = filtfilt(b,a,[HPfiltSample zeros(1,filtSampleDelay)]);
        LPfiltSample = LPfiltSample(filtSampleDelay+1:length(HPfiltSample)+filtSampleDelay);
        %         plot(LPfiltSample)
        
        % compute median absolute deviation (MAD)
        sampleMAD = 4*mad(HPfiltSample,1); %sampleSTD = std(adjustSample)
        % find high amplitude signal
        %         plot(abs(HPfiltSample-LPfiltSample));
        highAmpSampleIdx=abs(HPfiltSample-LPfiltSample)>sampleMAD;
        highAmpSampleIdx([false highAmpSampleIdx(1:end-1)])=true;
        highAmpSampleIdx([highAmpSampleIdx(2:end) false])=true;
        %         plot(60*highAmpSampleIdx)
        % find high diff
        samplediff=diff(HPfiltSample); %figure; plot(samplediff)
        diffMAD=mad(samplediff);
        %         plot(abs([samplediff(1) samplediff]-LPfiltSample))
        highDiffIdx=abs([samplediff(1) samplediff]-LPfiltSample)>2*diffMAD;
        %         plot(100*highDiffIdx)
        
        % merge the two indices and enlarge detected regions by one sample on each side
        highAmpandDiffSampleIdx=highAmpSampleIdx & highDiffIdx;
        highAmpandDiffSampleIdx([false highAmpandDiffSampleIdx(1:end-1)])=true;
        highAmpandDiffSampleIdx([highAmpandDiffSampleIdx(2:end) false])=true;
        %         plot(70*highAmpandDiffSampleIdx)
        
        % select highAmpandDiffSampleIdx-identified "spikes" based on minimal size
        highAmpSample=bwlabel(highAmpSampleIdx);%identify high amplitude regions
        selectHighAmpSample=unique(highAmpSample(highAmpandDiffSampleIdx));%select id number of those that are also high diff
        selectHighAmpSample=selectHighAmpSample(selectHighAmpSample>0);% remove zero id
        highAmpSampleSize=regionprops(highAmpSampleIdx,'area');% find high amplitude segmengts' size
        highAmpSampleSize=highAmpSampleSize(selectHighAmpSample);% restrict to high diff ones
        selectHighAmpSample=selectHighAmpSample([highAmpSampleSize.Area]>mean([highAmpSampleSize.Area]));% select those that are 5 samples or more
        
        %use amplitude as template
        highAmpSampleIdx(~(highAmpandDiffSampleIdx & ismember(highAmpSample,selectHighAmpSample)))=0;
        %         plot(200*highAmpSampleIdx)
        % increase chunk size
        highAmpSampleIdx([false highAmpSampleIdx(1:end-1)])=true;
        highAmpSampleIdx([highAmpSampleIdx(2:end) false])=true;
        
        %and add threshold
        %         mean(HPfiltSample(HPfiltSample>1.5*std(HPfiltSample)))
        
        % lowpass data
        [b,a] = butter(3,6000/(samplingRate/2),'low');
        filtSampleDelay = round(mean(grpdelay(b,a)));
        
        exporttype='hp'; % raw
        if strcmp(exporttype,'raw')
            LPfiltSample = int16(filtfilt(b,a,[data(chNm,:) zeros(1,filtSampleDelay)]));
            LPfiltSample = LPfiltSample(filtSampleDelay+1:length(data(chNm,:))+filtSampleDelay);
            LPfiltSample(highAmpSampleIdx)=LPfiltSample(highAmpSampleIdx)+data(chNm,highAmpSampleIdx);
        else
            LPfiltSample = filtfilt(b,a,[HPfiltSample zeros(1,filtSampleDelay)]);
            LPfiltSample = LPfiltSample(filtSampleDelay+1:length(HPfiltSample)+filtSampleDelay);
            LPfiltSample(highAmpSampleIdx)=LPfiltSample(highAmpSampleIdx)+HPfiltSample(highAmpSampleIdx);
        end
        
        % and finally, save
        data(chNm,:)=LPfiltSample;
        
        %                 figure; hold on;
        %                 plot(data(chNm,:))
        %                 plot(HPfiltSample)
        %                 plot(LPfiltSample)
        %         patch([1:length(zeros(1,samplingRate)),fliplr(1:length(zeros(1,samplingRate)))],...
        %         [zeros(1,samplingRate)-double(fooMAD),fliplr(zeros(1,samplingRate)+double(fooMAD))],'r','EdgeColor','none','FaceAlpha',0.1);
        
        %         plot(1:length(HPfiltSample),ones(1,length(HPfiltSample))*2*std(HPfiltSample))
        %         plot(1:length(HPfiltSample),-ones(1,length(HPfiltSample))*2*std(HPfiltSample))
        
        
        
        %         BPfiltSample=BPfiltSample(filtSampleDelay+1:length(adjustSample)+filtSampleDelay);
        %         data(chNm,:)=int16(BPfiltSample)+adjAmpTmplt;
        
        clearvars -except data extra filterOption{1} fname dname chNm rawInfo rec expname
        
        % optional: find their coordinates
        %         coordPutSpikes=regionprops(highAmpandDiffSampleIdx & ismember(highAmpSample,selectHighAmpSample),'Centroid');
        %         coordPutSpikes=[coordPutSpikes.Centroid];coordPutSpikes=coordPutSpikes(1:2:end);
        %         plot(coordPutSpikes,160*ones(1,length(coordPutSpikes)),'*');
        
        %delineate window around each "spike"
        % ideal would be 1ms, but too slow and unrealistic.
        %         So, just the time of rise and fall, as above
        %         spikeTemplate=false(size(data(chNm,:)));
        %         for spknm=1:size(coordPutSpikes,2)
        %             tic
        %             spkArea=sum(highAmpSample==highAmpSample(round(coordPutSpikes(spknm))));
        %             if round(coordPutSpikes(spknm))-spkArea<1
        %                 [spikeTemplate(1:round(coordPutSpikes(spknm))+samplingRate/1000/2)]=deal(true);
        %             elseif round(coordPutSpikes(spknm))+spkArea>size(spikeTemplate,2)
        %                 [spikeTemplate(round(coordPutSpikes(spknm))-spkArea:...
        %                     size(spikeTemplate,2))]=deal(true);
        %             else
        %                 [spikeTemplate(round(coordPutSpikes(spknm))-spkArea:...
        %                     round(coordPutSpikes(spknm))+spkArea)]=deal(true);
        %             end
        %             toc
        %         end
        
    end
    disp(['difffilt done in ' num2str(toc) 'seconds']);
elseif strcmp(filterOption{1},'multifilt')
    %% multi-stage filter / amplification
    tic;
    disp('multifilt started');
    for chNm=1:size(data,1)
        disp(['Channel ' num2str(chNm) ' of ' num2str(size(data,1))]);
        [b,a] = butter(3,500/(samplingRate/2),'low'); %'bandpass' is the default when Wn has two elements.
        filtSampleDelay = round(max(grpdelay(b,a)));
        LPfiltSample = filtfilt(b,a,[data(chNm,:) zeros(1,filtSampleDelay)]);
        LPfiltSample = LPfiltSample(filtSampleDelay+1:length(data(chNm,:))+filtSampleDelay);
        
        adjustSample=data(chNm,:)-int16(LPfiltSample);
        [b,a] = butter(3,1000/(samplingRate/2),'low'); %'bandpass' is the default when Wn has two elements.
        filtSampleDelay= round(max(grpdelay(b,a)));
        LPfiltSample = filtfilt(b,a,[adjustSample zeros(1,filtSampleDelay)]);
        LPfiltSample = LPfiltSample(filtSampleDelay+1:length(adjustSample)+filtSampleDelay);
        
        % compute median absolute deviation (MAD), qui vaut 1.5 STD. Donc un seuil a 7 en MAD, ca veut dire 4*STD (car 4*1.5=7).
        sampleMAD = mad(adjustSample,1); %sampleSTD = std(adjustSample)
        % find low amplitude signal
        lowampSampleIdx=abs(adjustSample-(int16(LPfiltSample)))<sampleMAD;
        %mid-amp
        midampSampleIdx=abs(adjustSample-(int16(LPfiltSample)))>=sampleMAD & abs(adjustSample-(int16(LPfiltSample)))<2*sampleMAD;
        %keep high amplitude template
        adjAmpTmplt=adjustSample;adjAmpTmplt(midampSampleIdx)=adjAmpTmplt(midampSampleIdx)/2;adjAmpTmplt(lowampSampleIdx)=0;
        %filter adjustSample
        [b,a] = butter(3,6000/(samplingRate/2),'low');
        filtSampleDelay = round(max(grpdelay(b,a)));
        BPfiltSample= filtfilt(b,a,[adjustSample zeros(1,filtSampleDelay)]);
        %     actualDelay=find(BPfiltSample(find(adjustSample==max(adjustSample)):end)==max(BPfiltSample(find(adjustSample==max(adjustSample)):end)));
        BPfiltSample=BPfiltSample(filtSampleDelay+1:length(adjustSample)+filtSampleDelay);
        data(chNm,:)=int16(BPfiltSample)+adjAmpTmplt;
        %         foo=int16(BPfiltSample)+adjAmpTmplt;
        %         fooMAD = 9*mad(foo,1);
        %
        %             figure; hold on;
        %             plot(data(chNm,1:samplingRate));
        %             plot(LPfiltSample(1:samplingRate));
        %             plot(adjustSample(1:samplingRate));
        %             plot(foo(1:samplingRate));
        %             plot(600*lowampSampleIdx(1:samplingRate));
        %             plot(800*midampSampleIdx(1:samplingRate));
        %
        %         patch([1:length(zeros(1,samplingRate)),fliplr(1:length(zeros(1,samplingRate)))],...
        %         [zeros(1,samplingRate)-double(fooMAD),fliplr(zeros(1,samplingRate)+double(fooMAD))],'r','EdgeColor','none','FaceAlpha',0.1);
        
        
        %             patch([1:length(foo(1:samplingRate)),fliplr(1:length(foo(1:samplingRate)))],...
        %         [foo(1:samplingRate)-fooMAD,fliplr(foo(1:samplingRate)+fooMAD)],'r','EdgeColor','none','FaceAlpha',0.1);
        
        
        %     [b,a] = butter(3,[600 6000]/(samplingRate/2)); %'bandpass' is the default when Wn has two elements.
        %     filtSampleDelay = round(max(grpdelay(b,a)));
        %     filtfoo = filtfilt(b,a,[foo zeros(1,filtSampleDelay)]));
        %     filtfoo=filtfoo(filtSampleDelay+1:length(foo)+filtSampleDelay);
        %     plot(filtfoo(1:samplingRate));
        
    end
    disp(['multifilt done in ' num2str(toc) 'seconds']);
    %preview
    %     [b,a] = butter(3,500/(samplingRate/2),'high'); %'bandpass' is the default when Wn has two elements.
    %     delay{1} = round(max(grpdelay(b,a)));
    %     filtData{1} = filtfilt(b,a,[adjustSample zeros(1,delay{1})]));
    %     filtData{1}=filtData{1}( delay{1}+1:length(adjustSample)+delay{1});
    %     figure; plot(filtData{1}(1,4400:5450));
elseif  strcmp(filterOption{1},'CAR_subset')
    %% common average referencing  on subset
    % select channels to use for CAR
        channelSelection= listdlg('PromptString',...
        'select channels to use for CAR to plot:','ListString',chStr);
    data(channelSelection,:)=(data(channelSelection,:)-...
        repmat(median(data(channelSelection,:),1),[size(data(channelSelection,:),1),1]));%./mad(faa,1);
end

set(0,'defaultfigureposition', defaultFigPos);
end