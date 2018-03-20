function normFactor=FindNormFactor(data, epochs, sigma)

if size(epochs,1)==1
    
    normFactor=cellfun(@(x,y) max([round(max(x(:,epochs(1):epochs(1)+249),[],2)),...
        round(max(y(:,epochs(2)-300:epochs(2)+299),[],2))],[],2),...
        data(:,1),data(:,2),'UniformOutput',false);

else

% Normalizes response from 0 to 1 using normalization factor. 
% Returns normalized responses and normalization factor

% data is a n by p cell array, with n neurons and p alignments
% each cell is structure with the following fields:
% rast: n by p array of n trials and p time points, with binary  spike train data (0=no spike, 1=spike)
% alignt: alignment time
% only the first row for each structure will be considered 

if nargin<3
    sigma=15;
end

% Convolve traces around epochs. Get peak firing rates.
maxResp=cell(size(data,1),size(data,2));

for alignnum=1:size(data,2)
    maxResp(:,alignnum)=cellfun(@(x) max(conv_raster(x(1,1).rast,sigma,...
        x(1,1).alignt-(epochs{alignnum}(1)+sigma*3),x(1,1).alignt+(epochs{alignnum}(2)+sigma*3))),...
        data(:,alignnum), 'UniformOutput',false); 
end

% foo=data{17,alignnum};
% bla=conv_raster(foo(1,1).rast,sigma,foo(1,1).alignt-(epochs{alignnum}(1)+sigma*3),...
%     foo(1,1).alignt+(epochs{alignnum}(2)+sigma*3));

% Find normalization factor
% The larger value is the normalization factor of the cell. 
normFactor=[max(cell2mat(maxResp),[],2) cell2mat(maxResp)];
end