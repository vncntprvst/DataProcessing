function videoFrameTimes=readVideoTTLData

%% Read TTL frame values from .csv file.

[filename,dname] = uigetfile({'*.csv','.csv Files';...
    '*.*','All Files' },'TTL Onset Data',cd);
cd(dname)
fileID = fopen(filename,'r');

delimiter = ',';
startRow = 0;
formatSpec = '%f';

videoFrameTimes.TTLFrames= cell2mat(textscan(fileID, formatSpec, 'Delimiter', delimiter,...
    'HeaderLines' ,startRow, 'ReturnOnError', false, 'CollectOutput', true));

% frewind(fileID);
fclose(fileID);

%% Now read times from HSCam csv file

[filename,dname] = uigetfile({'*.csv','.csv Files';...
    '*.*','All Files' },'HSCam frame times',cd);
cd(dname)
fileID = fopen(filename,'r');

% get file open time from first line
fileStartTime=regexp(fgets(fileID),'\d+','match');
videoFrameTimes.fileRecordingDate=datetime([fileStartTime{1} '-' fileStartTime{2} '-' fileStartTime{3}]);
videoFrameTimes.fileStartTime_ms=1000*(str2double(fileStartTime{1, 4})*3600+...
    str2double(fileStartTime{1, 5})*60+str2double([fileStartTime{6} '.' fileStartTime{7}]));

frewind(fileID);

% Read data 
formatSpec = '%*4u16%*1s%*2u8%*1s%*2u8%*1s%2u8%*1s%2u8%*1s%7.5f%*s';
startRow=1;
framesTimesArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false);

% Close file.
fclose(fileID);

%% transform to milliseconds
% if late recording, need to add 24h to relevant values
if sum(diff(int16(framesTimesArray{1, 1})))~=0
    dateChange=find(diff(int16(framesTimesArray{1, 1})))+1;
else 
    dateChange=[];
end

videoFrameTimes.frameTime_ms=1000*(double(framesTimesArray{1, 1})*3600+double(framesTimesArray{1, 2})*60+framesTimesArray{1, 3});

if ~isempty(dateChange)
    videoFrameTimes.frameTime_ms(dateChange:end)=videoFrameTimes.frameTime_ms(dateChange:end)+(24*3600*1000);
end

videoFrameTimes.frameTime_ms=videoFrameTimes.frameTime_ms-videoFrameTimes.frameTime_ms(1);

videoFrameTimes.TTLTimes=videoFrameTimes.frameTime_ms(videoFrameTimes.TTLFrames);

end