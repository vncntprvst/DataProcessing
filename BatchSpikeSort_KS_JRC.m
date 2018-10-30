%% Export .dat file with BatchExport
% go to data session's root directory
dataFiles=BatchExport;

for fileNum=1:size(dataFiles,1)
    %% get recording's info
        recInfo = [recordingName '_recInfo'];
  
    %% create configuration file for KiloSort
    if get(handles.CB_KSConfigurationFile,'value')==1
        useGPU=1;
        userParams.useGPU=num2str(useGPU);
        
        [status,cmdout]=GenerateKSConfigFile(exportname,cd,userParams);
        if status~=1
            disp('problem generating the configuration file')
        else
            disp(cmdout)
        end
    end
    
    %% create ChannelMap file for KiloSort
    if get(handles.CB_KSChannelMap,'value')==1
        probeInfo.numChannels=length(handles.rec_info.exportedChan);
        if isfield(handles.rec_info,'probeLayout')
            switch handles.rec_info.sys
                case 'OpenEphys'
                    probeInfo.chanMap=[handles.rec_info.probeLayout.OEChannel];
                case 'Blackrock'
                    probeInfo.chanMap=[handles.rec_info.probeLayout.BlackrockChannel];
            end
            if isfield(handles,'remapped') && handles.remapped==true
                [~,chSortIdx]=sort(probeInfo.chanMap);
                handles.rec_info.probeLayout=handles.rec_info.probeLayout(chSortIdx);
                probeInfo.chanMap=probeInfo.chanMap(chSortIdx);
            else
                probeInfo.chanMap=1:probeInfo.numChannels;
            end
            probeInfo.connected=true(probeInfo.numChannels,1);
            probeInfo.connected(isnan([handles.rec_info.probeLayout.Shank]))=0;
            probeInfo.kcoords=[handles.rec_info.probeLayout.Shank];
            probeInfo.kcoords=probeInfo.kcoords(~isnan([handles.rec_info.probeLayout.Shank]));
            if isfield(handles.rec_info.probeLayout,'x_geom')
                probeInfo.xcoords = [handles.rec_info.probeLayout.x_geom];
                probeInfo.ycoords = [handles.rec_info.probeLayout.y_geom];
            else
                probeInfo.xcoords = zeros(1,probeInfo.numChannels);
                probeInfo.ycoords = 200 * ones(1,probeInfo.numChannels);
                groups=unique(probeInfo.kcoords);
                for elGroup=1:length(groups)
                    if isnan(groups(elGroup))
                        continue;
                    end
                    groupIdx=find(probeInfo.kcoords==groups(elGroup));
                    probeInfo.xcoords(groupIdx(2:2:end))=20;
                    probeInfo.xcoords(groupIdx)=probeInfo.xcoords(groupIdx)+(0:length(groupIdx)-1);
                    probeInfo.ycoords(groupIdx)=...
                        probeInfo.ycoords(groupIdx)*(elGroup-1);
                    probeInfo.ycoords(groupIdx(round(end/2)+1:end))=...
                        probeInfo.ycoords(groupIdx(round(end/2)+1:end))+20;
                end
            end
        end
        
        [status,cmdout]=GenerateKSChannelMap(exportname,cd,probeInfo,handles.rec_info.samplingRate);
        if status~=1
            disp('problem generating the configuration file')
        else
            disp(cmdout)
        end
    end
    
    %% Run KiloSort
    % First run generated configuration file to instantiate 'ops'
    run(['config_'exportname]) %something like that
    rez=RunKS(ops)
end

%% run JRClust (kilosort branch)
% jrc import-ksort /path/to/your/rez.mat sessionName % sessionName is the name typically given to the .prm file
