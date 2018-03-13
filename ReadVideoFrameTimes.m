function videoFrameTimes=ReadVideoFrameTimes(dirName)
currentDir=cd; 
if nargin == 0
    dirName=cd;
end
dirListing=dir(dirName); 
%% Read times from HSCam csv file
try
    fileName=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'_FrameTimes.csv'),...
        {dirListing.name},'UniformOutput',false))).name;
catch
    [fileName,dirName] = uigetfile({'*.csv','.csv Files';...
        '*.*','All Files' },'HSCam frame times',dirName);
%     cd(dirName)
end
fileID = fopen(fullfile(dirName,fileName),'r');

% get file open time from first line
fileStartTime=regexp(fgets(fileID),'\d+','match');
videoFrameTimes.fileRecordingDate=datetime([fileStartTime{1} '-' fileStartTime{2} '-' fileStartTime{3}]);
videoFrameTimes.fileStartTime_ms=1000*(str2double(fileStartTime{1, 4})*3600+...
    str2double(fileStartTime{1, 5})*60+str2double([fileStartTime{6} '.' fileStartTime{7}]));

frewind(fileID);

% Read data
delimiter = ','; startRow=1; formatSpec = '%*4u16%*1s%*2u8%*1s%*2u8%*1s%2u8%*1s%2u8%*1s%7.5f%*s';
framesTimesArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false);

% Close file.
fclose(fileID);

%% transform to milliseconds
% if late recording, need to add 24h to relevant values
if framesTimesArray{1, 1}(1)==23 && sum(diff(int16(framesTimesArray{1, 1})))~=0
    dateChange=find(diff(int16(framesTimesArray{1, 1})))+1;
else
    dateChange=[];
end

videoFrameTimes.frameTime_ms=1000*(double(framesTimesArray{1, 1})*3600+double(framesTimesArray{1, 2})*60+framesTimesArray{1, 3});

if ~isempty(dateChange)
    videoFrameTimes.frameTime_ms(dateChange:end)=videoFrameTimes.frameTime_ms(dateChange:end)+(24*3600*1000);
end

videoFrameTimes.frameTime_ms=videoFrameTimes.frameTime_ms-videoFrameTimes.frameTime_ms(1);


%% Read TTL frame values from .csv file. (if any TTL signals)
try
    fileName=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'_TTLOnset.csv'),...
        {dirListing.name},'UniformOutput',false))).name;
    
    % [fileName,dname] = uigetfile({'*.csv','.csv Files';...
    %     '*.*','All Files' },'TTL Onset Data',cd);
    % cd(dname)
    fileID = fopen(fullfile(dirName,fileName),'r');
    
    delimiter = ','; startRow = 0; formatSpec = '%f';
    
    videoFrameTimes.TTLFrames= cell2mat(textscan(fileID, formatSpec, 'Delimiter', delimiter,...
        'HeaderLines' ,startRow, 'ReturnOnError', false, 'CollectOutput', true))-1; %TTL starts the frame before the detection (because of differential used)
    
    % frewind(fileID);
    fclose(fileID);
    
    videoFrameTimes.TTLTimes=videoFrameTimes.frameTime_ms(videoFrameTimes.TTLFrames);
catch %if file is absent from folder, assume that there were not TTL sync signals
    [videoFrameTimes.TTLFrames, videoFrameTimes.TTLTimes]=deal([]);
end
cd(currentDir);
end