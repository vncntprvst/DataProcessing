function rez=RunKS(configFileName)
% see original file master_kilosort.m 

%% [optional] add paths
% addpath(genpath('V:\Code\SpikeSorting\Kilosort2')) % path to kilosort folder
% addpath('V:\Code\Tools\npy-matlab') % for converting to Phy

%% parameters 
% run generated config file to create ops (see GenerateKSConfigFile) 
run(configFileName);
dataDir = ops.exportDir; % the raw data binary file is in this folder
tempDir = ops.tempDir; % path to temporary binary file (same size as data, should be on fast SSD)
if ~isfield(ops,'fproc')
    ops.fproc   = fullfile(tempDir, 'temp_wh.dat'); % proc file on a fast SSD
end
chanMapFile = ops.chanMap;
ops.chanMap = chanMapFile;

% main parameter changes from Kilosort2 to v2.5
ops.sig        = 20;  % spatial smoothness constant for registration
ops.fshigh     = 300; % high-pass more aggresively
ops.nblocks    = 5; % blocks for registration. 0 turns it off, 1 does rigid registration. Replaces "datashift" option. 

% is there a channel map file in this folder?
fs = dir(fullfile(dataDir, '*chan*.mat'));
if ~isempty(fs)
    ops.chanMap = fullfile(dataDir, fs(1).name);
end

if ~isfield(ops,'NchanTOT')
% load number of channels from channel map
    ops.NchanTOT = numel(load(ops.chanMap,'chanMap')); % total number of channels in your recording
end

if ~isfield(ops,'trange')
    ops.trange = [0 Inf]; % time range to sort
end

% find the binary file
if ~isfield(ops,'fbinary')
    fprintf('Looking for data inside %s \n', dataDir)
    fs          = [dir(fullfile(dataDir, '*.bin')) dir(fullfile(dataDir, '*.dat'))];
    ops.fbinary = fullfile(dataDir, fs(1).name);    
end

%% run KiloSort (2.5)
% preprocess data to create temp_wh.dat
rez = preprocessDataSub(ops); % preprocess data and extract spikes for initialization
% [rez, DATA, uproj] = preprocessDataSub(ops); 

%% Legacy KS 2.0 
% % time-reordering as a function of drift
% rez = clusterSingleBatches(rez);
% 
% % saving here is a good idea, because the rest can be resumed after loading rez
% save(fullfile(dataDir, 'rez.mat'), 'rez', '-v7.3');
% 
% % main tracking and template matching algorithm
% rez = learnAndSolve8b(rez);
% 
% % final merges
% rez = find_merges(rez, 1);
% 
% % final splits by SVD
% rez = splitAllClusters(rez, 1);
% 
% % final splits by amplitudes
% rez = splitAllClusters(rez, 0);
% 
% % decide on cutoff
% rez = set_cutoff(rez);

%% KS 2.5
% NEW STEP TO DO DATA REGISTRATION
rez = datashift2(rez, 1); % last input is for shifting data

% ORDER OF BATCHES IS NOW RANDOM, controlled by random number generator
iseed = 1;
                 
% main tracking and template matching algorithm
rez = learnAndSolve8b(rez, iseed);

% OPTIONAL: remove double-counted spikes - solves issue in which individual spikes are assigned to multiple templates.
% See issue 29: https://github.com/MouseLand/Kilosort/issues/29
%rez = remove_ks2_duplicate_spikes(rez);

% final merges
rez = find_merges(rez, 1);

% final splits by SVD
rez = splitAllClusters(rez, 1);

% decide on cutoff
rez = set_cutoff(rez);
% eliminate widely spread waveforms (likely noise)
rez.good = get_good_units(rez);

fprintf('found %d good units \n', sum(rez.good>0))

% copy processed file to main data folder
if ~isfield(ops,'fileName')
    ops.fileName=regexp(ops.fproc,['(?<=\' filesep ')\w+?(?=.dat)'],'match','once');
end
outfN=fullfile(ops.exportDir, [ops.fileName '.dat']);
if exist(outfN,'file')
    movefile(outfN,[outfN '.raw'])
end
movefile(ops.fproc, outfN);

rez.ops.fproc = fullfile(ops.exportDir, [ops.fileName '.dat']);

%% [optional] save python results file for Phy
if exist(fullfile(dataDir,'params.py'),'file')
    delete(fullfile(dataDir,'params.py'))
end
fprintf('Saving results to Phy  \n')
rezToPhy(rez, dataDir);

%% save final results
% discard features in final rez file (too slow to save)
rez.cProj = [];
rez.cProjPC = [];

%KS2.5 final time sorting of spikes, for apps that use st3 directly
[~, isort]   = sortrows(rez.st3);
rez.st3      = rez.st3(isort, :);

%KS2.5 Ensure all GPU arrays are transferred to CPU side before saving to .mat
rez_fields = fieldnames(rez);
for i = 1:numel(rez_fields)
    field_name = rez_fields{i};
    if(isa(rez.(field_name), 'gpuArray'))
        rez.(field_name) = gather(rez.(field_name));
    end
end

% save final results as rez2
fprintf('Saving final results in rez2  \n')
fname = fullfile(dataDir, 'rez2.mat');
save(fname, 'rez', '-v7.3');

