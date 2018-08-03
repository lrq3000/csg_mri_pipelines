#!/bin/bash
# Single subject Multi-Shell DTI analysis WITHOUT ACT for the Coma Science Group, by Stephen Larroque (2018).
# Required libraries: dcmtk dcmdjpeg (just to uncompress), mrtrix v3, trackvis, FSL, Python 2, SPM (just for reorientation).
# v1.1.0
# Tested on 19-07-2018 to latest MRTRIX3 github commit (post 3.0 RC3): d6656921594f22517d489a7f9f2d2598bcf18ce6

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
    echo "Please first extract the DWI with this command: mrconvert . dwi.mif"
    exit
fi

echo "======= DTI SINGLE-PATIENT PIPELINE ======="
# Change directory to the specified argument
cd "$1"
# Current working directory (for debug)
WORKDIR=$(pwd)
echo "Working from directory: $WORKDIR"

# Start DTI preprocessing
echo "== Starting DTI part 1"
dwipreproc dwi.mif dwicorr.mif -rpe_none -pe_dir AP
dwibiascorrect dwicorr.mif dwicorrunbias.mif -fsl # could use -ants if ants installed
echo "== Starting DTI part 2"
dwi2mask dwicorr.mif mask.mif
dwi2mask dwicorr.mif mask.nii # create for visualization
echo "== Starting DTI part 3"
# Response function estimation
dwi2response dhollander -force -mask mask.mif dwicorrunbias.mif wm_response.txt gm_response.txt csf_response.txt
# FOD
dwi2fod msmt_csd -force -mask mask.mif dwicorrunbias.mif wm_response.txt wmfod.mif gm_response.txt gm.mif csf_response.txt csf.mif
# Multi-tissue informed log-domain intensity normalisation
# from http://community.mrtrix.org/t/pipeline-for-multi-shell-data/1384/3
mtnormalise -force wmfod.mif wmfod_norm.mif gm.mif gm_norm.mif csf.mif csf_norm.mif -mask mask.mif
# Tractography!
tckgen -force wmfod.mif Allbrain.tck -seed_dynamic wmfod.mif -maxlength 250 -select 300K -seeds 300K -cutoff 0.06

# Convert from .tck to .trk (to open with Trackvis)
echo "Convert .tck to .trk (trackvis compatibility)..."
mrconvert -force dwicorrunbias.mif dwicorr.nii # first convert to nii because nipype does not support mif files
python $SCRIPTPATH/Conv_track.py # use nipype to convert


# Lastly: If there is any error, stop and restart! If not, open with trackvis!
trackvis "$WORKDIR/Allbrain.trk" -new
