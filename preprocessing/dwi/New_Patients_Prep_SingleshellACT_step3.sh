#!/bin/bash

WORKDIR=$(pwd)
# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")

# Path to MRTRIX3 install folder
MRTRIX3=$1

echo "Working from directory: $WORKDIR"

# Please check T1 registration with the dwi before tractography
# tractography

# Probabilistic tractography (mrtrix)
echo "Probabilistic tractography using mrtrix3..."
# 300000 is the number of seeds (but not ROI seeds but starting seeds to explore via viterbi-like exploration)
dwi2response tournier -force dwicorr.nii -mask WMdiff_masked2.nii -grad grad.txt -lmax 6 response.txt
dwi2fod csd -force dwicorr.nii response.txt -lmax 6 -mask mask.nii ODF.nii -grad grad.txt
#tckgen -force -seed_image WMdiffusion.nii -mask GM_WM_diffusion.nii -number 300000 -maxnum 300000 ODF.nii Allbrain.tck
tckgen -force -seed_image WMdiff_masked.nii -mask WMdiff_masked.nii -select 300000 -seeds 300000 ODF.nii Allbrain.tck

#tckgen -force -seed_image mask2.nii -mask mask2.nii -number 300000 -maxnum 300000 ODF.nii Allbrain.tck

# Convert from .tck to .trk (to open with Trackvis)
echo "Convert .tck to .trk (trackvis compatibility)..."
python $SCRIPTPATH/Conv_track.py

### connectome
#tck2connectome -info -force Allbrain.tck aalnative.nii Connectome.csv -zero_diagonal

#erode -dilate -npass 3 mask2.nii mask_dil.nii dilate mask?
##erode a mask or image by zeroing non-zero voxels when zero voxels found in kernel
##############################################################################################
#fslmaths 'mask.nii.gz' -kernel box 5x5x5 -ero 'output_image.nii.gz'
#tckgen -force -seed_image WM_native.nii -mask GM_WM_native.nii -number 50000000 -maxnum 50000000 ODF.nii AllbrainBefore.tck
#tcksift -force AllbrainBefore.tck ODF.nii Allbrain.tck
#rm AllbrainBefore.tck
