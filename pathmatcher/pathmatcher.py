#!/usr/bin/env python
#
# pathmatcher.py
# Copyright (C) 2016 Larroque Stephen
#
# Licensed under the MIT License (MIT)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#=================================
#        Regular Expression Path Reorganizer
#                    Python 2.7.11
#                by Stephen Larroque
#                     License: MIT
#            Creation date: 2016-03-24
#=================================
#
#
# TODO:
# * optimization: re.sub inputpath directly on list of all files in a folder?
# * No recwalk so that can copy whole folder directly, quicker
#

from __future__ import print_function

__version__ = '0.9'

import argparse
import os
import posixpath  # to generate unix paths
import re
import shlex
import shutil
import sys
import traceback

from pathlib2 import PurePath, PureWindowsPath, PurePosixPath # opposite operation of os.path.join (split a path
from tee import Tee

try:
    from scandir import walk # use the faster scandir module if available (Python >= 3.5), see https://github.com/benhoyt/scandir
except ImportError:
    from os import walk # else, default to os.walk()

# Progress bar if available
try:
    from tqdm import tqdm
except:
    # Mockup tqdm (no progress bar)
    print("** NOTICE: Please install tqdm to display a progress bar **")
    def tqdm(*args, **kwargs):
        if args:
            return args[0]
        return kwargs.get('iterable', None)



#***********************************
#                       AUX
#***********************************

class More(object):
    def __init__(self, num_lines):
        self.num_lines = num_lines
    def __ror__(self, other):
        s = str(other).split("\n")
        for i in range(0, len(s), self.num_lines):
            print("\n".join(s[i:i+self.num_lines]))
            raw_input("Press <Enter> for more")

def open_with_default_app(filepath):
    if sys.platform == "linux" or sys.platform == "linux2":
        os.system('%s %s' % (os.getenv('EDITOR'), filepath))
    elif sys.platform == "win32":
        os.system("start "+filepath)
    elif sys.platform == "darwin":
        os.system("open "+filepath)

def str_to_raw(str):
    '''Convert string received from commandline to raw (unescaping the string)'''
    try:  # Python 2
        return str.decode('string_escape')
    except:  # Python 3
        return str.encode().decode('unicode_escape')

def is_file(dirname):
    '''Checks if a path is an actual file that exists'''
    if not os.path.isfile(dirname):
        msg = "{0} is not an existing file".format(dirname)
        raise ArgumentTypeError(msg)
    else:
        return dirname

def is_dir(dirname):
    '''Checks if a path is an actual directory that exists'''
    if not os.path.isdir(dirname):
        msg = "{0} is not a directory".format(dirname)
        raise ArgumentTypeError(msg)
    else:
        return dirname

def is_dir_or_file(dirname):
    '''Checks if a path is an actual directory that exists or a file'''
    if not os.path.isdir(dirname) and not os.path.isfile(dirname):
        msg = "{0} is not a directory nor a file".format(dirname)
        raise ArgumentTypeError(msg)
    else:
        return dirname

def fullpath(relpath):
    '''Relative path to absolute'''
    if (type(relpath) is object or hasattr(relpath, 'read')): # relpath is either an object or file-like, try to get its name
        relpath = relpath.name
    return os.path.abspath(os.path.expanduser(relpath))

def recwalk(inputpath, sorting=True):
    '''Recursively walk through a folder. This provides a mean to flatten out the files restitution (necessary to show a progress bar). This is a generator.'''
    # If it's only a single file, return this single file
    if os.path.isfile(inputpath):
        abs_path = fullpath(inputpath)
        yield os.path.dirname(abs_path), os.path.basename(abs_path)
    # Else if it's a folder, walk recursively and return every files
    else:
        for dirpath, dirs, files in walk(inputpath):	
            if sorting:
                files.sort()
                dirs.sort() # sort directories in-place for ordered recursive walking
            for filename in files:
                yield (dirpath, filename) # return directory (full path) and filename

