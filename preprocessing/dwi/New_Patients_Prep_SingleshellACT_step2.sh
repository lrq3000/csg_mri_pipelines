#!/bin/bash

WORKDIR=$(pwd)
# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")
echo "Working from directory: $WORKDIR"

forcewhite=""
if [ $# -ge 1 ]; then
    forcewhite="$1"
fi

#run first ipython /home/brain/Downloads/FromEnri/DTI/EA_modules/EA_coreg.py and extract #Transform_t1_bet_pve_2_flirt_flirt.mat and t1_bet_pve_2_flirt_flirt.nii.gz then launch #New_patients_Prep2.sh
#flirt -in t1_bet_pve_1.nii -ref t1_bet_pve_2_flirt_flirt.nii -out GMdiffusion.nii -init Transform_t1_bet_pve_2_flirt_flirt.mat -applyxfm
#mv t1_bet_pve_2_flirt_flirt.nii WMdiffusion.nii
#fslmaths GMdiffusion.nii.gz -add WMdiffusion.nii.gz GM_WM_diffusion.nii
#gunzip GM_WM_diffusion.nii.gz

# Cleanup before beginning (if we already launched the analysis before)
rm -f WM.nii GM.nii
rm -f fathr015.nii DTIValueBefore.txt DTIValueAfter.txt
cp t1_bet_pve_2.nii WM.nii
cp t1_bet_pve_1.nii GM.nii

# If forcewhite is provided, then use that and don't ask any question
if [ -n "$forcewhite" ]; then
    choice_wmgm="$forcewhite"
else
    echo "Please check the White Matter (WM.nii) and Grey Matter (GM.nii)"
    mrview GM.nii &
    mrview WM.nii &
    echo "Use only the white matter (y) or use white+grey (n) ?:"
    read choice_wmgm
fi
# Use white+grey if user wants
if [ "$choice_wmgm" == "n" ]; then
    echo "Merging Grey and White matter, please wait..."
    rm -f WM.nii.gz
    fslmaths WM.nii -add GM.nii WM.nii.gz # fslmaths always save as 4D nifti, even if you just output "WM.nii", it will be named "WM.nii.gz"
    gunzip -f WM.nii.gz
    rm -f WM.nii.gz
fi

echo "Launching SPM coregistration and resampling, please wait..."
matlab -nodesktop -nosplash -r "addpath(genpath('$SCRIPTPATH'));process_spm_coreg_and_exit('fathr.nii', 'WM.nii', 'WMdiff.nii', 'WM.nii', 'GMdiff.nii', 'GM.nii');quit();"
matlab -nodesktop -nosplash -r "addpath(genpath('$SCRIPTPATH'));process_spm_coreg_and_exit('fathr.nii', 'WM.nii', 'T1diff.nii', 'T1.nii');quit();"

matlab -nodesktop -nosplash -r "addpath(genpath('$SCRIPTPATH'));Resample_im('mask.nii','WMdiff.nii','mask3.nii');quit();"


matlab -nodesktop -nosplash -r "addpath(genpath('$SCRIPTPATH'));EA_masking('mask3.nii','WMdiff.nii','WMdiff_masked.nii');quit();"

matlab -nodesktop -nosplash -r "addpath(genpath('$SCRIPTPATH'));Resample_im('WMdiff_masked.nii','mask.nii','WMdiff_masked2.nii');quit();"

# Quality Assurance: check if the WM mask is not cutting too much (and it eases interpretation)
mricron WMdiff.nii -o mask3.nii -b 50 -t 50 &


#Pacho number
fslmaths fa.nii -thr 0.15 fathr015.nii
fslstats fa.nii -M -S -V > DTIValueBefore.txt
fslstats fathr015.nii -M -V > DTIValueAfter.txt
