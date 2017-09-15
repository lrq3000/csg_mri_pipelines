function nifti_3dto4d_convert_recursive(rootpath, spmpath)
% nifti_3dto4d_convert_recursive(rootpath, spmpath)
% Converts all 3D nifti files to 4D nifti recursively, using SPM.
% WARNING: will delete the 3D nifti files! Make a backup before!
% Useful to avoid memory errors when processing (the dreaded "cant map view" error) when the nifti is too big.
% This script needs both SPM (to convert from 3D to 4D) and dirPlus (https://github.com/kpeaton/dirPlus).
% by Stephen Larroque, 2017, from the Coma Science Group, University of Liege
%
% Temporarily restore factory path and set path to SPM and its toolboxes, this avoids conflicts when having different versions of SPM installed on the same machine
bakpath = path; % backup the current path variable
restoredefaultpath(); matlabpath(strrep(matlabpath, userpath, '')); % clean up the path
addpath(spmpath); % add the path to SPM

% Get list of all folders recursively. We will then grab all the niftis at this level to convert to 4D.
folderslist = dirPlus('G:\Topreproc\Tutorial\data_niftis - Copie', 'ReturnDirs', true);

if numel(folderslist) > 0
    for f=1:numel(folderslist)
        % Get list of all nifti files (NOT recursively, and only .img or .nii files)
        rootpath = folderslist{f};
        niftifiles = dirPlus(rootpath, 'PrependPath', true, 'FileFilter', '.*\.(img|nii)$', 'Depth', 0);

        if numel(niftifiles) > 0
            % Test which are 3D nifti files
            idx3d = [];
            for i=1:size(niftifiles, 1)
                if ~is4D(niftifiles{i})
                    idx3d = [idx3d i];
                end
            end %endfor

            if numel(idx3d) > 0 % even if there is only 1 nifti file, we still continue so it gets converted to .nii (instead of hdr/img)
                % Extract only 3D nifti files
                nifti3dfiles = niftifiles(idx3d);

                % Concatenate all 3D nifti files of this folder into one 4D nifti file
                onefilename = nifti3dfiles{1};
                outfilename = sprintf('%s_4d.nii', onefilename(1:end-4));
                spm_file_merge(nifti3dfiles, outfilename);
                fprintf('3d to 4d nifti concatenation completed for: %s\n', outfilename);
                % Delete all 3d files
                for i=1:numel(nifti3dfiles)
                    % Get one 3D nifti file
                    nfile = nifti3dfiles{i};
                    % Delete 3D nifti files
                    delete(nfile);
                    % If format is old 4D nifti (with two files: .img/.hdr), delete also the .hdr file
                    if strcmpi(nfile(end-3:end), '.img')
                        delete([nfile(1:end-4) '.hdr']);
                    end %endif
                end %endfor
            end %endif
        end %endif
    end %endfor
end %endif


fprintf('All 3D nifti files converted to 4D! Restoring path and exiting...\n');
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
