function touchData=GetContactTime(videoFile, behaviorFile)
% analyze video recordings and find time of whisker contact
% may add other behavioral values later on

if ~exist('videoFile','var')
    % fileName='PrV77_52_HSCam2016-03-17T19_08_11'; 
[videoFile,vDir] = uigetfile({'*.avi','AVI files';'*.*','All Files' },...
    'Video files','C:\Data\Video');
% videoFile=[vDir videoFile];
end

if ~exist('behaviorFile','var')
    % fileName='PrV77_52_HSCam2016-03-17T19_08_11'; 
[behaviorFile,bDir] = uigetfile({'*.csv','CSV files';'*.*','All Files' },...
    'Behavior files','C:\Data\Behav');
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
formatSpec = '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%[^\n\r]';%4 "big" ROIs and 5 * small stacks of 3 ROI windows
startRow = 1;
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
    % make heatmap first
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
    %rules:
%     * if upper activation, needs to have gone through lower or side first 
%     -> whisker touch is when it went from lower to upper in order (may skip one?)
%     * all full-column activation is disregarded, unless it's a fast, periodical
%       input (define fast and periodic frequency)

%from left to right
boolArray(:,15) && ([true; boolArray(1:end-1,14)] || [true; boolArray(1:end-1,11)]) &&...
 ([true; true; boolArray(1:end-2,13)] || [true; true; boolArray(1:end-2,10)]);



end


