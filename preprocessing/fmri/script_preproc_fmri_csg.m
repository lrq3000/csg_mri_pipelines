function script_preproc_fmri_csg()
%
% Script for preprocessing of functional and structural MRI data before further functional MRI analysis (usually through CONN toolbox).
% No fieldmaps correction, but works on several sessions (several conditions / subjects, automatically detected by file walking),
%
% This script should work on all platforms where MATLAB and SPM are supported (Windows, Linux, MacOSX).
%
% Artifact Detection: detection of global mean and motion outliers in the
% fmri data using the art toolbox (composite motion measures). According to Alfonso Nieto-Castanon: �It is similar to framewise displacement but not exactly the same ("framewise displacement" converts angular differences to mm by multiplying by a constant factor -projecting to a sphere-, and then sums the 6 individual translation/rotation displacement absolute measures; ART's "composite motion" measure estimates instead the maximum voxel displacement resulting from the combined effect of the individual translation and rotation displacement measures)�. Ref: https://www.nitrc.org/forum/forum.php?thread_id=5792&forum_id=398
%
% DATA IN root_pth, AKA ROOT DIRECTORY, MUST BE ORGANIZED AS FOLLOWS:
% /root_pth/<condition>/<subject_id>/data/<sess_id>/(mprage|rest|task1|task2|anything)/*.(img|hdr|nii) -- Note: mprage for structural MRI, rest for fMRI BOLD EPI, task1 or task2 or anything is any other modality or tasks (the possible modalities can be specified as a regex in func_dir_regex)
%
% EXAMPLES:
% /root_pth/CONTROLS/ELIZABETH/data/session1/rest/somenifti.nii (for the fMRI data)
% /root_pth/CONTROLS/ELIZABETH/data/session1/mprage/somenifti.nii (for the structural)
%
% IF MULTIPLE SESSIONS SHARE THE SAME STRUCTURAL MRI, IT IS POSSIBLE TO PLACE mprage ONE LEVEL ABOVE:
% /root_pth/CONTROLS/ELIZABETH/data/mprage/somenifti.nii
%
% Note: only raw structural and functional images must be in this tree: if there is any already preprocessed image file, please delete them beforehand! (realigned, smoothed, etc.)
%
% You need to have installed the following libraries prior to launching this script:
% * ART
% * SPM8 (r6313) + VBM8 (r445, inside spm/toolbox folder) OR SPM12 native (Version 7771 13-Jan-20 as shown in Contents.m, for OldSeg or Unified Segmentation pipelines) OR SPM12 (Version 7771 13-Jan-20 as shown in Contents.m) + CAT12 (Version 2577 (CAT12.9) 2024-05-03 as shown in CAT12/Contents.m, and CAT12 must be placed inside spm/toolbox folder)
% * (optional) RSHRF toolbox if you want to deconvolve the haemodynamic response function (set enable_rshrf to true)
% Note: old versions of CAT12 can be downloaded at: http://www.neuro.uni-jena.de/cat12/
%
% Stephen Karl Larroque
% 2016-2024
% First version on 2016-04-07, inspired by pipelines from Mohamed Ali Bahri (03/11/2014)
% Last update 2024
% v2.5.1
% License: MIT
%
% TODO:
% * Nothing here!
%
% DEV NOTES:
% * This pipeline was designed with a philosophy of modularity, by being decoupled in two parts: the batch files, which are subprograms made via SPM batch system and contains all the technical processing parameters, and the script which purpose is solely to dynamically load content (such as subjects files, or provide an easy way to modify a few common parameters such as smoothing kernel). Thus, the maintenance and evolutivity is eased: if you want to add a pipeline, simply create a new batch file, and then load it here. Of course, the script will need to be a bit modified to add code lines to dynamically change the appropriate parameters/load the content where required. To ease that, you can search for all instances of "script_mode", this will show you every places where such new code lines need to be added.
% * 4D nifti files support (via Expand Frames module of SPM) was dropped to
% allow for parallel computing of multi-sessions with shared structural mri
% * Reslicing was removed during realignment as this was an unnecessary additional resampling step that can introduce artifacts, for more details see: https://www.nitrc.org/forum/forum.php?thread_id=7155&forum_id=1144
% * In case of issues, open the generated batch jobs files in the JOBS subfolder to check the parameters and debug
% -------------------------------------------------------------------------
% =========================================================================
clear all;
clear classes;

% --- PARAMETERS: change me!
% Motion correction uses scan-to-scan motion to determine outliers using composite measures (ART toolbox by Susan Gabrieli-Whitfield)
nslices = 0; % set to 0 for autodetect
TR = 0; % set to 0 for autodetect
script_mode = 2.5; % 0: use VBM8 + SPM8/DARTEL (slow); 1: use SPM12 with OldSeg only (fast); 2: use SPM12 + CAT12/DARTEL (slowest); 2.5: use SPM12 + CAT12/SHOOT (slowest); 3: use SPM12 with Unified Segmentation (fast).
    % Note also that if script_mode 2 or 2.5 is selected (CAT12), the LazyProcessing parameter is enabled by default and will ensure that previously preprocessed sMRI will be skipped, even in a previous run. So for example there is an issue during BOLD, no problem, just delete the BOLD data, keep the preprocessed sMRI, and restart the script, it will directly skip to BOLD preprocessing steps.
motionRemovalTool = 'art'; % do not modify (except if you want to skip art motion correction)
root_pth = 'X:\Path\To\Data'; % root path, where all the subjects data is
path_to_spm = 'C:\matlab_tools\spm12'; % change here if you use SPM8 + VBM8 pipeline
path_to_art = 'C:\matlab_tools\art-2015-10'; % path to the ART toolbox by Sue Whitfield (not ARTDETECT!)
% Only for script_mode 0: always use here the Dartel (or your custom) template n�1. When you generate a template, the template is made iteratively, from iteration 0 to iteration 6. Thus, you will have 7 templates, with different levels of "bluriness". Here in this pipeline, the iteration 1 is expected, not the others. A default template is provided in the VBM8 toolbox.
path_to_vbm_dartel_template = 'X:\customTemplate\Template_1_IXI550_MNI152.nii'; % only for script_mode 0, else can leave as-is, it won't be used
% BOLD subdirectories
func_dir_regex = '(rest|func|task|tennis|navigation)'; % regex to match the functional/modalities directories (eg, 'rest' or 'task1' or 'task2' or 'task3' etc.)
% Slice timing correction parameters
% * Slice order: You need to know the order of slices and select the corresponding option
%   1: ascending [1:1:nslices]
%   2: descending [nsclices:-1:1]
%   3: interleaved ascending (bottom -> up): [1:2:nslices 2:2:nslices]
%   4: interleaved descending (top -> down): [nslices:-2:1, nslices-1:-2:1]
%   [1 2 ...]: a custom vector to represent your own defined slice order
%   0: autodetect for each session the slice order to use (then other parameters beginning with slice_* do not matter, except slice_timing which will overwrite slice_order in any case! Note that this rarely works on nifti files, often this information is only present in the MRI machine sequence's printout and sometimes in the BIDS json or DICOMs)
slice_order = 0;
slice_hstep = 2;  % if interleaved: horizontal step, ie, to reduce tissue excitation artefact, scanners can skip each x slice at the first scan, then scan these slices at subsequent runs. Usually set at 2 but if faster FMRI acquisition, the hstep can be higher.
slice_vstep = 1;  % if interleaved: vertical step (usually 1 except if fast FMRI TR like 800ms)
slice_reverse = 0;  % if interleaved: 0 to set in normal order [1, 3, ... 2, 4, ...] or 1 to set in reverse order [2, 4, ..., 1, 3, ...] or specify your own vector with row indices to reorder.
slice_timing = [];  % you can specify here the exact slice timing in ms to use instead of slice order. If empty, the slice order will be used instead. Note that this must be extracted from dicoms or bids files, as the nifti only contains the slice order type, so the slice timing can only be an approximation and is equivalent to what SPM does when a slice order is specified instead of slice timing. Slice timing is hence more precise because scanners tend to round off some values (with their own logic... so not all slices are rounded!) to have rounder numbers that can more reliably/easily be attained for all acquisitions (else with very precise numbers, it is impossible for the machine to exactly acquire at that time, so the machine calculate beforehand where it needs to round off). Note that this overrides all slice_* parameters relative to slice order.
% * Reference slice
refslice = 'first';  % reference slice for slice timing correction. Can either be 'first', 'middle', 'last', or any slice number (in the spatial convention, ie the same numbers as in the slice order). NOTE: if you change it to any other value than 'first', you will also have to adapt microtime_onset (fmri_T0) in the statistical test (beware that then it is in the temporal convention and rescaled to microtime_resolution, eg if resolution is 20 and slice order = [5 4 3 2 1] and refslice = 2, then microtime_onset = 4/5 = 16 after rescaling on microtime_resolution). NOTE2: if using slice_timing, the refslice must also be in ms instead of slice number (however the microtime_onset will still be on slice temporal position). If you want to do this, do not try to do this programmatically, dependencies in matlabbatch are not made to be recoded dynamically, use the interface to create a separate batch that you can then load here.
% * Module order: slice timing correction first or motion correction (realignment) first?
%stc_or_motion_first = 'auto'; % NOT SUPPORTED because anyway for our use case, it is useless, we should always use slice time correction first as we expect a lot of movement
% Keep non-smoothed normalized functional bold timeseries?
% (but note that if an error happens, you'll have to redo the whole preprocessing!)
%keep_normalized_timeseries = 1; % 1: keep, 0: delete % DEPRECATED: normalized timeseries are kept in any case (user can always delete afterward)
% Smoothing kernel (isotropic)
smoothingkernel = 8;
% Resize/resample/reslice functionals to 3x3x3 before smoothing
% NOTE: if you have multiband BOLD, please disable this, else your BOLD may end up being cut in half!
resizeto3 = false;
% Parallel preprocessing? Tip: disable when having errors to ease debugging.
parallel_processing = false;
% Always disable shared MRI optimization?
% Global flag controlling whether shared MRI can be reused in the same job. When enabled, if a structural MRI is shared between sessions or modalities, all functional filesets will be processed in one job. This saves time, but coregistration is done on a mean of ALL sessions/modalities, so it may be worse. If false, then a new batch job will be created for each session and modality, regardless of whether the sMRI can be shared (if script_mode == 2 or 2.5, then once the sMRI is preprocessed once, it will be reused for other sessions/modalities without reprocessing, but for other script_mode, the sMRI will be reprocessed again). This needs to be enabled for parallel_processing to be enabled, otherwise parallel_processing will be disabled automatically.
% If true, it is assumed that all sessions and modalities sharing the same sMRI will also have the same parameters (same TR, nslices, slices order)
% If either your sessions/modalities have different parameters, or if you want to have a mean coregistration for each session/modality, then set this to false, and ensure to set script_mode to 2 or 2.5 if you still want to skip sMRI preprocessing when already done (via CAT12 LazyProcessing).
sharedmri_all = true;
% ART input files
art_before_smoothing = true; % At CSG, we always did ART on post-smoothed data, but according to Alfonso Nieto-Castanon, ART should be done before smoothing: https://www.nitrc.org/forum/message.php?msg_id=10652
% Skip preprocessing steps (to do only post-processing?) - useful in case
% of error and you want to restart just at post-processing
skip_preprocessing = false;
% Use the rshrf toolbox to deconvolve the Hemodynamic Response Function?  Note: the rshrf toolbox needs to be in the "toolbox" folder of SPM12. Important: do not enable this if you use CONN for analysis, as it is advised to use rshrf after CONN denoising: https://www.nitrc.org/forum/forum.php?thread_id=9818&forum_id=1144
enable_rshrf = false;
% Use Realign & Unwarp (=non-linear deformation recovery from movement artifacts) instead of Realign (without Reslice)? Note: available only for SPM12 pipelines.
realignunwarp = false;
% Ethnic regularization
ethnictemplate = 'mni'; % 'mni' for European brains, 'eastern' for East Asian brains, 'none' for no regularization, '' for no affine regularization, 'subj' for the average of subjects (might be incompatible with CAT12 as it is not offered on the GUI)
% SPM preprocessing accuracy, only if script_mode == 1 (using CAT12)
cat12_spm_preproc_accuracy = 0.5; % Use 0.5 for average (default, good for healthy subjects, fast about 10-20min per subject), or 0.75 or 1.0 for respectively higher or highest quality, but slower processing time (this replaces the sampling distance option in previous CAT12 releases - from script's author's own tests, there is not much visible difference).
cat12_shooting_method = 0.5; % use 0.5 for the default "Optimized Shooting - standard" in the template resolution (TR), but if you get an issue with some brain damaged patient ("Problem with Shooting", which means the shooting failed, probably because of a buggy mask/cropping?), then use 'eps' for the "Optimized Shooting - fast" in the template resolution too or 5 (vox) for "Optimized Shooting in the output resolution", this might fix the issue. Never use 4, the "Default Shooting", as it never detects if there is a problem. But do check visually afterwards, as even if there is no problem detected, the shooting might fail. Also note that geodesic shooting "reconstructs" the grey matter and deflates ventricles of brain damaged patients, prefer DARTEL if you want to limit reconstruction.

% DO NOT TOUCH (unless you use a newer version than SPM12 or if the batch files were renamed)
if script_mode == 0 % for SPM8+VBM8
    % path to the SPM batch job to use as a pipeline, relatively to current script location. If you are not familliar with SPM, this software allows to create a "batch" which is a collection of modules to run in a row. This allows to configure and save full pipelines. We can design a whole SPM batch programmatically, but here we chose to design a batch, load it, and just programmatically redefine some variables (like paths, etc.). This is more easily maintainable, as the neuroscientifical technical data is stored in the batch, and here we basically just automate its usage on any dataset.
    path_to_batch = 'batch_preproc_spm8_vbm8dartel_midtemplate_defbiascorrected.mat'; % relative to this script path
    % path relative to spm folder
    path_to_tissue_proba_map = 'toolbox/Seg/TPM.nii'; % relative to spm path, you can use the default VBM template or a custom one. But always input the 1st template out of the 6.
    % Where are the template segmentation provided by SPM?
    % path to the folder containing grey.nii, white.nii and csf.nii
    path_to_tpm_grey_white_csf = 'toolbox/Seg'; % relative to spm path
    % Disable incompatible options
    realignunwarp = false;
elseif script_mode == 1 % for SPM12 OldSeg
    if ~realignunwarp
        path_to_batch = 'batch_preproc_spm12_oldseg.mat'; % relative to this script path
    else
        path_to_batch = 'batch_preproc_spm12_oldseg_unwarp.mat'; % relative to this script path
    end
    path_to_tissue_proba_map = 'tpm/TPM.nii'; % relative to spm path
    path_to_tpm_grey_white_csf = 'toolbox/OldSeg'; % relative to spm path
elseif (script_mode == 2) || (script_mode == 2.5) % for SPM12+CAT12
    if ~realignunwarp
        path_to_batch = 'batch_preproc_spm12_CAT12Dartel_2024.mat'; % relative to this script path
    else
        path_to_batch = 'batch_preproc_spm12_CAT12Dartel_2024_unwarp.mat'; % relative to this script path
    end
    path_to_tissue_proba_map = 'tpm/TPM.nii'; % relative to spm path
    path_to_dartel_template = 'toolbox/cat12/templates_MNI152NLin2009cAsym/Template_1_Dartel.nii';
    path_to_shooting_template = 'toolbox/cat12/templates_MNI152NLin2009cAsym/Template_0_GS.nii'; % relative to cat12 path
    path_to_wmh_tpm = 'toolbox/cat12/templates_MNI152NLin2009cAsym/cat_wmh_miccai2017.nii';
    path_to_bv_tpm = 'toolbox/cat12/templates_MNI152NLin2009cAsym/cat_bloodvessels.nii';
    path_to_sl_tpm = 'toolbox/cat12/templates_MNI152NLin2009cAsym/cat_strokelesions_ATLAS303.nii';
elseif script_mode == 3 % for SPM12 UniSeg
    if ~realignunwarp
        path_to_batch = 'batch_preproc_spm12_uniseg.mat'; % relative to this script path
    else
        path_to_batch = 'batch_preproc_spm12_uniseg_unwarp.mat'; % relative to this script path
    end
    path_to_tissue_proba_map = 'tpm/TPM.nii'; % relative to spm path
end

slice_order_auto = {}; % initialize the slice order auto detection cellarray
% --- End of parameters

% --- Start of main script
% Temporarily restore factory path and set path to SPM and its toolboxes, this avoids conflicts when having different versions of SPM installed on the same machine
bakpath = path; % backup the current path variable
restoredefaultpath(); matlabpath(strrep(matlabpath, userpath, '')); % clean up the path
addpath(path_to_spm); % add the path to SPM
addpath(path_to_art); % add the path to art toolbox

% Start logging
% Alternative to diary: launch MATLAB with the -logfile switch
logfile = [mfilename() '_' datestr(now, 'yyyy-mm-dd_HH-MM-ss') '.txt'];
diary off;
diary(logfile);
diary on;
finishup = onCleanup(@() stopDiary(logfile)); % need to use an onCleanup function to diary off and commit content into the logfile (could also use a try/catch block)

% Scan the root path to extract all conditions and subjects names
% Extract conditions
conditions = get_dirnames(root_pth);
conditions = conditions(~strcmp(conditions, 'JOBS')); % remove JOBS from the conditions
% Extract subjects names from inside the conditions
subjects = {};
for c=1:length(conditions)
    subjects{c} = struct('names', []); % associate the subjects names for each condition
    subjn = get_dirnames(fullfile(root_pth, conditions{c}));
    subjects{c}.names = subjn;
end

% Notes and warnings
fprintf(1, '\n\nNote: data is expected to be manually reoriented and coregistered before the execution of this pipeline to optimize the results.\n');
fprintf(1, 'Note2: data is expected to be in 3D nifti format (extension .nii or .img). Experimental support for 4D nifti is implemented but not tested.\n');
fprintf(1, 'Note3: never launch this script from the "Play" button in MATLAB. Always launch this script from the commandline prompt (to force compilation).\n');
fprintf(1, 'Note4: Be careful to have a clean directory tree: inside the root path, there should only be one folder per condition, not any other folder containing any other kind of data!\n');
fprintf(1, 'Note5: Make sure your data is clean too: if you already ran the script but it failed, remove every files that were generated by the script, except the original files of course, then re-run the script (else it will fail because it will misdetect the generated files as the original ones).\n');
fprintf(1, 'Note6: Accentuated characters, paths with spaces and paths that are too long may make the SPM modules fail (file not found error). Please check all your paths, including the data and the toolboxes that you added in your MATLAB path.\n');
fprintf(1, 'Note7: If you get the error "Improper assignment with rectangular empty matrix" during slice timing, please check your TR and slice number (check that the values detected by SPM are the same than the ones you provided, else it means you need to fix something - be careful with SPM<12, spm_slice_timing will not show the number of slices and will show only one digit after comma for TR, eg, if you set TR=2.46, it will show only TR=2.5).\n');
fprintf(1, 'Note8: If you get the error "subsref, Reference to non-existent element of a cell array" as soon as the first subject gets processed ("Running job #1" is not even displayed yet) then please check that you have correctly installed all the required libraries (particularly VBM8 in spm/toolbox folder).\n');
fprintf(1, 'Note9: If you get the error "Cant map view of file.  It may be locked by another program.", then either you modified the script and something opened an image and did not release it , else if you did not change the script, you are using 4D nifti files that are too big for your memory or filesystem, then you need to convert them into 3D nifti.\n\n');

% Start ticking
tic

% Sanity check + autodetection
% check number of slices is correct for all subjects (if nslices is > 0, else it will be skipped)
% and autodetect EPI parameters
fprintf(1, '\n\n-------------------------\n=== SANITY CHECKS ===\n\n');
filescount = 0;
for c = 1:length(conditions)
    % Get the data structure for all subjects for this condition
    data = get_data(fullfile(root_pth, conditions{c}), subjects{c}, func_dir_regex);
    slice_order_auto{c} = {}; % initialize the slice order auto detection cellarray (for multiple subjects)
    for isub = 1:size(data, 2)
        slice_order_auto{c}{isub} = {}; % initialize the per subject slice order auto detection cellarray (because there are multiple sessions)
        for isess = 1:length(data(isub).sessions)  % loop over all sessions
            slice_order_auto{c}{isub}{isess} = {}; % initialize per session (because there are multiple modalities)
            fsess = data(isub).sessions{isess};
            for imodal = 1:length(fsess.modalities) % loop over all modalities
                % Load list of functional images
                fdata = get_fdata(data, isub, isess, imodal);
                filescount = filescount + size(fdata, 1);

                if nslices > 0 % no autodetect for nslices?
                    % Load first image in folder
                    Vin = spm_vol(fdata(1,:));
                    % Extract the number of slices of this image (should be the same for all functional images of the same subject)
                    snslices = Vin(1).dim(3);
                    % Compare against the expected number of slices, and warn if not equal
                    if snslices ~= nslices
                        error('Subject %s condition %s session %s modality %s has %i slices in fMRI instead of expected %i slices! Please either preprocess this subject separately or crop it down.\n', subjects{c}.names{isub}, conditions{c}, fsess.id, fsess.modalities{imodal}, snslices, nslices);
                    end
                end %endif

                % Autodetection of EPI parameters from nifti files
                if slice_order == 0 | TR == 0 | nslices == 0
                    slice_order_auto{c}{isub}{isess}{imodal} = struct('slice_order', [], ...
                                                            'TR', 0, ...
                                                            'nslices', 0);
                    fprintf('-> Autodetected parameters for condition %s subject %s session %s modality %s:\n', conditions{c}, data(isub).name, fsess.id, fsess.modalities{imodal});
                    [autores_so, autores_tr, autores_nslices] = autodetect_sliceorder(fdata(1, :), true); % use verbose mode to show the autodetected parameters
                    slice_order_auto{c}{isub}{isess}{imodal}.slice_order = autores_so;
                    slice_order_auto{c}{isub}{isess}{imodal}.TR = autores_tr;
                    slice_order_auto{c}{isub}{isess}{imodal}.nslices = autores_nslices;
                    if (isempty(autores_so) && isempty(slice_order)) || ((autores_tr == 0) && (TR == 0)) || ((autores_nslices == 0) && (nslices == 0))
                        error('Autodetection impossible for this session, cannot proceed further, please either process this session separately or fill manually the EPI parameters!');
                    end
                end
            end
        end
    end
end
if filescount == 0
    error('No files detected! Please check that your root_pth is organized according to the required layout: /root_pth/<condition>/<subject_id>/data/<sess_id>/(mprage|rest)/*.(img|hdr|nii)\nExamples:\n/root_pth/CONTROLS/ELIZABETH/data/session1/rest/somenifti.nii (for the fMRI data)\n/root_pth/CONTROLS/ELIZABETH/data/session1/mprage/somenifti.nii (for the structural) or /root_pth/CONTROLS/ELIZABETH/data/mprage/somenifti.nii (for shared structural for all functional sessions)');
end

% Preprocessing Jobs preparation loop!
fprintf(1, '\n\n-----------------\n=== PREPARING PREPROCESSING JOBS ===\n\n');
spm_jobman('initcfg'); % init the jobman
matlabbatchall_counter = 0; % we use this to be able to load multiple different batch files. The steps are in the next sublevel of the batch cell array.
matlabbatchall = {}; % cell array containing all batch files we will load here, to be able to run them all in a row
matlabbatchall_infos = {}; % store the infos to print for each batch job (eg, subject name, session, etc.) - this will be printed in the console so the user knows what is happening
for c = 1:length(conditions) % loop over all conditions/groups
    % Get the data structure for all subjects for this condition
    data = get_data(fullfile(root_pth, conditions{c}), subjects{c}, func_dir_regex);
    for isub = 1:size(data, 2) % loop over all subjects
        prevsdata = [];
        ffileset = 1; % counter that gets incremented for each file set (= set of functional images) added to the current batch file. This allows to append to the same batch job multiple sessions and modalities. It starts at 1 because the first loop/session/modality does not use it.
        sharedmri_sess = false; % tracks whether we already processed a structural MRI that can be shared across sessions for this subject. It is always false for the first session of any subject, so that this forces to create a de novo batch file, but then if the struct is shared (ie, not inside a session folder but in the subject folder), then the next sessions after the first will reuse the structural (and hence will skip all the very time-consuming segmentation calculations!)
        for isess = 1:length(data(isub).sessions) % loop over all sessions
            fsess = data(isub).sessions{isess};
            sharedmri_mod = false; % tracks whether we already processed a structural MRI that can be reused across modalities
            for imodal = 1:length(fsess.modalities) % loop over all modalities
                fprintf(1, '---- PREPARING CONDITION %s SUBJECT %i (%s) SESSION %s MODALITY %s ----\n', conditions{c}, isub, data(isub).name, data(isub).sessions{isess}.id, fsess.modalities{imodal});

                % IMPORTANT: explanation how the batch jobs work:
                % First we load a template batch job, in which we programmatically fill the dynamic field such as volumes paths, and also maybe change some parameters we allow to modify as simply variables at the top of this script for ease for the user (even though they can always open the template batch job to modify any non-dynamic parameter).
                % (dynamic parameters = parameters that are different for each subject, session, modality, etc., such as path to volumes)
                % Secondly, if a structural image is shared across sessions or modalities, we reuse the previous batch job to append the functional images of the other sessions/modalities as a new FileSet for the Functional input files to the same job
                % Reusing the same batch file across sessions/modalities is necessary, because of parallelism: we cannot process the same structural image in different batch jobs in parallel, so we need to make only one batch job per structural image.
                % Finally, once all sessions/modalities have been added to the job, and all dynamic parameters have been filled, we save the final job as a new batch file for backup for later introspection, and save it in memory in a big cell array matlabbatchall.
                % Then, after all batch jobs have been created, we can run them all in a row or in parallel using run_jobs()
                % This approach offers pros and cons:
                % pros: parallelism, must faster processing since sMRI is by far the most time-consuming step
                % cons: it is assumed that all sessions and modalities sharing the same sMRI will also have the same parameters (same TR, nslices, slices order), coregistration of all functional filesets to template is a mean for all sessions/modalities. Hence manual preprocessing (reorienting and coregistration) is very important, and bad sessions should be rejected and deleted before this automatic preprocessing pipeline.

                if ~sharedmri_all || ~(sharedmri_sess || sharedmri_mod)   % no already preprocessed shared mri available, we create a new batch/job (either it's the first session or modality, or there is a separate structural MRI for each, depending on where the structural MRI is placed in the folders tree)
% DROPPED due to too much complex coding and maintenance, the Expand Frames
% module (and thus 4D nifti) was dropped. If the Expand Frames module could
% support multiple sessions, it would ease things a lot! (no modules
% dependencies change anymore!)
%
%                 Prepare modules index offsets
%                 isessoffset = -1+isess;
%                 newexpandidx = 3+isessoffset;
%                 if script_mode == 1
%                     coregbaseidx = 6;
%                 elseif (script_mode == 0) || (script_mode == 2) || (script_mode == 2.5)
%                     coregbaseidx = 7;
%                 end
%                 % move all modules one index further, to leave room for a new Expand Frames module
%                 for i = (numel(matlabbatchall{matlabbatchall_counter})+1):-1:(newexpandidx)
%                     matlabbatchall{matlabbatchall_counter}{i} = matlabbatchall{matlabbatchall_counter}{i-1};
%                 end
%                 % configure the new Expand Frames module
%                 matlabbatchall{matlabbatchall_counter}{newexpandidx}.spm.util.exp_frames.files(1) = cfg_dep(sprintf('Named File Selector: Functional(%i) - Files', isess), substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files', '{}',{isess}));
% 
%                 % configure slice timing scans
%                 matlabbatchall{matlabbatchall_counter}{4+isessoffset}.spm.temporal.st.scans{isess}(1) = cfg_dep('Expand image frames: Expanded filename list.', substruct('.','val', '{}',{newexpandidx}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
% 
%                 for isesscur = 1:isess
%                     % configure realignment
%                     matlabbatchall{matlabbatchall_counter}{5+isessoffset}.spm.spatial.realign.estwrite.data{isesscur}(1) = cfg_dep(sprintf('Slice Timing: Slice Timing Corr. Images (Sess %i)', isesscur), substruct('.','val', '{}',{4+isessoffset}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{isesscur}, '.','files'));
% 
%                     % configure function coregistration to structural
%                     matlabbatchall{matlabbatchall_counter}{coregbaseidx+isessoffset}.spm.spatial.coreg.estimate.other(isesscur) = cfg_dep(sprintf('Realign: Estimate & Reslice: Realigned Images (Sess %i)', isesscur), substruct('.','val', '{}',{5+isessoffset}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','sess', '()',{isesscur}, '.','cfiles'));
%                 end
%                 % configure coregistration again, to update input and
%                 % output modules
%                 % note that we can't just change the value of the module,
%                 % we need to use cfg_dep which will take care of modifying
%                 % dynamically both input and output modules to match the
%                 % link bidirectionally
%                 if script_mode == 0
%                     % TODO
%                 elseif script_mode == 1
%                     % TODO
%                 elseif (script_mode == 2) || (script_mode == 2.5)
%                     % CORRECT (not tested)
%                     matlabbatchall{matlabbatchall_counter}{coregbaseidx+isessoffset}.spm.spatial.realign.estwrite.data{2}(1).src_exbranch(2) = struct('type', '{}', 'subs', {{matlabbatch{6}.spm.spatial.realign.estwrite.data{2}(1).src_exbranch(2).subs{1}+1}});
%                     % OTHER METHODS
%                     %matlabbatchall{matlabbatchall_counter}{coregbaseidx+isessoffset}.spm.spatial.coreg.estimate.ref = update_deps(matlabbatchall{matlabbatchall_counter}{coregbaseidx+isessoffset}.spm.spatial.coreg.estimate.ref, {{coregbaseidx+isessoffset-2}}, {{coregbaseidx+isessoffset-1}});
%                     %matlabbatchall{matlabbatchall_counter}{coregbaseidx+isessoffset}.spm.spatial.coreg.estimate.ref(1) = cfg_dep('CAT12: Segmentation: Native Bias Corr. Image', substruct('.','val', '{}',{coregbaseidx+isessoffset-1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','biascorr', '()',{':'}));
%                     % TODO: OTHER FIELDS
%                     %matlabbatch{6}.spm.spatial.realign.estwrite.data{2}(1).src_output = substruct('type', '()', 'subs', {{isess}})
%                 end

                    % = Increment the batches counter, to create a new batch for this job
                    matlabbatchall_counter = matlabbatchall_counter + 1;
                    % = Reset the functional MRI fileset counter (since we are detecting a new structural MRI since we are in this branch)
                    ffileset = 1;

                    % = Autodetection enabled? Then load in local variables the already autodetected parameters. If not, then load the specified arguments
                    if nslices > 0
                        nslices_sess = nslices;
                    else
                        nslices_sess = slice_order_auto{c}{isub}{isess}{imodal}.nslices;
                    end
                    if TR > 0
                        TR_sess = TR;
                    else
                        TR_sess = slice_order_auto{c}{isub}{isess}{imodal}.TR;
                    end
                    if slice_order > 0
                        slice_order_sess = slice_order;
                    else
                        slice_order_sess = slice_order_auto{c}{isub}{isess}{imodal}.slice_order;
                    end

                    % = Step 1: Load the SPM batch job template
                    % Load (or reload) already designed SPM batch
                    % We will use that as a template to create a specific batch with all dynamic fields such as volumes paths filled programmatically
                    % maintaining a batch is easier than code (particularly to compare between versions of SPM)
                    mbatch = load(get_template(path_to_batch));  % load into a variable for transparency (necessary for parfor)
                    matlabbatchall{matlabbatchall_counter} = mbatch.matlabbatch;
                    matlabbatchall_infos{matlabbatchall_counter} = sprintf('CONDITION %s SUBJECT %i (%s) SESSION %s MODALITY %s', conditions{c}, isub, data(isub).name, data(isub).sessions{isess}.id, fsess.modalities{imodal}); % info that will be printed when the job will run

                    % = Step 2: Modify the SPM batch to fill in the dynamic parameters (dynamic = parameters that change for each subject, session, modality, etc. such as volumes paths)

                    % == Batch step: Load the anatomical MRI
                    % Generate the list of mri for this session
                    [sdata, sharedmri_sess] = get_mri(data, isub, isess);
                    prevsdata = sdata; % memoize in case the structural MRI can be shared across sessions/modalities
                    % Sanity check: ensure only one structural is selected (else
                    % data is probably already preprocessed)
                    if (size(sdata,1) > 1) && ~skip_preprocessing
                        error('Multiple structural images found! Please check your input data, delete previously preprocessed data if necessary.');
                    end
                    if script_mode == 0
                        matlabbatchall{matlabbatchall_counter}{1}.cfg_basicio.cfg_named_file.files = transpose({cellstr(sdata)});
                    elseif (script_mode == 1) || (script_mode == 2) || (script_mode == 2.5) || (script_mode == 3)
                        matlabbatchall{matlabbatchall_counter}{1}.cfg_basicio.file_dir.file_ops.cfg_named_file.files = {cellstr(sdata)}';
                    end

                    % == Batch step: Load functional image
                    % Add the functional files of this session/modality
                    fdata = get_fdata(data, isub, isess, imodal);
                    % Detect if 4D, we need to expand
                    fdata_nbframes = spm_select_get_nbframes(fdata(1,:));
                    if fdata_nbframes > 1
                        %fdata = expand_4d_vols(fdata);  % WRONG: if you do that with a Named File Selector, it will give random results, with not the correct amount of frames (you can check after realign the motion text file rp* and compare against the number of EPI frames). The correct way is to use "Expand images frames" after named file selector
                        error('4D nifti file detected, they are unsupported. Please convert to 3D nifti files using SPM to avoid memory issues (cant map view error)!');
                    end
                    if script_mode == 0
                        matlabbatchall{matlabbatchall_counter}{2}.cfg_basicio.cfg_named_file.files = {cellstr(fdata)};
                    elseif (script_mode == 1) || (script_mode == 2) || (script_mode == 2.5) || (script_mode == 3)
                        matlabbatchall{matlabbatchall_counter}{2}.cfg_basicio.file_dir.file_ops.cfg_named_file.files = {cellstr(fdata)};
                    end

                    % == Batch step: Slice time correction
                    % add new session into slice timing
                    % IMPORTANT: make sure all batches have the functional
                    % named file selector named: "Functional" (and not just
                    % "Func" nor "functional" for example!), else you might get
                    % very weird errors (eg, files processed from wrong parent!)
                    if (script_mode == 2) || (script_mode == 2.5)
                        slicetimestepidx = 4;
                    else
                        slicetimestepidx = 3;
                    end % endif
                    matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.nslices = nslices_sess;
                    matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.tr = TR_sess;
                    matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.ta = (TR_sess-(TR_sess/nslices_sess));
                    if ~isempty(slice_timing)
                        fprintf('Using slice timing (in ms): %s\n', ['[' sprintf('%g, ', slice_timing) ']']);
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.so = slice_timing;
                    else
                        slice_order_sess2 = [];
                        if isscalar(slice_order_sess)
                            % slice order is a scalar (it is the nifti slice order type), we construct the full slice order
                            switch slice_order_sess
                                case 1 % ascending
                                    slice_order_sess2 = [1:1:nslices_sess];
                                case 2 % descending
                                    slice_order_sess2 = [nslices_sess:-1:1];
                                case 3 % interleaved ascending
                                    slice_order_sess2 = gen_slice_order(nslices_sess, slice_hstep, slice_vstep, 'asc', slice_reverse, true); % for hstep=2 and vstep=1 and slice_reverse=0: [1:2:nslices 2:2:nslices];
                                case 4 % interleaved descending
                                    slice_order_sess2 = gen_slice_order(nslices_sess, slice_hstep, slice_vstep, 'desc', slice_reverse, true); % for hstep=2 and vstep=1 and slice_reverse=0: [nslices:-2:1,nslices-1:-2:1];
                            end
                        else
                            % slice order is a vector, we directly feed it to SPM
                            slice_order_sess2 = slice_order_sess;
                        end %endif
                        % Set slice order/timing
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.so = slice_order_sess2;
                        fprintf('Using slice order: %s\n', ['[' sprintf('%i, ', slice_order_sess2) ']']);
                        % Set reference slice
                        [microtime_onset, microtime_resolution, refslice_sess] = gen_microtime_onset(slice_order_sess2, refslice);
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.refslice = refslice_sess;
                        if ~strcmpi(class(refslice), 'char')
                            refslice_str = int2str(refslice);
                        else
                            refslice_str = refslice;
                        end %endif
                        fprintf('Using reference slice: %i (wanted refslice: %s)\n', refslice_sess, refslice_str);
                        fprintf('If you use SPM for statistical analysis, you should set microtime_resolution %i and microtime_onset %i\n', microtime_resolution, microtime_onset);
                    end %endif

                    % == Batch step: Structural preprocessing (CAT12/VBM8/SPM12)
                    % Load segmentation templates
                    if script_mode == 0
                        % VBM config: load custom VBM TPM and DARTEL templates
                        % Tissue probability map (use native Seg toolbox template)
                        matlabbatchall{matlabbatchall_counter}{5}.spm.tools.vbm8.estwrite.opts.tpm = {strcat(fullfile(path_to_spm, path_to_tissue_proba_map), ',1')};
                        % Dartel template
                        matlabbatchall{matlabbatchall_counter}{5}.spm.tools.vbm8.estwrite.extopts.dartelwarp.normhigh.darteltpm = {strcat(path_to_vbm_dartel_template, ',1')};
                        % Ethnic affine regularization
                        matlabbatchall{matlabbatchall_counter}{5}.spm.tools.vbm8.estwrite.opts.affreg = ethnictemplate;
                    elseif (script_mode == 2) || (script_mode == 2.5)
                        % CAT12 config: load TPM and DARTEL templates
                        % Main tissue probability map (use native Seg toolbox template)
                        matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.opts.tpm = {fullfile(path_to_spm, path_to_tissue_proba_map)};
                        % Other tissue probability maps (specific to CAT12)
                        matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.extopts.segmentation.WMHtpm = {fullfile(path_to_spm, path_to_wmh_tpm)};
                        matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.extopts.segmentation.BVtpm = {fullfile(path_to_spm, path_to_bv_tpm)};
                        matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.extopts.segmentation.SLtpm = {fullfile(path_to_spm, path_to_sl_tpm)};
                        % Ethnic affine regularization
                        matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.opts.affreg = ethnictemplate;
                        % Dartel template
                        % Deprecated if using shooting template in new releases of CAT12
                        if script_mode == 2
                            % Dartel template
                            matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.extopts.registration.dartel.darteltpm = {fullfile(path_to_spm, path_to_dartel_template)};
                            if isfield(matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.extopts.registration, 'shooting')
                                matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.extopts.registration = rmfield(matlabbatchall{matlabbatchall_counter}{5}.spm.tools.cat.estwrite.extopts.registration, 'shooting'); % disable SHOOT
                            end
                        elseif script_mode == 2.5
                            % Geodesic shooting template
                            matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.extopts.registration.regmethod.shooting.shootingtpm = {fullfile(path_to_spm, path_to_shooting_template)};
                            matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.extopts.registration.regmethod.shooting.regstr = cat12_shooting_method;
                            if isfield(matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.extopts.registration, 'dartel')
                                matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.extopts.registration = rmfield(matlabbatchall{matlabbatchall_counter}{5}.spm.tools.cat.estwrite.extopts.registration, 'dartel'); % disable DARTEL
                            end
                        end
                        % SPM preprocessing accuracy
                        matlabbatchall{matlabbatchall_counter}{3}.spm.tools.cat.estwrite.opts.accstr = cat12_spm_preproc_accuracy;
                    elseif script_mode == 1
                        % SPM12 Old segmentation templates config
                        template_seg_list = {'grey.nii', 'white.nii', 'csf.nii'};
                        template_seg_cell = {};
                        for ti = 1:length(template_seg_list)
                            % Append vertically to the cellstr (this is the expected axis by SPM)
                            template_seg_cell = [template_seg_cell; strcat(fullfile(path_to_spm, path_to_tpm_grey_white_csf, template_seg_list{ti}), ',1')];
                        end
                        matlabbatchall{matlabbatchall_counter}{6}.spm.tools.oldseg.opts.tpm = template_seg_cell;
                        % Ethnic affine regularization
                        matlabbatchall{matlabbatchall_counter}{6}.spm.tools.oldseg.opts.regtype = ethnictemplate;
                        % Smoothing parameters
                        % Note: for SPM pipelines (ie, without VBM8 nor CAT12), the smoothing is done directly inside the batch. For CAT12/VBM8 however it's not possible, so the smoothing is done separately in another dynamically constructed batch (see below)
                        %if resizeto3
                            % If resizeto3, then we don't smooth here as we
                            % will do it afterward, after the resize
                            matlabbatchall{matlabbatchall_counter}(9) = []; % note the round braces (and not curly) to act on the cell and not the cell's content
                        %else
                            %matlabbatchall{matlabbatchall_counter}{9}.spm.spatial.smooth.fwhm = [smoothingkernel smoothingkernel smoothingkernel];
                            %matlabbatchall{matlabbatchall_counter}{9}.spm.spatial.smooth.prefix = ['s' int2str(smoothingkernel)];
                        %end
                    elseif script_mode == 3
                        % SPM12 Unified segmentation templates config
                        for i = 1:6
                            matlabbatchall{matlabbatchall_counter}{6}.spm.spatial.preproc.tissue(i).tpm = {[fullfile(path_to_spm, path_to_tissue_proba_map) sprintf(',%i', i)]};
                        end
                        % Ethnic affine regularization
                        matlabbatchall{matlabbatchall_counter}{6}.spm.spatial.preproc.warp.affreg = ethnictemplate;
                        % DEPRECATED: Smoothing parameters (now done systematically afterward in a post-processing job)
                        % Note: for SPM pipelines (ie, without VBM8 nor CAT12), the smoothing is done directly inside the batch. For CAT12/VBM8 however it's not possible, so the smoothing is done separately in another dynamically constructed batch (see below)
                        %if resizeto3
                            % If resizeto3, then we don't smooth here as we
                            % will do it afterward, after the resize
                            %matlabbatchall{matlabbatchall_counter}(8) = []; % note the round braces (and not curly) to act on the cell and not the cell's content
                        %else
                            %matlabbatchall{matlabbatchall_counter}{8}.spm.spatial.smooth.fwhm = [smoothingkernel smoothingkernel smoothingkernel];
                            %matlabbatchall{matlabbatchall_counter}{8}.spm.spatial.smooth.prefix = ['s' int2str(smoothingkernel)];
                        %end
                    end

                    % == Reuse the structural MRI for the next modalities in any case
                    % TODO: support per modality smri, akin to sessions? For now, smri is always shared between modalities.
                    sharedmri_mod = true;

                else  % There is a shared structural MRI for multiple functional sessions/modalities, we reuse previous batch job but add a new fileset
                    % If sharedmri_sess or sharedmri_mod, we add this session/modality functional volumes as an additional FileSet that will be processed simultaneously to the previous one, this is why we reuse the previous batch job.
                    % If there is a shared MRI for multiple sessions or modalities, we reuse the previous batch file by adding this session's/modality's functional files as an additional FileSet
                    % So that the sMRI will be processed only once, but applied on multiple sessions/modalities at once!
                    % This if condition branch gets activated only if there are multiple sessions or modalities reusing the same already preprocessed structural image
                    % This is important for parallel processing to avoid 2 jobs processing the same structural mri in parallel (else the file will be locked and the processing fail), and in addition it saves s x m times the total processing time since we do not have to repreprocess/resegment the structural for each session/modality but only once for all, which is by far the most time-consuming step.

                    % == Increment the fileset counter for each session and each modality, so that we ensure that each fileset gets appended and does not overwrite a previous one
                    ffileset = ffileset + 1;

                    % == Update the batch info to append the new session/modality
                    matlabbatchall_infos{matlabbatchall_counter} = sprintf('%s & SESSION %s MODALITY %s', matlabbatchall_infos{matlabbatchall_counter}, data(isub).sessions{isess}.id, fsess.modalities{imodal});

                    % == Batch step: Load the anatomical MRI
                    % Reuse mri if shared across sessions (placed at same level as conditions)
                    %sdata = prevsdata;
                    %if script_mode == 0
                    %    matlabbatchall{matlabbatchall_counter}{1}.cfg_basicio.cfg_named_file.files = transpose({cellstr(sdata)});
                    %elseif (script_mode == 1) || (script_mode == 2) || (script_mode == 2.5) || (script_mode == 3)
                    %    matlabbatchall{matlabbatchall_counter}{1}.cfg_basicio.file_dir.file_ops.cfg_named_file.files = {cellstr(sdata)}';
                    %end

                    % == Batch step: Load functional image
                    % Add the functional files of this session/modality
                    fdata = get_fdata(data, isub, isess, imodal);
                    % Detect if 4D, we need to expand
                    fdata_nbframes = spm_select_get_nbframes(fdata(1,:));
                    if fdata_nbframes > 1
                        %fdata = expand_4d_vols(fdata);  % WRONG: if you do that with a Named File Selector, it will give random results, with not the correct amount of frames (you can check after realign the motion text file rp* and compare against the number of EPI frames). The correct way is to use "Expand images frames" after named file selector, see above the commented block to see how to implement that, but the issue is then that out of memory errors are much more likely, so we prefer to just stick to 3D nifti.
                        error('4D nifti file detected, they are unsupported, as they can cause out of memory errors (cant map view error). Please convert to 3D nifti files using SPM or the provided helper script nifti_4dto3d_convert_recursive.m .');
                    end
                    if script_mode == 0
                        matlabbatchall{matlabbatchall_counter}{2}.cfg_basicio.cfg_named_file.files{ffileset} = cellstr(fdata);
                    elseif (script_mode == 1) || (script_mode == 2) || (script_mode == 2.5) || (script_mode == 3)
                        matlabbatchall{matlabbatchall_counter}{2}.cfg_basicio.file_dir.file_ops.cfg_named_file.files{ffileset} = cellstr(fdata);
                    end

                    % == Batch step: Slice time correction
                    % add new fileset into slice timing
                    % IMPORTANT: make sure all batches have the functional
                    % named file selector named: "Functional" (and not just
                    % "Func" nor "functional" for example!), else you might get
                    % very weird errors (eg, files processed from wrong parent!)
                    if (script_mode == 2) || (script_mode == 2.5)
                        slicetimestepidx = 4;
                    else
                        slicetimestepidx = 3;
                    end % endif
                    if script_mode == 0
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.scans{ffileset}(1) = cfg_dep;
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.scans{ffileset}(1).tname = 'Session';
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.scans{ffileset}(1).tgt_spec{1}(1).name = 'class';
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.scans{ffileset}(1).tgt_spec{1}(1).value = 'cfg_files';
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.scans{ffileset}(1).tgt_spec{1}(2).name = 'strtype';
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.scans{ffileset}(1).tgt_spec{1}(2).value = 'e';
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.scans{ffileset}(1).sname = sprintf('Named File Selector: Functional(%i) - Files', ffileset);
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.scans{ffileset}(1).src_exbranch = substruct('.','val', '{}',{2}, '.','val', '{}',{1});
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.scans{ffileset}(1).src_output = substruct('.','files', '{}',{ffileset});
                    elseif (script_mode == 1) || (script_mode == 2) || (script_mode == 2.5) || (script_mode == 3)
                        matlabbatchall{matlabbatchall_counter}{slicetimestepidx}.spm.temporal.st.scans{ffileset}(1) = cfg_dep(sprintf('Named File Selector: Functional(%i) - Files', ffileset), substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files', '{}',{ffileset}));
                    end

                    % == Batch step: Realignment (spatial detection of motion) in functional images
                    % idem for realignment, add new fileset
                    if (script_mode == 2) || (script_mode == 2.5)
                        realignstepidx = 5;
                    else
                        realignstepidx = 4;
                    end % endif
                    if ~realignunwarp
                        matlabbatchall{matlabbatchall_counter}{realignstepidx}.spm.spatial.realign.estwrite.data{ffileset}(1) = cfg_dep(sprintf('Slice Timing: Slice Timing Corr. Images (Sess %i)', ffileset), substruct('.','val', '{}',{slicetimestepidx}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{ffileset}, '.','files'));
                    else
                        matlabbatchall{matlabbatchall_counter}{realignstepidx}.spm.spatial.realignunwarp.data(ffileset).scans(1) = cfg_dep(sprintf('Slice Timing: Slice Timing Corr. Images (Sess %i)', ffileset), substruct('.','val', '{}',{slicetimestepidx}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{ffileset}, '.','files'));
                        matlabbatchall{matlabbatchall_counter}{realignstepidx}.spm.spatial.realignunwarp.data(ffileset).pmscan = '';
                    end

                    % == Batch step: Coregistration of functional images to structural
                    % idem, add fileset for functional images coregistration to structural
                    if (script_mode == 1) || (script_mode == 3)
                        coregbaseidx = 5;
                    elseif (script_mode == 0) || (script_mode == 2) || (script_mode == 2.5)
                        coregbaseidx = 6;
                    end
                    % Note: for realignment, there are 3 choices:
                    % * use Realign: Estimate & Reslice but only to generate the resliced mean image, on which we realign and coregister T1 (instead of the 1st BOLD image), but then the BOLD images are realigned by modifying the voxel-to-world header infos and not reslicing (no interpolation). So it's very similar to just using Realign: Estimate module, but the difference being that we here realign on mean image instead of first.
                    % * use Realign & Unwarp
                    % * use Realign: Estimate & Reslice with all options, reslicing all images. Advantage is that we can use masking, which will zero regions that are too much affected by motion, and they are perfectly realigned to the mean BOLD image. Cons are that we interpolate all BOLD images!
                    % We chose the first option (but this may change) by default, or third if you enable realignunwarp.
                    if ~realignunwarp
                        matlabbatchall{matlabbatchall_counter}{coregbaseidx}.spm.spatial.coreg.estimate.other(ffileset) = cfg_dep(sprintf('Realign: Estimate & Reslice: Realigned Images (Sess %i)', ffileset), substruct('.','val', '{}',{realignstepidx}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','sess', '()',{ffileset}, '.','cfiles')); % cfiles = realigned images, rfiles = resliced images
                    else
                        matlabbatchall{matlabbatchall_counter}{coregbaseidx}.spm.spatial.coreg.estimate.other(ffileset) = cfg_dep(sprintf('Realign & Unwarp: Unwarped Images (Sess %i)', ffileset), substruct('.','val', '{}',{realignstepidx}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','sess', '()',{ffileset}, '.','uwrfiles')); % uwrfiles = unwarped images
                    end
                end %end if sharedmri_sess || sharedmri_mod

                % Saving temporary batch (allow to introspect later on in case of issues)
                save_batch(fullfile(root_pth, 'JOBS'), matlabbatchall{matlabbatchall_counter}, 'preproc', script_mode, data(isub).name, isess, imodal);
            end %end for modalities
        end %end for sessions
    end % end for subjects
end % end for conditions

%%%%%%%%%%%%%% RUN PREPROCESSING JOBS
if ~skip_preprocessing
    run_jobs(matlabbatchall, parallel_processing && sharedmri_all, matlabbatchall_infos, path);
end

%%%%%%%%%%%%%% POST-PROCESSING (smoothing, ART composite motion outliers scrubbing)
fprintf(1, '\n\n-------------------------\n=== POST-PROCESSING STEPS (RESIZE, HRF DECONVOLUTION, SMOOTHING, ART) ===\n\n');
addprefix = ''; % prefix to prepend to the preprocessed files depending on the post-processing steps we use - this is more maintainable to change it at the end of each module than to make a function with all cases
if realignunwarp
    addprefix = strcat('u', addprefix);
end

if resizeto3
    fprintf(1, '\n\n-------------------------\n=== RESIZING FUNCTIONAL IMAGES TO 3x3x3 ===\n\n');
    spm_jobman('initcfg'); % init the jobman
    for c = 1:length(conditions)
        % Get the data structure for all subjects for this condition
        data = get_data(fullfile(root_pth, conditions{c}), subjects{c}, func_dir_regex);
        parfor isub = 1:size(data, 2)
            for isess = 1:length(data(isub).sessions)
                fsess = data(isub).sessions{isess};
                for imodal = 1:length(fsess.modalities) % loop over all modalities
                fprintf(1, '---- PROCESSING CONDITION %s SUBJECT %i (%s) SESSION %s MODALITY %s ----\n', conditions{c}, isub, data(isub).name, data(isub).sessions{isess}.id, fsess.modalities{imodal});

                    % =====================================================================
                    % Resize the warped images to get a voxel size of 3x3x3
                    % =====================================================================
                    prepfdata = get_prepfdata(data, isub, isess, imodal, script_mode, addprefix);
                    % Detect if 4D, we need to expand
                    prepfdata_nbframes = spm_select_get_nbframes(prepfdata(1,:));
                    if prepfdata_nbframes > 1
                        prepfdata = expand_4d_vols(prepfdata);
                    end
                    fclose('all');
                    resize_img(prepfdata,[3 3 3],nan(2,3));
                    % =====================================================================
                end %end for modalities
            end %end for sessions
        end % end for subjects
    end % end for conditions
    addprefix = strcat('r', addprefix);
end

if enable_rshrf
    % RSHRF uses its own parallelization, so we need to do it separately (because we cannot use a parfor loop since it would nest the RSHRF parfor loop! Which is not deactivable at the time!)
    fprintf(1, '\n\n-------------------------\n=== HEMODYNAMIC RESPONSE FUNCTION USING RSHRF TOOLBOX ===\n\n');
    spm_jobman('initcfg'); % init the jobman
    for c = 1:length(conditions)
        % Get the data structure for all subjects for this condition
        data = get_data(fullfile(root_pth, conditions{c}), subjects{c}, func_dir_regex);
        for isub = 1:size(data, 2)
            for isess = 1:length(data(isub).sessions)
                fsess = data(isub).sessions{isess};
                for imodal = 1:length(fsess.modalities) % loop over all modalities
                    fprintf(1, '---- PROCESSING CONDITION %s SUBJECT %i (%s) SESSION %s MODALITY %s ----\n', conditions{c}, isub, data(isub).name, data(isub).sessions{isess}.id, fsess.modalities{imodal});

                    % Prepare the parameters
                    if TR > 0
                        TR_sess = TR;
                    else
                        TR_sess = slice_order_auto{c}{isub}{isess}{imodal}.TR;
                    end
                    % Get the data
                    prepfdata = get_prepfdata(data, isub, isess, imodal, script_mode, addprefix);
                    % Detect if 4D, we need to expand
                    prepfdata_nbframes = spm_select_get_nbframes(prepfdata(1,:));
                    if prepfdata_nbframes > 1
                        prepfdata = expand_4d_vols(prepfdata);
                    end

                    matlabbatch = [];
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.images = cellstr(prepfdata);
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.HRFE.hrfm = 1;
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.HRFE.TR = TR_sess;
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.HRFE.hrflen = 32;
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.HRFE.thr = 1;
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.HRFE.mdelay = [4 8];
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.HRFE.cvi = 0; % Serial Correlation Auto Regression modelling - if enabled (even just value 1), it makes the step "Deconvolving HRF" a lot longer
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.HRFE.fmri_t = 1; % Microtime Resolution : Do NOT increase, else it will take an ENORMOUS amount of time (this will basically multiply the total time taken per session!)
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.HRFE.fmri_t0 = 1;
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.Denoising.generic = {};
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.Denoising.bands = {[0.008 0.09]}; % use the same bandpass filtering as default in CONN
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.Denoising.Detrend = 0;
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.Denoising.Despiking = 0;
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.rmoutlier = 0;
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.mask = {fullfile(spm('Dir'),'tpm','mask_ICV.nii')}; % IMPORTANT: use a mask to avoid too long calculations (which can take days instead of seconds/minutes normally! See https://github.com/compneuro-da/rsHRF/issues/51)
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.outdir = {''};
                    matlabbatch{1}.spm.tools.HRF.vox_rsHRF.prefix = 'deconv_';

                    % Saving temporary batch (allow to introspect later on in case of issues)
                    save_batch(fullfile(root_pth, 'JOBS'), matlabbatch, 'rshrf', script_mode, data(isub).name, isess, imodal);

                    spm_jobman('run', matlabbatch);
                end %end for modalities
            end %end for sessions
        end % end for subjects
    end % end for conditions
    addprefix = strcat('deconv_', addprefix);
end

% We prepare other post-processing jobs separately so we can parallelize them
fprintf('\n------------\n=== PREPARING POST-PROCESSING JOBS (SMOOTHING, ART) ===\n\n');
smoothingbatchall = {};
artbatchall = {};
matlabbatchall_infos = {};
matlabbatchall_counter = 0;
for c = 1:length(conditions)
    % Get the data structure for all subjects for this condition
    data = get_data(fullfile(root_pth, conditions{c}), subjects{c}, func_dir_regex);
    for isub = 1:size(data, 2)
        for isess = 1:length(data(isub).sessions)
            fsess = data(isub).sessions{isess};
            for imodal = 1:length(fsess.modalities) % loop over all modalities
                fprintf(1, '---- PREPARING CONDITION %s SUBJECT %i (%s) SESSION %s MODALITY %s ----\n', conditions{c}, isub, data(isub).name, data(isub).sessions{isess}.id, fsess.modalities{imodal});
                matlabbatchall_counter = matlabbatchall_counter + 1;
                matlabbatchall_infos{matlabbatchall_counter} = sprintf('CONDITION %s SUBJECT %i (%s) SESSION %s MODALITY %s', conditions{c}, isub, data(isub).name, data(isub).sessions{isess}.id, fsess.modalities{imodal}); % store the infos in the batch for later introspection

                %SMOOTHING (for CAT12/VBM8 as it's not possible to do it in the batch, and for SPM12 it's not possible if we do RSHRF deconvolution so we do it after in a separate batch in any case, it's simpler)
                fprintf(1, 'Smoothing functional to %i...\n', smoothingkernel); % use fprint(1, 'text') to enforce printing even during the parallel processing
                %clear matlabbatch; % can't clear in parfor
                smoothingbatchall{matlabbatchall_counter} = [];

                % Get the data
                prepfdata = get_prepfdata(data, isub, isess, imodal, script_mode, addprefix);
                % Detect if 4D, we need to expand
                prepfdata_nbframes = spm_select_get_nbframes(prepfdata(1,:));
                if prepfdata_nbframes > 1
                    prepfdata = expand_4d_vols(prepfdata);
                end
                fprintf(1,'BUILDING SPATIAL JOB : SMOOTH\n')
                smoothingbatchall{matlabbatchall_counter}{1}.spm.spatial.smooth.data = cellstr(prepfdata);
                smoothingbatchall{matlabbatchall_counter}{1}.spm.spatial.smooth.fwhm = [smoothingkernel smoothingkernel smoothingkernel];
                smoothingbatchall{matlabbatchall_counter}{1}.spm.spatial.smooth.dtype = 0;
                smoothingbatchall{matlabbatchall_counter}{1}.spm.spatial.smooth.im = 0;
                smoothingbatchall{matlabbatchall_counter}{1}.spm.spatial.smooth.prefix = ['s' int2str(smoothingkernel)];
                % Saving temporary batch (allow to introspect later on in case of issues)
                save_batch(fullfile(root_pth, 'JOBS'), smoothingbatchall{matlabbatchall_counter}, 'smoothing', script_mode, data(isub).name, isess, imodal);
                % -------------------------------------------------------------

                %ART TOOLBOX FOR MOTION ARTIFACT REMOVAL
                if strcmp(motionRemovalTool,'art')
                    fprintf(1, 'ART composite motion outliers scrubbing...\n');
                    %clear matlabbatch; % no clear in parfor
                    artbatchall{matlabbatchall_counter} = [];
                    datapath = fullfile(fsess.dir, fsess.modalities{imodal});
                    if art_before_smoothing
                        dataMotion = get_prepfdata(data, isub, isess, imodal, script_mode, addprefix);
                    else
                        dataMotion = get_prepfdata(data, isub, isess, imodal, script_mode, strcat(['s' int2str(smoothingkernel)], addprefix));
                    end

                    % Detect if 4D, we need to expand
                    % WARNING: does not work, use SPM expand frames instead
                    %dataMotion_nbframes = spm_select_get_nbframes(dataMotion(1,:));
                    %if dataMotion_nbframes > 1
                    %    dataMotion = expand_4d_vols(dataMotion);
                    %end

                    dataMotion_size = size(dataMotion,1);

                    % Make sure that SPM.mat does not exists, else a question
                    % will be asked to overwrite but in a parfor loop nothing
                    % will be shown and calculation will be stuck in an
                    % infinite loop
                    if exist(fullfile(datapath, 'SPM.mat'), 'file')
                        delete(fullfile(datapath, 'SPM.mat'));
                    elseif exist(fullfile(datapath, 'spm.mat'), 'file')
                        delete(fullfile(datapath, 'spm.mat'));
                    end

                    artbatchall{matlabbatchall_counter}{1}.cfg_basicio.cfg_named_file.name = 'smoothed coreg func';
                    artbatchall{matlabbatchall_counter}{1}.cfg_basicio.cfg_named_file.files = {cellstr(dataMotion)}';
                    
                    artbatchall{matlabbatchall_counter}{2}.spm.util.exp_frames.files(1) = cfg_dep;
                    artbatchall{matlabbatchall_counter}{2}.spm.util.exp_frames.files(1).tname = 'NIfTI file(s)';
                    artbatchall{matlabbatchall_counter}{2}.spm.util.exp_frames.files(1).tgt_spec{1}(1).name = 'class';
                    artbatchall{matlabbatchall_counter}{2}.spm.util.exp_frames.files(1).tgt_spec{1}(1).value = 'cfg_files';
                    artbatchall{matlabbatchall_counter}{2}.spm.util.exp_frames.files(1).tgt_spec{1}(2).name = 'strtype';
                    artbatchall{matlabbatchall_counter}{2}.spm.util.exp_frames.files(1).tgt_spec{1}(2).value = 'e';
                    artbatchall{matlabbatchall_counter}{2}.spm.util.exp_frames.files(1).sname = 'Named File Selector: smoothed coreg func(1) - Files';
                    artbatchall{matlabbatchall_counter}{2}.spm.util.exp_frames.files(1).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1});
                    artbatchall{matlabbatchall_counter}{2}.spm.util.exp_frames.files(1).src_output = substruct('.','files', '{}',{1});
                    artbatchall{matlabbatchall_counter}{2}.spm.util.exp_frames.frames = Inf;
                    
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.dir = {datapath};
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.timing.units = 'secs';
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.timing.RT = TR;
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.timing.fmri_t = 16;
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.timing.fmri_t0 = 1;
                    %%
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.scans(1) = cfg_dep;
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.scans(1).tname = 'Scans';
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.scans(1).tgt_spec{1}(1).name = 'filter';
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.scans(1).tgt_spec{1}(1).value = 'image';
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.scans(1).tgt_spec{1}(2).name = 'strtype';
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.scans(1).tgt_spec{1}(2).value = 'e';
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.scans(1).sname = 'Expand image frames: Expanded filename list.';
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.scans(1).src_exbranch = substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1});
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.scans(1).src_output = substruct('.','files');
                    %
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.cond.name = 'cond1';
                    %%
                    fprintf('Size of dataMotion: ');
                    disp(size(dataMotion));
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.cond.onset = [1:dataMotion_size];
                    %%
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.cond.duration = 1;
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.cond.tmod = 0;
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.cond.pmod = struct('name', {}, 'param', {}, 'poly', {});
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.multi = {''};
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.regress = struct('name', {}, 'val', {});
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.multi_reg = {''};
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.sess.hpf = 128;
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.volt = 1;
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.global = 'None';
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.mask = {''};
                    artbatchall{matlabbatchall_counter}{3}.spm.stats.fmri_spec.cvi = 'AR(1)';

                    % Saving temporary batch (allow to introspect later on in case of issues)
                    save_batch(fullfile(root_pth, 'JOBS'), artbatchall{matlabbatchall_counter}, 'spmgenart', script_mode, data(isub).name, isess, imodal);

                    %spm('defaults', 'FMRI');
                    %fclose('all');
                    %spm_jobman('serial',artbatchall{matlabbatchall_counter}); %serial and remove spm defaults
                    %fclose('all');
                    %art_batch(fullfile(datapath, 'SPM.mat'));
                end %end if
                %close all; % close all opened windows, because art toolbox is opening a new one everytime
            end % end for modalities
        end % end for sessions
    end % end for subjects
end % end for conditions

%%%%%%%%%%%%%% RUN POSTPROCESSING JOBS
fprintf(1, '\n----------------\n=== RUN SMOOTHING JOBS ===\n\n');
run_jobs(smoothingbatchall, parallel_processing, matlabbatchall_infos, path);
fprintf(1, '\n----------------\n=== RUN SPM.MAT GENERATION (FOR ART) ===\n\n');
run_jobs(artbatchall, parallel_processing, matlabbatchall_infos, path);

% ART must be done separately, it's not through SPM batch system
if strcmp(motionRemovalTool,'art')
    fprintf(1, '\n--------------\n=== ART COMPOSITE MOTION OUTLIERS SCRUBBING ===\n\n');
    for c = 1:length(conditions)
        % Get the data structure for all subjects for this condition
        data = get_data(fullfile(root_pth, conditions{c}), subjects{c}, func_dir_regex);
        for isub = 1:size(data, 2) % IMPORTANT: do NOT use parfor nor any parallelization here: art_batch() always create a temporary config file in the current folder, if you do parallel processing then there will be a conflict! (processing will run but in fact only the latest art_batch() call will run)
            for isess = 1:length(data(isub).sessions)
                fsess = data(isub).sessions{isess};
                for imodal = 1:length(fsess.modalities) % loop over all modalities
                    fprintf(1, '---- PROCESSING CONDITION %s SUBJECT %i (%s) SESSION %s MODALITY %s ----\n', conditions{c}, isub, data(isub).name, data(isub).sessions{isess}.id, fsess.modalities{imodal});
                    datapath = fullfile(fsess.dir, fsess.modalities{imodal});
                    art_batch(fullfile(datapath, 'SPM.mat'));
                    % close all opened windows, because art toolbox is opening a new one everytime
                    fclose all;
                    close all;
                end %end for modalities
            end % end for sessions
        end % end for subjects
    end % end for conditions
end % endif

toc % show the time it took to compute everything
fprintf('All jobs done! Restoring path and exiting...\n');
path(bakpath); % restore the path to the previous state
diary off;
end % end script

% =========================================================================
%                              Functions
% =========================================================================

function [matched_dirs] = get_subdirs_regex(dirpath, regex)
    % List subdirectories matching a regular expression
    % matched_dirs = get_subdirs_regex(dirpath, regex)
    %   dirpath: the path to the directory to search in
    %   regex: the regular expression to match the subdirectory name

    % List all subdirectories in the session directory
    subdirs = dir(dirpath);
    subdirs = subdirs([subdirs.isdir]); % Keep only directories
    subdir_names = {subdirs.name};

    % Filter subdirectories based on the user-specified regex
    matched_dirs = subdir_names(~cellfun(@isempty, regexp(subdir_names, regex)));
end

function [sdata, sharedmri_sess] = get_mri(data, isub, isess)
    % Get the structural subdirectory - first try to find a structural per session
    dirpath = fullfile(data(isub).sessions{isess}.dir, 'mprage');
    sharedmri_sess = false;
    if ~exist(dirpath, 'dir')
        % If there is no structural for this session, try to find a shared structural for all sessions (in the directory above)
        dirpath = fullfile(data(isub).dir, 'mprage');
        sharedmri_sess = true;
        if ~exist(dirpath, 'dir')
            error('Error: No structural mprage directory for subject %s.', data(isub).name);
        end
    end
    % Select the structural files
    [sdata]=spm_select('FPList',dirpath,strcat('^','.+\.(img|nii)$'));
    %sdata = char(regex_files(dirpath, strcat('^','.+\.(img|nii)$')));
    if isempty(sdata) % check if any file is in this folder
        error('No file detected in folder %s\nPlease check this folder contains neuroimage files!', dirpath);
    end
end

function [fdata] = get_fdata(data, isub, isess, imodal)
    % Get the functional subdirectory
    fsess = data(isub).sessions{isess};
    dirpath = fullfile(fsess.dir, fsess.modalities{imodal});
    if ~exist(dirpath, 'dir')
        error('Error: No functional rest directory for subject %s session %s modality %s.', data(isub).name, data(isub).sessions{isess}.id, fsess.modalities{imodal});
    end
    % Get the functional files
    [fdata]=spm_select('FPList',dirpath,strcat('^','.+\.(img|nii)$'));
    %fdata = char(regex_files(dirpath,strcat('^','.+\.(img|nii)$')));
    if isempty(fdata) % check if any file is in this folder
        error('No file detected in folder %s\nPlease check this folder contains neuroimage files!', dirpath);
    end
end

function [prepfdata] = get_prepfdata(data, isub, isess, imodal, script_mode, addprefix)
    if ~exist('addprefix', 'var')
        addprefix = '';
    end
    % Get the functional subdirectory
    fsess = data(isub).sessions{isess};
    dirpath = fullfile(fsess.dir, fsess.modalities{imodal});
    % Get the functional files
    prefix = 'wa'; % wra if using resliced images from Realign & Reslice module in Coregistration
    [prepfdata] = spm_select('FPList',dirpath,strcat('^',prefix,'.+\.(img|nii)$'));
    %prepfdata = char(regex_files(dirpath,strcat('^',prefix,'.+\.(img|nii)$')));
    if isempty(prepfdata) % check if any file is in this folder
        error('No file detected in folder %s\nPlease check this folder contains neuroimage files!', dirpath);
    end
    % Add the prefix, we can't do it in the spm_select call because the
    % files might not exist at the time, so we artificially rebuild the
    % path
    if ~isempty(addprefix)
        prepfdata2 = [];
        for i = 1:size(prepfdata, 1)
            [dir, fname, fext] = fileparts(prepfdata(i,:));
            prepfdata2(i,:) = fullfile(dir,[addprefix fname fext]);
        end
        % Convert to a char array
        prepfdata = char(prepfdata2);
    end
end

function dirNames = get_dirnames(filepath)
    % Get a list of all files and folders in this folder.
    files = dir(filepath);
    % Extract only those that are directories.
    subFolders = files([files.isdir]);
    dirNames = {subFolders.name};
    dirNames = dirNames(3:end); % remove '.' and '..'
end

function path = get_template(filename)
    % Templates are expected to be placed inside the same folder as this script.
    % This function will return the full path to the templates.
    curscript = mfilename('fullpath');
    curdir = fileparts(curscript); % get the parent directory of the current script
    path = strcat(curdir, '/', filename); % append the template filename/subdirectory path
end

% =========================================================================

function [data] = get_data(root_pth, subjects, func_dir_regex)
data = struct( ...
'DIR',[root_pth], ...
'name', [], ...
'dir',[], ...
'sessions',[]);
    for isubj = 1:size(subjects.names, 2)
        data(isubj).name = subjects.names{isubj};
        data(isubj).dir = fullfile(root_pth, subjects.names{isubj},'data');
        % Get the list of essions for this subject
        sessions_list = get_dirnames(data(isubj).dir);
        for isess = 1:length(sessions_list)
            % Loop through all sessions folders, except mprage (if shared across sessions, it's placed at the same level)
            if ~strcmpi(sessions_list(isess), 'mprage')
                % Append a struct to the sessions list for this subject
                data(isubj).sessions{end+1} = struct( ...
                                        'id',[], ...
                                        'dir',[], ...
                                        'funct',[], ...
                                        'struct',[]);
                % And fill session's infos
                data(isubj).sessions{end}.id = sessions_list{isess};
                data(isubj).sessions{end}.dir = fullfile(data(isubj).dir, sessions_list{isess});
                % Get the list of functional/modalities directories
                data(isubj).sessions{end}.modalities = get_subdirs_regex(data(isubj).sessions{end}.dir, func_dir_regex);
            end
        end
    end
end

function n = spm_select_get_nbframes(file)
% spm_select_get_nbframes(file) from SPM12 spm_select.m (copied here to be compatible with SPM8)
    N   = nifti(file);
    dim = [N.dat.dim 1 1 1 1 1];
    n   = dim(4);
    fclose('all'); % don't forget to close, else it might get stuck! Else you will get the infamous "Cant map view of file.  It may be locked by another program."
end

function out = expand_4d_vols(files)
% expand_4d_vols(nifti)  Given a path to a 4D nifti file, count the number of volumes and generate a list of all volumes
% updated by Stephen Larroque (LRQ3000) to expand multiple files
% this is an alternative to adding to the batch after named file selector the module: SPM -> Util -> Expand image frames or matlabbatch{2}.spm.util.exp_frames. This is necessary for VBM apply deformations (but not SPM steps), else you will get error Failed 'Apply Deformations (Many images)' Error using ==> inv Too many input arguments.
    out = {}; % use a cell because we will get strings of variable lengths (so can't use char)
    for i=1:size(files,1)
        s = files(i,:);
        nb_vols = spm_select_get_nbframes(s);
        out = [ out , cellstr(strcat(repmat(s, nb_vols, 1), ',', num2str([1:nb_vols]')))' ];
    end
    % Convert the cell to a char array
    out = char(out);
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

function save_batch(jobsdir, matlabbatch, jobname, script_mode, subjname, isess, imodal)
% Save a batch as a .mat file in the specified jobsdir folder
    if ~exist(jobsdir)
        mkdir(jobsdir)
    end
    prevfolder = cd();
    cd(jobsdir);
    if ~exist('isess', 'var')  % saving batch for structural preprocessing (no session nor modality)
        save(['jobs_' jobname '_mode' num2str(script_mode) '_' subjname '_' datestr(now,30)], 'matlabbatch')
    else  % saving batch for functional preprocessing (with session and modality)
        save(['jobs_' jobname '_mode' num2str(script_mode) '_' subjname '_session' int2str(isess) '_modality' int2str(imodal) '_' datestr(now,30)], 'matlabbatch')
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
