function nifti_4dto3d_convert_recursive(rootpath, spmpath)
% nifti_4dto3d_convert_recursive(rootpath, spmpath)
% Converts all 4D nifti files to 3D nifti recursively, using SPM.
% WARNING: will delete the 4D nifti files! Make a backup before!
% Useful to avoid memory errors when processing (the dreaded "cant map view" error) when the nifti is too big.
% This script needs both SPM (to convert from 4D to 3D) and dirPlus (https://github.com/kpeaton/dirPlus).
% v1.2.0, 2017-2024, Stephen Larroque, Coma Science Group, University of Liege
%

% Temporarily restore factory path and set path to SPM and its toolboxes, this avoids conflicts when having different versions of SPM installed on the same machine
bakpath = path; % backup the current path variable
restoredefaultpath(); matlabpath(strrep(matlabpath, userpath, '')); % clean up the path
addpath(spmpath); % add the path to SPM
% Get the full path of the currently executed script
currentScriptPath = mfilename('fullpath');
% Extract the directory containing the script
[currentScriptDir, ~, ~] = fileparts(currentScriptPath);
% Add the directory of the currently executed script to the MATLAB path (to be able to call dirPlus)
addpath(currentScriptDir);

% Get list of all nifti files (recursively, all .img or .nii files)
fprintf('Walking recursively through the %s directory to list all nifti files (3D, 4D uncompressed, 4D compressed)...\n', rootpath);
niftifiles = dirPlus(rootpath, 'PrependPath', true, 'FileFilter', '.*\.(img|nii|nii.gz)$');

if numel(niftifiles) > 0
    % Test which are 4D nifti files, and memoize the list of 4D nifti files
    fprintf('Found %d nifti files. Now checking which are 4D nifti files...\n', numel(niftifiles));
    idx4d = [];
    for i=1:size(niftifiles, 1)
        % If the file is a compressed 4D nifti file, don't try to open it. But if not, we check its content to see if it's an uncompressed 4D nifti file.
        nfile = niftifiles{i};
        if strcmpi(nfile(end-6:end), '.nii.gz') || is4D(niftifiles{i})
            idx4d = [idx4d i];
        end
    end %endfor

    % We now have the list of 4D nifti files, process them
    fprintf('Found %d 4D nifti files to convert to 3D. Now starting to convert...\n', numel(idx4d));
    if numel(idx4d) > 0
        % Extract only 4D nifti files from the initial list of all the detected nifti files
        nifti4dfiles = niftifiles(idx4d);

        % Convert each 4D nifti to 3D nifti
        for i=1:numel(nifti4dfiles)
            % Get one 4D nifti file
            nfile = nifti4dfiles{i};
            fprintf('Converting 4D nifti file %d/%d: %s\n', i, numel(nifti4dfiles), nfile);
            % Check if the file is compressed (.nii.gz)
            if strcmpi(nfile(end-6:end), '.nii.gz')
                % Uncompress the file
                uncompressedFile = gunzip(nfile);
                % Delete compressed file
                delete(nfile);
                % Update nfile to point to the uncompressed file for further processing
                nfile = uncompressedFile{1}; % gunzip returns a cell array
            end %endif
            % Convert to 3D nifti by using SPM
            spm_file_split(nfile);
            % Delete 4D nifti
            delete(nfile);
            % If format is old 4D nifti (with two files: .img/.hdr), delete also the .hdr file
            if strcmpi(nfile(end-3:end), '.img')
                delete([nfile(1:end-4) '.hdr']);
            end %endif
        end %endfor
    end %endif
end %endif

fprintf('All 4D nifti files converted to 3D! Restoring path and exiting...\n');
path(bakpath); % restore the path to the previous state
diary off;
end % end script

function res = is4D(file)
    nbframes = spm_select_get_nbframes(file);
    if nbframes > 1
        res = true;
    else
        res = false;
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
