function functionalcoreg(struct,func,others,mode,modality)

% FORMAT functionalcoreg(struct,func,others,mode,modality)
%
% Function to coregister functional (or other modalities) to structural images
% using rigid-body transform via a Mutual Information calculation on Joint Histograms.
% Works on SPM12.
%
% It is advised to check (and fix if necessary) manually the result (using CheckReg).
%
% Note: a two-line alternative to this script is to do the following:
% spm_auto_reorient(func, 'epi', others, 'mi');
% spm_auto_reorient(func, struct, others, 'mi');
%
% IN:
% - struct      : filename of the reference structural image
% - func        : filename of the source functional image (that will be coregistered to structural image). In general, this should be the first BOLD volume (to register to the first volume)
% - others      : list of filenames of other functional (or other modality) images to coregister with the same transform as the source image (format similar to what `ls` returns)
% - mode        : coregister using the old 'affine' method, or the new 'mi' Mutual Information method (default) or 'both' (first affine then mi) or 'minoprecoreg' to skip precoregistration
% - modality    : modality of the 'func' image, can be any type supported by SPM: 't1', 't2', 'epi', 'pd', 'pet', 'spect'. Default: 'epi'.
%
% OUT:
% - the voxel-to-world part of the headers of the selected source (func) and others images is modified.
%__________________________________________________________________________
% v1.0.7
% License: MIT License
% Copyright (C) 2019 Stephen Karl Larroque - Coma Science Group - GIGA-Consciousness - University & Hospital of Liege
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:

% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.

% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.

%% Check inputs
if nargin<1 || isempty(struct)
    struct = spm_select(inf,'image','Select structural image');
end
if nargin<2 || isempty(func)
    func = spm_select(inf,'image','Select functional images');
end
if iscell(struct), struct = char(struct); end
if iscell(func), func = char(func); end

if nargin<3 || isempty(others)
    others = [];
end
if ~isempty(others) & iscell(others), others = char(others); end

if nargin<4 || isempty(mode)
    mode = 'mi';
end

if nargin<5 || isempty(modality)
    modality = 'epi';
end

% PRE-COREGISTRATION ON TEMPLATE
% First, coregister on template brain
% This greatly enhance the results, particularly if the structural was auto-reoriented on MNI (using github.com/lrq3000/spm_auto_reorient) so that the template EPI is in the same space as the structural, hence why this enhances the results
% If this is not done, most often the coregistration will get the rotation right but not the translation
fprintf('Pre-coregistration on %s template, please wait...\n', modality);
if strcmp(mode,'affine')
    spm_auto_reorient(func, modality, others, 'affine');
elseif strcmp(mode,'mi') | strcmp(mode,'both')
    spm_auto_reorient(func, modality, others, 'mi');
end %endif
if strcmp(mode, 'precoreg')
    return
end

% AFFINE COREGISTRATION
if strcmp(mode,'affine') | strcmp(mode,'both')
    fprintf('Affine coregistration, please wait...\n');
    % Configure coregistration
    flags.sep = 5;  % sampling distance. Reducing this enhances a bit the reorientation but significantly increases processing time.
    flags.regtype = 'mni';  % can be 'none', 'rigid', 'subj' or 'mni'. On brain damaged patients, 'mni' seems to give the best results (non-affine transform), but we don't use the scaling factor anyway. See also a comparison in: Liu, Yuan, and Benoit M. Dawant. "Automatic detection of the anterior and posterior commissures on MRI scans using regression forests." 2014 36th Annual International Conference of the IEEE Engineering in Medicine and Biology Society. IEEE, 2014.
    smooth_factor = 20;
    % Load images
    spm_smooth(struct,'referencetemp.nii',[smooth_factor smooth_factor smooth_factor]);
    Vstruct = spm_vol('referencetemp.nii');
    Vfunc = spm_vol(func);
    % Estimate reorientation
    [M, scal] = spm_affreg(Vstruct,Vfunc,flags);
    M3 = M(1:3,1:3);
    [u s v] = svd(M3);
    M3 = u*v';
    M(1:3,1:3) = M3;
    % apply it on source functional image
    N = nifti(func);
    N.mat = M*N.mat;
    % Save the transform into nifti file headers
    create(N);
    % clean up
    delete('referencetemp.nii');
end %endif

% MUTUAL INFORMATION COREGISTRATION
if strcmp(mode,'mi') | strcmp(mode,'both') | strcmp(mode,'minoprecoreg')
    fprintf('Mutual information coregistration, please wait...\n');
    % Configure coregistration
    flags2.cost_fun = 'ecc';  % ncc works remarkably well, when it works, else it fails very badly, particularly for between-modalities coregistration... ecc works better on some edge cases than mi and nmi for coregistration
    flags2.tol = [0.1, 0.1, 0.02, 0.02, 0.02, 0.001, 0.001, 0.001, 0.01, 0.01, 0.01, 0.001, 0.001, 0.001, 0.0002, 0.0001, 0.00002];  % VERY important to get good results. This defines the amount of displacement tolerated. We start with one single big step allowed, to correct after the pre-coregistration if it somehow failed, and then we use the defaults from SPM GUI with progressively finer steps, repeated 2 times (multistart approach).
    flags2.fwhm = [1, 1];  % reduce smoothing for more efficient coregistering, since the pre-coregistration normally should have placed the brain quite in the correct spot overall. This greatly enhances results, particularly on brain damaged subjects.
    flags2.sep = [4 2 1];  % use [4 2 1] if you want to use a finer grained step at the end at 1mm, this can help to get more precise coregistration in some cases but at the cost of a quite longer computing time, this greatly help for a few hard cases
    % Load images
    Vstruct = spm_vol(struct);
    Vfunc = spm_vol(func);
    % Estimate reorientation from source image to reference (structural) image
    M_mi = spm_coreg(Vstruct,Vfunc,flags2);
    % apply it on source image
    N = nifti(func);
    N.mat = spm_matrix(M_mi)\N.mat;
    % Save the transform into nifti file headers
    create(N);
end %endif

% Apply coregistration transform on other images (without recalculating, so that we keep motion information)
if ~isempty(others)
    fprintf('Applying transform to other images...\n');
    for j = 1:size(others,1);
        % Get other file path
        func_other = strtrim(others(j,:));
        if ~isempty(func_other) && ~strcmp(func,func_other)  % If filepath is empty or same as source functional, just skip
            % Load volume
            N = nifti(func_other);
            if strcmp(mode,'affine') | strcmp(mode,'both')
                % Apply affine transform
                N.mat = M*N.mat;
            end %endif
            if strcmp(mode,'mi') | strcmp(mode,'both') | strcmp(mode,'minocoreg')
                % Apply Mutual Information rigid-body transform
                N.mat = spm_matrix(M_mi)\N.mat;
            end %endif
            % Save the transform into nifti file headers
            create(N);
        end
    end
end %endif

fprintf('Coregistration done!\n');

end % endfunction
