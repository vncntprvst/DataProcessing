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
ops.fproc   = fullfile(tempDir, 'temp_wh.dat'); % proc file on a fast SSD
chanMapFile = ops.chanMap;
ops.chanMap = chanMapFile;

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

%% run KiloSort2
% preprocess data to create temp_wh.dat
rez = preprocessDataSub(ops); % preprocess data and extract spikes for initialization
% [rez, DATA, uproj] = preprocessDataSub(ops); 

% time-reordering as a function of drift
rez = clusterSingleBatches(rez);

% saving here is a good idea, because the rest can be resumed after loading rez
save(fullfile(dataDir, 'rez.mat'), 'rez', '-v7.3');

% main tracking and template matching algorithm
rez = learnAndSolve8b(rez);

% final merges
rez = find_merges(rez, 1);

% final splits by SVD
rez = splitAllClusters(rez, 1);

% final splits by amplitudes
rez = splitAllClusters(rez, 0);

% decide on cutoff
rez = set_cutoff(rez);

fprintf('found %d good units \n', sum(rez.good>0))

%% [optional] save python results file for Phy
fprintf('Saving results to Phy  \n')
rezToPhy(rez, dataDir);

%% save final results
% discard features in final rez file (too slow to save)
rez.cProj = [];
rez.cProjPC = [];

% save final results as rez2
fprintf('Saving final results in rez2  \n')
fname = fullfile(dataDir, 'rez2.mat');
save(fname, 'rez', '-v7.3');

