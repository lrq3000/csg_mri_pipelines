For the preprocessing, use the single subject coma meetings package with "normalized" option enabled, then use this script here, or the new script in this github repository. It should work with both VBM8 and SPM12 (unified segmentation) mode, but maybe not with CAT12 (the scripts only need to be changed to account for the different filename prepend).

First run the ImCalc_* scripts (which generate the difference between two sessions, usually post-pre), then open spm fmri and Batch and load the exp_* files (which will generate the statistical tests).

NOTE: As of 2024, this approach is deprecated in favor of AFNI LMEr for activity analysis of task-based designs, or gPPI in CONN for connectivity analysis.
