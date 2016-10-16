function frameTimetable=readVFrameTime(csvFile,dName)
%% Import frame data from video's csv file.

%% Initialize variables.
switch nargin
    case 0
        [csvFile,dName] = uigetfile({'*.csv','.csv Files';...
            '*.*','All Files' },'Behavior Data','E:\Data\Video');
        cd(dName)
    case 1
        cd('E:\Data\Video')
%         dname=[];
    case 2
        cd(dName)
end
delimiter = ',';
startRow = 1;

%% Open .csv file.
fileID = fopen([dName csvFile],'r');
if fileID==-1
    % wrong filename, probably created slightly earlier than video file
    dirListing=dir(dName);
    dirListingNames={dirListing.name};
    dirListingNames = dirListingNames(~cellfun('isempty',strfind(dirListingNames,'csv')));
    nameMatch=cellfun(@(fnames) strcmp(fnames(1:end-8),csvFile(1:end-8)), dirListingNames,'UniformOutput', true);   
    csvFile=dirListingNames(nameMatch);
    fileID = fopen([dName csvFile{:}],'r');
end

%% get file open time from first line
fileCreateTime=regexp(fgets(fileID),'\d+','match');
frameTimetable.fileRecordingDate=datetime([fileCreateTime{1} '-' fileCreateTime{2} '-' fileCreateTime{3}]);
frameTimetable.fileCreateTime=hours(str2double(fileCreateTime{4})) + ...
    minutes(str2double(fileCreateTime{5})) + ...
    seconds(str2double([fileCreateTime{6} '.' fileCreateTime{7}]));
frameTimetable.fileCreateTimeSubMilli=str2double(fileCreateTime{7});
frewind(fileID);

%% Read data 
formatSpec = '%*4u16%*1s%*2u8%*1s%2u8%*1s%2u8%*1s%2u8%*1s%7.5f%*s';
% formatSpec = '%{yyyy-mm-dd}D%*1s%2u8%*1s%2u8%*1s%6.4f%s%[^\n\r]'; 
dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false);

%% Close file.
fclose(fileID);

%% get frame times
% if late recording, need to add 24h to relevant values
if sum(diff(dataArray{1, 1}))>0
    dateChange=find(diff(dataArray{1, 1}))+1;
else 
    dateChange=[];
end

frameTimetable.frameTimes_ms=1000*(double(dataArray{1, 2})*3600+double(dataArray{1, 3})*60+dataArray{1, 4});
if ~isempty(dateChange)
    frameTimetable.frameTimes_ms(dateChange:end)=frameTimetable.frameTimes_ms(dateChange:end)+(24*3600);
end