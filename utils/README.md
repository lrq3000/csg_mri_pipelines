# Coma Science Group MRI pipelines utilities

MRI utilities to facilitate or accelerate repetitive tasks in MRI preprocessing.

All tools are either in MATLAB or Python.

All tools are licensed under MIT (but not necessarily the required/optional libraries, please check their own licenses).

The rest of this document will describe some of the tool's purpose, usage and linked libraries. Literate programming is extensively used, so that you can expect lots of comments inside the scripts itself, so that they should be useable without any external documentation (eg, type help <script_name> to get usage information or look at the header).

## pathmatcher: Regular Expression Path Matcher

### Description

A files and folders hierarchy management tool with a regular expression matcher on _paths_ (instead of just filenames). Can display a simulation report and automatically detect conflicts (already existing files, collisions of multiple files copied to the same output filename because of regexp, etc.). Can also be used as a Python module that returns the list of matched files and the transformations.

If you often run experiments, you use scripts and applications, with some that you didn't design yourself. It might then happen that these apps/scripts expect a specific directory layout to work. Usually, you reorganize your files manually. Not only is this time consuming, this is also very error prone (eg, copying the wrong files to the wrong id).

If you happen to know this situation, this tool might help you: just specify a regular expression matching the files you need, enter an output regular expression (that can reuse parts of the input files, for example your subjects ids, using regexp groups and recall), and then launch the program.

This application can also be used as a Python module, so that you can include it in a pipeline to (semi-)automate repetitive stuff, like selecting the appropriate files to open in your favorite tool like SPM. For an exemple, see the script `reorient_pipeline` at the root of this repository.

Runs on Python 2.7 and Python 3.

If you are not experienced with [regular expressions](http://regexone.com/), you can use online tools such as [Pythex](http://pythex.org/) to instantly test your regexp.

A more exhaustive documentation along with a quickstart tutorial is available in the README inside the pathmatcher folder or at the dedicated repository: https://github.com/lrq3000/pathmatcher

## ASCII Rename

### Description

A simple Python script that will recursively rename all unicode files and folders in a path into ascii.

Several neuroscience tools like SPM cannot detect files with unicode characters (or accents or any non-ascii character).

This script avoids the need to manually rename every files (try to do that consistently with fMRI volumes...) by replacing any unicode character by its closest ascii counterpart.

Example: maéva -> maeva

### Usage

```
usage: asciirename.py [-h] -i /some/path [-v]

Ascii Path Renamer v0.3
Description: Rename all directories/files names from unicode (ie, accentuated characters) to ascii.

Note: use --gui (without any other argument) to launch the experimental gui (needs Gooey library).


optional arguments:
  -h, --help            show this help message and exit
  -i /some/path, --input /some/path
                        Path to the input folder. The renaming will be done recursively.
  -v, --verbose         Verbose mode (show more output).
```

## Reorientation and registration helper

### Description

A companion to help you reorient and coregister manually your structural and functional MRI in SPM, without having to click to select files.

This helper script will scan all images in the specified input path, and will accompagny you step-by-step to do the reorientation and coregistration correctly.

This script requires SPM12 (and MATLAB).

This script follows the following steps:

1. Automatic reorientation of structural MRI using [spm_auto_reorient.m](https://github.com/lrq3000/spm_auto_reorient) (please install this script along with SPM12 beforehand).
2. Check reorient and adjust manually.
3. Side-by-side check of multiple subjects' structural MRI.
4. Manual co-registration of functional images with structural.

This script will not only guide you through these steps, in the correct order, but it will also automatically load the files for you (no chance of doing a mistake or missing a subject), while showing you a progress bar (showing how many subjects are remaining and with a time estimate to finish).

There is a CLI user interface: you can skip steps you already done or don't want to do, skip patients, or reload another image (for step 4, to check other functional images).

### Usage

```
usage: reorientation_registration_helper.py [-h] -i /some/path [-v]

Reorientation and registration helper v1.0
Description: Guide and automate the file selection process that is required in SPM between each reorientation/registration.

No more useless clicks, just do the reorientation/registration in batch, you don't need to worry about selecting the corresponding files, this helper will do it for you.

If you have tqdm installed, a nice progress bar will tell you how many subjects are remaining to be processed and how much time will it take at your current pace.

Note: you need to `pip install mlab` before using this script.
Note2: you need to have set both spm and spm_auto_reorient in your path in MATLAB before using this script.
Note3: you need the pathmatcher.py library (see lrq3000 github).



optional arguments:
  -h, --help            show this help message and exit
  -i /some/path, --input /some/path
                        Path to the input folder (the root directory where you placed the files with a tree structure of [Condition]/[id]/data/(mprage|rest)/*.(nii|hdr|img)
  -v, --verbose         Verbose mode (show more output).
```

### Libraries

#### Required

* argparse
* pathmatcher
* [mlab](https://github.com/ewiger/mlab)

#### Optional

* scandir, to scan files faster
* tqdm, to show the progress bar

## CONN Subjects Loader

### Description

MATLAB script to batch load all subjects and conditions from a given directory root into CONN. This saves quite a lot of time.
The script can then just show the CONN GUI and you do the rest, or automate and process everything and show you CONN GUI only when the results are available.
You can also resume your job if there is an error or if you CTRL-C (but don't rely too much on it, data can be corrupted). Resume can also be used if you add new subjects.

### Usage

Simply modify the variables at the top of the script, and launch it in MATLAB.

### Libraries

#### Required

* SPM (tested with v12)
* CONN (tested with several versions from v15h up to v18a - please refer to the scripts headers for the latest updates)
