function [T_thr, P_thr] = threshold_fdr(mcc, thr, df, imfilepath, STAT, conjonc_nb, mask, twotailed, SPM, correlmap)
% threshold_fdr(mcc, thr, df, imfilepath, STAT, conjonc_nb, mask, twotailed)
% (For SPM12) This script allows the thresholding of any nifti file, no need for a SPM.mat structure. It supports FDR but also FWE and p-uncorrected, and also Nichols min-T conjunction (conjunction null hypothesis).
% If no argument is given, a SPM (minimal) GUI will open to ask for the required parameters.
%
% Inputs:
% imfilepath : can be any neuroimage, but generally you want to use the unthresholded maps, also called the T maps, in other words in SPM the contrast maps which are named spmT_XXXX.nii, where XXXX is the position of the contrast in the contrast manager (first, second, etc).
% twotailed : false by default, the test is one-tailed (we only look at positive OR negative correlations), but if you want to do both (for example after merging both), then you should do a two-tailed test.
% if using mcc = 'FWE', you need to provide a SPM.mat file in SPM variable (because else we cannot know what is the search volume). If you use a conjunction, please check beforehand that both SPM.mat have the same R (resel count) and S (number of voxels). Else you can try to use the highest S and min R (for the latter not sure, please check with a statistician who knows SPM!).
% correlmap : BUGGY DO NOT USE: boolean true/false to specify if the supplied imfilepath is in fact a correlation map instead of a T/Z map.
%
% Outputs:
% T_thr : corrected T threshold (at the voxel level, this is what is used to threshold the map at the end).
% P_thr : corrected P threshold (at voxel level)
% Also saves the thresholded and binarized nifti images (same filename as input but additional characters at the end to describe the correction and if thresholded or binarized (mask)).
%
% NOTE that this script does not do cluster-size thresholding, only voxel-wise thresholding, because cluster-wise thresholding needs to know the topology (resel, fwhm, etc), which is currently impossible to reliably estimate from a correlation map, a SPM.mat is then needed, and if you have a SPM.mat at hand, then you can directly use SPM to compute cluster-wise thresholding or Nichols script which is way more polished than mine (search for CorrClusTh.m, v1.13 currently for SPM12, https://warwick.ac.uk/fac/sci/statistics/staff/academic-research/nichols/scripts/spm/).
%
% By Stephen Larroque, Coma Science Group, GIGA-Consciousness, University and Hospital of Liege
% Created on 2017-11-29
%
% v0.1.0
%
% TODO:
% * Different results from conn_fdr and conn_clusters, the threshold here is lower (CONN is more conservative than SPM for the same thresholds)
% * Allow cluster-wise correction
% * Try to support Z maps (BETA_SubjectXXX_ConditionYYY_SourceZZZ.nii from CONN)
%
% Resources:
% https://warwick.ac.uk/fac/sci/statistics/staff/academic-research/nichols/scripts/spm/johnsgems5/corrclusth.m
% https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=ind1109&L=spm&P=R92768&1=spm&9=A&I=-3&J=on&d=No+Match%3BMatch%3BMatches&z=4
% http://andysbrainblog.blogspot.be/2013/10/whats-in-spmmat-file.html
% http://www.ehu.eus/ccwintco/index.php?title=Statistical_Parametric_Mapping
% http://blogs.warwick.ac.uk/nichols/entry/fwhm_resel_details/
% https://matthew-brett.github.io/teaching/random_fields.html
% http://andysbrainblog.blogspot.be/2015/07/converting-t-maps-to-z-maps.html
% https://www.nitrc.org/forum/forum.php?thread_id=3027&forum_id=1144
%

if ~exist('mcc', 'var') | isempty(mcc)
    % statistical correction kind selector from spm_getSPM.m
    mcc = spm_input('Voxel-wise p-value adjustment to control','+1','b','FWE|FDR|unc',[],1);
end
if ~exist('thr', 'var') | isempty(thr)
    thr    = spm_input('Enter voxel-wise threshold','+0','r',0.05,1);
end
if ~exist('df', 'var') | isempty(df)
    % degrees of freedom (at 1st level = nb of timepoints per subject - number of 1st-level covariates; at 2nd-level = nb of subjects - nb of regressors/2nd-level covariates kinds)
    df    = spm_input('Enter degrees of freedom');
end
if ~exist('imfilepath', 'var') | isempty(imfilepath)
    imfilepath  = spm_select([1 Inf],'image','Select T image(s) (minT conjunction if multiple)');
end
if ~exist('STAT', 'var') | isempty(STAT)
    STAT = 'T';
    %STAT  = spm_input('Kind of statistical map provided (T-map or P-values map):','+1','b','T|P',[],1);
end
if ~exist('conjonc_nb', 'var') | isempty(conjonc_nb)
    conjonc_nb = size(imfilepath,1); % number of conjunctions
end
if ~exist('mask', 'var') | isempty(mask)
    mask  = 0;
end
if ~exist('twotailed', 'var') | isempty(twotailed)
    twotailed  = false;
end
if ~exist('correlmap', 'var') | isempty(correlmap)
    correlmap = false;
end

% T map loading
V = spm_vol(imfilepath(1,:));
Torig     = spm_read_vols(V);     % Load T image, or spm_data_read()
if size(imfilepath,1) > 1 % Nichols minT conjunction: we load all images and just do the min of all voxels T values
    Torig_pos = Torig;
    Torig_pos(Torig_pos<0) = 0;
    Torig_neg = Torig;
    Torig_neg(Torig_neg>0) = 0;
    for i=2:size(imfilepath,1)
        % Load the next image
        Torig2 = spm_data_read(imfilepath(i,:));
        % Process the min separately for positive and negative maps
        Torig_pos = min(Torig_pos, Torig2);
        Torig_neg = max(Torig_neg, Torig2);
    end
    % Merge back the positive and negative
    Torig = Torig_pos + Torig_neg;
    % For voxels that have both positive and negative, it's undefined, we set to 0 to be conservative
    Torig(Torig_pos < 0 & Torig_neg > 0) = 0;
end

% T preprocessing, Copied from spm_uc_FDR.m
% Can compute T to input to spm_uc* like the following, but better just provide spm_vol(imfilepath) struct and let SPM do its magic, this will be better future compatible!
%T(T==mask) = []; % masking
%T(isnan(T)) = []; % Nan need to be removed
%T = sort(T(:));
%if STAT ~= 'P', T = flipud(T); end
%Ps = spm_z2p(T,[1 df],STAT,conjonc_nb); % Calculate p values of image, this is what is needed to input to spm_uc* (or a spm_vol() struct), but NOT the T values!
% Alternative way:
%Pval  = 2*(1-spm_Tcdf(abs(T),df));        % Compute P-values

if correlmap % we were supplied a correlatiom map (r-map), convert it to a z-map
    % BUGGY DO NOT USE
    zmap = .5.*log((1+Torig)./(1-Torig));
    zmap = real(Torig); % keep only the real part
    %pmap = norminv(1-Torig,0,1);
    tmap = tinv(normcdf(zmap,0,1), df);
    Torig = tmap;
end %endif

switch lower(mcc)
    case 'fwe' % Family-wise false positive rate
        S = numel(find(Torig)); % number of non-null voxels
        SPM = load('SPM');
        R = SPM.SPM.xVol.R; % resel count of the search volume
        T_thr = spm_uc(thr,[1 df],STAT,R,conjonc_nb,S);
        % TODO: what is the difference with spm_uc(thr,[1 df],STAT,S,conjonc_nb)
    case 'fdr' % False discovery rate
        T_thr = spm_uc_FDR(thr,[1 df],STAT,conjonc_nb,V,0); % Assumes one-sided P-values, see below for the two-sided fix
    case 'unc' % No adjustment: p for conjunctions is p of the conjunction SPM
        T_thr = spm_u(thr,[1 df],STAT);
    otherwise
        %--------------------------------------------------------------
        fprintf('\n');                                              %-#
        error('Unknown control method "%s".',mcc);
end %endswitch mcc

% Compute corrected voxel-wise P threshold (i.e., corrected for multiple comparison, note that this is a general formula that also works if p-uncorrected then corrected P_thr = thr)
%if strcmpi(STAT, 'P') % we were provided a P-values map, then we need to switch T and P and compute T threshold from P
%    P_thr = T_thr;
%    T_thr = spm_invTcdf(1-P_thr,df);
%else % else we have a T map, just compute the voxel correct P threshold
P_thr = 1-spm_Tcdf(T_thr,df);
%end %endif

if twotailed
    % Two-tailed test (for both positive and negative), by Thomas Nichols:
    % https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=ind03&L=spm&P=R344965&1=spm&9=A&I=-3&J=on&d=No+Match%3BMatch%3BMatches&z=4
    T_thr_twotail = spm_invTcdf(1-P_thr/2,df);  % Correct FDR T thresh
    P_thr_twotail = 1-spm_Tcdf(T_thr_twotail,df);
end

% Display results
if ~twotailed
    T_thr
    P_thr
else
    T_thr_twotail
    P_thr_twotail
    % Switch variables for thresholding and saving images below
    T_thr = T_thr_twotail;
    P_thr = P_thr_twotail;
end

% threshold original t-map
%if strcmpi(STAT, 'P') % we got a P-values map
%    map_mask = Torig < P_thr;
%    map_thr = Torig .* (Torig < P_thr);
%else % we got a T map
if twotailed % threshold both positive and negative
    map_mask = (Torig < -T_thr) | (Torig > T_thr);
    map_thr = Torig .* map_mask;
else
    if max(max(max(Torig))) > 0 % positive part thresholding
        map_mask = Torig > T_thr;  % will create a binary image
        map_thr = Torig .* map_mask;  % will create an image with all original values exceeding thr_ori
    else % negative part thresholding
        map_mask = Torig < -T_thr;
        map_thr = Torig .* map_mask;
    end %endif
end %endif
%end %endif

% write out the thresholded and binarized images
[p nm e v] = spm_fileparts(imfilepath(1,:));
V_old = spm_vol(imfilepath(1,:));
V_new = V_old;
%V_new.fname = [p filesep nm '_thr_pfdr_' e];
V_new.fname = [nm '_p-' lower(mcc) num2str(thr) '_thr' e];
spm_write_vol(V_new, map_thr);
V_new.fname = [nm '_p-' lower(mcc) num2str(thr) '_mask' e];
spm_write_vol(V_new, map_mask);
if correlmap | size(imfilepath,1) > 1
    V_new.fname = [nm '_tmap' e];
    spm_write_vol(V_new, Torig);
end %endif

end % endfunction
