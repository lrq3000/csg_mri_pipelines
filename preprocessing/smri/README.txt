Structural MRI voxel-based morphometry with DARTEL analysis pipeline using VBM8 and SPM8 or CAT12 and SPM12. The entry script is vbm_script_preproc_csg.m (requires MATLAB).

If you are running Windows, you don't need Python, as the script will automatically use the compiled binary if available, but otherwise you also needs Python 3 with PILLOW if you want to automatically generate result images. This pipeline is also interesting to see how it is possible to fully automate graphical results generation in SPM.

Please also use the exact SPM12 and CAT12 versions that are specified in the header of vbm_script_preproc_csg.m (they are available in the folder "external" at the root of this git repository).
