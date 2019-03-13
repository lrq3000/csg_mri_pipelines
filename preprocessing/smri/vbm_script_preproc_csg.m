function vbm_script_preproc_csg()
%
% Script for voxel based morphometric analysis of a single patient/subject, compared to a group of controls. Needs SPM8 and VBM8.
% T1 of patient in nifti format needs to be provided (no conversion is done from DICOM here).
% Can also provide a root directory with multiple subjects to process at once, this saves time if you do a multisubjects case study (where each subject is analyzed separately).
% VBM with DARTEL preprocessing will be done and also 2nd-level analysis SPM.mat of one patient/subject against a group of controls. A picture of the results using the voxel-wise thresholding of your choice can be generated for each subject.
%
% You need to have installed the following libraries prior to launching this script:
% * SPM8 + VBM8 (inside spm/toolbox folder) OR SPM12 + CAT12 (Geodesic Shooting, not DARTEL) (with cat12 inside spm/toolbox folder)
% Note: please enable expertgui (set to 1) in cat_defaults.m to see all the options used here.
%
% Exact versioning:
% * SPM12 Version 7487 (SPM12) 14-Nov-18 (from spm/Contents.m or by typing [a, b] = spm('Ver))
% * CAT12 r1434 | gaser | 2019-02-28 11:31:30 (from cat12/CHANGES.txt)
% * SPM8 Version 6313
% * VBM8 r445 | gaser | 2015-12-17 14:26:55 (from vbm8/CHANGES.txt)
%
% Also you need to use a fully compatible MATLAB version with SPM8. It was successfully tested on Matlab2011a and Matlab2013a, but failed with MATLAB 2016a and above. However, it successfully worked with MATLAB 2018a by modifying spm_render.m lines 260-261, by changing:
%    load('Split');
%    colormap(split);
% into:
%    oldcmap = load('Split');
%    colormap(oldcmap.split);
% You also need Python (and add it to the PATH! Must be callable from cmd.exe with a simple "python" command) and PILLOW (not PIL! Just do `conda install pillow` or `pip install pillow`) to generate the final stitched image, but if you want to do it yourself Python is not needed.
%
% STEPHEN KARL LARROQUE
% v1.3.3
% First version on: 2017-01-24 (first version of script based on batch from predecessors)
% 2017-2019
% LICENSE: MIT
%
% Inspired from a pipeline by Mohamed Ali BAHRI.
%
% TODO:
% * Parallelize smoothing and 2nd-level results generation?
% -------------------------------------------------------------------------
% =========================================================================
clear all;
clear classes;

% Initialization variables, PLEASE EDIT ME
rootpath_multi = 'X:\Path\To\MultipleSubjectsData'; % Set here the path to a directory of multiple groups, subjects and sessions to process multiple subjects at once. Else set to empty string to rather use rootpath_single. In this case, this should follow the same structure as the fmri preprocessing script: rootpath_multi/<Group>/<Subject>/data/<Session>/mprage/*.(nii|img)
rootpath_single = 'X:\Path\To\OneSubject\mprage\T1.nii'; % If you want to process only one subject, set here the full path to the T1 (extension: nii or img).
controlspath_greyonly = 'X:\Path\To\VBM_Controls\'; % controls images, must be generated using the same template AND grey only. If you don't have these images, run this pipeline on a set of healthy volunteers' T1 images with skip2ndlevel set to 1. Also this path is useless if skip2ndlevel is set to 1.
controlspath_greywhite = 'X:\Path\To\VBM_Controls_WhitePlusGrey\'; % controls images, grey + white, only necessary if you set skipgreypluswhite = 0. Skipped if skip2ndlevel = 1 or skipgreypluswhite = 1.
path_to_spm = 'C:\matlab_tools\spm12_fdr'; % change to spm8 or spm12 path depending on what script_mode you choose (respectively spm8 for script_mode 0 or spm12 for script_mode 1)
path_to_vbm8 = 'C:\matlab_tools\spm8\toolbox\vbm8'; % only necessary if script_mode == 0
path_to_cat12 = 'C:\matlab_tools\spm12_fdr\toolbox\cat12'; % only necessary if script_mode == 1
script_mode = 1; % 0: SPM8+VBM8(DARTEL), 1: SPM12+CAT12(SHOOT, successor of DARTEL), ref: https://www.researchgate.net/post/MR_brain_volume_spatial_normalization
num_cores = 0; % number of cores to use for parallel calculation in CAT12: use 0 to disable. For VBM8, multi-threading is always enabled and the number of cores cannot be chosen.
smoothsize = 12; % 12 for patients with damaged brains, 8 or 10 for healthy volunteers
skip1stlevel = 0; % only do 2nd-level analysis, skip preprocessing (particularly useful to continue at 2nd level directly if a bug happened or you change parameters such as significance)
skipcsfmask = 0; % do not apply a CSF exclusion mask in the results in SPM.mat
significance = 'fdr'; % 'fdr' by default, or 'unc'. Can skip1stlevel if you just change significance but already done the preprocessing once.
skipgreypluswhite = 1; % skip grey+white matters analysis? (if true, then will do only grey matter analysis, if false then will do both) - grey+white is disadvised, it was an experimental approach that was dropped due to inconsistent results
skip2ndlevel = 0; % if you only want to do VBM preprocessing but not compare against controls, set this to 1
skipresults = 0; % if you do not want to generate the result images from the 2nd level results (requires skip2ndlevel set to 0)
parallel_processing = false; % enable parallel processing between multiple subjects (num_cores need to be set to 0 to disable parallel processing inside CAT12, so we can parallelize outside!)
ethnictemplate = 'mni'; % 'mni' for European brains, 'eastern' for East Asian brains, 'none' for no regularization, '' for no affine regularization, 'subj' for the average of subjects (might be incompatible with CAT12 as it is not offered on the GUI)
cat12_spm_preproc_accuracy = 0.75; % SPM preprocessing accuracy, only if script_mode == 1 (using CAT12). Use 0.5 for average (default, good for healthy subjects, fast about 10-20min per subject), or 0.75 or 1.0 for respectively higher or highest quality, but slower processing time (this replaces the sampling distance option in previous CAT12 releases).

if script_mode == 0
    path_to_tissue_proba_map = 'toolbox/Seg/TPM.nii'; % relative to spm path
    path_to_dartel_template = 'Template_1_IXI550_MNI152.nii'; % relative to vbm8 path, you can use the default VBM template or a custom one. But always input the 1st template out of the 6.
elseif script_mode == 1
    path_to_tissue_proba_map = 'tpm/TPM.nii';
    %path_to_dartel_template = 'templates_1.50mm/Template_1_IXI555_MNI152.nii';
    path_to_shooting_template = 'templates_1.50mm/Template_0_IXI555_MNI152_GS.nii'; % relative to cat12 path
end

if parallel_processing
    num_cores = 0; % disabling CAT12 parallel processing if we parallelize outside
end

% --- Start of main script
fprintf(1, '\n=== VBM PREPROCESSING AND ANALYSIS ===\n');
% Temporarily restore factory path and set path to SPM and its toolboxes, this avoids conflicts when having different versions of SPM installed on the same machine
bakpath = path; % backup the current path variable
restoredefaultpath(); matlabpath(strrep(matlabpath, userpath, '')); % clean up the path
addpath(path_to_spm); % add the path to SPM8
if script_mode == 0
    addpath(path_to_vbm8); % add the path to VBM8
elseif script_mode == 1
    addpath(path_to_cat12); % add the path to CAT12
end

% Start logging
% Alternative to diary: launch MATLAB with the -logfile switch
logfile = [mfilename() '_' datestr(now, 'yyyy-mm-dd_HH-MM-ss') '.txt'];
diary off;
diary(logfile);
diary on;
finishup = onCleanup(@() stopDiary(logfile)); % need to use an onCleanup function to diary off and commit content into the logfile (could also use a try/catch block)

fprintf('== Building file list, please wait.\n');
T1fileslist = {};
if ~isempty(rootpath_multi)
    % Extract groups
    groups = get_dirnames(rootpath_multi);
    groups = groups(~strcmp(groups, 'JOBS')); % remove JOBS from the groups
    % Extract subjects names from inside the groups
    subjects = {};
    for g=1:length(groups)
        groupdir = fullfile(rootpath_multi, groups{g});
        subjn = get_dirnames(groupdir);
        for sub=1:length(subjn)
            subjdir = fullfile(groupdir,subjn{sub},'data');
            % Extract T1 for each session
            sessions = get_dirnames(subjdir);
            for s=1:length(sessions)
                structdir = fullfile(subjdir,sessions{s},'mprage');
                tempfiles = regex_files(structdir, '^.+\.(img|nii)$');
                if ~isempty(tempfiles)
                    % Add only if not empty
                    T1fileslist{end+1} = tempfiles;
                end
            end
            % If there is no session, try to extract from a top-level T1
            % (shared across sessions)
            structdir = fullfile(subjdir,'mprage');
            tempfiles = regex_files(structdir, '^.+\.(img|nii)$');
            if ~isempty(tempfiles)
                % Add only if not empty
                T1fileslist{end+1} = tempfiles;
            end
        end
    end
else
    T1fileslist = {rootpath_single};
end
fprintf('Found %i T1 files.\n', length(T1fileslist));

if ~skip1stlevel
    fprintf('=== BUILDING VBM PREPROCESSING (1ST-LEVEL) JOBS ===\n');
    matlabbatchall = {};
    matlabbatchall_infos = {};
    matlabbatchall_counter = 0;
    spm_jobman('initcfg'); % init the jobman
    for t=1:length(T1fileslist)
        % Extract parent dir and T1 filename (necessary for me function calls and to find segmented images)
        [rootpath, T1filename, T1fileext] = fileparts(T1fileslist{t});
        T1file = [T1filename, T1fileext];

        fprintf('== BUILDING PREPROCESSING (1st-LEVEL) JOB %i/%i: %s.\n', t, length(T1fileslist), T1fileslist{t});

        % Manual reorient
        %fprintf(1, '\nPlease reoriient the T1 for better segmentation and coreg with controls group. Press any key when you are done.\n');
        %spm_image('init', fullfile(rootpath, T1file));
        %spm_image('display', fullfile(rootpath, T1file));
        %pause();

        % Initialize the batch for this volume
        moduleid = 0;
        matlabbatchall_counter = matlabbatchall_counter + 1;
        matlabbatchall{matlabbatchall_counter} = [];
        matlabbatchall_infos{matlabbatchall_counter} = T1file;

        % == Segmentation of patient
        moduleid = moduleid + 1;
        if script_mode == 0
            fprintf('Using VBM8\n');
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.data = {strcat(fullfile(rootpath, T1file), ',1')};
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.opts.tpm = {strcat(fullfile(path_to_spm, path_to_tissue_proba_map), ',1')};
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.opts.ngaus = [2 2 2 3 4 2];
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.opts.biasreg = 0.0001;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.opts.biasfwhm = 60;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.opts.affreg = ethnictemplate;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.opts.warpreg = 4;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.opts.samp = 1;  % MODIFIED from defaults: sampling distance = 1 is better than default 3 for patients in clinical setting, because we want to reduce approximations and information loss
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.extopts.dartelwarp.normhigh.darteltpm = {strcat(fullfile(path_to_vbm8, path_to_dartel_template), ',1')};
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.extopts.sanlm = 2;  % sanlm 2 allow usage of multithreading to speedup the processing, but can set to 1 if issues happen (single thread)
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.extopts.mrf = 0.15;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.extopts.cleanup = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.extopts.print = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.GM.native = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.GM.warped = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.GM.modulated = 2;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.GM.dartel = 2;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.WM.native = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.WM.warped = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.WM.modulated = 2;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.WM.dartel = 2;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.CSF.native = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.CSF.warped = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.CSF.modulated = 2;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.CSF.dartel = 2;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.bias.native = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.bias.warped = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.bias.affine = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.label.native = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.label.warped = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.label.dartel = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.jacobian.warped = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.vbm8.estwrite.output.warps = [0 0];
        elseif script_mode == 1
            fprintf('Using CAT12\n');
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.data = {strcat(fullfile(rootpath, T1file), ',1')};
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.nproc = num_cores; % NOTE: if using parallel computation, then no other module can run after CAT12 (as specified in the documentation), but here in this pipeline anyway we always create a new job for the other postprocessing steps
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.opts.tpm = {fullfile(path_to_spm, path_to_tissue_proba_map)};
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.opts.affreg = ethnictemplate;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.opts.biasstr = 0.5;
            %matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.opts.samp = 1; % WAS DELETED BY NEWER CAT12, MODIFIED from defaults: sampling distance = 1 is better than default 3 for patients in clinical setting, because we want to reduce approximations and information loss
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.opts.accstr = cat12_spm_preproc_accuracy;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.segmentation.APP = 2; % Affine Preprocessing set to full
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.segmentation.NCstr = -Inf;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.segmentation.LASstr = 0.5;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.segmentation.gcutstr = 2;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.segmentation.cleanupstr = 0.5;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.segmentation.WMHC = 3; % WMH as its own class (so we can have the WMHC nifti image output, and it also means that WMHC is then separated from other tissues and thus less bias when doing statistical comparisons)
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.segmentation.SLC = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.segmentation.restypes.fixed = [1 0.1];
            %matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.registration.dartel.darteltpm = {strcat(fullfile(path_to_cat12, path_to_dartel_template), ',1')};
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.registration.shooting.shootingtpm = {fullfile(path_to_cat12, path_to_shooting_template)};
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.registration.shooting.regstr = 0.5;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.vox = 1.5;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.surface.pbtres = 0.5;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.surface.scale_cortex = 0.7;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.surface.add_parahipp = 0.1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.surface.close_parahipp = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.admin.ignoreErrors = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.admin.verb = 2;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.extopts.admin.print = 2;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.surface = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.ROImenu.atlases.neuromorphometrics = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.ROImenu.atlases.lpba40 = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.ROImenu.atlases.cobra = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.ROImenu.atlases.hammers = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.ROImenu.atlases.ibsr = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.ROImenu.atlases.aal = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.ROImenu.atlases.mori = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.ROImenu.atlases.anatomy = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.GM.native = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.GM.warped = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.GM.mod = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.GM.dartel = 3;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.WM.native = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.WM.warped = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.WM.mod = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.WM.dartel = 3;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.CSF.native = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.CSF.warped = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.CSF.mod = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.CSF.dartel = 3;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.WMH.native = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.WMH.warped = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.WMH.mod = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.WMH.dartel = 3;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.SL.native = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.SL.warped = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.SL.mod = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.SL.dartel = 0;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.atlas.native = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.atlas.dartel = 3;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.label.native = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.label.warped = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.label.dartel = 3;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.bias.native = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.bias.warped = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.bias.dartel = 3;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.las.native = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.las.warped = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.las.dartel = 3;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.jacobianwarped = 1;
            matlabbatchall{matlabbatchall_counter}{moduleid}.spm.tools.cat.estwrite.output.warps = [1 1];
        end
        % Save the batch for later introspection in case of issues
        save_batch(fullfile(rootpath, 'JOBS'), matlabbatchall{matlabbatchall_counter}, 'vbmcatsegment', script_mode, '');
    end %endfor

    fprintf('=== RUNNING VBM PREPROCESSING (1ST-LEVEL) JOBS ===\n');
    run_jobs(matlabbatchall, parallel_processing, matlabbatchall_infos, path);
end %endif

fprintf('=== RUNNING VBM POSTPROCESSING AND 2ND-LEVEL ANALYSIS JOBS ===\n');
matlabbatchall = {};
matlabbatchall_counter = 0;
spm_jobman('initcfg'); % init the jobman
for t=1:length(T1fileslist)
    % Extract parent dir and T1 filename (necessary for me function calls and to find segmented images)
    [rootpath, T1filename, T1fileext] = fileparts(T1fileslist{t});
    T1file = [T1filename, T1fileext];
    if script_mode == 1
        % CAT12 mode: all files are in mri subfolder
        rootpath = fullfile(rootpath, 'mri');
    end

    % == do two analyses: grey matter only or grey+white matter
    for i=1:2
        fprintf('== VBM 2ND-LEVEL ANALYSIS JOB %i/%i: %s.\n', t, length(T1fileslist), T1fileslist{t});
        if (i == 2) && (skipgreypluswhite == 1)
            break;
        end

        % Reinit batch (necessary for 2nd analysis to work)
        spm_jobman('initcfg'); % init the jobman
        moduleid = 0;
        clear matlabbatch;
        matlabbatch = [];

        % == Get segmented images
        if script_mode == 0
            segimg = regex_files(rootpath, '^m0wrp\d.+\.(img|nii)$');
        elseif script_mode == 1
            segimg = regex_files(rootpath, '^mwp\d.+\.(img|nii)$');
        end

        % == Extract controls images (for group comparison)
        % Note: do it first in csse there is an issue (ie: path incorrect, missing files)
        %moduleid = moduleid + 1;
        %matlabbatch{moduleid}.cfg_basicio.file_fplist.dir = {controlspath};
        %matlabbatch{moduleid}.cfg_basicio.file_fplist.filter = '.*\.img';
        %matlabbatch{moduleid}.cfg_basicio.file_fplist.rec = 'FPListRec';

        % == For second loop, generate the grey+white VBM statistical analysis
        if i == 2
            % == Merge grey+white if required
            moduleid = moduleid + 1;
            matlabbatch{moduleid}.spm.util.imcalc.input = {segimg{1}, segimg{2}};
            matlabbatch{moduleid}.spm.util.imcalc.output = 'greywhite.img';
            matlabbatch{moduleid}.spm.util.imcalc.outdir = {rootpath};
            matlabbatch{moduleid}.spm.util.imcalc.expression = '(i1+i2)/2';
            matlabbatch{moduleid}.spm.util.imcalc.options.dmtx = 0;
            matlabbatch{moduleid}.spm.util.imcalc.options.mask = 0;
            matlabbatch{moduleid}.spm.util.imcalc.options.interp = 1;
            matlabbatch{moduleid}.spm.util.imcalc.options.dtype = 4;
        end %endif

        % == Smoothing
        moduleid = moduleid + 1;
        if i == 2
            matlabbatch{moduleid}.spm.spatial.smooth.data = {fullfile(rootpath, 'greywhite.img,1')};
        else
            matlabbatch{moduleid}.spm.spatial.smooth.data = cellstr(segimg{1});
        end %endif
        matlabbatch{moduleid}.spm.spatial.smooth.fwhm = [smoothsize smoothsize smoothsize];
        matlabbatch{moduleid}.spm.spatial.smooth.dtype = 0;
        matlabbatch{moduleid}.spm.spatial.smooth.im = 0;
        matlabbatch{moduleid}.spm.spatial.smooth.prefix = strcat('s', int2str(smoothsize));

        % == Generate CSF exclusion mask
        moduleid = moduleid + 1;
        if script_mode == 0
            matlabbatch{moduleid}.spm.util.imcalc.input = segimg;
        elseif script_mode == 1
            matlabbatch{moduleid}.spm.util.imcalc.input = segimg';
        end
        matlabbatch{moduleid}.spm.util.imcalc.output = 'csf-exclude-mask.img';
        matlabbatch{moduleid}.spm.util.imcalc.outdir = {rootpath};
        matlabbatch{moduleid}.spm.util.imcalc.expression = '1-((i3>0) - ((i1+i2)/2 > 0))';
        matlabbatch{moduleid}.spm.util.imcalc.options.dmtx = 0;
        matlabbatch{moduleid}.spm.util.imcalc.options.mask = 0;
        matlabbatch{moduleid}.spm.util.imcalc.options.interp = 1;
        matlabbatch{moduleid}.spm.util.imcalc.options.dtype = 4;

        if ~skip2ndlevel
            % == Group comparison (2nd-level analysis: patient against controls)
            moduleid = moduleid + 1;
            matlabbatch{moduleid}.spm.stats.factorial_design.dir = {rootpath};
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.scans1(1) = cfg_dep;
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.scans1(1).tname = 'Group 1 scans';
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.scans1(1).tgt_spec{1}(1).name = 'filter';
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.scans1(1).tgt_spec{1}(1).value = 'image';
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.scans1(1).tgt_spec{1}(2).name = 'strtype';
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.scans1(1).tgt_spec{1}(2).value = 'e';
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.scans1(1).sname = 'Smooth: Smoothed Images';
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.scans1(1).src_exbranch = substruct('.','val', '{}',{moduleid-2}, '.','val', '{}',{1}, '.','val', '{}',{1});
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.scans1(1).src_output = substruct('.','files');
            % Get list of controls images for the control group
            if i == 2
                controlsimgs = check_exist(regex_files(controlspath_greywhite, '^.+\.(img|nii)$'));
            else
                controlsimgs = check_exist(regex_files(controlspath_greyonly, '^.+\.(img|nii)$'));
            end % endif
            % Use only first volume for each image
            for s=1:length(controlsimgs)
                controlsimgs{s} = strcat(controlsimgs{s}, ',1');
            end %endif
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.scans2 = controlsimgs'; % transpose (else you might run into "CAT arguments dimensions are not consistent." error). Can also sometimes do {cellstr(controlsimgs}'.
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.dept = 0;
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.variance = 0;
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.gmsca = 0;
            matlabbatch{moduleid}.spm.stats.factorial_design.des.t2.ancova = 0;
            matlabbatch{moduleid}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
            matlabbatch{moduleid}.spm.stats.factorial_design.masking.tm.tma.athresh = 0.1;
            matlabbatch{moduleid}.spm.stats.factorial_design.masking.im = 0;
            if ~skipcsfmask
                matlabbatch{moduleid}.spm.stats.factorial_design.masking.em = {fullfile(rootpath, 'csf-exclude-mask.img')};
            end % endif
            % matlabbatch{moduleid}.spm.stats.factorial_design.masking.em(1) = cfg_dep;
            % matlabbatch{moduleid}.spm.stats.factorial_design.masking.em(1).tname = 'Explicit Mask';
            % matlabbatch{moduleid}.spm.stats.factorial_design.masking.em(1).tgt_spec{1}(1).name = 'filter';
            % matlabbatch{moduleid}.spm.stats.factorial_design.masking.em(1).tgt_spec{1}(1).value = 'image';
            % matlabbatch{moduleid}.spm.stats.factorial_design.masking.em(1).tgt_spec{1}(2).name = 'strtype';
            % matlabbatch{moduleid}.spm.stats.factorial_design.masking.em(1).tgt_spec{1}(2).value = 'e';
            % matlabbatch{moduleid}.spm.stats.factorial_design.masking.em(1).sname = 'Image Calculator: Imcalc Computed Image: csf-exclude-mask.img';
            % matlabbatch{moduleid}.spm.stats.factorial_design.masking.em(1).src_exbranch = substruct('.','val', '{}',{moduleid-1}, '.','val', '{}',{1}, '.','val', '{}',{1});
            % matlabbatch{moduleid}.spm.stats.factorial_design.masking.em(1).src_output = substruct('.','files');
            matlabbatch{moduleid}.spm.stats.factorial_design.globalc.g_omit = 1;
            matlabbatch{moduleid}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
            matlabbatch{moduleid}.spm.stats.factorial_design.globalm.glonorm = 1;

            % == Estimate 2nd-level analysis
            moduleid = moduleid + 1;
            matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1) = cfg_dep;
            matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).tname = 'Select SPM.mat';
            matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(1).name = 'filter';
            matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(1).value = 'mat';
            matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(2).name = 'strtype';
            matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(2).value = 'e';
            matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).sname = 'Factorial design specification: SPM.mat File';
            matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).src_exbranch = substruct('.','val', '{}',{moduleid-1}, '.','val', '{}',{1}, '.','val', '{}',{1});
            matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).src_output = substruct('.','spmmat');
            matlabbatch{moduleid}.spm.stats.fmri_est.method.Classical = 1;

            % == Contrasts predefinition
            moduleid = moduleid + 1;
            matlabbatch{moduleid}.spm.stats.con.spmmat(1) = cfg_dep;
            matlabbatch{moduleid}.spm.stats.con.spmmat(1).tname = 'Select SPM.mat';
            matlabbatch{moduleid}.spm.stats.con.spmmat(1).tgt_spec{1}(1).name = 'filter';
            matlabbatch{moduleid}.spm.stats.con.spmmat(1).tgt_spec{1}(1).value = 'mat';
            matlabbatch{moduleid}.spm.stats.con.spmmat(1).tgt_spec{1}(2).name = 'strtype';
            matlabbatch{moduleid}.spm.stats.con.spmmat(1).tgt_spec{1}(2).value = 'e';
            matlabbatch{moduleid}.spm.stats.con.spmmat(1).sname = 'Model estimation: SPM.mat File';
            matlabbatch{moduleid}.spm.stats.con.spmmat(1).src_exbranch = substruct('.','val', '{}',{moduleid-1}, '.','val', '{}',{1}, '.','val', '{}',{1});
            matlabbatch{moduleid}.spm.stats.con.spmmat(1).src_output = substruct('.','spmmat');
            matlabbatch{moduleid}.spm.stats.con.consess{1}.tcon.name = 'Patient''s damages';
            matlabbatch{moduleid}.spm.stats.con.consess{1}.tcon.convec = [-1 1];
            matlabbatch{moduleid}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
            matlabbatch{moduleid}.spm.stats.con.consess{2}.tcon.name = 'Patient''s increases';
            matlabbatch{moduleid}.spm.stats.con.consess{2}.tcon.convec = [1 -1];
            matlabbatch{moduleid}.spm.stats.con.consess{2}.tcon.sessrep = 'none';
            matlabbatch{moduleid}.spm.stats.con.delete = 0;
        end

        % == Run the batch!
        % Saving temporary batch
        save_batch(fullfile(rootpath, 'JOBS'), matlabbatch, '2ndlevel', script_mode, '');

        % Run the preprocessing pipeline for current subject!
        spm_jobman('run', matlabbatch)

        if ~skip2ndlevel
            % Copy the analysis to a specific folder
            analysiscopyfolder = ['vbm_2ndlevel_ptsvsctr_type' int2str(i)];
            if i == 1
                analysiscopyfolder = 'vbm_2ndlevel_ptsvsctr_greyonly';
            elseif i == 2
                analysiscopyfolder = 'vbm_2ndlevel_ptsvsctr_greywhite';
            end
            acfDir = fullfile(rootpath, analysiscopyfolder);
            if exist(acfDir,'dir') == 7
                rmdir(acfDir, 's'); % delete if exists
            end
            %mkdir(acfDir); % not necessary, we will create it with copyfile, avoiding "unknown error occurred"
            try
                copyfile(fullfile(rootpath, '*'), acfDir, 'f');
            catch ME
                % ignore error "unknown error occurred", it will always happen because we are trying to copy all files, the destination folder included
                % also skip the weird "The requested lookup key was not found in any active activation context", which requires that you uninstall Internet Explorer and reboot
                if (isempty (strfind (ME.message, 'Unknown error'))) & (isempty (strfind (ME.message, 'The requested lookup key was not found in any active activation context.')))
                    rethrow(ME);
                end
            end

            % Generate the results images
            close all;
            if ~skipresults
                fprintf('== Generate final results report ==\n');
                if script_mode == 0
                    normprefix = 'wmr';
                elseif script_mode == 1
                    normprefix = 'wm';
                end
                vbm_results(path_to_spm, rootpath, T1fileslist{t}, significance, normprefix, i);
                close all;
                spm('quit');

                % Call Python script to generate final image
                fprintf('Generating final image using Python...\n');
                imprefix = ['img_type' int2str(i) '_'];
                callPython(fullfile('vbm_gen_final_image.py'), ['"' rootpath '" "' imprefix '" "' int2str(script_mode) '"'])
            end
        end
    end %endfor each analysis (grey only or grey+white)

end %endfor each T1

% == All done!
fprintf(1, 'All jobs done! Restoring path and exiting... \n');
path(bakpath); % restore the path to the previous state
diary off;
end % end script

% =========================================================================
%                              Functions
% =========================================================================

function dirNames = get_dirnames(dirpath)
% dirNames = get_dirnames(dirpath)
% Get the list of subdirectories inside a directory

    % Get a list of all files and folders in this folder.
    files = dir(dirpath);
    % Extract only those that are directories.
    subFolders = files([files.isdir]);
    dirNames = {subFolders.name};
    dirNames = dirNames(3:end); % remove '.' and '..'
end

function filesList = regex_files(dirpath, regex)
% filesList = regex_files(dirpath, regex)
% Extract files from a directory using regular expression

    % Get all files in directory
    filesList = dir(dirpath);
    % Filter out directories
    filesList = filesList(~[filesList.isdir]);
    % Use regular expression to filter only the files we want
    filesList = regexp({filesList.name}, regex, 'match');
    % Concatenate the filenames in a cellarray
    %filesList = {filesList.name};
    % Remove empty matches
    filesList = [filesList{:}];
    % Prepend the full path before each filename (so that we get absolute paths)
    if length(filesList) > 0
        filesList = cellfun(@(f) fullfile(dirpath, f), filesList, 'UniformOutput', false);
    end
    % Return directly the string instead of the cell array if there is only one file matched
    if length(filesList) == 1
        filesList = filesList{1};
    end
end

function filelist = check_exist(filelist)
%check_exist  Check if all the files in a given filelist exist, if not, print a warning
    if strcmp(class(filelist), 'cell')
        files_count = numel(filelist);
    else
        files_count = size(filelist, 1);
    end

    if isempty(filelist)
        msgID = 'check_exist:FileNotFound';
        msg = 'Error: file not found (filepath is empty).';
        FileNotFoundException = MException(msgID,msg);
        throw(FileNotFoundException);
    end
    for fi = 1:files_count
        if class(filelist) == 'cell'
            f = filelist{fi};
        else
            f = filelist(fi, 1:end);
        end
        if ~(exist(f, 'file') == 2) or isempty(f)
            msgID = 'check_exist:FileNotFound';
            msg = sprintf('Error: file not found: %s\n', f);
            FileNotFoundException = MException(msgID,msg);
            throw(FileNotFoundException);
        end
    end % endfor
end

function run_jobs(matlabbatchall, parallel_processing, matlabbatchall_infos, pathtoset)
% run_jobs(matlabbatchall, parallel_processing, matlabbatchall_infos)
% run in SPM a cell array of batch jobs, sequentially or in parallel
% matlabbatchall_infos is optional, it is a cell array of strings
% containing additional info to print for each job
% pathtoset is optional and allows to provide a path to set inside the
% parfor loop before running the jobs
    if exist('matlabbatchall_infos','var') % check if variable was provided, for parfor transparency we need to check existence before
        minfos_flag = true;
    else
        minfos_flag = false;
    end

    if parallel_processing
        fprintf(1, 'PARALLEL PROCESSING MODE\n');
        if exist('pathtoset', 'var') % not transparent, can't check variable existence in parfor loop
            pathtoset_flag = true;
        else
            pathtoset_flag = false;
        end
        parfor jobcounter = 1:numel(matlabbatchall)
        %parfor jobcounter = 1:1 % test on 1 job
            if minfos_flag
                fprintf(1, '\n---- PROCESSING JOB %i/%i FOR %s ----\n', jobcounter, numel(matlabbatchall), matlabbatchall_infos{jobcounter});
            else
                fprintf(1, '\n---- PROCESSING JOB %i/%i ----\n', jobcounter, numel(matlabbatchall));
            end
            % Set the path if provided, since in the parfor loop the
            % default path is restored. No need to backup because no need
            % to restore at the end of the thread, it will be destroyed
            if pathtoset_flag
                path(pathtoset)
            end
            % Init the SPM jobman inside the parfor loop
            spm_jobman('initcfg');
            % Load the batch for this iteration
            matlabbatch = matlabbatchall{jobcounter};
            % Run the preprocessing pipeline for current subject!
            spm_jobman('run', matlabbatch)
            %spm_jobman('serial',artbatchall{matlabbatchall_counter}); %serial and remove spm defaults
            % Close all windows
            fclose all;
            close all;
        end
    else
        fprintf(1, 'SEQUENTIAL PROCESSING MODE\n');
        % Set the path if provided
        if exist('pathtoset', 'var')
            bakpath = path; % backup the current path variable
            restoredefaultpath(); matlabpath(strrep(matlabpath, userpath, '')); % clean up the path
            path(pathtoset);
        end
        % Initialize the SPM jobman
        spm_jobman('initcfg');
        % Run the jobs sequentially
        for jobcounter = 1:numel(matlabbatchall)
        %for jobcounter = 1:1 % test on 1 job
            if minfos_flag
                fprintf(1, '\n---- PROCESSING JOB %i/%i FOR %s ----\n', jobcounter, numel(matlabbatchall), matlabbatchall_infos{jobcounter});
            else
                fprintf(1, '\n---- PROCESSING JOB %i/%i ----\n', jobcounter, numel(matlabbatchall));
            end
            matlabbatch = matlabbatchall{jobcounter};
            % Run the preprocessing pipeline for current subject!
            spm_jobman('run', matlabbatch)
            %spm_jobman('serial',artbatchall{matlabbatchall_counter}); %serial and remove spm defaults
            % Close all windows
            fclose all;
            close all;
        end
        % Restore the path
        path(bakpath);
    end
end %endfunction

function save_batch(jobsdir, matlabbatch, jobname, script_mode, subjname, isess)
% Save a batch as a .mat file in the specified jobsdir folder
    if ~exist(jobsdir)
        mkdir(jobsdir)
    end
    prevfolder = cd();
    cd(jobsdir);
    if ~exist('isess', 'var')
        save(['jobs_' jobname '_mode' int2str(script_mode) '_' subjname '_' datestr(now,30)], 'matlabbatch')
    else
        save(['jobs_' jobname '_mode' int2str(script_mode) '_' subjname '_session' int2str(isess) '_' datestr(now,30)], 'matlabbatch')
    end
    cd(prevfolder);
end %endfunction

function err_report = getReportError(errorStruct)
%getReportError  Get error report from specified error or lasterror (similarly to getReport() with exceptions)

    % Get last error if none specified
    if nargin == 0
        errorStruct = lasterror;
    end

    % Init
    err_report = '';

    % Get error message first
    if ~isempty(errorStruct.message)
        err_report = errorStruct.message;
    end

    % Then get error stack traceback
    errorStack = errorStruct.stack;
    for k=1:length(errorStack)
        stackline = sprintf('=> Error in ==> %s at %d', errorStack(k).name, errorStack(k).line);
        err_report = [err_report '\n' stackline];
    end
end

function stopDiary(logfile)
% Stop diary to save it into the logfile and save last error
% to be used with onCleanup, to commit the diary content into the log file
    % Stop the diary (commit all that was registered to the diary file)
    diary off;
    % Get the last error if there's one
    err = lasterror();
    if length(err.message) > 0
        errmsg = getReportError(err);
        fid = fopen(logfile, 'a+');
        fprintf(fid, ['ERROR: ??? ' errmsg]);
        fclose(fid);
    end
end

function callPython(scriptpath, arguments)
% Call a Python script with given arguments
    commandStr = ['python ' scriptpath ' ' arguments];
    [status, commandOut] = system(commandStr);
    if status==1
        fprintf('ERROR: Python call probably failed, return code is %d and error message:\n%s\n',int2str(status),commandOut);
    end
end
