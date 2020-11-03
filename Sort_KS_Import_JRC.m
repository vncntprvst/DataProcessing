configFileName = 'vIRt50_1022_4900_KSconfigFile';
rez=RunKS(configFileName);
jrc('bootstrap',[recInfo.recordingName '_export.meta'],'-noconfirm','-advanced')
jrc('import-ksort',cd,false);
jrc manual vIRt50_1022_4900_export.prm