function sortInfo=readJRClustSortInfo(fileName)
% parameters
delimiter = ',';
startRow = 2;
formatSpec = '%f%f%f%f%f%f%f%f%f%f%f%s%[^\n\r]';
%% Read values from .csv file.
fileID = fopen(fileName,'r');
dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'TextType',...
    'string', 'EmptyValue', NaN, 'HeaderLines' ,startRow-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
fclose(fileID);
%% convert data
sortInfo = table(dataArray{1:end-1}, 'VariableNames',...
    {'unit_id','SNR','center_site','nSpikes','xpos','ypos','uV_min','uV_pp',...
    'IsoDist','LRatio','IsiRat','note'});
