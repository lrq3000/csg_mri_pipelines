How to do the whole task-based paradigm analysis, as of 2024-07:

1. First preprocess using the fmri/script_preproc_csg.m script . Since 2024, script_mode 2 or 2.5 (CAT12 with DARTEL or Shooting respectively) are advised. This will preprocess the structural and fmri bold images and smooth them, ready to be used in a statistical design. This will necessarily normalize to the MNI template (so we do not calculate in subject space - which was supported before but not anymore since it is seldom useful in practice and is more prone to biases than normalized analyses).

With this data, you can already run a CONN gPPI connectivity analysis. If you want to do an activity analysis, follow the next steps.

2. Run Act_Package/EA_Act.m with skip_preproc = 1 to only calculate the first-level statistical design (block design which will correlate when the subject was asked to perform the task, and when they were asked not to). This will create a subfolder "Classical_ana" for each subject, with the 1st-level results. Note that this script expects the same folders structure as the preprocessing script (a BIDS-like structure), and will automatically process all conditions/groups, subjects, sessions and modalities/tasks.

With this data, you can run an AFNI LMEr activity analysis (which supports missing data, ie, variable number of sessions for subjects, and can provide 3rd-level results accounting for both longitudinal and group-wise effects, and both random and fixed effects). If you want to do a simpler SPM analysis, continue with the next steps.
NOTE: As of 2024, the following steps (after 2) are deprecated in favor of AFNI LMEr for activity analysis of task-based designs, or gPPI in CONN for connectivity analysis.

3. Per-subject longitudinal 2nd-level results, comparing post minus pre sessions, can be calculated with ImCalc_job_* scripts. They expect the same folders structure as the preprocessing script, and will process all conditions/groups, subjects, sessions and modalities/tasks. For example, to calculate all longitudinal navigation tests, run ImCalc_job_navigation.m . This will create a file "navigation_diff.nii" at the root of each subject's folder, calculating post-pre (literally using ImCalc i2-i1 on the con_0001*.mat files for each session's statistical tests that were generated at step 2). Other variants using the followup session instead of post-pre are also available.
    * Note: if you only want the 2nd-level results, then although the substraction method can be equivalent to a [-1 1] contrast and a one-sample t-test can be done afterwards, a more statistically robust alternative would be to run a statistical design matrix in SPM12 with a paired t-test or repeated measures ANOVA over the con_0001*.mat files of pre and post sessions, and calculate a contrast [-1 1], which would then generate a new con_0001*.mat file for this longitudinal 2nd-level analysis, but which would be correctable with multiple comparison correction (including non-parametric using SnPM).

4. Group-wise, between-subjects 3rd-level results, comparing the difference between groups (eg, controls versus target_group) with regards to the longitudinal differences found in the 2nd-level results, can be calculated using the exp*.mat batch job files that can be loaded in `spm fmri` and clicking on the Batch button. This will in effect highlight differences between post-pre that are found uniquely in the target_group, and not in the control group. Hence, this allows to exclude effects that are just due to time passing by. This will generate a SPM.mat file with the contrasts already predefined, and it will find the files recursively too even if not filled dynamically, using a native module provided in SPM Batch manager. This can be corrected for multiple comparison.

By now you should have the end results.

Made by Stephen Karl Larroque, 2016-2024
Licensed under MIT license (all the scripts and batch jobs).

-----
Old instructions (before 2020):

For the preprocessing, use the single subject coma meetings package with "normalized" option enabled, then use this script here, or the new script in this github repository. It should work with both VBM8 and SPM12 (unified segmentation) mode, but maybe not with CAT12 (the scripts only need to be changed to account for the different filename prepend).

First run the ImCalc_* scripts (which generate the difference between two sessions, usually post-pre), then open spm fmri and Batch and load the exp_* files (which will generate the statistical tests).
