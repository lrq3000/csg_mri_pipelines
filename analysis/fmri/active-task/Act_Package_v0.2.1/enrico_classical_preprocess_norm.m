function enrico_classical_preprocess_norm(F, S, path_to_spm8, tr, slice_order, refslice)

% Init optional arguments
if ~exist('slice_order', 'var')
    slice_order = [];
end
if ~exist('tr', 'var')
    tr = [];
end
if ~exist('refslice', 'var') | isempty(refslice)
    % take the first temporal slice as reference by default
    if ~isempty(slice_order)
        % detect if slice order or slice timing
        if any(round(slice_order) ~= slice_order)
            % slice timing
            [~, slice_order2] = sort(slice_order);
            refslice = slice_order(slice_order2(1)); % could also just do a min(slice_order)...
        else
            % slice order
            refslice = slice_order(1);
        end %endif
    else
        refslice = [];
    end %endif
end

% Build job
matlabbatch = {};
bi = 1;
% Load nifti images and expand all frames if 4D nifti .nii file (instead of .hdr/.img)
matlabbatch{bi}.spm.util.exp_frames.files = F;
matlabbatch{bi}.spm.util.exp_frames.frames = Inf;
%
if ~isempty(slice_order) & ~isempty(tr)
    bi = bi + 1;
    nslices = numel(slice_order);
    matlabbatch{bi}.spm.temporal.st.scans{1}(1) = cfg_dep;
    matlabbatch{bi}.spm.temporal.st.scans{1}(1).tname = 'Session';
    matlabbatch{bi}.spm.temporal.st.scans{1}(1).tgt_spec{1}(1).name = 'filter';
    matlabbatch{bi}.spm.temporal.st.scans{1}(1).tgt_spec{1}(1).value = 'image';
    matlabbatch{bi}.spm.temporal.st.scans{1}(1).tgt_spec{1}(2).name = 'strtype';
    matlabbatch{bi}.spm.temporal.st.scans{1}(1).tgt_spec{1}(2).value = 'e';
    matlabbatch{bi}.spm.temporal.st.scans{1}(1).sname = 'Expand image frames: Expanded filename list.';
    matlabbatch{bi}.spm.temporal.st.scans{1}(1).src_exbranch = substruct('.','val', '{}',{bi-1}, '.','val', '{}',{1}, '.','val', '{}',{1});
    matlabbatch{bi}.spm.temporal.st.scans{1}(1).src_output = substruct('.','files');
    matlabbatch{bi}.spm.temporal.st.nslices = nslices;
    matlabbatch{bi}.spm.temporal.st.tr = tr;
    matlabbatch{bi}.spm.temporal.st.ta = (tr-(tr/nslices));
    matlabbatch{bi}.spm.temporal.st.so = slice_order;
    matlabbatch{bi}.spm.temporal.st.refslice = refslice;
    matlabbatch{bi}.spm.temporal.st.prefix = 'a';
end %endif

