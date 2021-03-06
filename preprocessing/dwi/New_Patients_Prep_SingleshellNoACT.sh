#!/bin/bash
# Single subject Single-Shell DTI analysis WITHOUT ACT for the Coma Science Group, by Stephen Karl Larroque (2018).
# Required libraries: dcmtk dcmdjpeg (just to uncompress), mrtrix v3, trackvis, FSL, Python 2, ANTS.
# v2.0.0
# License: MIT
#
# Tested on 19-07-2018 to latest MRTRIX3 github commit (post 3.0 RC3): d6656921594f22517d489a7f9f2d2598bcf18ce6
# Also requires eddy v5.0.11 (for movement/slice timing correction and multishell acquired in separate sequences)
# IMPORTANT: you need to specify a slspec.txt file with the slice order. If you don't have it or do not wish to correct for this type of motion, select the appropriate choice at the prompt.

# TODO: automatically do the T1 and dwi conversion commands, but show to user so that he can check. And if confusion, ask user to do it (if we cannot know which T1 or DTI to use).
# Note: DO NOT use another DICOM->NIFTI converter! For example, mriconvert mcverter will output rounded values for grad.bvecs and grad.bvals, so beware!
# TODO: at the end, with Trackvis, autogenerate the images (need to turn but also put in high resolution and zoom a bit to be the correct size).

# CHANGEME: path to MRTRIX3 (necessary to know where the dwi2response script is)
MRTRIX3="/home/brain/neurotools/mrtrix3"

# Constants
RED='\033[0;31m'
NC='\033[0m' # No Color

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
# QUESTIONS
echo "Please input the number to select DTI: "
read choice_dti
#echo "Please input the number of DTI slices per volume: "
#read nb_dti_grad_dim # Check this with mrinfo on dti, this is the 4th dimension of the DTI image
# TODO: detect from grad.bvals = (b0 + all vectors) * 2 (the measurement is always repeated twice)
# Multishell?
echo "If the data is multishell, enter b-value of the shell to extract? [integer or 0 for no multishell] "
read choice_multishell
echo "Overwrite any image if necessary? [y/n] "
read choice_overwrite
if [ "$choice_overwrite" == "y" ]; then
    rm dwicorr.mif
    rm dwicorrunbias.mif
    rm dwicorr.nii
    rm grad.txt grad.bvecs grad.bvals
    rm mask.mif
    rm mask.nii
    rm wm_response.txt
    rm wmfod.mif
    rm wmfod_norm.mif
    rm Allbrain.tck Allbrain.trk
fi
echo "Attempt slice motion correction? [0 to skip, 1 to automatically detect slice timing, 2 if a my_sliceorder.txt file exists to be provided]"
read choice_slcorr
if [ "$choice_slcorr" -eq "0" ]; then
    echo "Please input the number of multiband/simultaneous-multi-slice bands? [0 or 1 to disable multiband correction]"
    read choice_multiband
    if [ "$choice_multiband" -ge "2" ]; then
        multiband="--ol_type=both --mb=$choice_multiband"
    else
        multiband="--ol_type=sw"
    fi
fi
echo "Automatic phase encoding? [0 for AP with no reverse phase, 1 for automatic]"
read choice_phaseencoding

# Extracting DWI and preparing everything
if [ "$choice_multishell" -gt "0" ]; then
    # Multishell data, extract the first non zero b-values shell (must provide -shells 0,<b-value> to extract a specific shell, else will extract the highest b-value)
    echo "$choice_dti" | dwiextract . dwi.mif -singleshell -bzero -export_grad_mrtrix grad.txt -export_grad_fsl grad.bvecs grad.bvals -shells 0,"$choice_multishell"
else
    # Singleshell data, simply convert
    echo "$choice_dti" | mrconvert . dwi.mif
    echo "$choice_dti" | mrinfo . -export_grad_mrtrix grad.txt -export_grad_fsl grad.bvecs grad.bvals
fi

# Sanity checks
if [ ! -f dwi.mif ]; then
    echo -e "${RED}ERROR: DTI file (dwi.mif) not found! Please type 'mrconvert . dwi.mif' beforehand to extract the dti if singleshell, or 'dwiextract . dwi.mif -singleshell -bzero -shells 0,XXXX' if multishell, where XXXX is to be replaced by the bvalue you want to extract.${NC}"
    exit 1
