
subjectDir=cd; 

% List session directories
expDirs= dir([subjectDir filesep '*' filesep 'SpikeSorting']);
expDirs = expDirs([expDirs.isdir]);
expDirs = expDirs(~cellfun(@(folderName) any(strcmp(folderName,...
    {'.','..'})),{expDirs.name}));

for sessionNum=1:numel(expDirs)
    try
    cd(fullfile(expDirs(sessionNum).folder,expDirs(sessionNum).name));
    SaveProcessedData
    catch
        disp(['error saving data from '...
            fullfile(expDirs(sessionNum).folder,expDirs(sessionNum).name)])
        continue
    end
end

cd(subjectDir)
