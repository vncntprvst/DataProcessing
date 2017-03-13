function normData=RespNormalization(data, normFactor, sigma)
% Normalizes response from 0 to 1 using normalization factor. 
if nargin<3
    sigma=15;
end
normData=cell(size(data,1),size(data,2));
for nurnum=1:size(data,1)
    for alignnum=1:size(data,2)
        rastData=data{nurnum,alignnum};
        if isfield(rastData,'rast')
            for condition=1:size(rastData,2)
                rastData(1,condition).rast(isnan(rastData(1,condition).rast))=0;
                normData{nurnum,alignnum}{condition,1}=conv_raster(rastData(1,condition).rast,sigma)/normFactor(nurnum,1);
            end
        else
            rastData(isnan(rastData))=0;
            normData{nurnum,alignnum}=conv_raster(rastData,sigma)/normFactor(nurnum,1);
            if length(normData{nurnum,alignnum})==1 && isnan(normData{nurnum,alignnum})
                normData{nurnum,alignnum}=nan(size(rastData,1),size(rastData,2)-6*sigma);
            end
        end
    end
end
