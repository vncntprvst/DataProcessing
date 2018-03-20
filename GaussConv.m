function convTrace=GaussConv(data,sigma)
% sigma=1;
size = 6*sigma;
width = linspace(-size / 2, size / 2, size);
gaussFilter = exp(-width .^ 2 / (2 * sigma ^ 2));
gaussFilter = gaussFilter / sum (gaussFilter); % normalize

convTrace = conv (data, gaussFilter, 'same');
end