function TTLtimes=ReadVideoTTLData

%% Read TTL frame values from .csv file.

[filename,dname] = uigetfile({'*.csv','.csv Files';...
    '*.*','All Files' },'TTL Onset Data',cd);
cd(dname)
fileID = fopen(filename,'r');

delimiter = ',';
startRow = 0;
formatSpec = '%f';

TTLtimes= cell2mat(textscan(fileID, formatSpec, 'Delimiter', delimiter,...
    'HeaderLines' ,startRow, 'ReturnOnError', false, 'CollectOutput', true));

% frewind(fileID);
fclose(fileID);