bi = bi + 1;
if ~isempty(slice_order)
    matlabbatch{bi}.spm.spatial.realign.estwrite.data{1}(1) = cfg_dep('Slice Timing: Slice Timing Corr. Images (Sess 1)', substruct('.','val', '{}',{bi-1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
else
    matlabbatch{bi}.spm.spatial.realign.estwrite.data{1}(1) = cfg_dep('Expand image frames: Expanded filename list.', substruct('.','val', '{}',{bi-1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
end %endif
matlabbatch{bi}.spm.spatial.realign.estwrite.eoptions.quality = 0.9;
matlabbatch{bi}.spm.spatial.realign.estwrite.eoptions.sep = 4;
matlabbatch{bi}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;
matlabbatch{bi}.spm.spatial.realign.estwrite.eoptions.rtm = 1;
matlabbatch{bi}.spm.spatial.realign.estwrite.eoptions.interp = 2;
matlabbatch{bi}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
matlabbatch{bi}.spm.spatial.realign.estwrite.eoptions.weight = {''};
matlabbatch{bi}.spm.spatial.realign.estwrite.roptions.which = [2 1];
matlabbatch{bi}.spm.spatial.realign.estwrite.roptions.interp = 4;
matlabbatch{bi}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
matlabbatch{bi}.spm.spatial.realign.estwrite.roptions.mask = 1;
matlabbatch{bi}.spm.spatial.realign.estwrite.roptions.prefix = 'r';

bi = bi + 1;
matlabbatch{bi}.spm.spatial.coreg.estimate.ref = S;
matlabbatch{bi}.spm.spatial.coreg.estimate.source(1) = cfg_dep;
matlabbatch{bi}.spm.spatial.coreg.estimate.source(1).tname = 'Source Image';
matlabbatch{bi}.spm.spatial.coreg.estimate.source(1).tgt_spec{1}(1).name = 'filter';
matlabbatch{bi}.spm.spatial.coreg.estimate.source(1).tgt_spec{1}(1).value = 'image';
matlabbatch{bi}.spm.spatial.coreg.estimate.source(1).tgt_spec{1}(2).name = 'strtype';
matlabbatch{bi}.spm.spatial.coreg.estimate.source(1).tgt_spec{1}(2).value = 'e';
matlabbatch{bi}.spm.spatial.coreg.estimate.source(1).sname = 'Realign: Estimate & Reslice: Mean Image';
matlabbatch{bi}.spm.spatial.coreg.estimate.source(1).src_exbranch = substruct('.','val', '{}',{bi-1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{bi}.spm.spatial.coreg.estimate.source(1).src_output = substruct('.','rmean');
matlabbatch{bi}.spm.spatial.coreg.estimate.other(1) = cfg_dep;
matlabbatch{bi}.spm.spatial.coreg.estimate.other(1).tname = 'Other Images';
matlabbatch{bi}.spm.spatial.coreg.estimate.other(1).tgt_spec{1}(1).name = 'filter';
matlabbatch{bi}.spm.spatial.coreg.estimate.other(1).tgt_spec{1}(1).value = 'image';
matlabbatch{bi}.spm.spatial.coreg.estimate.other(1).tgt_spec{1}(2).name = 'strtype';
matlabbatch{bi}.spm.spatial.coreg.estimate.other(1).tgt_spec{1}(2).value = 'e';
matlabbatch{bi}.spm.spatial.coreg.estimate.other(1).sname = 'Realign: Estimate & Reslice: Realigned Images (Sess 1)';
matlabbatch{bi}.spm.spatial.coreg.estimate.other(1).src_exbranch = substruct('.','val', '{}',{bi-1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{bi}.spm.spatial.coreg.estimate.other(1).src_output = substruct('.','sess', '()',{1}, '.','cfiles');
matlabbatch{bi}.spm.spatial.coreg.estimate.other(2) = cfg_dep;
matlabbatch{bi}.spm.spatial.coreg.estimate.other(2).tname = 'Other Images';
matlabbatch{bi}.spm.spatial.coreg.estimate.other(2).tgt_spec{1}(1).name = 'filter';
matlabbatch{bi}.spm.spatial.coreg.estimate.other(2).tgt_spec{1}(1).value = 'image';
matlabbatch{bi}.spm.spatial.coreg.estimate.other(2).tgt_spec{1}(2).name = 'strtype';
matlabbatch{bi}.spm.spatial.coreg.estimate.other(2).tgt_spec{1}(2).value = 'e';
matlabbatch{bi}.spm.spatial.coreg.estimate.other(2).sname = 'Realign: Estimate & Reslice: Resliced Images (Sess 1)';
matlabbatch{bi}.spm.spatial.coreg.estimate.other(2).src_exbranch = substruct('.','val', '{}',{bi-1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{bi}.spm.spatial.coreg.estimate.other(2).src_output = substruct('.','sess', '()',{1}, '.','rfiles');
matlabbatch{bi}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
matlabbatch{bi}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
matlabbatch{bi}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
matlabbatch{bi}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];

bi = bi + 1;
matlabbatch{bi}.spm.spatial.preproc.data = S;
matlabbatch{bi}.spm.spatial.preproc.output.GM = [0 0 1];
matlabbatch{bi}.spm.spatial.preproc.output.WM = [0 0 1];
matlabbatch{bi}.spm.spatial.preproc.output.CSF = [0 0 0];
matlabbatch{bi}.spm.spatial.preproc.output.biascor = 1;
matlabbatch{bi}.spm.spatial.preproc.output.cleanup = 0;
matlabbatch{bi}.spm.spatial.preproc.opts.tpm = {
                                               fullfile(path_to_spm8, 'tpm', 'csf.nii,1')
                                               fullfile(path_to_spm8, 'tpm', 'grey.nii,1')
                                               fullfile(path_to_spm8, 'tpm', 'white.nii,1')
                                               };
matlabbatch{bi}.spm.spatial.preproc.opts.ngaus = [2
                                                 2
                                                 2
                                                 4];
matlabbatch{bi}.spm.spatial.preproc.opts.regtype = 'mni';
matlabbatch{bi}.spm.spatial.preproc.opts.warpreg = 1;
matlabbatch{bi}.spm.spatial.preproc.opts.warpco = 25;
matlabbatch{bi}.spm.spatial.preproc.opts.biasreg = 0.0001;
matlabbatch{bi}.spm.spatial.preproc.opts.biasfwhm = 60;
matlabbatch{bi}.spm.spatial.preproc.opts.samp = 3;
matlabbatch{bi}.spm.spatial.preproc.opts.msk = {''};

bi = bi + 1;
matlabbatch{bi}.spm.spatial.normalise.write.subj.matname(1) = cfg_dep;
matlabbatch{bi}.spm.spatial.normalise.write.subj.matname(1).tname = 'Parameter File';
matlabbatch{bi}.spm.spatial.normalise.write.subj.matname(1).tgt_spec{1}(1).name = 'filter';
matlabbatch{bi}.spm.spatial.normalise.write.subj.matname(1).tgt_spec{1}(1).value = 'mat';
matlabbatch{bi}.spm.spatial.normalise.write.subj.matname(1).tgt_spec{1}(2).name = 'strtype';
matlabbatch{bi}.spm.spatial.normalise.write.subj.matname(1).tgt_spec{1}(2).value = 'e';
matlabbatch{bi}.spm.spatial.normalise.write.subj.matname(1).sname = 'Segment: Norm Params Subj->MNI';
matlabbatch{bi}.spm.spatial.normalise.write.subj.matname(1).src_exbranch = substruct('.','val', '{}',{bi-1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{bi}.spm.spatial.normalise.write.subj.matname(1).src_output = substruct('()',{1}, '.','snfile', '()',{':'});
matlabbatch{bi}.spm.spatial.normalise.write.subj.resample(1) = cfg_dep;
matlabbatch{bi}.spm.spatial.normalise.write.subj.resample(1).tname = 'Images to Write';
matlabbatch{bi}.spm.spatial.normalise.write.subj.resample(1).tgt_spec{1}(1).name = 'filter';
matlabbatch{bi}.spm.spatial.normalise.write.subj.resample(1).tgt_spec{1}(1).value = 'image';
matlabbatch{bi}.spm.spatial.normalise.write.subj.resample(1).tgt_spec{1}(2).name = 'strtype';
matlabbatch{bi}.spm.spatial.normalise.write.subj.resample(1).tgt_spec{1}(2).value = 'e';
matlabbatch{bi}.spm.spatial.normalise.write.subj.resample(1).sname = 'Coregister: Estimate: Coregistered Images';
matlabbatch{bi}.spm.spatial.normalise.write.subj.resample(1).src_exbranch = substruct('.','val', '{}',{bi-2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{bi}.spm.spatial.normalise.write.subj.resample(1).src_output = substruct('.','cfiles');
matlabbatch{bi}.spm.spatial.normalise.write.roptions.preserve = 0;
matlabbatch{bi}.spm.spatial.normalise.write.roptions.bb = [-78 -112 -50
                                                          78 76 85];
matlabbatch{bi}.spm.spatial.normalise.write.roptions.vox = [3 3 3];
matlabbatch{bi}.spm.spatial.normalise.write.roptions.interp = 1;
matlabbatch{bi}.spm.spatial.normalise.write.roptions.wrap = [0 0 0];
matlabbatch{bi}.spm.spatial.normalise.write.roptions.prefix = 'w';

bi = bi + 1;
matlabbatch{bi}.spm.spatial.smooth.data(1) = cfg_dep;
matlabbatch{bi}.spm.spatial.smooth.data(1).tname = 'Images to Smooth';
matlabbatch{bi}.spm.spatial.smooth.data(1).tgt_spec{1}(1).name = 'filter';
matlabbatch{bi}.spm.spatial.smooth.data(1).tgt_spec{1}(1).value = 'image';
matlabbatch{bi}.spm.spatial.smooth.data(1).tgt_spec{1}(2).name = 'strtype';
matlabbatch{bi}.spm.spatial.smooth.data(1).tgt_spec{1}(2).value = 'e';
matlabbatch{bi}.spm.spatial.smooth.data(1).sname = 'Normalise: Write: Normalised Images (Subj 1)';
matlabbatch{bi}.spm.spatial.smooth.data(1).src_exbranch = substruct('.','val', '{}',{bi-1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{bi}.spm.spatial.smooth.data(1).src_output = substruct('()',{1}, '.','files');
matlabbatch{bi}.spm.spatial.smooth.fwhm = [8 8 8];
matlabbatch{bi}.spm.spatial.smooth.dtype = 0;
matlabbatch{bi}.spm.spatial.smooth.im = 0;
matlabbatch{bi}.spm.spatial.smooth.prefix = 's';

% Save job
eval(['save jobs_preproc_' datestr(now,30) ' matlabbatch']);

% Run job
spm_jobman('initcfg');
spm_jobman('serial',matlabbatch);
end % end script