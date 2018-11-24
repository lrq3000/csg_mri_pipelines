#!/bin/bash

# Get argument
gradients_count=$1 # Get the gradients dimensions count as an argument

# Get working dir
WORKDIR=$(pwd)
# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")

echo "Working from directory: $WORKDIR"
echo $nb_dti_grad_dim

rm -f index.txt nodif.nii nodif.nii.gz mask.nii mask.nii.gz
rm -f dwicorr.nii
rm -f dwicorr.nii.gz tensor.nii fa.nii fathr.nii fathr.nii.gz
rm -f t1_bet.nii t1_bet.nii.gz t1_bet_pve_*

sed -i 's/nan/0/g' grad.*
# TODO: autodetect number of volumes (using mrinfo?)
for (( i=1;i<=$gradients_count;i++)); do printf "%i " 1 >> index.txt; done
fslroi dwi.nii nodif 0 1
gunzip nodif.nii.gz
bet nodif mask -f 0.4 -g 0.15 -c 62 63 26 -n -m  
mv mask_mask.nii.gz mask.nii.gz
gunzip mask.nii.gz
# TODO: Only run for old acquisition protocol, (if voxel dimension is a non-int like 1.8)
#mrconvert -datatype UInt16 -vox 2,2,2 mask.nii mask2.nii
#mrconvert -datatype UInt16 -vox 2,2,2 dwi.nii dwi2.nii
# motion correction for diffusion imaging
# acqp.txt is a fixed file for all patients = acquisition parameters for the scan for the CHU (for another scanner you need to change)
# TODO: auto set path of acqp.txt (in the same folder as current script) + check if exists at the start of this script
# TODO: blocking commands (convert to Python?): if a command fail, stop everything
# TODO: check if each file exists before using, and force scripts to overwrite files! Do not ask!
# TODO: add status messages and progress bar? for example when eddy is launched, say that it is currently processing (and check CPU activity of eddy process?)
# TODO: auto overwrite all files (can input --force to this script) without asking first
# TODO: write a copy of console output to a log file, for all softwares called!
echo "Motion correction using fsl eddy, this can take a while..."
eddy --very_verbose --imain=dwi.nii --mask=mask.nii --index=index.txt --acqp=$SCRIPTPATH/acqp.txt --bvecs=grad.bvecs --bvals=grad.bvals --out=dwicorr.nii # can also do --very_verbose

# Tensor directions estimation
echo "Tensor directions estimation, this can also take a while..."
gunzip dwicorr.nii.gz
dwi2tensor -force -grad grad.txt -mask mask.nii dwicorr.nii tensor.nii
tensor2metric -force -mask mask.nii tensor.nii -adc adc.nii -fa fa.nii -vector RGB_fa.nii
fslmaths fa.nii -thr 0.20 fathr.nii
gunzip fathr.nii.gz
# fa.nii = fractional anistotropy estimation

#Segmentation with fast and registration to native space (t1 and aal)
#### T1 registration to mni, GM and WM mask creation (pve 2 WM, 1 GM, 0 CSF)
echo "Segmentation using BET..."
bet T1.nii t1_bet -m -f .4 -v
gunzip t1_bet.nii.gz
echo "Coregistration using FAST..."
fast -v t1_bet.nii
gunzip t1_bet_pve_*

# Quality Assurance: Check segmentation using mricron (display white and grey matter segmentation over skull extracted brain)
mricron t1_bet.nii -o t1_bet_pve_2.nii -o t1_bet_pve_1.nii -b 50 -t 50 &

# Extra (registration, stuff)
#flirt -in mask2.nii -ref t1_bet_pve_2.nii -out mask_t1.nii
#fslmaths mask_t1.nii -mul t1_bet_pve_2.nii WM.nii
#fslmaths mask_t1.nii -mul t1_bet_pve_1.nii GM.nii
## segmentation might fail, in patients is important to add this extra step (change EA_coreg.py accordingly!!!)
#cp /usr/share/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz MNI152_T1_1mm_brain.nii.gz
#cp /usr/share/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz MNI152_T1_2mm_brain.nii.gz
#gunzip MNI152_T1_1mm_brain.nii.gz
#gunzip MNI152_T1_2mm_brain.nii.gz
##### run EA_coreg.py then EA_coreg.sh then DtiTMS2.sh
# run first ipython /home/enrico/Dropbox/Ulg/My_fun/DTI/EA_modules/EA_coreg.py and extract Transform_t1_bet_pve_2_flirt_flirt.mat and t1_bet_pve_2_flirt_flirt.nii.gz then launch New_patients_Prep2.sh WARNING! U should be in the structurefunction folder on dropbox when launching AND don't forget to copy aal.nii into the patient folder
