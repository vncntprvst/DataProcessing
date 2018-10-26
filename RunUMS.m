% parameters
num_trials   = 1;
Fs           = 30000;
num_channels =  32;
trial_dur    = [];

% load data
load('vIRt22_2018-10-16_18-43-54_5100_50ms1Hz5mW_CAR_traces.mat');
data={double(rawData')};

% [optional] Filter data
Wp = [ 700 8000] * 2 / Fs; % pass band for filtering
Ws = [ 500 10000] * 2 / Fs; % transition zone
[N,Wn] = buttord( Wp, Ws, 3, 20); % determine filter parameters
[B,A] = butter(N,Wn); % builds filter
data = filtfilt( B, A, data ); % runs filter

% run algorithm
spikes = ss_default_params(Fs);
spikes = ss_detect(data,spikes);
spikes = ss_align(spikes);
spikes = ss_kmeans(spikes);
spikes = ss_energy(spikes);
spikes = ss_aggregate(spikes);

% main tool
splitmerge_tool(spikes)

% stand alone outlier tool
outlier_tool(spikes)

%
% Note: In the code below, "clus", "clus1", "clus2", and "clus_list" are dummy
% variables.  The user should fill in these vlaues with cluster IDs found 
% in the SPIKES object after running the algorithm above.
%
clus_list=unique(spikes.assigns)
clus=1; clus1=1; clus2=2;
% plots for single clusters
plot_waveforms( spikes, clus );
plot_stability( spikes, clus);
plot_residuals( spikes,clus);
plot_isi( spikes, clus );
plot_detection_criterion( spikes, clus );

% comparison plots
plot_fld( spikes,clus1,clus2);
plot_xcorr( spikes, clus1, clus2 );

% whole data plots
plot_features(spikes );
plot_aggtree(spikes);
show_clusters(spikes, [clus_list]);
compare_clusters(spikes, [clus_list]);

% outlier manipulation (see M-files for description on how to use)
spikes = remove_outliers( spikes, which ); 
spikes = reintegrate_outliers( spikes, indices, mini );

% quality metric functions
%
% Note: There are versions of these functions in the quality_measures 
% directory that have an interface that does not depend on the SPIKES
% structure.  These are for use by people who only want to use the quality
% metrics but do not want to use the rest of the package for sorting. 
% These functions have the same names as below but without the "ss_" prefix.
%
FN1 = ss_censored( spikes, clus1 );
FP1 = ss_rpv_contamination( spikes, clus1  );
FN2 = ss_undetected(spikes,clus1);
confusion_matrix = ss_gaussian_overlap( spikes, clus1, clus2 ); % call for every pair of clusters

