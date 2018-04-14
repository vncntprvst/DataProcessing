function TTLtimes=ReadVideoTTLData

%% Read TTL frame values from .csv file.
try
    fileName=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'_TTLOnset.csv'),...
        {dirListing.name},'UniformOutput',false))).name;
catch
    [fileName,dname] = uigetfile({'*.csv','.csv Files';...
        '*.*','All Files' },'TTL Onset Data',cd);
    cd(dname)
end
fileID = fopen(fileName,'r');

delimiter = ',';
startRow = 0;
formatSpec = '%f';

TTLtimes= cell2mat(textscan(fileID, formatSpec, 'Delimiter', delimiter,...
    'HeaderLines' ,startRow, 'ReturnOnError', false, 'CollectOutput', true));

% frewind(fileID);
fclose(fileID);
