function ImCalc_job_tennis_followuppost()

root_path = 'G:\Topreproc\Cosmo2019Tasks\workingFiles_cosmo_task_fMRI_autopreproc';

% ------ LOADING SUBJECTS FILES
fprintf('-- Loading subjects files --\n');

% Scan the root path to extract all groups and subjects names
fprintf('Loading subjects groups...\n');
% Extract groups
groups = get_dirnames(root_path);
groups = groups(~strcmp(groups, 'JOBS')); % remove JOBS from the groups
% Extract subjects names from inside the groups
subjects = {};
for g=1:length(groups)
    subjects{g} = struct('names', []); % associate the subjects names for each group
    subjn = get_dirnames(fullfile(root_path, groups{g}));
    subjects{g}.names = subjn;
end

% Counting number of subjects
subjects_real_total = 0;
subjects_total = 0;
for g=1:length(groups)
    subjects_real_total = subjects_real_total + length(subjects{g}.names);
end
% count every subjects across all groups
subjects_total = subjects_real_total;

% Extracting all info and files for each subject necessary to construct the CONN project
% We first construct our own "data" struct with our own format, this is easier to manage
% Then later, we fill the CONN project using the info from this "data" struct
fprintf('Detect images for all subjects...\n');
data = struct('groups', []);
data.groups = struct('id', {}, 'subjects', {});
sid = 0;
for g=1:length(groups)
    data.groups{g}.id = groups{g};
    for s=1:length(subjects{g}.names)
        sid = sid + 1;
        % Initialize the subject's struct
        sname = subjects{g}.names{s};
        spath = fullfile(root_path, groups{g}, sname);
        data.groups{g}.subjects{s} = struct('id', sname, ...
                                                'dir', spath, ...
                                                'sessions', [] ...
                                                );
        % Find the sessions
        sessions = get_dirnames(fullfile(spath, 'data'));

        for sessid=1:length(sessions)
            % Print status
            fprintf('Detect images for subject %i/%i session %i/%i (%s %s %s)...\n', sid, subjects_real_total, sessid, length(sessions), groups{g}, sname, sessions{sessid});

            % Get path to images (inside each session)
            sesspath = fullfile(spath, 'data', sessions{sessid});

            % Init session data struct
            session = struct('id', sessions{sessid}, ...
                             'files', struct('tennis', [])); % Note: NEVER init with {}, always with [] because else the struct will be considered empty and unmodifiable! (famous errors: ??? A dot name structure assignment is illegal when the structure is empty. or ??? Error using ==> end)

            % Get full filepaths of all images
            tennispath = getimgpath(sesspath, 'tennis');
            % Save the structural images
            session.files.tennis = check_exist(regex_files(tennispath, ['^con_0001\.(img|nii)$']));
            % Append in the list of sessions for this subject in our big data struct
            data.groups{g}.subjects{s}.sessions{end+1} = session;
        end % for sessions
    end % for subjects
end % for groups

% == Calculate difference between two sessions of tennis test for each subject
job = 0;
sid = 0; % subject counter, because we need to add them all in a row in CONN, we assign groups later
for g=1:length(groups)
    for s=1:length(subjects{g}.names)
        if numel(data.groups{g}.subjects{s}.sessions) >= 3  % only process subjects where there is a follow up (a 3rd session)
            sid = sid + 1; % We need to continue the subjects counter after switch to next group, but subject counter s will go back to 0, hence the sid which is the CONN subject's id
            sessions = data.groups{g}.subjects{s}.sessions;
            if length(sessions) < 2
                error('Not enough sessions for group %s subject %s!', data.groups{g}, data.groups{g}.subjects{s})
            end

            % Construct the SPM job for this subject
            job = job+1;
            spm_jobman('initcfg'); % init the jobman
            matlabbatch{job}.spm.util.imcalc.input = {
                                                    data.groups{g}.subjects{s}.sessions{2}.files.tennis
                                                    data.groups{g}.subjects{s}.sessions{3}.files.tennis
                                                    };
            matlabbatch{job}.spm.util.imcalc.output = 'Tennis_diff_followup-post.nii'; % name the the output image
            matlabbatch{job}.spm.util.imcalc.outdir = {data.groups{g}.subjects{s}.dir}; % out
            matlabbatch{job}.spm.util.imcalc.expression = 'i2-i1';
            matlabbatch{job}.spm.util.imcalc.var = struct('name', {}, 'value', {});
            matlabbatch{job}.spm.util.imcalc.options.dmtx = 0;
            matlabbatch{job}.spm.util.imcalc.options.mask = 0;
            matlabbatch{job}.spm.util.imcalc.options.interp = 1;
            matlabbatch{job}.spm.util.imcalc.options.dtype = 4;
        end % end if
    end % end for subjects
end % end for groups

% Launch all the jobs!
eval(['save jobs_imcalc_' datestr(now,30) ' matlabbatch'])
spm_jobman('run',matlabbatch)


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
        case 'tennis'
            fpath = fullfile(dirpath, 'tennis', 'Classical_ana');
        case 'struct'  % anatomical images (T1 aka structural) folder
            fpath = fullfile(dirpath, 'mprage');
        case 'func' % functional images (T2) folder
            fpath = fullfile(dirpath, 'rest');
        case 'func_motion_corrected'
            fpath = fullfile(dirpath, 'rest', 'restMotionCorrected');
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


end % end function
