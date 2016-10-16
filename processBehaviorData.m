function [Behavior,Performance]=processBehaviorData(fileName,dirName,drawPlots)
% fileName='E:\Data\Behav\PrV77_32_2016-01-30T02_06_59.csv';
behavDir='E:\Data\Behav';
if nargin<3
    drawPlots=0;
end
Behavior=struct('fileRecordingDate',[],'fileStartTime_ms',[],...
'trialNumberIdx',[],'trialEventType',[],'successCount',[],...
    'eventTime_ms',[],'trials',[]);
Performance=struct('CorrectSides',[],'gTrialsCumDist',[],...
    'overallPerf',[],'instantPerf',[]);

switch nargin
    case 0
        [fileName,dirName] = uigetfile({'*.csv','.csv Files';...
            '*.*','All Files' },'Behavior Data',behavDir,'MultiSelect','on');
        cd(dirName)
    case 1
        cd(behavDir)
    case 2
        cd(dirName)
end

if ~iscell(fileName)
    fileName={fileName};
end
if size(fileName,2)>1
    drawPlots=0;
end

for fileNum=1:size(fileName,2)
    
    fileNameSuffix=regexp(fileName{fileNum},'\w+(?=_.+$)','match');
    fileNameSuffix=fileNameSuffix{1};
    try
        Behavior(fileNum)=readTrialData(fileName{fileNum},'E:\Data\Behav');
    catch
        continue
    end
    if Behavior(fileNum).fileRecordingDate<datetime(2016,3,16)
        continue
    end
    % Intervals
    % trialDuration=Behavior(fileNum).trials.trialEndTime-Behavior(fileNum).trials.trialStartTime;
    % ITI=Behavior(fileNum).trials.trialStartTime(2:end)-Behavior(fileNum).trials.trialEndTime(1:end-1);
    
    % Side bias
    Performance(fileNum).CorrectSides=hist(double(Behavior(fileNum).trials.trialOutcomeType(...
        Behavior(fileNum).trials.correctTrialIdx(:,1),1)),2);
    
    % Errors
    Performance(fileNum).IncorrectSides=hist(double(Behavior(fileNum).trials.trialOutcomeType(...
        Behavior(fileNum).trials.errorTrialIdx(:,1),1)),2);
    
    % Cumulative distribution of correct trials
    Performance(fileNum).gTrialsCumDist=cumsum(Behavior(fileNum).trials.correctTrialIdx(:,1))./...
        max(cumsum(Behavior(fileNum).trials.correctTrialIdx(:,1)))*100;
    
    %Performance
    Performance(fileNum).overallPerf=sum(Behavior(fileNum).trials.correctTrialIdx(:,1))/...
        size(Behavior(fileNum).trials.correctTrialIdx(:,1),1);
    Performance(fileNum).instantPerf=cumsum(Behavior(fileNum).trials.correctTrialIdx(:,1))./...
        (1:size(Behavior(fileNum).trials.correctTrialIdx(:,1),1))';
    
    %Hit rate (probability to go to the correct reward port when texture is
    %present
    Performance(fileNum).hitRate=sum(Behavior(fileNum).trials.trialType==1 & Behavior(fileNum).trials.correctTrialIdx(:,1))/...
        sum(Behavior(fileNum).trials.trialType==1);
    Performance(fileNum).falseAlarm=sum(Behavior(fileNum).trials.trialType==2 & Behavior(fileNum).trials.errorTrialIdx(:,1))/...
        sum(Behavior(fileNum).trials.trialType==2);
    
    %Plots
    if drawPlots==1
        figure('Name',fileNameSuffix,'NumberTitle','off','position',[1000 215 800 750])
        colormap lines;
        cmap = colormap(gcf);
        
        subplot(2,3,1)
        bar(Performance(fileNum).CorrectSides);
        set(gca,'xticklabel',{'Left','Right'})
        set(gca,'Color','white','TickDir','out')
        title('Correct answers') 
        
        subplot(2,3,2)
        bar(Performance(fileNum).IncorrectSides);
        set(gca,'xticklabel',{'Left','Right'})
        set(gca,'Color','white','TickDir','out')
        title('Incorrect answers')
        
        subplot(2,3,3)
        plot(round(Behavior(fileNum).trials.trialEndTime/60000),...
            Performance(fileNum).gTrialsCumDist,'LineWidth',1.5,'Color',cmap(2,:))
        axis(gca,'tight'); box off;
        set(gca,'Color','white','TickDir','out')
        xlabel('Time (mn)')
        ylabel('% of total correct trials')
        title('Cumulative sum of correct trials')
        
        subplot(2,3,4:6)
        plot(round(Behavior(fileNum).trials.trialEndTime/60000),...
            Performance(fileNum).instantPerf,'LineWidth',1.5,'Color',cmap(4,:))
        axis(gca,'tight'); box off;
        set(gca,'Color','white','TickDir','out','ylim',[0 1])
        xlabel('Time (mn)')
        ylabel('Instantaneous performance level')
        title('Success rate')
        
        % plot d' over sliding window of 20 trials 
        
        % figure
        % subplot(2,1,1)
        % plot(trialDuration)
        % title('trial duration')
        % subplot(2,1,2)
        % plot(ITI)
        % title('inter-trial interval')
        
        %print figure
        print(gcf, '-dpdf', '-noui', '-painters', fileName{:}(1:end-4));
        
    end
    
end


end

