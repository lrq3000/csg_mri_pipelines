function movvis(root_path, maxelt)
% movvis(root_path, maxelt)
% Movement visualization of all subjects after preprocessing with ART
% Folders tree structure must correspond to conn subjects loader expected structure (Condition/Subject/data/Session/modality/rp_*.txt), but in fact all subfolders are optional apart from Condition/Subject
% maxelt allows to select the maximum number of elements to show on the same plot (the rest will be shown after pressing a key in the console)
%
% v1.4
% by Stephen Larroque 2016-2019
% License MIT

close all;

if nargin < 1
    error('No root_path provided, please provide the path to a directory containing your data (in the near BIDS-like structure: Condition/Subject/data/Session/modality/rp_*.txt), but in fact all subfolders are optional apart from Condition/Subject');
end

if nargin < 2 || isempty(maxelt)
    maxelt = 25;  % by default we will show up to 25 plots on the same screen
end

% PREPARE DATA TO VISUALIZE
% Single file mode, we show the graph for only this file
if exist(root_path, 'file') == 2
    fprintf('Loading realign movement file of one subject: %s\n', root_path);
    if ~isempty(root_path)
        sid = 1;
        list_files{sid} = struct('condition', '', ...
                                'name', '', ...
                                'session', '', ...
                                'file', root_path);
    end
% Folder mode, we scan all groups/subjects/sessions
else
    % Scan the root path to extract all conditions and subjects names
    fprintf('Loading realign movement files from all groups, subjects and sessions...\n');
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
    % For each group
    for c=1:length(conditions)
        % For each subject
        for s=1:length(subjects{c}.names)
            sname = subjects{c}.names{s};
            datapath = fullfile(root_path, conditions{c}, sname, 'data');

            % For each session
            sessions = get_dirnames(datapath);
            if length(sessions) == 0
                sessions = {'.'};
            end %endif
            for isess=1:length(sessions)
                sesspath = fullfile(datapath, sessions{isess});
                modalities = get_dirnames(sesspath);
                if length(modalities) == 0
                    modalities = {'.'};
                end %endif
                % check all modalities folders (eg, rest, tennis, etc.)
                for im=1:length(modalities)
                    % skip mprage and jobs folders
                    if ~strcmpi(modalities{im}, 'mprage') & ~strcmpi(modalities{im}, 'jobs')
                        spath = fullfile(sesspath, modalities{im});
                        % Extract realign motion txt file (from SPM)
                        sfile = regex_files(spath, '^rp_.+\.txt$');

                        % Add this file only if found (eg, do not add mprage folders)
                        if ~isempty(sfile)
                            sid = sid + 1;
                            list_files{sid} = struct('condition', conditions{c}, ...
                                                    'name', sname, ...
                                                    'session', sessions{isess}, ...
                                                    'modality', modalities{im}, ...
                                                    'file', sfile);
                    end %endif
                end %endfor
                end
            end
        end
    end
end

total_files = length(list_files);
fprintf('Found %i movement files.\n', total_files);
if total_files == 0
    return;
end %endif

% PLOT
% Compute the number of colums per row (we want to have a square like shape)
width = ceil(sqrt(maxelt));
height = ceil(maxelt / width);
% Display multiple subjects as subplot on the same figure
figure(1); suptitle('Translation (in mm)');
figure(2); suptitle('Rotation (in rad)');
curelt = 0;  % count where we are at about printing (to stay below maxelt)
%for s=1:ceil(total_subjects)
for sid=1:length(list_files)
    % Check where we stop printing for this batch
    if curelt >= maxelt
        fprintf('Please press any key to continue plotting the next batch of subjects.\n');
        pause;
        % Reset counter
        curelt = 0;
        % Recreate figures
        close all;
        figure(1); suptitle('Translation (in mm)');
        figure(2); suptitle('Rotation (in rad)');
    end %endif

    % Load ART movement data
    mov_data = importdata(list_files{sid}.file);

    % Plot translation (x,y,z in mm)
    figure(1);
    %i = 1 + floor(s / width);
    %j = mod(s, width);
    subplot(height, width, mod(sid-1,maxelt)+1 );
    plot(mov_data(:,1:3)); % x, y, z translation in mm
    xlabel('Volume number');
    ylabel('mm');
    title(['Subject ' list_files{sid}.name ' cond ' list_files{sid}.condition ' sess ' list_files{sid}.session ' mod ' list_files{sid}.modality]);

    % Plot rotation (tx, ty, tz in radians)
    figure(2);
    subplot(height, width, mod(sid-1,maxelt)+1 );
    plot(mov_data(:,4:6)); % tx, ty, tz rotation in radians
    xlabel('Volume number');
    ylabel('rad');
    title(['Subject ' list_files{sid}.name ' cond ' list_files{sid}.condition ' sess ' list_files{sid}.session ' mod ' list_files{sid}.modality]);

    % Update counter
    curelt = curelt + 1;
end

% Set one legend for all the subplots, and place it outside the last subplot (because the subplots will probably be small, with the legend over it would be impossible to see anything)
figure(1);
legend('x', 'y', 'z', 'location','northeast');
legend('boxoff');
figure(2);
legend('tx', 'ty', 'tz', 'location','northeast');
legend('boxoff');

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
