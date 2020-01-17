# Coma Science Group MRI pipelines

MRI preprocessing and analysis pipelines and tools for the study of disorders of consciousness.

This includes pipelines for fMRI BOLD EPI (using SPM and CONN and optionally CAT12 and rshrf), for DWI tractography (using MRTRIX3 and FSL) and structural voxel-based morphometry using VBM8 or CAT12.

All tools are either in MATLAB or Python.

All tools are licensed under MIT (but not necessarily the required/optional libraries, please check their own licenses).

The rest of this document will describe some of the tool's purpose, usage and linked libraries. More documentation will be written in the future (maybe). In any case, literate programming is extensively used, so that you can expect lots of comments inside the scripts itself, so that they should be useable without any external documentation.

The directory "external" contains external packages to ease reproducibility of our scripts by providing the exact same revisions of the packages we used.

## pathmatcher: Regular Expression Path Matcher

### Description

A files and folders hierarchy management tool with a regular expression matcher on _paths_ (instead of just filenames). Can display a simulation report and automatically detect conflicts (already existing files, collisions of multiple files copied to the same output filename because of regexp, etc.). Can also be used as a Python module that returns the list of matched files and the transformations.

If you often run experiments, you use scripts and applications, with some that you didn't design yourself. It might then happen that these apps/scripts expect a specific directory layout to work. Usually, you reorganize your files manually. Not only is this time consuming, this is also very error prone (eg, copying the wrong files to the wrong id).

If you happen to know this situation, this tool might help you: just specify a regular expression matching the files you need, enter an output regular expression (that can reuse parts of the input files, for example your subjects ids, using regexp groups and recall), and then launch the program.

This application can also be used as a Python module, so that you can include it in a pipeline to (semi-)automate repetitive stuff, like selecting the appropriate files to open in your favorite tool like SPM. For an exemple, see the script `reorient_pipeline` at the root of this repository.

Runs on Python 2.7.15, but uses good standards to ensure easy conversion to Python 3 in case you really need it.