def path2unix(path, nojoin=False, fromwinpath=False):
    '''From a path given in any format, converts to posix path format
    fromwinpath=True forces the input path to be recognized as a Windows path (useful on Unix machines to unit test Windows paths)'''
    if fromwinpath:
        pathparts = list(PureWindowsPath(path).parts)
    else:
        pathparts = list(PurePath(path).parts)
    if nojoin:
        return pathparts
    else:
        return posixpath.join(*pathparts)

def remove_if_exist(path):  # pragma: no cover
    """Delete a file or a directory recursively if it exists, else no exception is raised"""
    if os.path.exists(path):
        if os.path.isdir(path):
            shutil.rmtree(path)
            return True
        elif os.path.isfile(path):
            os.remove(path)
            return True
    return False

def create_dir_if_not_exist(path):  # pragma: no cover
    """Create a directory if it does not already exist, else nothing is done and no error is return"""
    if not os.path.exists(path):
        os.makedirs(path)

def copy_any(src, dst, only_missing=False):  # pragma: no cover
    """Copy a file or a directory tree, deleting the destination before processing"""
    if not only_missing:
        remove_if_exist(dst)
    if os.path.exists(src):
        if os.path.isdir(src):
            if not only_missing:
                shutil.copytree(src, dst, symlinks=False, ignore=None)
            else:
                for dirpath, filepath in recwalk(src):
                    srcfile = os.path.join(dirpath, filepath)
                    relpath = os.path.relpath(srcfile, src)
                    dstfile = os.path.join(dst, relpath)
                    if not os.path.exists(dstfile):
                        create_dir_if_not_exist(os.path.dirname(dstfile))
                        shutil.copyfile(srcfile, dstfile)
                        shutil.copystat(srcfile, dstfile)
            return True
        elif os.path.isfile(src) and (not only_missing or not os.path.exists(dst)):
            create_dir_if_not_exist(os.path.dirname(dst))
            shutil.copyfile(src, dst)
            shutil.copystat(src, dst)
            return True
    return False



#***********************************
#        GUI AUX FUNCTIONS
#***********************************

# Try to import Gooey for GUI display, but manage exception so that we replace the Gooey decorator by a dummy function that will just return the main function as-is, thus keeping the compatibility with command-line usage
try:  # pragma: no cover
    import gooey
except ImportError as exc:
    # Define a dummy replacement function for Gooey to stay compatible with command-line usage
    class gooey(object):  # pragma: no cover
        def Gooey(func):
            return func
    # If --gui was specified, then there's a problem
    if len(sys.argv) > 1 and sys.argv[1] == '--gui':  # pragma: no cover
        print('ERROR: --gui specified but an error happened with lib/gooey, cannot load the GUI (however you can still use this script in commandline). Check that lib/gooey exists and that you have wxpython installed. Here is the error: ')
        raise(exc)

def conditional_decorator(flag, dec):  # pragma: no cover
    def decorate(fn):
        if flag:
            return dec(fn)
        else:
            return fn
    return decorate

def check_gui_arg():  # pragma: no cover
    '''Check that the --gui argument was passed, and if true, we remove the --gui option and replace by --gui_launched so that Gooey does not loop infinitely'''
    if len(sys.argv) > 1 and sys.argv[1] == '--gui':
        # DEPRECATED since Gooey automatically supply a --ignore-gooey argument when calling back the script for processing
        #sys.argv[1] = '--gui_launched' # CRITICAL: need to remove/replace the --gui argument, else it will stay in memory and when Gooey will call the script again, it will be stuck in an infinite loop calling back and forth between this script and Gooey. Thus, we need to remove this argument, but we also need to be aware that Gooey was called so that we can call gooey.GooeyParser() instead of argparse.ArgumentParser() (for better fields management like checkboxes for boolean arguments). To solve both issues, we replace the argument --gui by another internal argument --gui_launched.
        return True
    else:
        return False

