function process_spm_coreg_and_exit(fileto, filefrom, fileout, filein, fileout2, filein2)

% Usage: process_spm_coreg_and_exit(fileto, filefrom, fileout, filein, fileout2, filein2)
% fileto        filename of a reference image to coregister to (if file 
%               contains several volumes, only the first is used)
% filefrom      filename of the source image to coregister to the reference
%               (if file contains several volumes, only the first is used)
% fileout       new filename (required)
% filein        optional input image which will be transformed using the 
%               transform from filefrom->fileto and which needs to be in 
%               the same space as the source image
% fileout2      2nd new filename (optional)
% filein2       2nd optional input image which will be transformed using 
%               the transform from filefrom->fileto and which needs to be 
%               in the same space as the source image
%
% (c) Timo Roine (timo.roine@uantwerpen.be) and Ben Jeurissen 
% (ben.jeurissen@uantwerpen.be), 2014

if nargin<4
    filein=filefrom;
end
VG = spm_vol(fileto);
VF = spm_vol(filefrom);
x = spm_coreg(VG(1),VF(1));
mat = spm_matrix(x(:)');

nii = load_untouch_nii(filein);
nii.hdr.hist.qform_code = 0;
nii.hdr.hist.quatern_b = 0;
nii.hdr.hist.qoffset_x = 0;
nii.hdr.hist.qoffset_y = 0;
nii.hdr.hist.qoffset_z = 0;
tmp = mat\cat(1,nii.hdr.hist.srow_x,nii.hdr.hist.srow_y,nii.hdr.hist.srow_z,[0 0 0 1]);
nii.hdr.hist.srow_x = tmp(1,:); nii.hdr.hist.srow_y = tmp(2,:); nii.hdr.hist.srow_z = tmp(3,:);
save_untouch_nii(nii,fileout);

if nargin>5
    nii = load_untouch_nii(filein2);
    nii.hdr.hist.qform_code = 0;
    nii.hdr.hist.quatern_b = 0;
    nii.hdr.hist.qoffset_x = 0;
    nii.hdr.hist.qoffset_y = 0;
    nii.hdr.hist.qoffset_z = 0;
    tmp = mat\cat(1,nii.hdr.hist.srow_x,nii.hdr.hist.srow_y,nii.hdr.hist.srow_z,[0 0 0 1]);
    nii.hdr.hist.srow_x = tmp(1,:); nii.hdr.hist.srow_y = tmp(2,:); nii.hdr.hist.srow_z = tmp(3,:);
    save_untouch_nii(nii,fileout2);
end

%exit