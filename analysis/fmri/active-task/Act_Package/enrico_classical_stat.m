%-----------------------------------------------------------------------
% Job configuration created by cfg_util (rev $Rev: 4252 $)
%-----------------------------------------------------------------------
if(size(SR,1) == 104 || size(SR,1) == 300 )
   SR(1:3) = []; 
end

SR = cellstr(SR);
RP = spm_select('FPList',funDir, '^rp*.*\.txt$');
RP = cellstr(RP);
mkdir([funDir '\Classical_ana']);
moduleid = 0;

% Load nifti images and expand all frames if 4D nifti .nii file (instead of .hdr/.img)
moduleid = moduleid + 1;
matlabbatch{moduleid}.spm.util.exp_frames.files = SR;
matlabbatch{moduleid}.spm.util.exp_frames.frames = Inf;

% == Model definition
moduleid = moduleid + 1;
matlabbatch{moduleid}.spm.stats.fmri_spec.dir = {[funDir '\Classical_ana']};
matlabbatch{moduleid}.spm.stats.fmri_spec.timing.units = 'scans';
matlabbatch{moduleid}.spm.stats.fmri_spec.timing.RT = 2;
matlabbatch{moduleid}.spm.stats.fmri_spec.timing.fmri_t = 16;
matlabbatch{moduleid}.spm.stats.fmri_spec.timing.fmri_t0 = 1;
%%
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.scans(1) = cfg_dep;
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.scans(1).tname = 'Scans';
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.scans(1).tgt_spec{1}(1).name = 'filter';
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.scans(1).tgt_spec{1}(1).value = 'image';
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.scans(1).tgt_spec{1}(2).name = 'strtype';
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.scans(1).tgt_spec{1}(2).value = 'e';
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.scans(1).sname = 'Expand image frames: Expanded filename list.';
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.scans(1).src_exbranch = substruct('.','val', '{}',{moduleid-1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.scans(1).src_output = substruct('.','files');
%%
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.cond.name = activation_name;
% %%% Here you can change the onsets
% matlabbatch{moduleid}.spm.stats.fmri_spec.sess.cond.onset = [5
%                                                       21
%                                                       37
%                                                       53
%                                                       69
%                                                       85];
% matlabbatch{moduleid}.spm.stats.fmri_spec.sess.cond.onset = [12
%                                                       42
%                                                       72
%                                                       102
%                                                       132];
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.cond.onset = Onset;
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.cond.duration = 15;
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.cond.tmod = 0;
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.cond.pmod = struct('name', {}, 'param', {}, 'poly', {});
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.multi = {''};
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.regress = struct('name', {}, 'val', {});
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.multi_reg = RP;
matlabbatch{moduleid}.spm.stats.fmri_spec.sess.hpf = 128;
matlabbatch{moduleid}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
matlabbatch{moduleid}.spm.stats.fmri_spec.bases.hrf.derivs = hrfTimeDispersionDerivative; % enable time (peak time shift + or - 1s) or time + dispersion derivative (peak time shift and width also) by respectively setting [1 0] or [1 1]. To disable totally use [0 0].
matlabbatch{moduleid}.spm.stats.fmri_spec.volt = 1;
matlabbatch{moduleid}.spm.stats.fmri_spec.global = 'None';
matlabbatch{moduleid}.spm.stats.fmri_spec.mask = {''};
matlabbatch{moduleid}.spm.stats.fmri_spec.cvi = 'AR(1)';

% == Model estimation
moduleid = moduleid + 1;
matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1) = cfg_dep;
matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).tname = 'Select SPM.mat';
matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(1).name = 'filter';
matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(1).value = 'mat';
matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(2).name = 'strtype';
matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(2).value = 'e';
matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).sname = 'fMRI model specification: SPM.mat File';
matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).src_exbranch = substruct('.','val', '{}',{moduleid-1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{moduleid}.spm.stats.fmri_est.spmmat(1).src_output = substruct('.','spmmat');
matlabbatch{moduleid}.spm.stats.fmri_est.method.Classical = 1;

% == Contrasts predefinition
moduleid = moduleid + 1;
matlabbatch{moduleid}.spm.stats.con.spmmat(1) = cfg_dep;
matlabbatch{moduleid}.spm.stats.con.spmmat(1).tname = 'Select SPM.mat';
matlabbatch{moduleid}.spm.stats.con.spmmat(1).tgt_spec{1}(1).name = 'filter';
matlabbatch{moduleid}.spm.stats.con.spmmat(1).tgt_spec{1}(1).value = 'mat';
matlabbatch{moduleid}.spm.stats.con.spmmat(1).tgt_spec{1}(2).name = 'strtype';
matlabbatch{moduleid}.spm.stats.con.spmmat(1).tgt_spec{1}(2).value = 'e';
matlabbatch{moduleid}.spm.stats.con.spmmat(1).sname = 'Model estimation: SPM.mat File';
matlabbatch{moduleid}.spm.stats.con.spmmat(1).src_exbranch = substruct('.','val', '{}',{moduleid-1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{moduleid}.spm.stats.con.spmmat(1).src_output = substruct('.','spmmat');
matlabbatch{moduleid}.spm.stats.con.consess{1}.tcon.name = 'Patient activity-correlation';
matlabbatch{moduleid}.spm.stats.con.consess{1}.tcon.convec = [1];
matlabbatch{moduleid}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
matlabbatch{moduleid}.spm.stats.con.consess{2}.tcon.name = 'Patient anticorrelation maybe';
matlabbatch{moduleid}.spm.stats.con.consess{2}.tcon.convec = [-1];
matlabbatch{moduleid}.spm.stats.con.consess{2}.tcon.sessrep = 'none';
matlabbatch{moduleid}.spm.stats.con.delete = 0;

% Save job
eval(['save jobs_stat_' datestr(now,30) ' matlabbatch']);

% Run job
spm_jobman('initcfg');
spm_jobman('serial',matlabbatch);
