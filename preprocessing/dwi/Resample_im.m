function Resample_im(Im,Target,Output)
%%% Resample Im to the same dimensions as the Target image (needed to flirt the T1 without resampling)
%Fa=['./' 'fathr.nii' ',1'];
%Wm=['./' 'WM.nii' ',1'];
%Output='fa_res.nii';

matlabbatch{1}.spm.util.imcalc.input = {
                                        Target
                                        Im
                                        
                                        };
matlabbatch{1}.spm.util.imcalc.output = Output;
matlabbatch{1}.spm.util.imcalc.outdir = {''};
matlabbatch{1}.spm.util.imcalc.expression = 'i2';
matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
matlabbatch{1}.spm.util.imcalc.options.mask = 0;
matlabbatch{1}.spm.util.imcalc.options.interp = 1;
matlabbatch{1}.spm.util.imcalc.options.dtype = 4;
spm_jobman('serial',matlabbatch);

