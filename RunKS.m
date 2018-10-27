%% generated config file to create ops
% e.g., config_vIRt22_2018-10-16_19-11-34_5100_50ms1Hz10mW_nopp
% see DataExportGUI

%% Run KiloSort
[rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
rez                = fitTemplates(rez, DATA, uproj);  % fit templates iteratively
rez                = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)

%% spk2 add-ons %%
%% save python results file for Phy
rezToPhy(rez, cd);

%% Auto merge
rez = merge_posthoc2(rez);

%% save python results file for Phy
rezToPhy(rez, cd);

%% save and clean up
save(fullfile(cd,  'rez.mat'), 'rez', 'ops', '-v7.3');
