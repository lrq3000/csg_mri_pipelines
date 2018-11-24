DWI (diffusion MRI) preprocessing script up to tractography of the Coma Science Group. It does not do fieldmap correction (topup), but it does every other possible corrections (motion correction, multi-band correction, etc.)

You need to have the latest MRTRIX3, FSL, ANTS and dipy (Python, use Anaconda distribution, easier to install) installed on your system to run these scripts.

In addition, for the Single-Shell with ACT (anatomical constraints) pipeline, you need to have MATLAB with SPM installed, and you need to copy the templates from Freesurfer.

Here are the entry points:
* New_Patients_Prep_Multishell.sh for multi-shell DWI analysis (latest pipeline). This does not use ACT.
* New_Patients_Prep_SingleshellNoACT.sh for single-shell DWI analysis without ACT. It's basically the same, with same parameters, as the Multishell pipeline but using only a single shell.
* New_Patients_Prep_SingleshellACT.sh for single-shell DWI analysis with ACT. This requires MATLAB with SPM and Freesurfer templates.

Read the comments or help messages for these scripts to get more information on their usage.
