# neuro_experiments_tools
Various tools I made to help automate some usual tasks.

Each tool is placed in its own folder. Most tools will be in Python, but you can expect to see some tools in Matlab or other languages as they fit my needs.

All tools are licensed under MIT (but not necessarily the required/optional libraries, please check their licences).

The rest of this document will describe each tool's purpose, usage and linked libraries.

## Regular Expression Path Matcher

### Description

A files and folders hierarchy management tool with a regular expression matcher on _paths_ (instead of just filenames). Can display a simulation report and automatically detect conflicts (already existing files, collisions of multiple files copied to the same output filename because of regexp, etc.). Can also be used as a Python module that returns the list of matched files and the transformations.

If you often run experiments, you use scripts and applications, with some that you didn't design yourself. It might then happen that these apps/scripts expect a specific directory layout to work. Usually, you reorganize your files manually. Not only is this time consuming, this is also very error prone (eg, copying the wrong files to the wrong id).

If you happen to know this situation, this tool might help you: just specify a regular expression matching the files you need, enter an output regular expression (that can reuse parts of the input files, for example your subjects ids, using regexp groups and recall), and then launch the program.

This application can also be used as a Python module, so that you can include it in a pipeline to (semi-)automate repetitive stuff, like selecting the appropriate files to open in your favorite tool like SPM. For an exemple, see the script `reorient_pipeline` at the root of this repository.

Runs on Python 2.7.11, but uses good standards to ensure easy conversion to Python 3 in case you really need it.

If you are not experienced with [regular expressions](http://regexone.com/), you can use online tools such as [Pythex](http://pythex.org/) to instantly test your regexp.

### Usage

```
usage: pathmatcher.py [-h] -i /some/path -ri sub[^/\]*/\d+ [-o /new/path]
                      [-ro newsub/\1] [-c] [-m] [-t] [-y] [-f]
                      [--show_fullpath] [--report pathmatcher_report.txt]
                      [-l /some/folder/filename.log] [-v] [--silent]

Regex Path Matcher v0.9
Description: Match paths using regular expression, and then generate a report. Can also substitute using regex to generate output paths. A copy mode is also provided to allow the copy of files from input to output paths.
This app is essentially a path matcher using regexp, and it then rewrites the path using regexp, so that you can reuse elements from input path to build the output path.
This is very useful to reorganize folders for experiments, where scripts/softwares expect a specific directories layout in order to work.

Note that the paths are compared against filepaths, not just folders (but of course you can match folders with regex, but remember when designing your regexp that it will compared against files paths, not directories).

Note: use --gui (without any other argument) to launch the experimental gui (needs Gooey library).
Note2: can be used as a Python module to include in your scripts (set return_report=True).
    

optional arguments:
  -h, --help            show this help message and exit
  -i /some/path, --input /some/path
                        Path to the input folder
  -ri sub[^/\]*/(\d+), --regex_input sub[^/\]*/(\d+)
                        Regex to match input paths. Must be defined relatively from --input folder.
  -o /new/path, --output /new/path
                        Path to the output folder (where file will get copied over if --copy)
  -ro newsub/\1, --regex_output newsub/\1
                        Regex to substitute input paths to convert to output paths. Must be defined relatively from --output folder. If not provided but --output is specified, will keep the same directory layout as input (useful to extract specific files without changing layout).
  -c, --copy            Copy the matched input paths to the regex-substituted output paths.
  -m, --move            Move the matched input paths to the regex-substituted output paths.
  -t, --test            Regex test mode: Stop after the first matched file and show the result of substitution. Useful to quickly check if the regex patterns are ok.
  -y, --yes             Automatically accept the simulation and apply changes (good for batch processing and command chaining).
  -f, --force           Force overwriting the target path already exists. Note that by default, if a file already exist, without this option, it won't get overwritten and no message will be displayed.
  --show_fullpath       Show full paths instead of relative paths in the simulation.
  --report pathmatcher_report.txt
                        Where to store the simulation report.
  -l /some/folder/filename.log, --log /some/folder/filename.log
                        Path to the log file. (Output will be piped to both the stdout and the log file)
  -v, --verbose         Verbose mode (show more output).
  --silent              No console output (but if --log specified, the log will still be saved in the specified file).
```

### Libraries

#### Required

* core Python libraries...
* argparse
* pathlib2 (provided with the script)
* Tee (provided with the script)

#### Optional

* **[tqdm](https://github.com/tqdm/tqdm/)** (for progress bar, **highly recommended**)
* scandir (for faster file walking and simulation report)
* Gooey (for gui)

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

This script follows the following steps:

1. Automatic reorientation of structural MRI using [spm_auto_reorient.m (see CRC Cyclotron Github)](https://github.com/CyclotronResearchCentre/spm_auto_reorient).
2. Check reorient and adjust manually.
3. Side-by-side check of multiple subjects' structural MRI.
4. Manual co-registration of functional images with structural.

This script will not only guide you through these steps, in the correct order, but it will also automatically load the files for you (no chance of doing a mistake or missing a subject), while showing you a progress bar (showing how many subjects are remaining and with a time estimate to finish).

There is a CLI user interface: you can skip steps you already done or don't want to do, skip patients, or reload another image (for step 4, to check other functional images).

### Usage

```
usage: reorientation_registration_helper.py [-h] -i /some/path [-v]

Reorientation and registration helper v1.0
Description: Automate the file selection process that is required in SPM between each reorientation/registration.

No more useless clicks, just do the reorientation/registration in batch, you don't need to worry about selecting the corresponding files, this helper will do it for you.

Also note that the program expects the anatomical images to be the same across all conditions. Thus, you will reorient the anatomical images only once per subject, and then they will be copied over all other conditions.
WARNING: if that's not the case (you have different anatomical images per condition), please DO NOT use this helper, or comment the reorientation step!

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
* CONN (tested with v15h and v16a)
