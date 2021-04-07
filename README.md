# Coma Science Group MRI pipelines

Magnetic Resonance Imagery (MRI) preprocessing and analysis pipelines and tools for the study of disorders of consciousness.

## Description

This repository contains open-sourced MRI pipelines for:

* fMRI BOLD EPI (using SPM and CONN and optionally CAT12 and rshrf)
* DWI/DTI tractography (using MRTRIX3 and FSL)
* structural voxel-based morphometry using VBM8 or CAT12.

SPM8 and VBM8 are also supported for structural and functional MRI analyses for retrocompatibility and reproducibility purposes.

In combination with the [Coma Science Group's open-sourced MRI protocol](https://github.com/lrq3000/mri_protocol), this allows for the implementation of clinical and research MRI pipelines from A to Z, from image acquisition to publishable results.

All tools are either in MATLAB or Python.

All tools are licensed under MIT (but not necessarily the required/optional libraries, please check their own licenses).

Literate programming is extensively used, so that you can expect lots of comments inside the scripts itself, so that they should be useable without any external documentation (ie, type `help <script_name>` at the MATLAB or Python prompt to get usage information or read the file's headers).

## Outline of pipelines

This repository is organized as follows:
* preprocessing: contains all preprocessing pipelines for all modalities.
* analysis: contains all analysis pipelines for all modalities, these should be used after preprocessing pipelines.
* utils: utilities to ease or accelerate repetitive manual tasks such as files reorganization into a BIDS-like architecture or manual reorientation of structural and functional MRI images.
    * note: there are other utilities specific to each modalities in their respective folders, eg, in `/fmri` there are utilities such as `/fmri/slice_order` to detect slice order, `/fmri/nifti_4dto3d_convert_recursive` to convert 3d nifti to 4d nifti and inversely recursively in all subfolders from a given path (useful for some SPM12 libraries that do not support 4d nifti files because they take much more RAM memory during preprocessing), to plot motion data using `/fmri/various/movvis.m` for manual screening and rejection of subjects that moved too much, to make nice 3D brain renders using CONN from any nifti map via `conn_3dvis.m`, make a 1st-level statistical test using `conn_1stlevel_ttest.m`, etc.
* external: external packages such as CAT12 and SPM12 to ease reproducibility of our scripts by providing the exact same revisions of the packages we used. Indeed, revisions (under the same version) may break some functions and APIs that are expected in the provided pipelines.

### Functional MRI (fMRI)

MATLAB, SPM12 and [CONN](https://www.nitrc.org/projects/conn) are required for this pipeline (see the `external` folder for the exact revision of SPM12 we used). Optionally, CAT12 can be used for the preprocessing of the structural image to leverage the accuracy of geodesic shooting for template matching and segmentation and automatic lesions segmentation from white matter hyperintensities (not 100% accurate but better than no lesion detection usually). This pipeline is cross-platform (tested on Windows 10 and Linux Ubuntu).

The structural image does not need to be preprocessed separately, everything will be done by the same script.

1. Use a Dicom to Nifti converter such as MRIConvert or dcm2niix. Use a BIDS-like architecture for the script to automatically recognize the file tree and process it automatically. Alternatively, use the PathMatcher utility to batch reorganize your files in a BIDS-like architecture.
2. Manually reorient the structural image and manually coregister the functional BOLD images onto the structural (see [this tutorial for more details](https://github.com/lrq3000/neuro_slides/blob/master/csg-mri-mini-workshop-2017/csg-lecture-mri.pdf)). The utility [reorientation_registration_helper-cli](https://github.com/lrq3000/pathmatcher/blob/master/reorientation_registration_helper-cli.py) can help in quickly reorienting big datasets. Note that an automatic reorientation and coregistration can be done by the pipeline via the [auto_acpc_reorient utility](https://github.com/lrq3000/auto_acpc_reorient), although it is preferable to do it manually to ensure proper initial conditions since segmentation is sensitive to the initial brain orientation. Optionally: make a zip archive to backup your manually processed dataset before proceeding further, this allows to quickly relaunch preprocessing in case an error happened by simply discarding (deleting) the preprocessed folder and restoring the zip's content.
3. Open with an editor such as Notepad++ (or any editor that supports Unix line returns) the file `/preprocessing/fmri/script_preproc_fmri_csg.m` to edit the parameters in the headers. This is where the parameters of your MRI protocol are to be set, such as the repetition time, slice order, etc. Multi-band BOLD is supported too.
4. Open MATLAB, change directory to `preprocessing/fmri/` and type `script_preproc_fmri_csg`. The preprocessing should proceed without errors, with continuous progress updates. If there is an error, please follow the indications in the MATLAB prompt to fix it, then restart (restore the zip backup first to ensure no SPM generated file will be mistaken as input - this is difficult to ensure given that SPM only prepends generated files with a prefix, which can be confusing since input files can be freely named, hence why a zip backup is the safest way to work around this potential issue).
5. Open with an editor the file `/analysis/fmri/conn_subjects_loader/conn_subjects_loader.m` and edit the headers to setup the path to your preprocessed dataset and some MRI parameters. This script will load up all the data in a new CONN project, and if you want it can also launch the CONN preprocessing, denoising, 1st-level analysis steps so that you can then setup your experiment design at the 2nd-level. 1st-level covariates (volume-level within-subject covariates such as motion) need to be setup BEFORE launching denoising and 1st-level analysis, so then you should disable automatic mode -- the exception being motion regression and outliers scrubbing which is already included by default by the script. Alternatively, the script also has a variable `firstlevelcovars` to instruct custom 1st-level covariates to import from .txt files, which then allows to use the automatic mode. 2nd-level covariates can be added at anytime after all the CONN preprocessing steps are done, so you can enable the automatic mode and add 2nd-level covariates (group-level between-subjects covariates) such as age, sex etc at the end.
6. For more information on how to conduct functional MRI analyses using CONN, see https://web.conn-toolbox.org/

Alternatively, steps 3 and 4 can be skipped by doing the whole preprocessing in CONN, by importing in CONN's GUI the preprocessing pipelines in `/preprocessing/fmri-conn`. Be however warned that the results will be different than those obtained with the SPM12 pipeline above.

### Voxometry analysis from structural MRI

MATLAB, SPM12 and CAT12 are required for this pipeline (see the `external` folder for the exact revisions of SPM12 and CAT12 we used -- CAT12's API is frequently changed). This pipeline is cross-platform (tested on Windows 10 and Linux Ubuntu).

1. Use a Dicom to Nifti converter such as MRIConvert or dcm2niix. Use a BIDS-like architecture for the script to automatically recognize the file tree and process it automatically. Alternatively, use the PathMatcher utility to batch reorganize your files in a BIDS-like architecture.
2. Manually reorient the structural image and manually coregister the functional BOLD images onto the structural (see [this tutorial for more details](https://github.com/lrq3000/neuro_slides/blob/master/csg-mri-mini-workshop-2017/csg-lecture-mri.pdf)). The utility [reorientation_registration_helper-cli](https://github.com/lrq3000/pathmatcher/blob/master/reorientation_registration_helper-cli.py) can help in quickly reorienting big datasets. Note that an automatic reorientation and coregistration can be done by the pipeline via the [auto_acpc_reorient utility](https://github.com/lrq3000/auto_acpc_reorient), although it is preferable to do it manually to ensure proper initial conditions since segmentation is sensitive to the initial brain orientation. Optionally: make a zip archive to backup your manually processed dataset before proceeding further, this allows to quickly relaunch preprocessing in case an error happened by simply discarding (deleting) the preprocessed folder and restoring the zip's content.
3. Open with an editor such as Notepad++ (or any editor that supports Unix line returns) the file `/preprocessing/smri/vbm_script_preproc_csg.m` to edit the parameters in the headers. This is where the parameters of your MRI protocol are to be set, such as the repetition time, slice order, etc. Multi-band BOLD is supported too.
4. Open MATLAB, change directory to `preprocessing/smri/` and type `vbm_script_preproc_csg.m`. The preprocessing should proceed without errors, with continuous progress updates. If there is an error, please follow the indications in the MATLAB prompt to fix it, then restart (restore the zip backup first to ensure no SPM generated file will be mistaken as input - this is difficult to ensure given that SPM only prepends generated files with a prefix, which can be confusing since input files can be freely named, hence why a zip backup is the safest way to work around this potential issue).
5. For analysis, the usual SPM12 2nd-level designs can be used, hence no pipeline is provided here. There are however a few example SPM12 designs in `/analysis/smri/single-subject-longitudinal`.

CAT12 will generate a report for each subject and session, that allows for quality check but also that provides volumes for each kind of tissue. This data can be used for further statistical analysis on volumes comparison between groups for example.

For a more extensive tutorial on the basics of MRI preprocessing and analysis, see [this presentation](https://github.com/lrq3000/neuro_slides/blob/master/csg-mri-mini-workshop-2017/csg-lecture-mri.pdf).

### Diffusion (DWI/DTI) MRI

This pipeline requires MRTRIX3, FSL, ANTS and dipy (Python, use Anaconda distribution, easier to install). It is NOT cross-platform, due to the dependencies, it works only on Linux (tested on Ubuntu 16.04).

How to use:
* To preprocess, open a command prompt, change directory to `/preprocessing/dwi`, and launch one of these scripts depending on your MRI protocol and experimental design:
    * New_Patients_Prep_Multishell.sh for multi-shell DWI analysis (latest pipeline). This does not use ACT.
    * New_Patients_Prep_SingleshellNoACT.sh for single-shell DWI analysis without ACT. It's basically the same, with same parameters, as the Multishell pipeline but using only a single shell.
    * New_Patients_Prep_SingleshellACT.sh for single-shell DWI analysis with ACT. This requires MATLAB with SPM and Freesurfer templates.
* You will end up with one tractographic image for each subject (ie, 1st-level analysis), which can be opened with [Trackvis](http://trackvis.org/) or MRTRIX3 viewer.

For a more extensive tutorial on the basics of DTI preprocessing and analysis, see [this presentation](https://github.com/lrq3000/neuro_slides/blob/master/csg-mri-mini-workshop-2017/csg-lecture-dti.pdf). To implement group-level analysis, see the slide about 2nd-level analysis.

## Author and licensing

These pipelines were made by Stephen Karl Larroque. The author is indebted to [Professor Mohamed Ali Bahri](https://gitlab.uliege.be/M.Bahri) who provided pipelines and education that inspired these pipelines (that were written from the ground up).

All tools are licensed under the open-source MIT License (but not necessarily the required/optional libraries, please check their own licenses).
