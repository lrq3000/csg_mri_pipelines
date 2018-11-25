function vbm_results(path_to_spm, rootpath, T1file, significance, id)
% vbm_results(path_to_spm, rootpath, T1file, significance)
% Automagically print VBM analysis results onto png images.
% Significance is either unc or fdr
% Tested on SPM12 and SPM8
% STEPHEN KARL LARROQUE
% v0.1.5
% 2017-2018
% LICENSE: MIT

% Analysis id (just for filename)
if isempty(id)
    id = 0;
end

% Build image filename prefix
imprefix = ['img_type' int2str(id) '_'];

% Split T1file into parts
[T1pathstr,T1name,T1ext] = fileparts(T1file);

% keep current folder in memory
scriptfolder = cd;

% Setup SPM results gui
load(fullfile(rootpath, 'SPM.mat'));
connum = 1;
if strcmpi(significance, 'unc')
    thresh = 0.001;
    threshdesc = 'none';
else
    thresh = 0.05;
    threshdesc = 'FDR';
end
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
spmfigprint(fullfile(rootpath, [imprefix '1.png']), 'png', 'white');

% Rendered 3D brains visu
rendfile = fullfile(path_to_spm, 'rend', 'render_spm96.mat');
brt = NaN;
dat    = struct( 'XYZ',  xSPM.XYZ,...
    't',    xSPM.Z',...
    'mat',  xSPM.M,...
    'dim',  xSPM.DIM);
% Workaround SPM8 bug: even if we provide rendfile argument, spm_render will still look for a prevrend.rendfile or else ask user. So we setup an artificial one to ensure batch.
global prevrend
prevrend = struct('rendfile',rendfile, 'brt',brt, 'col',[]);
% Render and save!
spm_render(dat,brt,rendfile);
spmfigprint(fullfile(rootpath, [imprefix '2.png']), 'png', 'white');
%spm_figure('Print'); % Works but only in eps
%spm_print('im2.png'); % Works but only in eps

% Display patient's unnormalized brain
spm_image('init', fullfile(rootpath, T1file));
spm_image('display', fullfile(rootpath, T1file));
spm_orthviews('Xhairs','off');
spmfigprint(fullfile(rootpath, [imprefix '3.png']), 'png', 'black');

% Display a gender and age matched control's brain
controlt1 = spm_select(1,'IMAGE','Select age/gender matched control T1 (unnormalized)');
spm_image('init', controlt1);
spm_image('display', controlt1);
spm_orthviews('Xhairs','off');
spmfigprint(fullfile(rootpath, [imprefix '4.png']), 'png', 'black');

% Close all SPM displays
%spm_figure('Close');
%spm('Quit');
cd(scriptfolder);

fprintf(1, 'All VBM results images printed!\n');

end % endfunction


% ==== AUX FUNCTIONS ====

function spmfigprint(filename, type, background)
% spmfigprint(filename, type, background)
% save current SPM figure to a filename by simulating MATLAB's GUI File > Export
    style = hgexport('factorystyle');
    style.Background = background;
    style.Format = type;
    hgexport(spm_figure('FindWin'), filename, style);
end %endfunction