fi

# Get the gradients dimension count from the gradients files
#gradients_count=`cat grad.bvals | wc -w`

# Start DTI preprocessing
echo "== Starting DTI part 1"
# Prepare arguments
if [ "$choice_phaseencoding" -eq "1" ]; then
    phaseencoding="-rpe_header"
else
    phaseencoding="-rpe_none -pe_dir AP"
fi
# Eddy & between volume motion & inhomogeneity correction
if [ "$choice_slcorr" -eq "1" ]; then
    # With slice motion correction with autodetected slice timing from DICOM
    # TODO: use eddy_cuda and not eddy_openmp (there is no eddy anymore in latest releases), as only the cuda version will have the newest features per the documentation
    # TODO: provide dwipreproc with EPI readout time (normally if all b0 scans have the same readout time it's not necessary per doc): -readout_time 0.1
    # Note: if you don't know the phase encoding and you use nifti files (instead of mif files), set -rpe_none instead of -rpe_header
    # Note2: if using .mif file, and the DICOM contains slice timing information, there is no need for the --slspec=my_sliceorder.txt argument, MRTRIX3 can detect the appropriate slice order automatically
    dwipreproc dwi.mif dwicorr.mif $phaseencoding -eddy_options " --verbose --repol --fwhm=10,0,0,0,0 --slm=linear --ol_type=both --mporder=6 --s2v_niter=5 --s2v_lambda=1 --s2v_interp=trilinear" -info # if acquiring multiple sequences separately and concatenating them using mrcat, it is mandatory to provide --data_is_shelled to FSL eddy, else it will reject the data! See for more infos for the options: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/UsersGuide
elif [ "$choice_slcorr" -eq "2" ]; then
    # With slice motion correction using a provided slice timing file
    dwipreproc dwi.mif dwicorr.mif $phaseencoding -eddy_options " --verbose --repol --fwhm=10,0,0,0,0 --slm=linear --ol_type=both --mporder=6 --slspec=my_sliceorder.txt --s2v_niter=5 --s2v_lambda=1 --s2v_interp=trilinear" -info
else
    # Without slice motion correction
    dwipreproc dwi.mif dwicorr.mif $phaseencoding -eddy_options " --verbose --repol --fwhm=10,0,0,0,0 --slm=linear $multiband" -info
fi
# More bias correction
dwibiascorrect dwicorr.mif dwicorrunbias.mif -ants # -ants is advised for better masking than -fsl
echo "== Starting DTI part 2"
dwi2mask dwicorr.mif mask.mif
dwi2mask dwicorr.mif mask.nii # create for visualization
echo "== Starting DTI part 3"
# Response function estimation
#dwi2response dhollander -force -mask mask.mif dwicorrunbias.mif wm_response.txt gm_response.txt csf_response.txt
dwi2response tournier dwicorrunbias.mif -mask mask.mif -grad grad.txt wm_response.txt
# FOD
#dwi2fod msmt_csd -force -mask mask.mif dwicorrunbias.mif wm_response.txt wmfod.mif gm_response.txt gm.mif csf_response.txt csf.mif
dwi2fod csd dwicorrunbias.mif wm_response.txt -mask mask.mif wmfod.mif -grad grad.txt
# Multi-tissue informed log-domain intensity normalisation
# from http://community.mrtrix.org/t/pipeline-for-multi-shell-data/1384/3
mtnormalise wmfod.mif wmfod_norm.mif -mask mask.mif
# Tractography!
tckgen wmfod.mif Allbrain.tck -seed_dynamic wmfod.mif -maxlength 250 -select 300K -seeds 300K -cutoff 0.06

# Convert from .tck to .trk (to open with Trackvis)
echo "Convert .tck to .trk (trackvis compatibility)..."
mrconvert dwicorrunbias.mif dwicorr.nii # first convert to nii because nipype does not support mif files
python $SCRIPTPATH/Conv_track.py # use nipype to convert


# Lastly: If there is any error, stop and restart! If not, open with trackvis!
trackvis "$WORKDIR/Allbrain.trk" -new
