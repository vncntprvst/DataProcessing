
%% declarations
slash='\';
scriptDir='C:\Anaconda\envs\spykc\Scripts';
exportDir='PrV77_63_BR_16Ch';
exportFile='PrV77_63_ManualStim_ContraBet_BR_16Ch_nopp';
% load implant list and find probe file name
userinfo=UserDirInfo;
subjectName=regexp(strrep(handles.dname,'_','-'),'(?<=\\)\w+\d+','match');
load([userinfo.probemap userinfo.slash 'ImplantList.mat']);
probeID=implantList(~cellfun('isempty',...
    strfind(strrep({implantList.Mouse},'-',''),subjectName{:}))).Probe;
probeFile=['C:\\Users\\Vincent\\spyking-circus\\probes\\' probeID '.prb'];

%% create parameter file
status = system(['cd ' scriptDir ' &'...
        'activate spykc &'...
        'spyking-circus C:\Data\export\' ...
        exportDir slash exportFile '.dat <C:\Code\yes.txt']); 
    %  add ' &' to run in background outside Matlab

fid  = fopen([exportFile '.params'],'r');
params=fread(fid,'*char')';
fclose(fid);
delete([exportFile '.params'])

%% replace parameters
params = regexprep(params,'(?<=data_offset    = )\w+(?= )','0');
params = regexprep(params,'(?<=mapping        = )\w+.\w+.\w+(?= )', probeFile);
params = regexprep(params,'(?<=data_dtype     = )\w+(?= )','int16');
params = regexprep(params,'(?<=dtype_offset   = )\w+(?= )','0');
params = regexprep(params,'(?<=sampling_rate  = )\w+(?= )','30000');
params = regexprep(params,'(?<=N_t            = )\w+(?= )','2');
params = regexprep(params,'(?<=spike_thresh   = )\w+(?= )','7');
params = regexprep(params,'(?<=peaks          = )\w+(?= )','both');
params = regexprep(params,'(?<=remove_median  = )\w+(?= )','True');
params = regexprep(params,'(?<=max_elts       = )\w+(?= )','20000');
params = regexprep(params,'(?<=nclus_min      = )\w.\w+(?= )','0.0001');
params = regexprep(params,'(?<=max_elts       = )\w+(?= )','20000');
params = regexprep(params,'(?<=smart_search   = )\w+(?= )','0.01');
params = regexprep(params,'(?<=noise_thr      = )\w.\w+(?= )','0.9');

fid  = fopen([exportFile '.params'],'w');
fprintf(fid,'%s',params);
fclose(fid);

% start MS-MPI
!C:\Anaconda\Scripts\anaconda.bat & activate spykc & smpd -d 1 &

%% run preview
% doesn't work. Matlab don't get rights to run mpiexec properly
status = system(['cd ' scriptDir ' &'...
        'activate spykc &'...
        'SETLOCAL &'...
        'set PATH="C:\Anaconda\envs\spykc;C:\Anaconda\envs\spykc\Scripts;C:\Anaconda\envs\spykc\Library\bin;C:\Program Files\Microsoft MPI\Bin\;C:\Windows\system32;C:\Windows" &'...
        'spyking-circus C:\Data\export\' ...
        exportDir slash exportFile '.dat -p &']); 
    
%alternative 1
% system('C:\Windows\System32\cmd.exe /k "C:\Anaconda\Scripts\anaconda.bat" ')
% cd C:\Anaconda\envs\spykc\Scripts
% activate spykc
% spyking-circus C:\Data\export\PrV77_63_BR_16Ch\PrV77_63_ManualStim_ContraBet_BR_16Ch_nopp.dat -p

%alternative 2
%  !cd C:\Anaconda\envs\spykc\Scripts & activate spykc & spyking-circus C:\Data\export\PrV77_63_BR_16Ch\PrV77_63_ManualStim_ContraBet_BR_16Ch_nopp.dat -p

