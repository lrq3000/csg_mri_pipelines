function h = conn_3dvis(imfilepath, vismode)
% conn_3dvis(imfilepath, mode)
% Load CONN 3D brain visualization on any given nifti map.
% You need CONN in the path in MATLAB to use this script.
% If no argument is given, a SPM (minimal) GUI will open to ask for the required parameters.
%
% Inputs:
% imfilepath : can be any neuroimage, but generally you want to use the unthresholded maps, also called the T maps, in other words in SPM the contrast maps which are named spmT_XXXX.nii, where XXXX is the position of the contrast in the contrast manager (first, second, etc).
% vismode : type of visualization to use, can be either 'surface' or 'volume'.
%
% Outputs:
% h : GUI handler
%
%
% By Stephen Larroque, Coma Science Group, GIGA-Consciousness, University and Hospital of Liege
% Created on 2019-06-18
% License: MIT
%
% v0.1.1
%
% TODO:
% * Nothing
%

if ~exist('imfilepath', 'var') | isempty(imfilepath)
    imfilepath  = spm_select(1,'image','Select NIfTI image');
end
if ~exist('vismode', 'var') | isempty(mode)
    vismode = spm_input('Visualization mode','+1','b','surface|volume',[],1);
end

if strcmpi(vismode, 'surface')
    h = conn_mesh_display(imfilepath);
elseif strcmpi(vismode, 'volume')
    h = conn_mesh_display('' ,imfilepath, [],[],[],[],0.5);
else
    error('Invalid vismode!\n')
end

end % endfunction
