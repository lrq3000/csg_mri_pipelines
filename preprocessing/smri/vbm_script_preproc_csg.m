function vbm_script_preproc_csg()
%
% Script for voxel based morphometric analysis of a single patient/subject, compared to a group of controls. Needs SPM8 and VBM8.
% T1 of patient in nifti format needs to be provided (no conversion is done from DICOM here).
% Can also provide a root directory with multiple subjects to process at once, this saves time if you do a multisubjects case study (where each subject is analyzed separately).
% VBM with DARTEL preprocessing will be done and also 2nd-level analysis SPM.mat of one patient/subject against a group of controls. A picture of the results using the voxel-wise thresholding of your choice can be generated for each subject.
%
% You need to have installed the following libraries prior to launching this script:
% * SPM8 + VBM8 (inside spm/toolbox folder)
% Also you need to use a fully compatible MATLAB version with SPM8. It was successfully tested on Matlab2011a and Matlab2013a, but failed on Matlab2016a (even with the latest patch on github, which should make SPM8 compatible!).
% You also need Python (and add it to the PATH! Must be callable from cmd.exe with a simple "python" command) to generate the final stitched image, but if you want to do it yourself it is not needed.
%
% STEPHEN KARL LARROQUE
% v0.5.4
% First version on: 2017-01-24 (first version of script based on batch from predecessors)
% 2017-2018
% LICENSE: MIT
%
% Inspired from a pipeline from Mohamed Ali BAHRI.
%
% TODO:
% * Nothing here!
% -------------------------------------------------------------------------
% =========================================================================
clear all;
clear classes;

