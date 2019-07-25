cd('V:\Code\Tools\mp4fpsmod\vcproj\Debug')
mp4fpsmod -p timecode.txt Z:\all_staff\Wenxi\PrV_Recordings\WX008_23apr19\04_23_2_666607\WX008_A_output.mp4


filename = 'Z:\all_staff\Wenxi\PrV_Recordings\WX008_23apr19\04_23_2_666607\timecode.txt';
delimiter = ' ';
startRow = 2;
formatSpec = '%f%*s%*s%*s%[^\n\r]';
fileID = fopen(filename,'r');
timecode = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'MultipleDelimsAsOne', true, 'TextType', 'string', 'EmptyValue', NaN, 'HeaderLines' ,startRow-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
fclose(fileID);
timecode = timecode{1:end-1};
clearvars filename delimiter startRow formatSpec fileID;

unique(diff(timecode))

% TTLfileID=fopen('ttl.bin','r');
% TTLs=fread(TTLfileID,Inf,'int64');
% fclose(TTLfileID);