%alternative 3
% status = system(['runas /user:Vincent & cd ' scriptDir ' &'...
%         'activate spykc &'...
%         'spyking-circus C:\Data\export\' ...
%         exportDir slash exportFile '.dat -p &']); 

%% run process
% works until fitting
[status,cmdout] = system(['cd ' scriptDir ' &'...
        'activate spykc &'...
        'SETLOCAL &'...
        'set PATH="C:\Anaconda\envs\spykc;C:\Anaconda\envs\spykc\Scripts;C:\Anaconda\envs\spykc\Library\bin;C:\Program Files\Microsoft MPI\Bin\;C:\Windows\system32;C:\Windows" &'...
        'spyking-circus C:\Data\export\' ...
        exportDir slash exportFile '.dat -m filtering,whitening,clustering -c 4']); 

% finish fitting
[status,cmdout] = system(['cd ' scriptDir ' &'...
        'activate spykc &'...
        'SETLOCAL &'...
        'set PATH="C:\Anaconda\envs\spykc;C:\Anaconda\envs\spykc\Scripts;C:\Anaconda\envs\spykc\Library\bin;C:\Program Files\Microsoft MPI\Bin\;C:\Windows\system32;C:\Windows" &'...
        'spyking-circus C:\Data\export\' ...
        exportDir slash exportFile '.dat -m fitting']); 

%tests on -maginefile vs -gmachinefile   
 
% !runas /user:Vincent & C:\Windows\System32\cmd.exe /k "C:\Anaconda\Scripts\anaconda.bat" &

%this works!
% !C:\Anaconda\Scripts\anaconda.bat & activate spykc & cd C:\Users\Vincent\spyking-circus & testbatch.bat & 
% % testbatch.bat (ni C:\Users\Vincent\spyking-circus)
%     % cd C:\Code
%     % mpiexec -machinefile circus.hosts -np 2 hostname 
% % circus.hosts (in C:\Code)
%     % 10.122.169.230
    
%tried the game of russian dolls further, with testbtach calls like:
% cmd /c "C:\Anaconda\Scripts\anaconda.bat && cd C:\Code && activate spykc && mpiexec -gmachinefile circus.hosts -np 3 hostname"
%or even better:
% CMD /c "Runas /profile /user:setup_souris\vincent C:\Anaconda\Scripts\anaconda.bat && cd C:\Code && activate spykc && mpiexec -gmachinefile circus.hosts -np 3 hostname"
% didn't work -> Unknown option: -gmachinefile (although -machinefile works)

% but this works:
% [status,cmdout] = system(['cd C:\Users\Vincent\spyking-circus &'...
%         'activate spykc &'...
%         'SETLOCAL &'...
%         'set PATH="C:\Anaconda\envs\spykc;C:\Anaconda\envs\spykc\Scripts;C:\Anaconda\envs\spykc\Library\bin;C:\Program Files\Microsoft MPI\Bin\;C:\Windows\system32;C:\Windows" &'...
%         '"C:\Program Files\Microsoft MPI\Bin\mpiexec.exe" -gmachinefile circus.hosts -np 3 hostname &']); 


%% exporting
[status,cmdout] = system(['cd ' scriptDir ' &'...
        'activate spykc &'...
        'SETLOCAL &'...
        'set PATH="C:\Anaconda\envs\spykc;C:\Anaconda\envs\spykc\Scripts;C:\Anaconda\envs\spykc\Library\bin;C:\Program Files\Microsoft MPI\Bin\;C:\Windows\system32;C:\Windows" &'...
        'spyking-circus C:\Data\export\' ...
        exportDir slash exportFile '.dat -m converting -c 4']); 

%% run GUI (no need for clusters here)
status = system(['cd ' scriptDir ' &'...
        'activate spykc &'...
        'circus-gui-matlab C:\Data\export\' ...
        exportDir slash exportFile '.dat']); 
