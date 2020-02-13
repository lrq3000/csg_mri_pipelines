== Structural MRI voxel-based morphometry with DARTEL analysis pipeline using VBM8 and SPM8 or CAT12 and SPM12 ==

by Stephen Karl Larroque
2017-2020

=== Install ===

The entry script is vbm_script_preproc_csg.m (requires MATLAB).

You also need to install SPM12 and CAT12 (or SPM8 and VBM8). Please use the exact SPM12 and CAT12 versions that are specified in the header of vbm_script_preproc_csg.m (they are available in the folder "external" at the root of this git repository), because we are here using experimental features (particularly for CAT12) and the way to access them is changing between minor releases.

Note that CAT12 must be installed inside spm/toolbox/cat12, it cannot be placed outside (else you will get weird errors). Also, you need to set topoFDR=0 in spm_defaults.m, and set cat.extopts.expertgui = 1; in cat_defaults.m

You also needs Python 3 with PILLOW if you want to automatically generate result images. For deployment, it's possible to use `pyinstaller vbm_gen_final_image.py` to compile a binary, then a Python install won't be necessary anymore to run this whole pipeline (binaries can be compiled on Windows, Linux and Mac - use Miniconda to produce a minimally sized binary). For Windows, the compiled binary is already provided.

Then edit vbm_script_preproc_csg.m variables in the beginning of the script to fill the path to the SPM and CAT/VBM install, and the path to your subjects nifti files to analyze, and you can also change a few other options at your convenience (such as the ethnic template to use). Then simply run vbm_script_preproc_csg.m and wait for the magic to happen.

Note this pipeline is also interesting to see how it is possible to fully automate graphical results generation in SPM.

=== How to use and do a voxel-based morphometry analysis? ===

Read the instructions in INSTRUCTIONS_HOWTO_VBM_ANALYSIS_CSG.txt for an example process from start to finish, for single case analyses.

For group-subject analyses, the process is the same as for single-case analyses, but additionally after running this script on ALL subjects, you should do a contrast to compare the resulting segmented smoothed grey matter images. An example of a within-subject between-sessions contrast can be found in analysis\smri\single-subject-longitudinal (for between-groups contrast it's very similar but use a normal t-test instead of a paired t-test).

=== How to make a self-contained portable install (almost fully automated and unattended) ===

It's possible to make a self-contained install that requires only MATLAB to run, and can even be placed on a shared network drive such as samba.

To do that, follow these instructions:

* create a directory "pipeline"
* copy this "smri" folder into "pipeline/smri"
* create a folder "pipeline/external"
* unzip spm12 inside (from the "external" folder at the root of this git repository), you should get a folder "pipeline/external/spm12"
* unzip cat12 (from external at the root of this git repo) into "pipeline/external/spm12/toolbox/cat12". Make sure inside the cat12 folder there is no other superfluous subfolder (sometimes created by file archiver software when unzipping), you should get all cat12 main folders and files inside, such as "atlases_surfaces", "atlases_surfaces_32k", etc right inside "pipeline/external/spm12/toolbox/cat12".
* optional: for automatic reorientation, install https://github.com/lrq3000/spm_auto_reorient_coregister inside "pipeline/external/spm12"
* using notepad++ or a similar editor which supports Linux line return code, set topoFDR=0 in spm_defaults.m and cat.extopts.expertgui = 1 in cat_defaults.m
* place your controls nifti images (segmented smoothed grey matter, as produced with first-level analysis by this script) for the second-level analysis in pipeline\Controls_VIDA_CAT12_10subj\Final . If you don't have them, you can produce them from raw MPRAGE from controls, simply run this script with rootpath_multi to process multiple subjects at once and set skip2ndlevel = 1; and skipresults = 1;
* On Linux and MacOS: you will need to install Miniconda3 and `pip install PILLOW` and `pip install pyinstaller`, then type `pyinstaller pipeline/smri/vbm_gen_final_image.py` which will create a precompiled binary for your platform so other users won't need to install Python.

At this point, you are done, you can deploy the "pipeline" folder anywhere, anyone can run it using only MATLAB (tested on MATLAB 2018b), by doing the following:

* Simply open MATLAB and run `pipeline\smri\vbm_script_preproc_csg_relativepaths.m`, this script is already preconfigured to use relative paths matching those outlined in the previous instructions, so whenever you place the whole "pipeline" folder should work (you can also rename "pipeline" to whatever you want, but not any of the folders inside). Upon running this script, it will ask you the nifti file of a patient (it runs in single-case analysis mode by default). If you would rather have it analyze a group of subjects, edit the script and set rootpath_multi = 'gui'; and rootpath_single = '';
