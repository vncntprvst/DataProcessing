function filtTrace=FilterTrace(data,threshold,samplingRate,option)
    [coeffb,coeffa] = butter(3,threshold/(samplingRate/2),option);    %options: 'low' | 'bandpass' | 'high' | 'stop'
    for chNm=1:size(data,1)
        filtTrace(chNm,:)= filtfilt(coeffb, coeffa, data(chNm,:));
    end
end
