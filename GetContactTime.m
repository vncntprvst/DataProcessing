function touchData=GetContactTime(videoFile, behaviorFile)
% analyze video recordings and find time of whisker contact
% may add other behavioral values later on

if ~exist('videoFile','var')
    % fileName='PrV77_52_HSCam2016-03-17T19_08_11'; 
[videoFile,vDir] = uigetfile({'*.avi','AVI files';'*.*','All Files' },...
    'Video files','E:\Data\Video');
% videoFile=[vDir videoFile];
end

if ~exist('behaviorFile','var')
    % fileName='PrV77_52_HSCam2016-03-17T19_08_11'; 
[behaviorFile,bDir] = uigetfile({'*.csv','CSV files';'*.*','All Files' },...
    'Behavior files','E:\Data\Behav');
end

%% get trial times
% [Behavior,Performance]=processBehaviorData(behaviorFile,bDir,0);
Behavior=readTrialData(behaviorFile,bDir);

%% find frame time table
frameTimetable=readVFrameTime([videoFile(1:end-3) 'csv'],vDir);

%% export trials times to isolate video clips
trialTimes=nan(size(Behavior.trials.trialStartTime,1),2);
for trials=1:size(Behavior.trials.trialStartTime,1)
trialTimes(trials,1:2)=[find(Behavior.trials.trialStartTime(trials)<...
    frameTimetable.frameTimes_ms,1) find(Behavior.trials.trialEndTime(trials)<...
    frameTimetable.frameTimes_ms,1)];
% move start by a fixed time (300ms), toi adjust for IR detection time
trialTimes(trials,1)=trialTimes(trials,1)-300;
% crop trial duration to 10 seconds max
if trialTimes(trials,2)-trialTimes(trials,1)>10000
    trialTimes(trials,2)=trialTimes(trials,1)+10000;
end
end

cd('TrialTimes')
% csvwrite([videoFile(1:end-4) '_trialTimes.csv'],trialTimes)
dlmwrite([videoFile(1:end-4) '_trialTimes.csv'],uint32(trialTimes),...
    'delimiter',',','precision',8); %8 digit is good enough for >50 hours @ 500Hz

%% %%%%%% VideoReader stinks ! %%%%%%%%%%
% Create a multimedia reader object
videoInput = VideoReader([vDir videoFile]);
% video = read(videoInput,firstFrame:firstFrame+500);
% 
% % Initialize parameters
%  vidStruc = struct('cdata',zeros(videoInput.Height,videoInput.Width,3,'uint8'),'colormap',[]);
% 
% % set initial time
% videoInput.CurrentTime = (10*60)+37; %13:34
% 
% % Read one frame at a time using readFrame until the end of 2 sec epoch.
% % Append data from each video frame to the structure array.
% clipDuration=2;
% rfameIncr = 1;
% while rfameIncr<=(clipDuration*videoInput.FrameRate)
%     vidStruc(rfameIncr).cdata = readFrame(videoInput);
%     rfameIncr = rfameIncr+1;
% end

% lastFrame = read(videoInput, inf);
% Error in VideoReader/read (line 143)
% numFrames = get(obj, 'NumberOfFrames');
% set(videoInput, 'NumberOfFrames',size(frameTimetable.frameTimes_ms,1));

if videoInput.Duration<(frameTimetable.frameTimes_ms(end)-frameTimetable.frameTimes_ms(1))/1000
    disp('Incorrect video duration!')
    % Use VLC to fix this
%     Try to automatize: 
%     https://forum.videolan.org/viewtopic.php?t=78126
%     https://wiki.videolan.org/VLC_command-line_help
    % see Processing Data doc file for instructions
    dirlisting=dir(vDir);
    if sum(~cellfun('isempty',cellfun(@(fname) strfind(fname,[videoFile(1:end-4) '_Fixed.avi']),...
        {dirlisting.name},'UniformOutput',false)))
    % alrady fixed the file
        videoFile=dirlisting(~cellfun('isempty',cellfun(@(fname) strfind(fname,[videoFile(1:end-4) '_Fixed.avi']),...
        {dirlisting.name},'UniformOutput',false))).name;
    else
        return
    end
