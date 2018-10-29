function filtTrace=FilterTrace(data,samplingRate,threshold,option)

switch nargin
    case 0
        return;
    case 1
        samplingRate = 30000;
end

if size(data,2) > size(data,1)
    data=permute(data,[2,1]);
    permuteData=true;
else
    permuteData=false;
end

if exist('option','var') & ~contains(option,'UMS')
    %options: 'low' | 'bandpass' | 'high' | 'stop'
    [coeffB,coeffA] = butter(3,threshold/(samplingRate/2),option);
    filtTrace= filtfilt(coeffB, coeffA, data);
%     for chNm=1:size(data,1)
%         filtTrace(chNm,:)= filtfilt(coeffb, coeffa, data(chNm,:));
%     end
else % UMS type signal filtering
    % see UltraMegaSort2000 by Hill DN, Mehta SB, & Kleinfeld D  - 07/12/2010
    Wp = [ 700 8000] * 2 / samplingRate; % pass band for filtering
    Ws = [ 500 10000] * 2 / samplingRate; % transition zone
    [N,Wn] = buttord( Wp, Ws, 3, 20); % determine filter parameters
    [coeffB,coeffA] = butter(N,Wn); % builds filter
    filtTrace = filtfilt(coeffB, coeffA, data); % runs filter
end

if permuteData
        filtTrace=permute(filtTrace,[2,1]);
end