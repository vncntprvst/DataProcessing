function rez=RunKS(ops,fileName)

%% run generated config file to create ops
% e.g., config_vIRt22_2018-10-16_19-11-34_5100_50ms1Hz10mW_nopp
% see DataExportGUI

%% Run KiloSort
[rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
rez                = fitTemplates(rez, DATA, uproj);  % fit templates iteratively
rez                = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)

%% spk2 add-ons %%
%% [optional] Auto merge
rez = merge_posthoc2(rez);

%% [optional] save python results file for Phy
rezToPhy(rez, cd);

%% save
save(fullfile(cd,  [fileName '_rez.mat']), 'rez', 'ops', '-v7.3');

%% run JRClust (kilosort branch)
% jrc import-ksort /path/to/your/rez.mat sessionName % sessionName is the name typically given to the .prm file 

%% [optional] raw traces filtering  
clear rez
rawTraces = memmapfile(ops.fbinary,'Format','int16');
rawTraces=double(rawTraces.Data); 
filtTraces=FilterTrace(rawTraces);
fileID = fopen([fileName '_filtered.dat'],'w');
fwrite(fileID,filtTraces,'int16');
fclose(fileID);


