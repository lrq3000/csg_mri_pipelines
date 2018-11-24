#!/bin/bash
# Single subject Single-shell DTI analysis WITH ACT for the Coma Science Group, by Enrico Amico (2012-2016) enhanced by Stephen Karl Larroque (2016-2018).
# Works also on multi-shell data, but will do single-shell analysis.
# Required libraries: dcmtk dcmdjpeg (just to uncompress), mrtrix v3, trackvis, FSL, Python 2, SPM (just for reorientation).
# v1.1.3
# Updated to MRTRIX3 major update: http://www.mrtrix.org/2016/03/12/major-update-to-mrtrix3/
# Updated again on 19-07-2018 to latest MRTRIX3 github commit: d6656921594f22517d489a7f9f2d2598bcf18ce6


# TODO: automatically do the T1 and dwi conversion commands, but show to user so that he can check. And if confusion, ask user to do it (if we cannot know which T1 or DTI to use).
# Note: DO NOT use another DICOM->NIFTI converter! For example, mriconvert mcverter will output rounded values for grad.bvecs and grad.bvals, so beware!
# TODO: at the end, with Trackvis, autogenerate the images (need to turn but also put in high resolution and zoom a bit to be the correct size).

# CHANGEME: path to MRTRIX3 (necessary to know where the dwi2response script is)
MRTRIX3="/home/brain/neurotools/mrtrix3"

# Initialization
# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")
# Current script filename
SCRIPTNAME=$(basename "$0")

# Help message
if [ $# -lt 1 ]; then
    echo "Usage: ./$SCRIPTNAME /path/to/root/of/dicom/dir/"
    echo "Note: input should be dicom folder with subdirectories being modalities, do not input niftis! (because mrtrix is more precise to extract gradients and dti image)."
    exit
fi

echo "======= DTI SINGLE-PATIENT PIPELINE ======="
# Change directory to the specified argument
cd "$1"
# Current working directory (for debug)
WORKDIR=$(pwd)
echo "Working from directory: $WORKDIR"

echo "== Extracting nifti images and gradients from DICOM"
# Display list of dicom modalities
echo "q" | mrinfo .
# Uncompress if JPEG2000 compressed? (need dcmtk dcmdjpeg!)
echo "Is the DICOM JPEG2000 compressed? (if the sessions are not readable (red messages), then can use dcmtk dcmdjpeg to uncompress): [y/n] "
read choice_uncompress
if [ "$choice_uncompress" == "y" ]; then
    for f in $(find .); do dcmdjpeg $f $f; done
    echo "q" | mrinfo .
fi
# What number for T1?
echo "Please input the number to select T1: "
read choice_t1
# What number for DTI?
echo "Please input the number to select DTI: "
read choice_dti
#echo "Please input the number of DTI slices per volume: "
#read nb_dti_grad_dim # Check this with mrinfo on dti, this is the 4th dimension of the DTI image
# TODO: detect from grad.bvals = (b0 + all vectors) * 2 (the measurement is always repeated twice)
# Multishell?
echo "If the data is multishell, enter b-value of the shell to extract? [integer or 0 for no multishell] "
read choice_multishell
# Use white matter only or white + grey?
echo "Use only white matter [y] or white+grey [n]? [y/n] "
read forcewhite
# Extract T1 and DTI images and the DTI gradients vectors
echo "Overwrite any image if necessary? [y/n] "
read choice_overwrite
if [ "$choice_overwrite" == "y" ]; then
    rm T1.nii
    rm dwi.nii
    rm grad.txt grad.bvecs grad.bvals
fi
echo "$choice_t1" | mrconvert . T1.nii
if [ "$choice_multishell" -gt "0" ]; then
    # Multishell data, extract the first non zero b-values shell (must provide -shells 0,<b-value> to extract a specific shell, else will extract the highest b-value)
    echo "$choice_dti" | dwiextract . dwi.nii -singleshell -bzero -export_grad_mrtrix grad.txt -export_grad_fsl grad.bvecs grad.bvals -shells 0,"$choice_multishell"
else
    # Singleshell data, simply convert
    echo "$choice_dti" | mrconvert . dwi.nii
    echo "$choice_dti" | mrinfo . -export_grad_mrtrix grad.txt -export_grad_fsl grad.bvecs grad.bvals
fi

# Get the gradients dimension count from the gradients files
gradients_count=`cat grad.bvals | wc -w`

# Manual reorientation of T1 and DTI using SPM
# This allows to have a better coregistration and segmentation, and also at the end to have a better oriented visualization in Trackis (else the brain can be tilted sideways, etc.).
echo "== Reorienting images"
echo "Please manually reorient T1."
matlab -nodesktop -nosplash -r "cd '$WORKDIR'; spm_image('display', '$WORKDIR/T1.nii'); fprintf('Please manually reorient the T1 image. Type quit() when you are done reorienting the image.');"
echo "Please manually reorient DTI."
matlab -nodesktop -nosplash -r "cd '$WORKDIR'; spm_image('display', '$WORKDIR/dwi.nii'); fprintf('Please manually reorient the DTI image. Type quit() when you are done reorienting the image.');"

# Start DTI preprocessing
echo "== Starting DTI part 1"
"$SCRIPTPATH/New_Patients_Prep_SingleshellACT_step1.sh" "$gradients_count"
echo "== Starting DTI part 2"
"$SCRIPTPATH/New_Patients_Prep_SingleshellACT_step2.sh" "$forcewhite"
echo "== Starting DTI part 3"
"$SCRIPTPATH/New_Patients_Prep_SingleshellACT_step3.sh" "$MRTRIX3"

# Lastly: If there is any error, stop and restart! If not, open with trackvis!
trackvis "$WORKDIR/Allbrain.trk" -new
