function conn_1stlevel_ttest()
% First-level t-test for CONN
% make sure to cd to the firstlevel folder in your CONN project before running this script
% By Alfonso Nieto-Castanon and Stephen Karl Larroque
% From an original script here: https://www.nitrc.org/forum/message.php?msg_id=10082
% v1.0
% 2014-2019

% PARAMETERS - EDIT ME
threshold=0.05; % p-FDR threshold
conds = {'Subject037_Condition001', 'Subject038_Condition001'}; % conditions to use for the t-test
contrast=[-1 1]; % contrast to use

% Main script, do not modify

% Prepare the output string describing the contrast
contraststr = {};
for i=1:numel(conds)
    contraststr{end+1} = sprintf('%dx%s', contrast(i), conds{i});
end
contraststr = join(contraststr, '_');
contraststr = contraststr{1};

% Compute degrees of freedom and standard error
dof = [];
for cond=conds
    d = load(['resultsROI_' cond{1} '.mat'],'DOF');
    dof(end+1) = d.DOF;
end
se=sqrt(sum(1./max(0, dof-3)));

% Get list of sources (we will compute the difference map for each!
files=dir(['BETA_' conds{1} '_Source*.nii']); % list beta files (to get the sources list, not for the t-test)
sources=cellfun(@(x)sscanf(x,['BETA_' conds{1} '_Source%d.nii']),{files.name}); % list sources integer numbers

% For each source (seed)
for source=sources
    % Get the beta (z) maps for each condition
    filenames=arrayfun(@(cond)sprintf('BETA_%s_Source%03d.nii',cond{1},source),conds, 'uni', 0);
    a=spm_vol(char(filenames));
    z=spm_read_vols(a);
    % Get the brain mask (the voxels outside the brain being nans or 0)
    mask=any(isnan(z),4)|all(z==0,4);

    % Apply the contrast to each zmap
    zmaps = zeros(size(z));
    for i=1:numel(conds)
        zmaps(:,:,:,i) = z(:,:,:,i).*contrast(i);
    end
    % Compute t-test and get the (unthresholded) contrast z-map
    diffmap=sum(zmaps, 4); % t-test (simply sum with the contrasts, so it will do +, -, etc)
    % Save this map
    filename=sprintf('BETA_%s_Source%03d.nii', contraststr, source);
    V=struct('mat',a(1).mat,'dim',a(1).dim,'fname',filename,'pinfo',[1;0;0],'n',[1,1],'dt',[spm_type('float32') spm_platform('bigend')]);
    spm_write_vol(V,diffmap);

    % Compute uncorrected p-values map
    p=spm_Ncdf(diffmap/se); % difference in correlations p-value
    p=2*min(p,1-p); % two-sided p-values (remove for one-sided)
    p(mask)=nan;
    filename=sprintf('p_corr_%s_Source%03d.nii', contraststr, source);
    V=struct('mat',a(1).mat,'dim',a(1).dim,'fname',filename,'pinfo',[1;0;0],'n',[1,1],'dt',[spm_type('float32') spm_platform('bigend')]);
    spm_write_vol(V,p);

    % Compute voxel-wise corrected p-values map
    p(:)=conn_fdr(p(:));
    filename=sprintf('pFDR_corr_%s_Source%03d.nii', contraststr, source);
    V=struct('mat',a(1).mat,'dim',a(1).dim,'fname',filename,'pinfo',[1;0;0],'n',[1,1],'dt',[spm_type('float32') spm_platform('bigend')]);
    spm_write_vol(V,p);

    % Compute p-FDR < 0.05 thresholded p-values map
    pthresh=double(p<threshold); % threshold the p-FDR map to p < 0.05
    filename=sprintf('pFDR_thresholded_corr_%s_Source%03d.nii', contraststr, source);
    V=struct('mat',a(1).mat,'dim',a(1).dim,'fname',filename,'pinfo',[1;0;0],'n',[1,1],'dt',[spm_type('uint8') spm_platform('bigend')]);
    spm_write_vol(V,pthresh);

    % Compute difference z-map (BETA map) thresholded at p-FDR < 0.05
    diffmapthresh=diffmap.*pthresh; % save difference BETA (Z) map thresholded at p-FDR < 0.05
    filename=sprintf('BETA_thresholded_%s_Source%03d.nii', contraststr, source);
    V=struct('mat',a(1).mat,'dim',a(1).dim,'fname',filename,'pinfo',[1;0;0],'n',[1,1],'dt',[spm_type('float32') spm_platform('bigend')]);
    spm_write_vol(V,diffmapthresh);

    % Compute positive/negative parts of the thresholded difference z-map
    % (to ease visualization)
    diffmapthreshpos=diffmapthresh.*(diffmapthresh>0); % save only positive side (easier for visualizations)
    filename=sprintf('BETA_thresholdedpos_%s_Source%03d.nii', contraststr, source);
    V=struct('mat',a(1).mat,'dim',a(1).dim,'fname',filename,'pinfo',[1;0;0],'n',[1,1],'dt',[spm_type('float32') spm_platform('bigend')]);
    spm_write_vol(V,diffmapthreshpos);
    diffmapthreshneg=diffmapthresh.*(diffmapthresh<0); % save only negative side (easier for visualizations)
    filename=sprintf('BETA_thresholdedneg_%s_Source%03d.nii', contraststr, source);
    V=struct('mat',a(1).mat,'dim',a(1).dim,'fname',filename,'pinfo',[1;0;0],'n',[1,1],'dt',[spm_type('float32') spm_platform('bigend')]);
    spm_write_vol(V,diffmapthreshneg);
end
end