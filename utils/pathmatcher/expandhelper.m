function outfiles = expandhelper(niftifiles)
% expandhelper(files)
% Given a list of files, automatically detect 4D nifti files and return an expanded list (where each entry = one volume)
% This script needs SPM in the path (to open nifti files)
% by Stephen Karl Larroque, 2019, Coma Science Group, GIGA-Consciousness, University & Hospital of Liege
% v1.0.0
%

if numel(niftifiles) > 0
    outfiles = cellstr(expand_4d_vols(char(niftifiles)));
else
    outfiles = [];
end %endif

end % endfunction

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