If you are not experienced with [regular expressions](http://regexone.com/), you can use online tools such as [Pythex](http://pythex.org/) to instantly test your regexp.

### Usage

```
usage: pathmatcher.py [-h] -i /some/path -ri "sub[^/]+/\d+" [-o /new/path]
                      [-ro "newsub/\1"] [-c] [-s] [-m] [-d] [-t] [-y] [-f]
                      [--show_fullpath] [-ra 1:10-255]
                      [--report pathmatcher_report.txt]
                      [-l /some/folder/filename.log] [-v] [--silent]

Regex Path Matcher v0.9.5
Description: Match paths using regular expression, and then generate a report. C
an also substitute using regex to generate output paths. A copy mode is also pro
vided to allow the copy of files from input to output paths.
This app is essentially a path matcher using regexp, and it then rewrites the pa
th using regexp, so that you can reuse elements from input path to build the out
put path.
This is very useful to reorganize folders for experiments, where scripts/softwar
es expect a specific directories layout in order to work.

Advices
-------
- Filepath comparison: Paths are compared against filepaths, not just folders (b
ut of course you can match folders with regex, but remember when designing your
regexp that it will compared against files paths, not directories).
- Relative filepath: Paths are relative to the rootpath (except if --show-fullpa
th) and that they are always unix style, even on Windows (for consistency on all
 platforms and to easily reuse regexp).
- Partial matching: partial matching regex is accepted, so you don't need to mod
el the full filepath, only the part you need (eg, 'myfile' will match '/myfolder
/sub/myfile-034.mat').
- Unix filepaths: on all platforms, including Windows, paths will be in unix for
mat (except if you set --show_fullpath). It makes things simpler for you to make
 crossplatform regex patterns.
- Use [^/]+ to match any file/folder in the filepath: because paths are always u
nix-like, you can use [^/]+ to match any part of the filepath. Eg, "([^/]+)/([^/
]+)/data/mprage/.+\.(img|hdr|txt)" will match "UWS/John_Doe/data/mprage/12345_t1
_mprage_98782.hdr".
- Split your big task in several smaller, simpler subtasks: instead of trying to
 do a regex that match T1, T2, DTI, everything at the same time, try to focus on
 only one modality at a time and execute them using multiple regex queries: eg,
move first structural images, then functional images, then dti, etc. instead of
all at once.
- Python module: this library can be used as a Python module to include in your
scripts (just call `main(return_report=True)`).

Note: use --gui (without any other argument) to launch the experimental gui (nee
ds Gooey library).


optional arguments:
  -h, --help            show this help message and exit
  -i /some/path, --input /some/path
                        Path to the input folder
  -ri "sub[^/]+/(\d+)", --regex_input "sub[^/]+/(\d+)"
                        Regex to match input paths. Must be defined relatively f
rom --input folder. Do not forget to enclose it in double quotes (and not single
)! To match any directory, use [^/\]* or the alias \dir.
  -o /new/path, --output /new/path
                        Path to the output folder (where file will get copied ov
er if --copy)
  -ro "newsub/\1", --regex_output "newsub/\1"
                        Regex to substitute input paths to convert to output pat
hs. Must be defined relatively from --output folder. If not provided but --outpu
t is specified, will keep the same directory layout as input (useful to extract
specific files without changing layout). Do not forget to enclose it in double q
uotes!
  -c, --copy            Copy the matched input paths to the regex-substituted ou
tput paths.
  -s, --symlink         Copy with a symbolic/soft link the matched input paths t
o the regex-substituted output paths (works only on Linux).
  -m, --move            Move the matched input paths to the regex-substituted ou
tput paths.
  -d, --delete          Delete the matched files.
  -t, --test            Regex test mode: Stop after the first matched file and s
how the result of substitution. Useful to quickly check if the regex patterns ar
e ok.
  -y, --yes             Automatically accept the simulation and apply changes (g
ood for batch processing and command chaining).
  -f, --force           Force overwriting the target path already exists. Note t
hat by default, if a file already exist, without this option, it won't get overw
ritten and no message will be displayed.
  --show_fullpath       Show full paths instead of relative paths in the simulat
ion.
  -ra 1:10-255, --range 1:10-255
                        Range mode: match only the files with filenames containi
ng numbers in the specified range. The format is: (regex-match-group-id):(range-
start)-(range-end). regex-match-group-id is the id of the regular expression tha
t will contain the numbers that must be compared to the range. range-end is incl
usive.
  --report pathmatcher_report.txt
                        Where to store the simulation report (default: pwd = cur
rent working dir).
  -l /some/folder/filename.log, --log /some/folder/filename.log
                        Path to the log file. (Output will be piped to both the
stdout and the log file)
  -v, --verbose         Verbose mode (show more output).
  --silent              No console output (but if --log specified, the log will
still be saved in the specified file).
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

### Tutorial

Here is a short introduction in the usage of `pathmatcher.py`.

The most important trick to use `pathmatcher.py` efficiently that you should remember is this one: **try to break operations over multiple commands**. Indeed, it's simpler to match anatomical first, then functional, then dwi, etc... Rather than trying to match and reorder them all in only one command (which is possible but hard, for exactly the same result!).

Let's take a concrete example: we are going to reorganize the NIfTI files from the [ABIDE I dataset](http://fcon_1000.projects.nitrc.org/indi/abide/) to the [BIDS scheme](http://bids.neuroimaging.io/).

To do that, first create a directory anywhere you want (we will call this directory the "root directory", and unzip inside all ABIDE I dataset in one folder "ABIDE" (just "unzip here" the ABIDE I archives and this will create the `ABIDE` folder with the expected scheme). Then, inside the root directory, create another folder `ABIDE-BIDS` just beside the `ABIDE` folder. Now, open a terminal/console, and `cd` to the root directory, where there are now two subdirectories: "ABIDE" with ABIDE1 data, and `ABIDE-BIDS` that is empty.

Now, in the commandline, execute the two following commands:

```python
python pathmatcher.py -ri "Caltech_([0-9]+)/\dir/scans/anat/resources/NIfTI/files/mprage.nii.gz" -ro "sub-\1/anat/sub-\1_T1w.nii.gz" -i ABIDE/ -o ABIDE-BIDS/ -c

python pathmatcher.py -ri "Caltech_([0-9]+)/\dir/scans/rest/resources/NIfTI/files/rest.nii.gz" -ro "sub-\1/func/sub-\1_task-rest_bold.nii.gz" -i ABIDE/ -o ABIDE-BIDS/ -c
```

Where `-i = --input` (base input directory), `-o = --output` (base output directory where files will get copied/moved), `-ri = --regex_input` (regular expression to match input files), `-ro = --regex_output` (regular expression to copy/move input files to output folder), `-c = --copy` (to enable copy mode, can also --symlink, --move, --delete). Note that you can type `--help` to get an extensive documentation of the arguments along with advices.

Note also that `\dir` is an alias for `[^/\]*`, which allows to reliably match any directory in the path. Note also that `--regex_input` (`-ri`) and `--regex_output` (`-ro`) are matching paths relative to the `--input` and `--output` folders, thus nothing above `--input` and `--output` exist for pathmatcher. This was done so for two reasons: to more easily make your regexp (because you don't have to care about any parent folder from your `--input` or `--output`), and because of safety (to avoid `--delete` on your disk root! You are guaranteed that patchmatcher only works on subdirs).

After executing both of these commands, `pathmatcher.py` will generate a report detailing all file operations it will do, and eventually warn you about conflicts (files getting the same filename and thus collisionning in the output folder).

This works alright, converting the `ABIDE I` dataset scheme to `BIDS`, but this can be made simpler. Pathmatcher was made to allow for loose matching, so basically the idea is that you should try to match only the things that are necessary for you (either for recapture to use in the output like subject's id, or just to disambiguate like the folder name). Here are two simplified commands doing the same thing as above:

```python
python pathmatcher.py -c -i "ABIDE/" -o "ABIDE-BIDS/" -ri "Caltech_([0-9]+)/.+/mprage.nii.gz" -ro "sub-\1/anat/sub-\1_T1w.nii.gz"

python pathmatcher.py -c -i "ABIDE/" -o "ABIDE-BIDS/" -ri "Caltech_([0-9]+)/.+/rest.nii.gz" -ro "sub-\1/func/sub-\1_task-rest_bold.nii.gz"
```

Also partial matching is supported, so if you just want to get the list of all T1, you can do the following:

```python
python pathmatcher.py -i "ABIDE/" -ri "mprage.nii.gz"
```

This will generate the whole list of T1 and show them in a report.

Of course, you can also use absolute paths for `--input` and `--output`.

And a last trick to help you when you design the regular expressions: use the `--test` argument to see if it matches at least one file, and what operation will be done:

```python
python pathmatcher.py -c --test -i "ABIDE/" -o "ABIDE-BIDS/" -ri "Caltech_([0-9]+)/.+/mprage.nii.gz" -ro "sub-\1/anat/sub-\1_T1w.nii.gz"
```

Result:

```
== Regex Path Matcher started ==

Parameters:
- Input root: C:\GigaData\BIDS\ABIDE
- Input regex: Caltech_([0-9]+)/.+/mprage.nii.gz
- Output root: C:\GigaData\BIDS\ABIDE-BIDS
- Output regex: sub-\1/anat/sub-\1_T1w.nii.gz


Computing paths matching and simulation report, please wait (total time depends
on files count - filesize has no influence). Press CTRL+C to abort

Match: Caltech_51456/Caltech_51456/scans/anat/resources/NIfTI/files/mprage.nii.gz --> sub-51456/anat/sub-51456_T1w.nii.gz


End of simulation. 1 files matched.
```

Finally, `pathmatcher.py` can be used as an integral part of your own scripts, by either using it on commandline with the `--yes` argument to skip the report, or from your own python script by using the following:

```python
from pathmatcher import main as pm

# Match all T1 from ABIDE I, don't forget the r'' to avoid conflicts with / character
# You can use the commandline arguments, but the script will be called without bash but directly inside Python
my_results = pm(r'-i "ABIDE/" -ri "mprage.nii.gz"', return_report=True)  # use return_report=True to get the matches returned to your my_results variable

print(my_results)
```

A concrete example of scripting of `pathmatcher.py` can be found inside the `reorientation_registration_helper.py` script, which streamlines the manual preprocessing of fMRI data (reorientation, coregistration, quality and motion assessment, generation of composite motion metrics such as framewise median absolute deviation, etc).

### Similar projects

A similar project, and potentially more powerful, is [fselect](https://github.com/jhspetersson/fselect), which allows to use SQL-like queries on files. In MATLAB, similar functions are available in [dirPlus](https://github.com/kpeaton/dirPlus).

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
