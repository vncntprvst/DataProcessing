function whiskerStim_FrameIdx=GetFrame_WhiskerTouch(csvFile,dName,formatSpec)
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
fileID = fopen(fullfile(dName,csvFile),'r');
if fileID==-1
    % wrong filename, probably created slightly earlier than video file
    dirListing=dir(dName);
    dirListingNames={dirListing.name};
    dirListingNames = dirListingNames(~cellfun('isempty',strfind(dirListingNames,'csv')));
    nameMatch=cellfun(@(fnames) strcmp(fnames(1:end-8),csvFile(1:end-8)), dirListingNames,'UniformOutput', true);   
    csvFile=dirListingNames(nameMatch);
    fileID = fopen([dName csvFile{:}],'r');
end

%% Read data 
if ~exist('formatSpec','var')
    formatSpec = '%s';
%     formatSpec = '%*4u16%*1s%*2u8%*1s%2u8%*1s%2u8%*1s%2u8%*1s%7.5f%*s';
% formatSpec = '%{yyyy-mm-dd}D%*1s%2u8%*1s%2u8%*1s%6.4f%s%[^\n\r]'; 
end
dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false);

%% Close file.
fclose(fileID);

string2boolean = @(s) ~strcmpi(s, 'false');
whiskerStim_FrameIdx=cellfun(@(frameROIs) cellfun(@(eachRoi) string2boolean(eachRoi),...
    regexp(frameROIs,'\w+','match')),dataArray{:},'UniformOutput',false);
whiskerStim_FrameIdx=vertcat(whiskerStim_FrameIdx{:});