end

%% use Bonsai to extract frames
exportVDir=[vDir cell2mat(regexp(videoFile,'^\w+(?=__)','match')) '__HSCamClips'];
% try to automatize this step from command line
% See Processing Data doc file for instructions, but basically, use
% getHSVidTrials workflow.

% [optional] rotate video frames to head-centered reference frame

%% use Bonsai to find contact time
% Bonsai: WhiskerContactTime (first frames are skipped, so line 1 in CSV file is frame #3)

%% Open result .csv file and export contact time points for alignment
cd(exportVDir);
exportVDirListing=dir(exportVDir);
exportVDirListingNames={exportVDirListing.name};
exportVDirListingNames=exportVDirListingNames(~cellfun('isempty',strfind(exportVDirListingNames,'csv')));

delimiter = ' ';
% formatSpec = '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%[^\n\r]';%4 "big" ROIs and 5 * small stacks of 3 ROI windows
formatSpec = ['%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s' ...
            '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s' ...
            '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s' ...
            '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s' ...
            '%s%s%s%s%s%s%s%[^\n\r]'];                          %13 stacks of 7 ROI windows
startRow = 1;

Sweep=struct('Frame',[],'LongiPosition',[],'Duration',[],'MaxDepth',[],'Velocity',[]);
for csvFile=1:size(exportVDirListingNames,2) 
    %open file
    fileID = fopen(exportVDirListingNames{csvFile},'r');
    
    % Read ROIs data
    boolArray = textscan(fileID, formatSpec, 'Delimiter', delimiter,...
        'MultipleDelimsAsOne', true, 'EmptyValue' ,NaN, 'ReturnOnError', false);
    boolArray = strcmp([boolArray{1:end-1}],'True');
    
    %just for debugging purposes: frewind(fileID);
    
    % Close file.
    fclose(fileID);
    
    %% analyze it
        %rules:
%     * if upper activation, needs to have gone through lower or side first 
%     -> whisker touch is when it went from lower to upper in order (may skip one?)
%     * all full-column activation is disregarded, unless it's a fast, periodical
%       input (define fast and periodic frequency)

% make heatmap first
    %%
%     figure; colormap(copper); %imagesc(boolArray);
%     subplot(1,6,1)
%     imagesc(fliplr(boolArray(1:300,1:4)));
%     subplot(1,6,2)
%     imagesc(boolArray(1:300,17:19));
%     subplot(1,6,3)
%     imagesc(boolArray(1:300,14:16));
%     subplot(1,6,4)
%     imagesc(boolArray(1:300,11:13));
%     subplot(1,6,5)
%     imagesc(boolArray(1:300,8:10));
%     subplot(1,6,6)
%     imagesc(boolArray(1:300,5:7));
    %% 91 ROIs version
    ROIactivation=zeros(size(boolArray,1),13);
    for frameIdx=1:size(boolArray,1);
        frameActivationData(:,:,frameIdx)=reshape(boolArray(frameIdx,:),[7 13]);
        ROIactivation(frameIdx,:)=sum(frameActivationData(:,:,frameIdx));
    end
    lastActivFrame=find(diff(sum(ROIactivation')),1,'last');
    firstActivFrame=find(diff(sum(ROIactivation')),1,'first');
    
    figure; cmap=colormap('copper'); %colormap(flipud(cmap));
    surf(ROIactivation(max([1 firstActivFrame-100]):min([lastActivFrame+100 size(boolArray,1)]),:))
    
    xlabel(gca,'Position, Left to Right ')
    ylabel(gca,'Time (ms)')
    zlabel(gca,'Degree of activation')
    
    figure; colormap(copper);
    for ROIcol=1:13
        subplot(1,13,ROIcol);
        imagesc(fliplr(flipud(squeeze(frameActivationData(:,...
            ROIcol,max([1 firstActivFrame-100]):min([lastActivFrame+100 size(boolArray,1)])))')));
        set(gca,'xticklabel','')
        if ROIcol>1
            set(gca,'YTickLabel','')
        else
            set(gca,'YTickLabel',flipud(get(gca,'YTickLabel')))
            ylabel(gca,'Time (ms)')
        end
    end
    titleh=title([exportVDirListingNames{csvFile}(1:9) '_' num2str(csvFile)]);
    set(titleh,'interpreter','none');
% boolArray(:,15) && ([true; boolArray(1:end-1,14)] || [true; boolArray(1:end-1,11)]) &&...
%  ([true; true; boolArray(1:end-2,13)] || [true; true; boolArray(1:end-2,10)]);

activ3D=flip(frameActivationData(:,:,firstActivFrame:lastActivFrame)); %flipping depth back to bottom up
%find connected regions
connComp = bwconncomp(activ3D);
% keep only blobs with more than 10 pixels
connComp.PixelIdxList=connComp.PixelIdxList(cellfun(@(comp) numel(comp)>10, connComp.PixelIdxList));
connComp.NumObjects=size(connComp.PixelIdxList,2);
% get indices
[Depth,Position,Frame] = cellfun(@(comp) ind2sub(connComp.ImageSize,comp),connComp.PixelIdxList,'UniformOutput',false);
% for a given object, keep "highest" depth for a given frame

% ROIs are 10px deep, frame freq is 1kHz, so velocity is in px/ms;
ROIdepth=10;
for compNum=1:connComp.NumObjects
    keepFrame=nan(size(Depth{compNum},1),1);
    for frameNum=1:size(Depth{compNum},1)
        framesDepth=Depth{compNum}(Frame{compNum}==Frame{compNum}(frameNum));
        keepFrame(frameNum)=find(Frame{compNum}==Frame{compNum}(frameNum),1,'first')+...
            find(framesDepth==max(framesDepth),1,'first')-1;
    end
    Depth{compNum}=Depth{compNum}(unique(keepFrame));
    Position{compNum}=Position{compNum}(unique(keepFrame));
    Frame{compNum}=Frame{compNum}(unique(keepFrame));
    %   figure; hold on; plot(Depth{compNum});
    % get monotonic epochs (= bottom up sweeps), depth, duration
    sweepEpochs=bwlabel([true;diff(Depth{compNum})>=0]);
    for sweepNum=1:max(unique(sweepEpochs(sweepEpochs>0)))
        if sum(sweepEpochs==sweepNum)==1
            continue;
        end
        Sweep(csvFile).Frame(compNum,sweepNum)=Frame{compNum}(find(sweepEpochs==sweepNum,1,'first'));
        Sweep(csvFile).LongiPosition(compNum,sweepNum)=Position{compNum}(find(sweepEpochs==sweepNum,1,'first'));
        Sweep(csvFile).Duration(compNum,sweepNum)=sum(sweepEpochs==sweepNum);
        Sweep(csvFile).MaxDepth(compNum,sweepNum)=max(Depth{compNum}(sweepEpochs==sweepNum))*ROIdepth;
        Sweep(csvFile).Velocity(compNum,sweepNum)=(max(Depth{compNum}(sweepEpochs==sweepNum))-...
                                    min(Depth{compNum}(sweepEpochs==sweepNum))+1)*ROIdepth/...
                                    sum(sweepEpochs==sweepNum);
    end
end
Sweep(csvFile).Frame(Sweep.Frame==0)=NaN;
Sweep(csvFile).LongiPosition(Sweep.LongiPosition==0)=NaN;
Sweep(csvFile).Duration(Sweep.Duration==0)=NaN;
Sweep(csvFile).MaxDepth(Sweep.MaxDepth==0)=NaN;
Sweep(csvFile).Velocity(Sweep.Velocity==0)=NaN; 

end
figure;
durHist=histogram(Sweep.Duration')
    durHist.EdgeColor = 'k';
    xlabel('Whisker sweep duration (ms)')
    axis('tight');box off;
%     set(gca,'xlim',[0 200],'XTick',linspace(0,200,5),'XTickLabel',linspace(0,200,5),...
%         'TickDir','out','Color','white','FontSize',10,'FontName','Calibri');
%     hold off

figure;
velHist=histogram(Sweep.Velocity')
    velHist.EdgeColor = 'k';
    xlabel('Whisker sweep duration (px/ms)')
    axis('tight');box off;


