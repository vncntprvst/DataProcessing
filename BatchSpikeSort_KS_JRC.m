% start from the folder where the files to process are
dataDir = cd;
[filepath,folderName] = fileparts(dataDir);

% list directories above, assuming the parent folder is the container for
% all files from that subject
parentDir=regexp(dataDir,['(?<=\' filesep ').+?(?=\' filesep ')'],'match');
parentDir = parentDir{end};

%% Export notes
exportNotes = 1;
if exportNotes
    ExportXPNotes(['Experiment Note Sheet - ' parentDir '.xlsx'] , filepath)
end

%% Export .dat files with BatchExport
exportData = 1;
if exportData
    % start from data session's root directory
    [dataFiles,allRecInfo]=BatchExport;
    save('fileInfo','dataFiles','allRecInfo');
end

spikeSort = 1;
if spikeSort
    %% generate config and channel map files. Create batch file
    cd(fullfile(dataDir,'SpikeSorting'))
    GenerateConfigChannelMap_KS_JRC
    
    %% Run KiloSort on batch file
    % open batch file
    batchFileID = fopen([folderName '.batch'],'r');
    delimiter = {''};formatSpec = '%s%[^\n\r]';
    prmFiles = textscan(batchFileID, formatSpec, 'Delimiter', delimiter,...
        'TextType', 'string',  'ReturnOnError', false);
    fclose(batchFileID);
    prmFiles = [prmFiles{1}];
    % Run KS2
    for fileNum=1:size(prmFiles,1)
        try
            RunKS(prmFiles{fileNum});
        catch
            close all; continue
        end
        close all
    end
    
    %% import results into JRC
    if ~exist('dataFiles','var'); load('fileInfo.mat'); end
    for fileNum=1:size(dataFiles,1)
        try
            recInfo = allRecInfo{fileNum};
            cd([recInfo.recordingName])
            jrc('bootstrap',[recInfo.recordingName '_export.meta'],'-noconfirm','-advanced')
            jrc('import-ksort',cd,false);
            cd ..
        catch
            continue
        end
    end
end
