function reorienthelper(p)
% reorienthelper(path)
% Launch SPM12 Display dialog on the given nifti file, with contextual menu (right-click) enabled
    spm_image('display', p);
    spm_orthviews('AddContext');
end %endfunction
