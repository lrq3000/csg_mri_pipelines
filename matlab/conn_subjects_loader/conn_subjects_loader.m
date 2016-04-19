function conn_subjects_loader()
% conn_subjects_loader
% Batch load all subjects and conditions from a given directory root into CONN. This saves quite a lot of time.
% This script expects the subjects data to be already preprocessed.
% The tree structure from the root must follow the following structure:
% /root_pth/subject_id/data/(mprage|rest)/*.(img|hdr) -- Note: mprage for structural MRI, rest for fMRI
%
% by Stephen Larroque
% Created on 2016-04-11
% Tested on conn15h and conn16a
% v0.4
%

% ------ PARAMETERS HERE
TR = 2.0;
conn_file = fullfile(pwd, 'conn_project.mat');
%root_path = 'G:\Work\GigaData\Conn_test';
root_path = 'H:\Stephen\DONE\Patients-and-controls';
path_to_spm = 'G:\Work\Programs\matlab_tools\spm12';
path_to_conn = 'G:\Work\Programs\matlab_tools\conn';
% ------ END OF PARAMETERS


% Temporarily restore factory path and set path to SPM and its toolboxes, this avoids conflicts when having different versions of SPM installed on the same machine
bakpath = path; % backup the current path variable
restoredefaultpath(); matlabpath(strrep(matlabpath, userpath, '')); % clean up the path
addpath(path_to_spm); % add the path to SPM
addpath(path_to_conn); % add the path to CONN toolbox

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

% Extracting all info and files for each subject necessary to construct the CONN project
fprintf('Detect images for all subjects...\n');
data = struct('conditions', []);
data.conditions = struct('subjects', {});
subjects_total = 0;
for c=1:length(conditions)
    for s=1:length(subjects{c}.names)
        % Counting total number of subjects by the way
        subjects_total = subjects_total + 1;
        fprintf('Detect images for subject %i...\n', subjects_total);
        % Initialize the subject's struct
        sname = subjects{c}.names{s};
        spath = fullfile(root_path, conditions{c}, sname);
        data.conditions{c}.subjects{s} = struct('id', sname, ...
                                                                'dir', spath, ...
                                                                'files', struct('struct', [], 'func', [], 'roi', []) ...
                                                                );
        % Extracting structural realigned normalized images
        structpath = getimgpath(spath, 'struct');
        funcpath = getimgpath(spath, 'func_motion_corrected');
        data.conditions{c}.subjects{s}.files.struct = regex_files(structpath, '^wmr.+\.nii$');
        % Extracting functional motion artifacts corrected, realigned, smoothed images
        data.conditions{c}.subjects{s}.files.func = regex_files(funcpath, '^s8rwa.+\.img$');
        % Extracting regions of interests (we expect 3 different ROIs: 1,2,3 respectively for grey matter, white matter and CSF)
        data.conditions{c}.subjects{s}.files.roi = struct('grey', [], 'white', [], 'csf', []);
        data.conditions{c}.subjects{s}.files.roi.grey = regex_files(structpath, '^m0wrp1.+\.nii$');
        data.conditions{c}.subjects{s}.files.roi.white = regex_files(structpath, '^m0wrp2.+\.nii$');
        data.conditions{c}.subjects{s}.files.roi.csf = regex_files(structpath, '^m0wrp3.+\.nii$');
        % Covariates 1st-level
        % ART movement artifacts correction
        data.conditions{c}.subjects{s}.files.covars1.movement = regex_files(funcpath, '^art_regression_outliers_and_movement_s8rwa.+\.mat$');
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
CONN_x.Setup.isnew = 1;  % tell CONN to fill this struct with the default project structure (ie, add all the required fields)
CONN_x.Setup.done = 0;  % do not execute any task, just fill the fields
CONN_x.Setup.nsubjects = subjects_total;
CONN_x.Setup.RT = ones(1, subjects_total) * TR;
CONN_x.Setup.acquisitiontype = 1;

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
        sid = sid + 1;
        % Structural and functional images
        CONN_x.Setup.structurals{sid} = {};
        CONN_x.Setup.functionals{sid} = {};
        CONN_x.Setup.structurals{sid}{1} = data.conditions{c}.subjects{s}.files.struct;
        CONN_x.Setup.functionals{sid}{1} = char(data.conditions{c}.subjects{s}.files.func); % convert cell array to char array
        % ROI masks
        CONN_x.Setup.masks.Grey{sid} = data.conditions{c}.subjects{s}.files.roi.grey;
        CONN_x.Setup.masks.White{sid} = data.conditions{c}.subjects{s}.files.roi.white;
        CONN_x.Setup.masks.CSF{sid} = data.conditions{c}.subjects{s}.files.roi.csf;
        % Covariates 1st-level
        CONN_x.Setup.covariates.files{1}{sid}{1} = data.conditions{c}.subjects{s}.files.covars1.movement;
    end
end

% SUBJECTS GROUPS
fprintf('Loading groups...\n');
CONN_x.Setup.subjects.group_names = conditions;
CONN_x.Setup.subjects.groups = [];
for c=1:length(conditions)
    CONN_x.Setup.subjects.groups = [CONN_x.Setup.subjects.groups ones(1, length(subjects{c}.names))*c];
end

% COVARIATES LEVEL-1
CONN_x.Setup.covariates.names = {'movement'};
CONN_x.Setup.covariates.add = 0;

% ---- SAVE/LOAD INTO CONN
fprintf('-- Save/load into CONN --\n');
% EXECUTE BATCH (to convert our raw CONN_x struct into a project file - because the structure is a bit different with the final CONN_x (eg, CONN_x.Setup.structural instead of CONN_x.Setup.structurals with an 's' at the end, plus the structure inside is different)
fprintf('Save project via conn_batch (may take a few minutes)...\n');
conn_batch(CONN_x);  % save our CONN_x structure onto a project file using conn_batch() to do the conversion and fill missing fields
%save(conn_file, 'CONN_x');  % saving directly into a mat file does not work because conn_batch will reprocess CONN_x into the internal format, which is different to conn_batch API.

% LOAD/DISPLAY EXPERIMENT FILE INTO CONN GUI
fprintf('Load project into CONN GUI...\n');
% Clear up a bit of memory
clear CONN_x data;
% Launch conn gui to explore results
conn;  % launch CONN
conn('load', conn_file);  % Load the parameters
conn gui_setup; % Refresh display: need to refresh the gui to show the loaded parameters. You can also directly switch to any other panel: gui_setup, gui_results, etc.

% THE END
fprintf('Done! Press Enter to restore path and exit...\n');
input('','s');
path(bakpath); % restore the path to the previous state
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
