function conn_subjects_loader()
% conn_subjects_loader
% Batch load all subjects and conditions from a given directory root into CONN. This saves quite a lot of time.
% The script can then just show the CONN GUI and you do the rest, or automate and process everything and show you CONN GUI only when the results are available.
% You can also resume your job if there is an error or if you CTRL-C (but don't rely too much on it, data can be corrupted). Resume can also be used if you add new subjects.
% This script expects the subjects data to be already preprocessed.
% The tree structure from the root must follow the following structure:
% /root_pth/subject_id/data/(mprage|rest)/*.(img|hdr) -- Note: mprage for structural MRI, rest for fMRI
%
% Note that BATCH.Setup.preprocessing is not used here as the data is expected to be already preprocessed by your own means (SPM, Dartel/VBM/CAT, custom pipeline, etc.)
% If you need to modify this script, take a look at the conn_batch_workshop_nyudataset.m script provided with CONN, it's a very good example that inspired this script.
%
% by Stephen Larroque
% Created on 2016-04-11
% Tested on conn17a (see older versions for older conn support)
% v0.9.8
%
% Licensed under MIT LICENSE
% Copyleft 2016 Stephen Larroque
% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
%
% TODO:
% * 3rd level analysis (multi-subjects and multi-sessions): Accept third mode with both inter and intra, by setting number of sessions per subject, and root_path a vector of paths and inter_or_intra a vector of 0 and 1 (to define the mode for each dataset in root_path). Also must set TR per dataset.
% * Try to have Dynamic FC for multi-datasets run.
% * Add CSV reading to automatically input 2nd-level covariates like age or sex.
% * save an example CONN_x into .mat to show the expected structure (useful if need to debug).
% * support BIDS format
%

% ------ PARAMETERS HERE
TR = 2.0;
conn_file = fullfile(pwd, 'conn_project_patients.mat');  % where to store the temporary project file that will be used to load the subjects into CONN
root_path = '/media/coma_meth/CALIMERO/Stephen/DONE/Patientstest';
path_to_spm = '/home/coma_meth/Documents/Stephen/Programs/spm12';
path_to_conn = '/home/coma_meth/Documents/Stephen/Programs/conn';
path_to_roi_maps = '/media/coma_meth/CALIMERO/Stephen/DONE/roitest'; % Path to your ROIs maps, extracted by MarsBars or whatever software... Can be left empty if you want to setup them yourself. If filled, the folder is expected to contain one ROI per .nii file. Each filename will serve as the ROI name in CONN. This script only supports ROI for all subjects (not one ROI per subject, nor one ROI per session, but you can modify the script, these features are supported by CONN).
func_smoothed_prefix = 's8rwa'; % prefix of the smoothed motion corrected images that we need to remove to get the filename of the original, unsmoothed functional image. This is a standard good practice advised by CONN: smoothed data for voxel-level descriptions (because this increases the reliability of the resulting connectivity measures), but use if possible the non-smoothed data for ROI-level descriptions (because this decreases potential 'spillage' of the BOLD signal from nearby areas/ROIs). If empty, we will reuse the smoothed images for ROI-level descriptions.
inter_or_intra = 0; % 0 for inter subjects analysis (each condition = a different group in covariates 2nd level) - 1 for intra subject analysis (each condition = a different session, only one subjects group)
automate = 0; % if 1, automate the processing (ie, launch the whole processing without showing the GUI until the end to show the results)
resume_job = 0; % resume from where the script was last stopped (ctrl-c or error). Warning: if you here change parameters of already done steps, they wont take effect! Only parameters of not already done steps will be accounted. Note that resume can also be used to add new subjects without reprocessing old ones.
run_dynamicfc = 1; % run Dynamic Functional Connectivity analysis? BEWARE: it may fail. This script tries to setup the experiment correctly so that DFC runs, but it may still fail for no obvious reason!
% ------ END OF PARAMETERS

% Notes and warnings
fprintf('Note: data is expected to be already preprocessed\n(realignment/slicetiming/coregistration/segmentation/normalization/smoothing)\n');
fprintf('Note2: this script expects a very specific directry tree layout\nfor your images (see script header comment). If not met,\nthis may produce errors like "Index exceeds matrix dimensions."\nwhen executing conn_batch(CONN_x).\n');
fprintf('Note3: if in inter-subjects mode you get the error\n"Reference to non-existent field t. Error in spm_hrf", you have to\nedit spm_hrf.m to replace stats.fmri.t by stats.fmri.fmri_t .\n');
fprintf('Note4: Voxel-to-Voxel analysis needs at least 2 subjects per condition/group!\n');

% Temporarily restore factory path and set path to SPM and its toolboxes, this avoids conflicts when having different versions of SPM installed on the same machine
bakpath = path; % backup the current path variable
restoredefaultpath(); matlabpath(strrep(matlabpath, userpath, '')); % clean up the path
addpath(path_to_spm); % add the path to SPM
addpath(path_to_conn); % add the path to CONN toolbox

% Start logging if automating
if automate == 1
    % Alternative to diary: launch MATLAB with the -logfile switch
    logfile = [mfilename() '_' datestr(now, 'yyyy-mm-dd_HH-MM-ss') '.txt'];
    diary off;
    diary(logfile);
    diary on;
    finishup = onCleanup(@() stopDiary(logfile)); % need to use an onCleanup function to diary off and commit content into the logfile (could also use a try/catch block)
end

% START OF SCRIPT
fprintf('== Conn subjects loader ==\n');

% ------ LOADING SUBJECTS FILES
fprintf('-- Loading subjects files --\n');

% Scan the root path to extract all conditions and subjects names
fprintf('Loading conditions (subjects groups)...\n');
% Extract conditions
conditions = get_dirnames(root_path);
conditions = conditions(~strcmp(conditions, 'JOBS')); % remove JOBS from the conditions
% Extract subjects names from inside the conditions
subjects = {};
for c=1:length(conditions)
    subjects{c} = struct('names', []); % associate the subjects names for each condition
    subjn = get_dirnames(fullfile(root_path, conditions{c}));
    subjects{c}.names = subjn;
end

% Counting number of subjects
subjects_real_total = 0;
subjects_total = 0;
for c=1:length(conditions)
    subjects_real_total = subjects_real_total + length(subjects{c}.names);
end
if inter_or_intra == 0
    % If inter-subjects project: count every subjects across all conditions
    subjects_total = subjects_real_total;
elseif inter_or_intra == 1
    % If intra-subject project: count subjects of the first session, the other sessions are expected to include the same subjects
    subjects_total = length(subjects{1}.names);
end

% Extracting all info and files for each subject necessary to construct the CONN project
fprintf('Detect images for all subjects...\n');
data = struct('conditions', []);
data.conditions = struct('subjects', {});
sid = 0;
for c=1:length(conditions)
    for s=1:length(subjects{c}.names)
        sid = sid + 1;
        fprintf('Detect images for subject %i/%i...\n', sid, subjects_real_total);
        % Initialize the subject's struct
        sname = subjects{c}.names{s};
        spath = fullfile(root_path, conditions{c}, sname);
        data.conditions{c}.subjects{s} = struct('id', sname, ...
                                                                'dir', spath, ...
                                                                'files', struct('struct', [], 'func', [], 'roi', []) ...
                                                                );
        % Extracting structural realigned normalized images
        structpath = getimgpath(spath, 'struct');
        funcpath = getimgpath(spath, 'func'); % do not use the func_motion_corrected subdirectory to find smoothed func images, because we need both the smoothed motion corrected images AND the original images for CONN to work best
        funcmotpath = getimgpath(spath, 'func_motion_corrected');
        data.conditions{c}.subjects{s}.files.struct = check_exist(regex_files(structpath, '^wmr.+\.nii$'));
        % Extracting functional motion artifacts corrected, realigned, smoothed images
        data.conditions{c}.subjects{s}.files.func = check_exist(regex_files(funcpath, '^s8rwa.+\.img$'));
        % Extracting regions of interests (we expect 3 different ROIs: 1,2,3 respectively for grey matter, white matter and CSF)
        data.conditions{c}.subjects{s}.files.roi = struct('grey', [], 'white', [], 'csf', []);
        data.conditions{c}.subjects{s}.files.roi.grey = check_exist(regex_files(structpath, '^m0wrp1.+\.nii$'));
        data.conditions{c}.subjects{s}.files.roi.white = check_exist(regex_files(structpath, '^m0wrp2.+\.nii$'));
        data.conditions{c}.subjects{s}.files.roi.csf = check_exist(regex_files(structpath, '^m0wrp3.+\.nii$'));
        % Covariates 1st-level
        % ART movement artifacts correction
        data.conditions{c}.subjects{s}.files.covars1.movement = check_exist(regex_files(funcmotpath, ['^art_regression_outliers_and_movement_' func_smoothed_prefix '.+\.mat$']));
    end
end

% ROIs detection
if length(path_to_roi_maps) > 0
    fprintf('ROIs maps detection...\n');
    % Get all the roi files
    roi_maps = regex_files(path_to_roi_maps, '^.+\.(nii|img)$');  % can also provide .hdr, but if it's a multi-rois image, then it won't be detected automatically. For automatic multi-rois detection in CONN, provide the .img instead of .hdr.
    % Extract the filenames, they will serve as the roi names in CONN
    roi_names = {};
    for r=1:length(roi_maps)
        [~, n] = fileparts(roi_maps{r});
        roi_names{r} = n;
    end
end

% Sanity checks
% 1. Check that there are loaded images, else the tree structure is obviously wrong
a = data.conditions{:};
b = a.subjects{:};
if length(b.files.struct) == 0
    error('No subject found. Please check that the specified root_path follows the required tree structure.');
end
% 2. If intra-subject project, check that there is the exact same subjects across all conditions (= sessions here)
if inter_or_intra == 1
    if length(conditions) < 2
        error('Project set to be intra-subject, but there are less than 2 sessions!')
    end
    for c=2:length(conditions)
        if strcmp( char(subjects{c}.names), char(subjects{1}.names) ) == 0
            error('Project set to be intra-subject, but all sessions do not contain the same subjects (or some are missing in one session)!');
        end
    end
end


% ---- FILLING CONN PROJECT STRUCT
fprintf('-- Generating CONN project struct --\n');
fprintf('Struct initialization...\n');
clear CONN_x;
CONN_x = {};

% load the structure and modify it
%clear CONN_x;
%load(conn_file);

% SETUP
CONN_x.filename = conn_file; % Our new conn_*.mat project filename
CONN_x.Setup.isnew = 1;  % tell CONN that this is a new project we will completely programmatically define without using a SPM.mat, and thus CONN should fill this struct with the default project structure (ie, add all the required fields)
if resume_job == 1, CONN_x.Setup.isnew = 0; end;
CONN_x.Setup.done = 0;  % do not execute any task, just fill the fields
CONN_x.Setup.nsubjects = subjects_total;
CONN_x.Setup.RT = ones(1, subjects_total) * TR;
CONN_x.Setup.acquisitiontype = 1; % continuous
CONN_x.Setup.analyses=1:4; % set the type of analyses to run (basically: all)
CONN_x.Setup.voxelresolution = 1; % set voxel resolution to the default, normalized template (2 for structurals, 3 for functionals)
CONN_x.Setup.analysisunits = 1; % set BOLD signal units to percent signal change

% OTHER PARTS -> DISABLE
CONN_x.Denoising.done = 0;
CONN_x.Analysis.done = 0;
CONN_x.Results.done = 0;

% LOADING IMAGES
fprintf('Loading images...\n');
% Initializing required fields
CONN_x.Setup.structurals = {};
CONN_x.Setup.functionals = {};
CONN_x.Setup.masks.Grey = {};
CONN_x.Setup.masks.White = {};
CONN_x.Setup.masks.CSF = {};
% Main filling loop
sid = 0; % subject counter, because we need to add them all in a row in CONN, we assign conditions later
for c=1:length(conditions)
    for s=1:length(subjects{c}.names)
        % Set subject id and session id depending on if we do inter-subjects project or intra-subject
        if inter_or_intra == 0
            % Inter-subjects project: each subject gets its own id, and they will be separated in different groups in covars 2nd-level
            sid = sid + 1;
            sessid = 1;  % and we always use one session only
        elseif inter_or_intra == 1
            % Intra-subject project: the different conditions are just various sessions for the same subjects, so we reuse the subject's id and just make a new session
            sid = s;
            sessid = c;
        end

        % Structural and functional images
        if length(CONN_x.Setup.structurals) < sid
            CONN_x.Setup.structurals{sid} = {};
            CONN_x.Setup.functionals{sid} = {};
        end
        CONN_x.Setup.structurals{sid}{sessid} = data.conditions{c}.subjects{s}.files.struct;
        CONN_x.Setup.functionals{sid}{sessid} = char(data.conditions{c}.subjects{s}.files.func); % convert cell array to char array
        % ROI masks
        CONN_x.Setup.masks.Grey{sid}{sessid} = data.conditions{c}.subjects{s}.files.roi.grey;
        CONN_x.Setup.masks.White{sid}{sessid} = data.conditions{c}.subjects{s}.files.roi.white;
        CONN_x.Setup.masks.CSF{sid}{sessid} = data.conditions{c}.subjects{s}.files.roi.csf;
        % Covariates 1st-level
        CONN_x.Setup.covariates.files{1}{sid}{sessid} = data.conditions{c}.subjects{s}.files.covars1.movement;
    end
end

% SUBJECTS GROUPS
if inter_or_intra == 0
    fprintf('Loading groups...\n');
    CONN_x.Setup.subjects.group_names = conditions;
    CONN_x.Setup.subjects.groups = [];
    for c=1:length(conditions)
        CONN_x.Setup.subjects.groups = [CONN_x.Setup.subjects.groups ones(1, length(subjects{c}.names))*c];
    end
    CONN_x.Setup.subjects.effect_names = {'AllSubjects'};
    CONN_x.Setup.subjects.effects{1} = ones(1, subjects_total);
elseif inter_or_intra == 1
    CONN_x.Setup.subjects.group_names = {'AllSubjects'};
    CONN_x.Setup.subjects.groups = ones(1, subjects_total);
end

% CONDITIONS DURATION
if inter_or_intra == 0
    % Inter-subjects mode: create only one condition and one session, all files are considered to belong to different subjects and different conditions
    nconditions = 1;
    nsessions = 1;
    CONN_x.Setup.conditions.names={'rest'};
    for ncond=1:nconditions,for nsub=1:subjects_total,for nses=1:nsessions
        CONN_x.Setup.conditions.onsets{ncond}{nsub}{nses}=0;
        CONN_x.Setup.conditions.durations{ncond}{nsub}{nses}=inf;
    end;end;end     % rest condition (all sessions)
elseif inter_or_intra == 1
    % Intra-subject mode: the different conditions are considered to be multiple sessions from same set of subjects. In CONN, we will describe that by adding one condition and one session per folder condition, and we will link the session to the condition (eg, condition rest1 will have onset and duration set only for session1, empty for session2, and on the opposite condition rest2 will have onset and duration set for session2 but not session1).
    nconditions = length(conditions);
    nsessions = length(conditions);
    CONN_x.Setup.conditions.names = conditions;
    for ncond=1:nconditions,for nsub=1:subjects_total,for nses=1:nsessions
        % Assign if session == condition, else set to empty
        if ncond == nses
            CONN_x.Setup.conditions.onsets{ncond}{nsub}{nses} = 0;
            CONN_x.Setup.conditions.durations{ncond}{nsub}{nses} = inf;
        else
            CONN_x.Setup.conditions.onsets{ncond}{nsub}{nses} = [];
            CONN_x.Setup.conditions.durations{ncond}{nsub}{nses} = [];
        end
    end;end;end     % rest condition (all sessions)
    % Add a special condition that will include absolutely all subjects, this allows Dynamic Functional Connectivity to work
    CONN_x.Setup.conditions.names = [CONN_x.Setup.conditions.names {'AllSessions'}];
    for ncond=nconditions+1,for nsub=1:subjects_total,for nses=1:nsessions
        CONN_x.Setup.conditions.onsets{ncond}{nsub}{nses}=0;
        CONN_x.Setup.conditions.durations{ncond}{nsub}{nses}=inf;
    end;end;end     % rest condition (all sessions)
end

% COVARIATES LEVEL-1: intra-subject covariates: artifacts we will regress (remove)
CONN_x.Setup.covariates.names = {'movement'};
CONN_x.Setup.covariates.add = 0;

% ROIs maps
if length(path_to_roi_maps) > 0
    %start_rois = length(CONN_x.Setup.rois.names);
    CONN_x.Setup.rois.add = 0; % Add over the existing ROIs
    for r=1:length(roi_names)
        %s = r+start_rois
        CONN_x.Setup.rois.names{r} = roi_names{r};
        CONN_x.Setup.rois.files{r} = roi_maps{r};
    end
end

% ROI-level BOLD timeseries extraction: reuse smoothed functional images or use raw images?
% See for more info: http://www.nitrc.org/forum/forum.php?thread_id=4515&forum_id=1144
if length(func_smoothed_prefix) == 0
    CONN_x.Setup.roifunctionals.roiextract = 1;
else
    CONN_x.Setup.roifunctionals.roiextract = 3;
    CONN_x.Setup.roifunctionals.roiextract_rule = {};
    CONN_x.Setup.roifunctionals.roiextract_rule{1} = 1; % work on filename, not on absolute path
    CONN_x.Setup.roifunctionals.roiextract_rule{2} = ['^' func_smoothed_prefix];
    CONN_x.Setup.roifunctionals.roiextract_rule{3} = '';
end

% DENOISING
%CONN_x.Denoising.confounds.names = [{'Grey Matter', 'White Matter', 'CSF'}, CONN_x.Setup.rois.names]; % use GM/WM/CSF + all rois as denoising confounds effects

% ANALYSIS
CONN_x.Analysis.type = 3; % do all analyses at once, we will explore and choose them later
% ROI-to-ROI and Seed-to-Voxel
CONN_x.Analysis.sources = CONN_x.Setup.rois.names; % Use all ROIs
% Voxel-to-voxel
% Note that conn_batch cannot do all 1st-level analyses, if you specify Analysis.measures then it will compute only Voxel-to-Voxel analysis, else only ROI-to-ROI/Seed-to-Voxel analysis (but we workaround that by calling conn_process directly for the other analyses, see below)
CONN_x.vvAnalysis.measures = conn_v2v('measurenames'); % Load all available kinds of measures

% Automate processing?
if automate
    CONN_x.Setup.done = 1;
    CONN_x.Denoising.done = 1;
    CONN_x.Analysis.done = 1;
    CONN_x.vvAnalysis.done = 1;
    if run_dynamicfc; CONN_x.dynAnalysis.done = 1; else; CONN_x.dynAnalysis.done = 0; end;
    CONN_x.Results.done = 1;
    CONN_x.vvResults.done = 1;
end

% Resume?
if resume_job
    CONN_x.Setup.overwrite = 0;
    CONN_x.Denoising.overwrite = 0;
    CONN_x.Analysis.overwrite = 0;
    CONN_x.vvAnalysis.overwrite = 0;
    CONN_x.dynAnalysis.overwrite = 0;
    % Always recompute the 2nd level results based on first level
    CONN_x.Results.overwrite = 1;
    CONN_x.vvResults.overwrite = 1;
end

% ---- SAVE/LOAD INTO CONN
if automate == 0
    fprintf('-- Save/load into CONN --\n');
    fprintf('Save project via conn_batch (may take a few minutes)...\n');
elseif automate == 1
    fprintf('-- Save into CONN and run batch --\n');
    fprintf('Save and run project via conn_batch (may take a while for the whole analysis to finish)...\n');
end
% EXECUTE BATCH (to convert our raw CONN_x struct into a project file - because the structure is a bit different with the final CONN_x (eg, CONN_x.Setup.structural instead of CONN_x.Setup.structurals with an 's' at the end, plus the structure inside is different)
% Save our CONN_x structure onto a project file using conn_batch() to do the conversion and fill missing fields
% If automate = 1, we also run the experiments, so the project file will also contain the results
conn_batch(CONN_x); % if you get an error, your CONN_x struct is malformed (maybe some files are missing, or project type is incorrect?)
%save(conn_file, 'CONN_x');  % DEPRECATED: saving directly into a mat file does not work because conn_batch will reprocess CONN_x into the internal format, which is different to conn_batch API.

% PROCESS OTHER 1ST-LEVEL ANALYSES
% conn_batch can only do one type of analysis at a time. Here we workaround by directly calling conn_process for each missed analysis.
if automate
    % First: load the CONN_x batch struct, conn_process will access it as a global
    clear CONN_x;
    load(conn_file); % will load var CONN_x into workspace
    global CONN_x;
    CONN_x.gui.overwrite = 'Yes' % avoid CONN GUI asking us what to do, overwrite files directly
    % Compute Seed-to-Voxel 1st-level analysis
    conn_process('analyses_seed');
    % Compute ROI-to-ROI 1st-level analysis
    conn_process('analyses_seedandroi');
    % Compute Dynamic FC (functional connectivity) 1st-level analysis
    % Trick to compute DFC is to use the backprojection technic: you need to create a condition and a 2nd-level group that includes all subjects across all conditions/sessions.
    if run_dynamicfc == 1, conn_process('analyses_dyn'); end;
    % Save the new struct and results!
    if isfield(CONN_x,'filename'), conn save; end;
end

% LOAD/DISPLAY EXPERIMENT FILE INTO CONN GUI
fprintf('Load project into CONN GUI...\n');
% Clear up a bit of memory
clear CONN_x data;
% Launch conn gui to explore results
conn;  % launch CONN
conn('load', conn_file);  % Load the parameters/results
if automate == 0
    conn gui_setup; % Refresh display: need to refresh the gui to show the loaded parameters. You can also directly switch to any other panel: gui_setup, gui_results, etc.
elseif automate == 1
    conn gui_results; % Refresh display and switch directly to the results tab.
end

% THE END
fprintf('Done!\n');
fprintf('Tip: when you hover the mouse cursor over an image, a title with the file path appears. You can hover the cursor on it to get the full path, or double click on it to show the file on the right panel.\n');
fprintf('Press Enter to restore path and exit...\n');
input('','s');
path(bakpath); % restore the path to the previous state
if automate == 1, diary off; end;
end  % endfunction

% =========================================================================
%                              Auxiliary Functions
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

function fpath = getimgpath(dirpath, imtype)
% fpath = get_images_path(dirpath, imtype)
% Generate directory paths according to Cyclotron standard tree layout
% This eases access to the various images types

    fpath = '';
    switch imtype
        case 'struct'  % anatomical images (T1 aka structural) folder
            fpath = fullfile(dirpath, 'data', 'mprage');
        case 'func' % functional images (T2) folder
            fpath = fullfile(dirpath, 'data', 'rest');
        case 'func_motion_corrected'
            fpath = fullfile(dirpath, 'data', 'rest', 'restMotionCorrected');
    end
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
    if class(filelist) == 'cell'
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
