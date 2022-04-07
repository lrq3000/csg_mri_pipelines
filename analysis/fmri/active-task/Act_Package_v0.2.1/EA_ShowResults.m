function EA_ShowResults()
% Setup SPM results gui
load(fullfile(rootpath, 'SPM.mat'));
connum = 1;
thresh = 0.05;
threshdesc = 'FDR';
k = 0;
job = struct('swd', SPM.swd, ...
    'Ic', connum, ...
    'u', thresh, ...
    'Im', [], ...
    'thresDesc', threshdesc, ...
    'title', SPM.xCon(connum).name, ...
    'k', k);

% Set modality (FMRI)
spm('defaults', 'FMRI')
% Load the SPM results
[hReg, xSPM, SPM] = spm_results_ui('setup', job);

% Section visu
spm_sections(xSPM,hReg,fullfile(rootpath, ['wmr' T1name '.nii']));
end % end script