% Initialization variables, PLEASE EDIT ME
rootpath_multi = 'X:\Path\To\MultipleSubjectsData'; % Set here the path to a directory of multiple groups, subjects and sessions to process multiple subjects at once. Else set to empty string to rather use rootpath_single. In this case, this should follow the same structure as the fmri preprocessing script: rootpath_multi/<Group>/<Subject>/data/<Session>/mprage/*.(nii|img)
rootpath_single = 'X:\Path\To\OneSubject\mprage\T1.nii'; % If you want to process only one subject, set here the full path to the T1 (extension: nii or img).
controlspath_greyonly = 'X:\Path\To\VBM_Controls\'; % controls images, must be generated using the same template AND grey only. If you don't have these images, run this pipeline on a set of healthy volunteers' T1 images with skip2ndlevel set to 1. Also this path is useless if skip2ndlevel is set to 1.
controlspath_greywhite = 'X:\Path\To\VBM_Controls_WhitePlusGrey\'; % controls images, grey + white, only necessary if you set skipgreypluswhite = 0. Skipped if skip2ndlevel = 1 or skipgreypluswhite = 1.
path_to_spm8 = 'C:\matlab_tools\spm8';
path_to_spm8_tissue_proba_map = 'C:\matlab_tools\spm8\toolbox\Seg\TPM.nii';
path_to_vbm8 = 'C:\matlab_tools\spm8\toolbox\vbm8';
path_to_mni_template = 'C:\matlab_tools\spm8\toolbox\vbm8\Template_1_IXI550_MNI152.nii'; % you can use the default VBM template or a custom one. But always input the 1st template out of the 6.
smoothsize = 12; % 12 for patients with damaged brains, 8 or 10 for healthy volunteers
skip1stlevel = 0; % only do 2nd-level analysis, skip preprocessing (particularly useful to continue at 2nd level directly if a bug happened or you change parameters such as significance)
skipcsfmask = 0; % do not apply a CSF exclusion mask in the results in SPM.mat
significance = 'fdr'; % 'fdr' by default, or 'unc'. Can skip1stlevel if you just change significance but already done the preprocessing once.
skipgreypluswhite = 1; % skip grey+white matters analysis? (if true, then will do only grey matter analysis, if false then will do both) - grey+white is disadvised, it was an experimental approach that was dropped due to inconsistent results
skip2ndlevel = 0; % if you only want to do VBM preprocessing but not compare against controls, set this to 1
skipresults = 0; % if you do not want to generate the result images from the 2nd level results (requires skip2ndlevel set to 0)

% --- Start of main script
fprintf(1, '\n=== VBM PREPROCESSING AND ANALYSIS ===\n');
% Temporarily restore factory path and set path to SPM and its toolboxes, this avoids conflicts when having different versions of SPM installed on the same machine
bakpath = path; % backup the current path variable
restoredefaultpath(); matlabpath(strrep(matlabpath, userpath, '')); % clean up the path
addpath(path_to_spm8); % add the path to SPM8
addpath(path_to_vbm8); % add the path to VBM8

% Start logging
% Alternative to diary: launch MATLAB with the -logfile switch
logfile = [mfilename() '_' datestr(now, 'yyyy-mm-dd_HH-MM-ss') '.txt'];
diary off;
diary(logfile);
diary on;
finishup = onCleanup(@() stopDiary(logfile)); % need to use an onCleanup function to diary off and commit content into the logfile (could also use a try/catch block)

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
            subjdir = fullfile(groupdir,subjn{sub},'Data');
            sessions = get_dirnames(subjdir);
            for s=1:length(sessions)
                structdir = fullfile(subjdir,sessions{s},'mprage');
                T1fileslist{end+1} = regex_files(structdir, ['^.+\.(img|nii)$']);
            end
        end
    end
else
    T1fileslist = {rootpath_single};
end

fprintf('Launching VBM analysis of %i T1 files.\n', length(T1fileslist));

for t=1:length(T1fileslist)
    fprintf('== VBM PREPROCESSING JOB %i/%i: %s.\n', t, length(T1fileslist), T1fileslist{t});
    % Extract parent dir and T1 filename (necessary for me function calls and to find segmented images)
    [rootpath, T1filename, T1fileext] = fileparts(T1fileslist{t});
    T1file = [T1filename, T1fileext];

    %-----------------------------------------------------------------------
    % Job configuration created by cfg_util (rev $Rev: 4252 $)
    %-----------------------------------------------------------------------

    if ~skip1stlevel
        % Manual reorient
        %fprintf(1, '\nPlease reoriient the T1 for better segmentation and coreg with controls group. Press any key when you are done.\n');
        %spm_image('init', fullfile(rootpath, T1file));
        %spm_image('display', fullfile(rootpath, T1file));
        %pause();

        spm_jobman('initcfg'); % init the jobman
        moduleid = 0;
        clear matlabbatch;
        matlabbatch = [];

        % == Segmentation of patient
        fprintf('Running 1st-level analysis (segmentation)');
        moduleid = moduleid + 1;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.data = {strcat(fullfile(rootpath, T1file), ',1')};
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.opts.tpm = {strcat(path_to_spm8_tissue_proba_map, ',1')};
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.opts.ngaus = [2 2 2 3 4 2];
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.opts.biasreg = 0.0001;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.opts.biasfwhm = 60;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.opts.affreg = 'mni';
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.opts.warpreg = 4;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.opts.samp = 1;  % MODIFIED from defaults: sampling distance = 1 is better than default 3 for patients in clinical setting, because we want to reduce approximations and information loss
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.extopts.dartelwarp.normhigh.darteltpm = {strcat(path_to_mni_template, ',1')};
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.extopts.sanlm = 2;  % sanlm 2 allow usage of multithreading to speedup the processing, but can set to 1 if issues happen (single thread)
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.extopts.mrf = 0.15;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.extopts.cleanup = 1;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.extopts.print = 1;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.GM.native = 0;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.GM.warped = 0;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.GM.modulated = 2;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.GM.dartel = 2;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.WM.native = 0;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.WM.warped = 0;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.WM.modulated = 2;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.WM.dartel = 2;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.CSF.native = 0;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.CSF.warped = 0;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.CSF.modulated = 2;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.CSF.dartel = 2;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.bias.native = 0;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.bias.warped = 1;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.bias.affine = 0;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.label.native = 0;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.label.warped = 0;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.label.dartel = 0;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.jacobian.warped = 0;
        matlabbatch{moduleid}.spm.tools.vbm8.estwrite.output.warps = [0 0];
        % Run the pipeline for current subject!
        spm_jobman('run', matlabbatch)
    end %endif

    % == do two analyses: grey matter only or grey+white matter
    for i=1:2
        fprintf('== VBM ANALYSIS JOB %i/%i: %s.\n', t, length(T1fileslist), T1fileslist{t});
        if (i == 2) && (skipgreypluswhite == 1)
            break;
        end

        % Reinit batch (necessary for 2nd analysis to work)
        spm_jobman('initcfg'); % init the jobman
        moduleid = 0;
        clear matlabbatch;
        matlabbatch = [];

        % == Get segmented images
        segimg = regex_files(rootpath, ['^m0wrp\d.+\.(img|nii)$']);

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
            matlabbatch{moduleid}.spm.spatial.smooth.data = {segimg{1}};
        end %endif
        matlabbatch{moduleid}.spm.spatial.smooth.fwhm = [smoothsize smoothsize smoothsize];
        matlabbatch{moduleid}.spm.spatial.smooth.dtype = 0;
        matlabbatch{moduleid}.spm.spatial.smooth.im = 0;
        matlabbatch{moduleid}.spm.spatial.smooth.prefix = strcat('s', int2str(smoothsize));

        % == Generate CSF exclusion mask
        moduleid = moduleid + 1;
        matlabbatch{moduleid}.spm.util.imcalc.input = segimg;
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
        jobsdir = fullfile(rootpath, 'JOBS'); % Put JOBS in the root folder (we will trim it from the conditions). fullfile(data(isub).dir(1:(dirindex(end-1))),'JOBS');

        if ~exist(jobsdir)
            mkdir(jobsdir)
        end
        prevfolder = cd();
        cd(jobsdir);
        save(['jobs_singlecase_VBMDartel_analysis' int2str(i) '_' datestr(now,30)], 'matlabbatch');
        cd(prevfolder);

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
                vbm_results(path_to_spm8, rootpath, T1file, significance, i);
                close all;
                spm('quit');

                % Call Python script to generate final image
                callPython(fullfile(prevfolder, 'vbm_gen_final_image.py'), ['"' rootpath '" "img_type' int2str(i) '_"'])
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
