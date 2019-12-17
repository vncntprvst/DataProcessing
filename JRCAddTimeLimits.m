%% Load data
% List sync data files
videoSyncFiles = cellfun(@(fileFormat) dir([workDir filesep '*' filesep '*' filesep fileFormat]),...
    {'*vSync*'},'UniformOutput', false);
videoSyncFiles=vertcat(videoSyncFiles{~cellfun('isempty',videoSyncFiles)});

%% Convert data
for fileNum=1:numel(videoSyncFiles)
    %% get time info from sync TTL
    syncFile = fopen(fullfile(videoSyncFiles(fileNum).folder,videoSyncFiles(fileNum).name));
    TTLSignals = fread(syncFile,'int32');
    fclose(syncFile);           
    loadTimeLimits = [TTLSignals(1) TTLSignals(end)]/1000;

    % find corresponding param files
    dirListing=dir(videoSyncFiles(fileNum).folder);
    paramFiles={dirListing(~cellfun(@isempty,cellfun(@(fileName) strfind(fileName,'.prm'), ...
        {dirListing.name},'UniformOutput', false))).name};

    inputParams={'loadTimeLimits',['[' num2str(TTLSignals(1)/1000) ',' num2str(TTLSignals(end)/1000) ']']};
    for paramFileNum=1:numel(paramFiles)
        paramFileName=fullfile(videoSyncFiles(fileNum).folder,paramFiles{paramFileNum});
        try
            [paramFStatus,cmdout]=ModifyJRCParamFile(paramFileName(1:end-4),false,inputParams);
        catch
        end
    end
end



