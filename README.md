# neuro_experiments_tools
Various tools I made to help automate some usual tasks.

Each tool is placed in its own folder. Most tools will be in Python, but you can expect to see some tools in Matlab or other languages as they fit my needs.

All tools are licensed under MIT (but not necessarily the required/optional libraries, please check their licences).

The rest of this document will describe each tool's purpose, usage and linked libraries.

## Regex path reorganizer

### Description

A file and folder hierarchy management tool with a regular expression matcher. Can display a simulation report and automatically detect conflicts (already existing files, collisions of multiple files copied to the same output filename because of regexp, etc.).

If you often run experiments, you use scripts and applications, with some that you didn't design yourself. It might then happen that these apps/scripts expect a specific directory layout to work. Usually, you reorganize your files manually. If you happen to know this situation, this tool might help you: just specify a regular expression matching the files you need, enter an output regular expression (that can reuse parts of the input files, for example your subjects ids, using regexp groups and recall), and then launch the program.

Runs on Python 2.7.11, but uses good standards to ensure easy conversion to Python 3 in case you really need it.

### Usage

```
usage: regex_path_reorganizer.py [-h] -i /some/path -o /new/path -ri
                                 sub[^/\]*)/(\d) -ro newsub/\1/\2 [-y] [-f]
                                 [-s] [--show_fullpath] [--report REPORT]
                                 [-l /some/folder/filename.log] [-v]
                                 [--silent]

Regex Path Reorganizer v0.7
Description: Copy files/folder from one path to a new path, with the wanted architecture, matched via regular expression.
This app is essentially a path matcher using regexp, and it then rewrites the path using regexp, so that you can reuse elements from input path to build the output path.
This is very useful to reorganize folders for experiments, where scripts/softwares expect a specific directories layout in order to work.

Note that the paths are compared against filepaths, not just folders (but of course you can match folders, but remember when designing your regexp that it will compared against filepath).

Note: use --gui (without any other argument) to launch the experimental gui (needs Gooey library).


optional arguments:
  -h, --help            show this help message and exit
  -i /some/path, --input /some/path
                        Path to the input folder
  -o /new/path, --output /new/path
                        Path to the output folder (where file will get copied over)
  -ri (sub[^/\]*)/(*.*), --regex_input (sub[^/\]*)/(\d)
                        Regex for input folder/files filter. Must be defined relatively from basepath (eg, do not prepend the path with /some/path).
  -ro newsub/\1/\2, --regex_output newsub/\1/\2
                        Regex for output folder/files structure. Must be defined relatively from basepath.
  -y, --yes             Automatically accept the simulation and apply changes (good for batch processing and command chaining).
  -f, --force           Force overwriting the target path already exists. Note that by default, if a file already exist, without this option, it won't get overwritten and no message will be displayed.
  -s, --simulate        Only simulate, print the list and stop.
  --show_fullpath       Show full paths instead of relative paths in the simulation.
  --report REPORT       Where to store the simulation report.
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