def AutoGooey(fn):  # pragma: no cover
    '''Automatically show a Gooey GUI if --gui is passed as the first argument, else it will just run the function as normal'''
    if check_gui_arg():
        return gooey.Gooey(fn)
    else:
        return fn



#***********************************
#                       MAIN
#***********************************



@AutoGooey
def main(argv=None):
    if argv is None: # if argv is empty, fetch from the commandline
        argv = sys.argv[1:]
    elif isinstance(argv, _str): # else if argv is supplied but it's a simple string, we need to parse it to a list of arguments before handing to argparse or any other argument parser
        argv = shlex.split(argv) # Parse string just like argv using shlex

    #==== COMMANDLINE PARSER ====

    #== Commandline description
    desc = '''Regex Path Matcher v%s
Description: Copy files/folder from one path to a new path, with the wanted architecture, matched via regular expression.
This app is essentially a path matcher using regexp, and it then rewrites the path using regexp, so that you can reuse elements from input path to build the output path.
This is very useful to reorganize folders for experiments, where scripts/softwares expect a specific directories layout in order to work.

Note that the paths are compared against filepaths, not just folders (but of course you can match folders, but remember when designing your regexp that it will compared against filepath).

Note: use --gui (without any other argument) to launch the experimental gui (needs Gooey library).
    ''' % __version__
    ep = ''' '''

    #== Commandline arguments
    #-- Constructing the parser
    # Use GooeyParser if we want the GUI because it will provide better widgets
    if len(argv) > 0 and (argv[0] == '--gui' and not '--ignore-gooey' in argv):  # pragma: no cover
        # Initialize the Gooey parser
        main_parser = gooey.GooeyParser(add_help=True, description=desc, epilog=ep, formatter_class=argparse.RawTextHelpFormatter)
        # Define Gooey widget types explicitly (because type auto-detection doesn't work quite well)
        widget_dir = {"widget": "DirChooser"}
        widget_filesave = {"widget": "FileSaver"}
        widget_file = {"widget": "FileChooser"}
        widget_text = {"widget": "TextField"}
    else: # Else in command-line usage, use the standard argparse
        # Delete the special argument to avoid unrecognized argument error in argparse
        if len(argv) > 0 and '--ignore-gooey' in argv[0]: argv.remove('--ignore-gooey') # this argument is automatically fed by Gooey when the user clicks on Start
        # Initialize the normal argparse parser
        main_parser = argparse.ArgumentParser(add_help=True, description=desc, epilog=ep, formatter_class=argparse.RawTextHelpFormatter)
        # Define dummy dict to keep compatibile with command-line usage
        widget_dir = {}
        widget_filesave = {}
        widget_file = {}
        widget_text = {}
    # Required arguments
    main_parser.add_argument('-i', '--input', metavar='/some/path', type=str, required=True,
                        help='Path to the input folder', **widget_dir)
    main_parser.add_argument('-o', '--output', metavar='/new/path', type=str, required=True,
                        help='Path to the output folder (where file will get copied over)', **widget_dir)
    main_parser.add_argument('-ri', '--regex_input', metavar=r'(sub[^/\]*)/(\d)', type=str, required=True,
                        help='Regex for input folder/files filter. Must be defined relatively from basepath (eg, do not prepend the path with /some/path).')
    main_parser.add_argument('-ro', '--regex_output', metavar=r'newsub/\1/\2', type=str, required=True,
                        help='Regex for output folder/files structure. Must be defined relatively from basepath.')

    # Optional general arguments
    main_parser.add_argument('-y', '--yes', action='store_true', required=False, default=False,
                        help='Automatically accept the simulation and apply changes (good for batch processing and command chaining).')
    main_parser.add_argument('-f', '--force', action='store_true', required=False, default=False,
                        help='Force overwriting the target path already exists. Note that by default, if a file already exist, without this option, it won\'t get overwritten and no message will be displayed.')
    main_parser.add_argument('-s', '--simulate', action='store_true', required=False, default=False,
                        help='Only simulate, print the list and stop.')
    main_parser.add_argument('--show_fullpath', action='store_true', required=False, default=False,
                        help='Show full paths instead of relative paths in the simulation.')
    main_parser.add_argument('--report', type=str, required=False, default='pathmatcher_report.txt',
                        help='Where to store the simulation report.')
    main_parser.add_argument('-l', '--log', metavar='/some/folder/filename.log', type=str, required=False,
                        help='Path to the log file. (Output will be piped to both the stdout and the log file)', **widget_filesave)
    main_parser.add_argument('-v', '--verbose', action='store_true', required=False, default=False,
                        help='Verbose mode (show more output).')
    main_parser.add_argument('--silent', action='store_true', required=False, default=False,
                        help='No console output (but if --log specified, the log will still be saved in the specified file).')


    #== Parsing the arguments
    args = main_parser.parse_args(argv) # Storing all arguments to args
    
    #-- Set variables from arguments
    inputpath = fullpath(args.input)
    rootfolderpath = inputpath
    outputpath = fullpath(args.output)
    rootoutpath = outputpath
    regex_input = args.regex_input
    regex_output = args.regex_output
    simulate = args.simulate
    yes_flag = args.yes
    force = args.force
    only_missing = not force
    show_fullpath = args.show_fullpath
    reportpath = args.report
    verbose = args.verbose
    silent = args.silent

    # -- Sanity checks
    if os.path.isfile(inputpath): # if inputpath is a single file (instead of a folder), then define the rootfolderpath as the parent directory (for correct relative path generation, else it will also truncate the filename!)
        rootfolderpath = os.path.dirname(inputpath)
    if os.path.isfile(outputpath): # if inputpath is a single file (instead of a folder), then define the rootfolderpath as the parent directory (for correct relative path generation, else it will also truncate the filename!)
        rootoutpath = os.path.dirname(outputpath)

    if not os.path.isdir(rootfolderpath):
        raise NameError('Specified input path does not exist. Please check the specified path')

    # -- Configure the log file if enabled (ptee.write() will write to both stdout/console and to the log file)
    if args.log:
        ptee = Tee(args.log, 'a', nostdout=silent)
        #sys.stdout = Tee(args.log, 'a')
        sys.stderr = Tee(args.log, 'a', nostdout=silent)
    else:
        ptee = Tee(nostdout=silent)

    #== Main program
    try:
        regin = re.compile(str_to_raw(regex_input))
        regout = re.compile(str_to_raw(regex_output))
    except re.error as exc:
        ptee.write("Regular expression is not correct, please fix it! Here is the error stack:\n")
        ptee.write(traceback.format_exc())
        return 1

    ptee.write("== Regex Path Matcher started ==\n")
    ptee.write("Parameters:")
    ptee.write("- Input: %s" % inputpath)
    ptee.write("- Output: %s" % outputpath)
    ptee.write("- Regex input: %s" % regex_input)
    ptee.write("- Regex output: %s" % regex_output)
    ptee.write("\n")

    # == SIMULATION STEP
    files_list = []  # "to copy" files list, stores the list of input files and their corresponding output path (computed using regex)
    ptee.write("Calculating paths restructuration and simulation report, please wait (total time depends on how many files you have, filesize has no influence)...")
    for dirpath, filename in tqdm(recwalk(inputpath), unit='files', leave=True, smoothing=0):
        # Get full absolute filepath and relative filepath from base dir
        filepath = os.path.join(dirpath, filename)
        relfilepath = path2unix(os.path.relpath(filepath, rootfolderpath)) # File relative path from the root (we truncate the rootfolderpath so that we can easily check the files later even if the absolute path is different)
        # Check if relative filepath matches the input regex
        if regin.match(relfilepath):  # Matched! We store it in the "to copy" files list
            # Compute the output filepath using output regex
            newfilepath = regin.sub(regex_output, relfilepath)
            fulloutpath = os.path.join(rootoutpath, newfilepath)
            # Store both paths into the "to copy" list
            files_list.append([filepath, fulloutpath])
            if verbose and not silent: ptee.write("Match: %s --> %s" % (relfilepath, newfilepath))

    # End of simulation, show result and ask user if s/he wants to apply
    ptee.write("Preparing simulation report, please wait...")

    # Initialize conflicts global flags
    conflict1_flag = False
    conflict2_flag = False

    # Show result in console using a Python implementation of MORE (because file list can be quite long)
    #more_display=More(num_lines=30)
    #"\n".join(map(str,files_list)) | more_display

    # Precompute conflict type 2 lookup table (= dict where each key is a output filepath, and the value the number of occurrences)
    outdict = {}
    for file_op in files_list:
        outdict[file_op[1]] = outdict.get(file_op[1], 0) + 1

    # Build and show simulation report in user's default text editor
    with open(reportpath, 'w') as reportfile:
        reportfile.write("== SIMULATION OF REORGANIZATION ==\n")
        reportfile.write("Total number of files matched: %i\n" % len(files_list))
        reportfile.write("\n")
        for file_op in files_list:
            # Check if there was a conflict:
            # Type 1 - already existing output file)
            fulloutpath = os.path.join(rootoutpath, file_op[1])
            conflict1 = False
            if os.path.exists(fulloutpath):
                conflict1 = True
                conflict1_flag = True

            # 2- two files will be created with same output name
            conflict2 = False
            if outdict[file_op[1]] > 1:
                conflict2 = True
                conflict2_flag = True

            # Show relative or absolute paths?
            if show_fullpath:
                showinpath = file_op[0]
                showoutpath = file_op[1]
            else:
                showinpath = path2unix(os.path.relpath(file_op[0], rootfolderpath))
                showoutpath = path2unix(os.path.relpath(file_op[1], rootoutpath))

            # Write into report file
            reportfile.write("* %s --> %s %s %s" % (showinpath, showoutpath, "[ALREADY_EXIST]" if conflict1 else '', "[CONFLICT]" if conflict2 else ''))
            reportfile.write("\n")
    # Open the simulation report with the system's default text editor
    if not yes_flag:  # if --yes is supplied, just skip question and apply!
        ptee.write("Opening simulation report with your default editor, a new window should open.")
        open_with_default_app(reportpath)

    # == USER NOTIFICATION AND VALIDATION
    # Notify user of conflicts
    ptee.write("\n")
    if conflict1_flag:
        ptee.write("Warning: conflict type 1 (files already exist) has been detected. Please use --force if you want to overwrite them, else they will be skipped.\n")
    if conflict2_flag:
        ptee.write("Warning: conflict type 2 (collision) has been detected. If you continue, several files will have the same name due to the specified output regex (thus, some will be lost). You should cancel and check your regular expression for output.\n")
    if not conflict1_flag and not conflict2_flag:
        ptee.write("No conflict detected. You are good to go!")

    # Ask user if we should apply
    if not yes_flag:  # if --yes is supplied, just skip question and apply!
        applycopy = raw_input("Do you want to apply the result of the path reorganization simulation on %i files? [Y/N]: " % len(files_list))
        if applycopy.lower() != 'y':
            return 0

    # == APPLY STEP
    ptee.write("Applying new path structure, please wait (total time depends on file sizes and matches count)...")
    for infilepath, outfilepath in tqdm(files_list, total=len(files_list), unit='files', leave=True):
        if verbose and not silent: ptee.write("%s --> %s" % (infilepath, outfilepath))
        # Copy the file! (User previously accepted to apply the simulation)
        copy_any(infilepath, outfilepath, only_missing=only_missing)

    # End of main function
    return 0

# Calling main function if the script is directly called (not imported as a library in another program)
if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
