function movvis(root_path)
% Movement visualization of all subjects after preprocessing with ART
% Folders tree structure must correspond to Cyclotron's standard layout.

close all;

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

list_files = {};
sid = 0;
for c=1:length(conditions)
    for s=1:length(subjects{c}.names)
        sid = sid + 1;
        sname = subjects{c}.names{s};
        spath = fullfile(root_path, conditions{c}, sname, 'data', 'rest', 'restMotionCorrected');
        sfile = regex_files(spath, '^rp_.+\.txt$');

        list_files{sid} = struct('condition', conditions{c}, ...
                                'name', sname, ...
                                'file', sfile);
    end
end

% Compute the number of colums per row (we want to have a square like shape)
total_subjects = length(list_files);
width = ceil(sqrt(total_subjects));
height = ceil(total_subjects / width);
% Display multiple subjects as subplot on the same figure
figure(1); suptitle('Translation (in mm)');
figure(2); suptitle('Rotation (in rad)');
for s=1:ceil(total_subjects)
    % Load ART movement data
    mov_data = importdata(list_files{s}.file);

    % Plot translation (x,y,z in mm)
    figure(1);
    %i = 1 + floor(s / width);
    %j = mod(s, width);
    subplot(height, width, s);
    plot(mov_data(:,1:3)); % x, y, z translation in mm
    xlabel('Volume number');
    ylabel('mm');
    title(['Subject ' list_files{s}.name ' cond ' list_files{s}.condition]);

    % Plot rotation (tx, ty, tz in radians)
    figure(2);
    subplot(height, width, s);
    plot(mov_data(:,4:6)); % tx, ty, tz rotation in radians
    xlabel('Volume number');
    ylabel('rad');
    title(['Subject ' list_files{s}.name ' cond ' list_files{s}.condition]);
end

% Set one legend for all the subplots, and place it outside the last subplot (because the subplots will probably be small, with the legend over it would be impossible to see anything)
figure(1);
legend('x', 'y', 'z', 'location','northeastoutside');
figure(2);
legend('tx', 'ty', 'tz', 'location','northeastoutside');

% Bring to the front
figure(1); shg;
figure(2); shg;

end % endfunction


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
