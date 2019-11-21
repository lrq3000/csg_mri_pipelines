#!/usr/bin/env python
#
# pathmatcher.py
# Copyright (C) 2016-2019 Larroque Stephen
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
#                    Python 2.7.15
#                by Stephen Larroque
#                     License: MIT
#            Creation date: 2016-03-24
#=================================
#
#
# TODO:
# * optimization: re.sub inputpath directly on list of all files in a folder? Modify recwalk to include regin and regout, and match directly all files in a folder and substitute. Also, stop if folder match and return it (to copy the whole folder directly instead of per file). See http://stackoverflow.com/questions/120656/directory-listing-in-python
#

from __future__ import print_function
from __future__ import absolute_import
from __future__ import unicode_literals

from future import standard_library
standard_library.install_aliases()
from builtins import str
from builtins import input
from builtins import range
from past.builtins import basestring
from builtins import object

__version__ = '1.3.0'

import sys
PY3 = (sys.version_info >= (3,0,0))

import argparse
import chardet
import os
import posixpath  # to generate unix paths
import re
import shlex
import shutil
import traceback
import urllib.request, urllib.parse, urllib.error

if PY3:
    from pathlib import PurePath, PureWindowsPath, PurePosixPath # opposite operation of os.path.join (split a path
    from tee import Tee
else:
    from .pathlib2 import PurePath, PureWindowsPath, PurePosixPath # opposite operation of os.path.join (split a path
    from .tee import Tee

from io import StringIO

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

try:
    _str = basestring
except NameError:
    _str = str

try:
    import ujson as json
except ImportError as exc:
    import json



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
            input("Press <Enter> for more")

def open_with_default_app(filepath):
    """Open the report with the default text editor"""
    if sys.platform == "linux" or sys.platform == "linux2":
        defaulteditor = os.getenv('EDITOR')
        if defaulteditor:
            # default editor is set in bash, use it
            os.system('%s %s' % (defaulteditor, filepath))
        else:
            # else no default editor is set in bash, use xdg-open
            os.system("xdg-open "+filepath)
    elif sys.platform == "win32":
        os.system("start "+filepath)
    elif sys.platform == "darwin":
        os.system("open "+filepath)
    else:
        # Failsafe case: use the webbrowser module to open the file
        import webbrowser
        webbrowser.open(filepath)

def str_to_raw(str):
    """Convert string received from commandline to raw (unescaping the string)"""
    try:  # Python 2
        return str.decode('string_escape')
    except:  # Python 3
        return str.encode().decode('unicode_escape')

def is_file(dirname):
    """Checks if a path is an actual file that exists"""
    if not os.path.isfile(dirname):
        msg = "{0} is not an existing file".format(dirname)
        raise ArgumentTypeError(msg)
    else:
        return dirname

def is_dir(dirname):
    """Checks if a path is an actual directory that exists"""
    if not os.path.isdir(dirname):
        msg = "{0} is not a directory".format(dirname)
        raise ArgumentTypeError(msg)
    else:
        return dirname

def is_dir_or_file(dirname):
    """Checks if a path is an actual directory that exists or a file"""
    if not os.path.isdir(dirname) and not os.path.isfile(dirname):
        msg = "{0} is not a directory nor a file".format(dirname)
        raise ArgumentTypeError(msg)
    else:
        return dirname

def fullpath(relpath):
    """Relative path to absolute"""
    if (type(relpath) is object or hasattr(relpath, 'read')): # relpath is either an object or file-like, try to get its name
        relpath = relpath.name
    return os.path.abspath(os.path.expanduser(relpath))

def recwalk(inputpath, sorting=True, folders=False, topdown=True):
    """Recursively walk through a folder. This provides a mean to flatten out the files restitution (necessary to show a progress bar). This is a generator."""
    # If it's only a single file, return this single file
    if os.path.isfile(inputpath):
        abs_path = fullpath(inputpath)
        yield os.path.dirname(abs_path), os.path.basename(abs_path)
    # Else if it's a folder, walk recursively and return every files
    else:
        for dirpath, dirs, files in walk(inputpath, topdown=topdown):	
            if sorting:
                files.sort()
                dirs.sort()  # sort directories in-place for ordered recursive walking
            # return each file
            for filename in files:
                yield (dirpath, filename)  # return directory (full path) and filename
            # return each directory
            if folders:
                for folder in dirs:
                    yield (dirpath, folder)

def path2unix(path, nojoin=False, fromwinpath=False):
    """From a path given in any format, converts to posix path format
    fromwinpath=True forces the input path to be recognized as a Windows path (useful on Unix machines to unit test Windows paths)"""
    if not path:
        return path
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

def copy_any(src, dst, only_missing=False, symlink=False):  # pragma: no cover
    """Copy a file or a directory tree, deleting the destination before processing.
    If symlink, then the copy will only create symbolic links to the original files."""
    def real_copy(srcfile, dstfile):
        """Copy a file or a folder and keep stats"""
        shutil.copyfile(srcfile, dstfile)
        shutil.copystat(srcfile, dstfile)
    def symbolic_copy(srcfile, dstfile):
        """Create a symlink (symbolic/soft link) instead of a real copy"""
        os.symlink(srcfile, dstfile)

    # Delete destination folder/file if it exists
    if not only_missing:
        remove_if_exist(dst)
    # Continue only if source exists
    if os.path.exists(src):
        # If it's a folder, recursively copy its content
        if os.path.isdir(src):
            # If we copy everything, we already removed the destination folder, so we can just copy it all
            if not only_missing and not symlink:
                shutil.copytree(src, dst, symlinks=False, ignore=None)
            # Else we will check each file and add only new ones (present in source but absent from destination)
            # Also if we want to only symlink all files, shutil.copytree() does not support that, so we do it here
            else:
                for dirpath, filepath in recwalk(src):
                    srcfile = os.path.join(dirpath, filepath)
                    relpath = os.path.relpath(srcfile, src)
                    dstfile = os.path.join(dst, relpath)
                    if not only_missing or not os.path.exists(dstfile):  # only_missing -> dstfile must not exist
                        create_dir_if_not_exist(os.path.dirname(dstfile))
                        if symlink:
                            symbolic_copy(srcfile, dstfile)
                        else:
                            real_copy(srcfile, dstfile)
            return True
        # Else it is a single file, copy the file
        elif os.path.isfile(src) and (not only_missing or not os.path.exists(dst)):
            create_dir_if_not_exist(os.path.dirname(dst))
            if symlink:
                symbolic_copy(src, dst)
            else:
                real_copy(src, dst)
            return True
    return False

def move_any(src, dst, only_missing=False):  # pragma: no cover
    """Move a file or a directory tree, deleting the destination before processing."""
    def real_move(srcfile, dstfile):
        """Move a file or a folder and keep stats"""
        shutil.move(srcfile, dstfile)

    # Delete destination folder/file if it exists
    if not only_missing:
        remove_if_exist(dst)
    # Continue only if source exists
    if os.path.exists(src):
        # If it's a folder, recursively copy its content
        if os.path.isdir(src):
            # We will check each file and add only new ones (present in source but absent from destination)
            for dirpath, filepath in recwalk(src):
                srcfile = os.path.join(dirpath, filepath)
                relpath = os.path.relpath(srcfile, src)
                dstfile = os.path.join(dst, relpath)
                if not only_missing or not os.path.exists(dstfile):  # only_missing -> dstfile must not exist
                    create_dir_if_not_exist(os.path.dirname(dstfile))
                    real_move(srcfile, dstfile)
            return True
        # Else it is a single file, copy the file
        elif os.path.isfile(src) and (not only_missing or not os.path.exists(dst)):
            create_dir_if_not_exist(os.path.dirname(dst))
            real_move(src, dst)
            return True
    return False

def pop_first_namedgroup(groupdict, value):
    """Search a value in a groupdict and remove the first key found from the dict"""
    for k,v in groupdict.items():
        if v == value:
            groupdict.pop(k)
            return k, v, groupdict
    return False, value, groupdict



#***********************************
#        GUI AUX FUNCTIONS
#***********************************

# Try to import Gooey for GUI display, but manage exception so that we replace the Gooey decorator by a dummy function that will just return the main function as-is, thus keeping the compatibility with command-line usage
try:  # pragma: no cover
    import gooey
except ImportError as exc:
    # Define a dummy replacement function for Gooey to stay compatible with command-line usage
    class gooey(object):  # pragma: no cover
        @staticmethod
        def Gooey(func):
            return func

def conditional_decorator(flag, dec):  # pragma: no cover
    def decorate(fn):
        if flag:
            return dec(fn)
        else:
            return fn
    return decorate

def check_gui_arg():  # pragma: no cover
    """Check that the --gui argument was passed, and if true, we remove the --gui option and replace by --gui_launched so that Gooey does not loop infinitely"""
    if len(sys.argv) == 1 or '--gui' in sys.argv:
        # DEPRECATED since Gooey automatically supply a --ignore-gooey argument when calling back the script for processing
        #sys.argv[1] = '--gui_launched' # CRITICAL: need to remove/replace the --gui argument, else it will stay in memory and when Gooey will call the script again, it will be stuck in an infinite loop calling back and forth between this script and Gooey. Thus, we need to remove this argument, but we also need to be aware that Gooey was called so that we can call gooey.GooeyParser() instead of argparse.ArgumentParser() (for better fields management like checkboxes for boolean arguments). To solve both issues, we replace the argument --gui by another internal argument --gui_launched.
        return True
    else:
        return False

def AutoGooey(fn):  # pragma: no cover
    """Automatically show a Gooey GUI if --gui is passed as the first argument, else it will just run the function as normal"""
    if check_gui_arg():
        return gooey.Gooey(fn)
    else:
        return fn



#***********************************
#                       MAIN
#***********************************



@AutoGooey
def main(argv=None, return_report=False, regroup=False):
    if argv is None: # if argv is empty, fetch from the commandline
        argv = sys.argv[1:]
    elif isinstance(argv, _str): # else if argv is supplied but it's a simple string, we need to parse it to a list of arguments before handing to argparse or any other argument parser
        argv = shlex.split(argv) # Parse string just like argv using shlex

    # If --gui was specified, then there's a problem
    if len(argv) == 0 or '--gui' in argv:  # pragma: no cover
        raise Exception('--gui specified but an error happened with lib/gooey, cannot load the GUI (however you can still use this script in commandline). Check that lib/gooey exists and that you have wxpython installed. Here is the error: ')

    #==== COMMANDLINE PARSER ====

    #== Commandline description
    desc = '''Regex Path Matcher v%s
Description: Match paths using regular expression, and then generate a report. Can also substitute using regex to generate output paths. A copy mode is also provided to allow the copy of files from input to output paths.
This app is essentially a path matcher using regexp, and it then rewrites the path using regexp, so that you can reuse elements from input path to build the output path.
This is very useful to reorganize folders for experiments, where scripts/softwares expect a specific directories layout in order to work.

Advices
-------
- Filepath comparison: Paths are compared against filepaths, not just folders (but of course you can match folders with regex, but remember when designing your regexp that it will compared against files paths, not directories).
- Relative filepath: Paths are relative to the rootpath (except if --show-fullpath) and that they are always unix style, even on Windows (for consistency on all platforms and to easily reuse regexp).
- Partial matching: partial matching regex is accepted, so you don't need to model the full filepath, only the part you need (eg, 'myfile' will match '/myfolder/sub/myfile-034.mat').
- Unix filepaths: on all platforms, including Windows, paths will be in unix format (except if you set --show_fullpath). It makes things simpler for you to make crossplatform regex patterns.
- Use [^/]+ to match any file/folder in the filepath: because paths are always unix-like, you can use [^/]+ to match any part of the filepath. Eg, "([^/]+)/([^/]+)/data/mprage/.+\.(img|hdr|txt)" will match "UWS/John_Doe/data/mprage/12345_t1_mprage_98782.hdr".
- Split your big task in several smaller, simpler subtasks: instead of trying to do a regex that match T1, T2, DTI, everything at the same time, try to focus on only one modality at a time and execute them using multiple regex queries: eg, move first structural images, then functional images, then dti, etc. instead of all at once.
- Python module: this library can be used as a Python module to include in your scripts (just call `main(return_report=True)`).

Note: use --gui (without any other argument) to launch the experimental gui (needs Gooey library).

In addition to the switches provided below, using this program as a Python module also provides 2 additional options:
 - return_report = True to return as a variable the files matched and the report instead of saving in a file.
 - regroup = True will return the matched files (if return_report=True) in a tree structure of nested list/dicts depending on if the groups are named or not. Groups can also avoid being matched by using non-matching groups in regex.
    ''' % __version__
    ep = ''' '''

    #== Commandline arguments
    #-- Constructing the parser
    # Use GooeyParser if we want the GUI because it will provide better widgets
    if (len(argv) == 0 or '--gui' in argv) and not '--ignore-gooey' in argv:  # pragma: no cover
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
    main_parser.add_argument('-ri', '--regex_input', metavar=r'"sub[^/]+/(\d+)"', type=str, required=True,
                        help=r'Regex to match input paths. Must be defined relatively from --input folder. Do not forget to enclose it in double quotes (and not single)! To match any directory, use [^/\]*? or the alias \dir, or \dirnodot if you want to match folders in combination with --dir switch.', **widget_text)

    # Optional output/copy mode
    main_parser.add_argument('-o', '--output', metavar='/new/path', type=str, required=False, default=None,
                        help='Path to the output folder (where file will get copied over if --copy)', **widget_dir)
    main_parser.add_argument('-ro', '--regex_output', metavar=r'"newsub/\1"', type=str, required=False, default=None,
                        help='Regex to substitute input paths to convert to output paths. Must be defined relatively from --output folder. If not provided but --output is specified, will keep the same directory layout as input (useful to extract specific files without changing layout). Do not forget to enclose it in double quotes!', **widget_text)
    main_parser.add_argument('-c', '--copy', action='store_true', required=False, default=False,
                        help='Copy the matched input paths to the regex-substituted output paths.')
    main_parser.add_argument('-s', '--symlink', action='store_true', required=False, default=False,
                        help='Copy with a symbolic/soft link the matched input paths to the regex-substituted output paths (works only on Linux).')
    main_parser.add_argument('-m', '--move', action='store_true', required=False, default=False,
                        help='Move the matched input paths to the regex-substituted output paths.')
    main_parser.add_argument('--move_fast', action='store_true', required=False, default=False,
                        help='Move the matched input paths to the regex-substituted output paths, without checking first that the copy was done correctly.')
    main_parser.add_argument('-d', '--delete', action='store_true', required=False, default=False,
                        help='Delete the matched files.')

    # Optional general arguments
    main_parser.add_argument('-t', '--test', action='store_true', required=False, default=False,
                        help='Regex test mode: Stop after the first matched file and show the result of substitution. Useful to quickly check if the regex patterns are ok.')
    main_parser.add_argument('--dir', action='store_true', required=False, default=False,
                        help='Match directories too? (else only files are matched)')
    main_parser.add_argument('-y', '--yes', action='store_true', required=False, default=False,
                        help='Automatically accept the simulation and apply changes (good for batch processing and command chaining).')
    main_parser.add_argument('-f', '--force', action='store_true', required=False, default=False,
                        help='Force overwriting the target path already exists. Note that by default, if a file already exist, without this option, it won\'t get overwritten and no message will be displayed.')
    main_parser.add_argument('--show_fullpath', action='store_true', required=False, default=False,
                        help='Show full paths instead of relative paths in the simulation.')
    main_parser.add_argument('-ra', '--range', type=str, metavar='1:10-255', required=False, default=False,
                        help='Range mode: match only the files with filenames containing numbers in the specified range. The format is: (regex-match-group-id):(range-start)-(range-end). regex-match-group-id is the id of the regular expression that will contain the numbers that must be compared to the range. range-end is inclusive.')
    main_parser.add_argument('-re', '--regex_exists', metavar=r'"newsub/\1"', type=str, required=False, default=None,
                        help='Regex of output path to check if the matched regex here is matched prior writing output files.', **widget_text)
    main_parser.add_argument('--report', type=str, required=False, default='pathmatcher_report.txt', metavar='pathmatcher_report.txt',
                        help='Where to store the simulation report (default: pwd = current working dir).', **widget_filesave)
    main_parser.add_argument('--noreport', action='store_true', required=False, default=False,
                        help='Do not create a report file, print the report in the console.')
    main_parser.add_argument('--tree', action='store_true', required=False, default=False,
                        help='Regroup in a tree structure the matched files according to named and unnamed regex groups, and save the result as a json file (pathmatcher_tree.json).')
    main_parser.add_argument('-l', '--log', metavar='/some/folder/filename.log', type=str, required=False,
                        help='Path to the log file. (Output will be piped to both the stdout and the log file)', **widget_filesave)
    main_parser.add_argument('-v', '--verbose', action='store_true', required=False, default=False,
                        help='Verbose mode (show more output).')
    main_parser.add_argument('--silent', action='store_true', required=False, default=False,
                        help='No console output (but if --log specified, the log will still be saved in the specified file).')


    #== Parsing the arguments
    args = main_parser.parse_args(argv) # Storing all arguments to args
    
    #-- Set variables from arguments
    inputpath = args.input
    outputpath = args.output if args.output else None
    regex_input = args.regex_input
    regex_output = args.regex_output
    regex_exists = args.regex_exists
    copy_mode = args.copy
    symlink_mode = args.symlink
    move_mode = args.move
    movefast_mode = args.move_fast
    delete_mode = args.delete
    test_flag = args.test
    dir_flag = args.dir
    yes_flag = args.yes
    force = args.force
    only_missing = not force
    show_fullpath = args.show_fullpath
    path_range = args.range
    reportpath = args.report
    noreport = args.noreport
    tree_flag = args.tree
    verbose = args.verbose
    silent = args.silent

    # -- Sanity checks

    # First check if there is any input path, it's always needed
    if inputpath is None:
        raise NameError('No input path specified! Please specify one!')

	# Try to decode in unicode, else we will get issues down the way when outputting files
    try:
        inputpath = str(inputpath)
    except UnicodeDecodeError as exc:
        inputpath = str(inputpath, encoding=chardet.detect(inputpath)['encoding'])
    if outputpath:
        try:
            outputpath = str(outputpath)
        except UnicodeDecodeError as exc:
            outputpath = str(outputpath, encoding=chardet.detect(outputpath)['encoding'])

    # Remove trailing spaces
    inputpath = inputpath.strip()
    if outputpath:
        outputpath = outputpath.strip()

    # Input or output path is a URL (eg: file:///media/... on Ubuntu/Debian), then strip that out
    RE_urlprotocol = re.compile(r'^\w{2,}:[/\\]{2,}', re.I)
    if RE_urlprotocol.match(inputpath):
        inputpath = urllib.parse.unquote(inputpath).decode("utf8")  # first decode url encoded characters such as spaces %20
        inputpath = r'/' + RE_urlprotocol.sub(r'', inputpath)  # need to prepend the first '/' since it is probably an absolute path and here we will strip the whole protocol
    if outputpath and RE_urlprotocol.match(outputpath):
        outputpath = urllib.parse.unquote(outputpath).decode("utf8")
        outputpath = r'/' + RE_urlprotocol.sub(r'', outputpath)

    # Check if input/output paths exist, else might be a relative path, then convert to an absolute path
    rootfolderpath = inputpath if os.path.exists(inputpath) else fullpath(inputpath)
    rootoutpath = outputpath if outputpath is None or os.path.exists(outputpath) else fullpath(outputpath)

    # Single file specified instead of a folder: we define the input folder as the top parent of this file
    if os.path.isfile(inputpath): # if inputpath is a single file (instead of a folder), then define the rootfolderpath as the parent directory (for correct relative path generation, else it will also truncate the filename!)
        rootfolderpath = os.path.dirname(inputpath)
    if outputpath and os.path.isfile(outputpath): # if inputpath is a single file (instead of a folder), then define the rootfolderpath as the parent directory (for correct relative path generation, else it will also truncate the filename!)
        rootoutpath = os.path.dirname(outputpath)

    # Strip trailing slashes to ensure we correctly format paths afterward
    if rootfolderpath:
        rootfolderpath = rootfolderpath.rstrip('/\\')
    if rootoutpath:
        rootoutpath = rootoutpath.rstrip('/\\')

    # Final check of whether thepath exist
    if not os.path.isdir(rootfolderpath):
        raise NameError('Specified input path: %s (detected as %s) does not exist. Please check the specified path.' % (inputpath, rootfolderpath))

    # Check the modes are not conflicting
    if sum([1 if elt == True else 0 for elt in [copy_mode, symlink_mode, move_mode, movefast_mode, delete_mode]]) > 1:
        raise ValueError('Cannot set multiple modes simultaneously, please choose only one!')

    # Check if an output is needed and is not set
    if (copy_mode or symlink_mode or move_mode or movefast_mode) and not outputpath:
        raise ValueError('--copy or --symlink or --move or --move_fast specified but no --output !')

    # If tree mode enabled, enable also the regroup option
    if tree_flag:
        regroup = True

    # -- Configure the log file if enabled (ptee.write() will write to both stdout/console and to the log file)
    if args.log:
        ptee = Tee(args.log, 'a', nostdout=silent)
        #sys.stdout = Tee(args.log, 'a')
        sys.stderr = Tee(args.log, 'a', nostdout=silent)
    else:
        ptee = Tee(nostdout=silent)
    
    # -- Preprocess regular expression to add aliases
    # Directory alias
    regex_input = regex_input.replace('\dirnodot', r'[^\\/.]*?').replace('\dir', r'[^\\/]*?')
    regex_output = regex_output.replace('\dirnodot', r'[^\\/.]*?').replace('\dir', r'[^\\/]*?') if regex_output else regex_output
    regex_exists = regex_exists.replace('\dirnodot', r'[^\\/.]*?').replace('\dir', r'[^\\/]*?') if regex_exists else regex_exists

    #### Main program
    # Test if regular expressions are correct syntactically
    try:
        regin = re.compile(str_to_raw(regex_input))
        regout = re.compile(str_to_raw(regex_output)) if regex_output else None
        regexist = re.compile(str_to_raw(regex_exists)) if regex_exists else None
        if path_range:  # parse the range format
            temp = re.search(r'(\d+):(\d+)-(\d+)', path_range)
            prange = {"group": int(temp.group(1)), "start": int(temp.group(2)), "end": int(temp.group(3))}
            del temp
    except re.error as exc:
        ptee.write("Regular expression is not correct, please fix it! Here is the error stack:\n")
        ptee.write(traceback.format_exc())
        return 1

    ptee.write("== Regex Path Matcher started ==\n")
    ptee.write("Parameters:")
    ptee.write("- Input root: %s" % inputpath)
    ptee.write("- Input regex: %s" % regex_input)
    ptee.write("- Output root: %s" % outputpath)
    ptee.write("- Output regex: %s" % regex_output)
    ptee.write("- Full arguments: %s" % ' '.join(sys.argv))
    ptee.write("\n")

    # == FILES WALKING AND MATCHING/SUBSTITUTION STEP
    files_list = []  # "to copy" files list, stores the list of input files and their corresponding output path (computed using regex)
    files_list_regroup = {}  # files list regrouped, if regroup = True
    ptee.write("Computing paths matching and simulation report, please wait (total time depends on files count - filesize has no influence). Press CTRL+C to abort\n")
    for dirpath, filename in tqdm(recwalk(inputpath, topdown=False, folders=dir_flag), unit='files', leave=True, smoothing=0):
        # Get full absolute filepath and relative filepath from base dir
        filepath = os.path.join(dirpath, filename)
        relfilepath = path2unix(os.path.relpath(filepath, rootfolderpath)) # File relative path from the root (we truncate the rootfolderpath so that we can easily check the files later even if the absolute path is different)
        regin_match = regin.search(relfilepath)
        # Check if relative filepath matches the input regex
        if regin_match:  # Matched! We store it in the "to copy" files list
            # If range mode enabled, check if the numbers in the filepath are in the specified range, else we skip this file
            if path_range:
                curval = int(regin_match.group(prange['group']))
                if not (prange['start'] <= curval <= prange['end']):
                    continue
            # Compute the output filepath using output regex
            if outputpath:
                newfilepath = regin.sub(regex_output, relfilepath) if regex_output else relfilepath
                #fulloutpath = os.path.join(rootoutpath, newfilepath)
            else:
                newfilepath = None
                #fulloutpath = None
            # Check if output path exists (if argument is enabled)
            if regex_exists and newfilepath:
                if not os.path.exists(os.path.join(rootoutpath, regin.sub(regex_exists, relfilepath))):
                    # If not found, skip to the next file
                    if verbose or test_flag:
                        ptee.write("\rFile skipped because output does not exist: %s" % newfilepath)
                    continue
            # Store both paths into the "to copy" list
            files_list.append([relfilepath, newfilepath])
            if verbose or test_flag:  # Regex test mode or verbose: print the match
                ptee.write("\rMatch: %s %s %s\n" % (relfilepath, "-->" if newfilepath else "", newfilepath if newfilepath else ""))
                if test_flag:  # Regex test mode: break file walking after the first match
                    break
            # Store paths in a tree structure based on groups if regroup is enabled
            if regroup and regin_match.groups():
                curlevel = files_list_regroup  # current level in the tree
                parentlevel = curlevel  # parent level in the tree (necessary to modify the leaf, else there is no way to reference by pointer)
                lastg = 0  # last group key (to access the leaf)
                gdict = regin_match.groupdict()  # store the named groups, so we can pop as we consume it
                for g in regin_match.groups():
                    # For each group
                    if g is None:
                        # If group value is empty, just skip (ie, this is an optional group, this allow to specify multiple optional groups and build the tree accordingly)
                        continue
                    # Find if the current group value is in a named group, in this case we will also use the key name of the group followed by the value, and remove from dict (so that if there are multiple matching named groups with same value we don't lose them)
                    k, v, gdict = pop_first_namedgroup(gdict, g)
                    # If a named group is found, use the key followed by value as nodes
                    if k:
                        if not k in curlevel:
                            # Create node for group key/name
                            curlevel[k] = {}
                        if not g in curlevel[k]:
                            # Create subnode for group value
                            curlevel[k][g] = {}
                        # Memorize the parent level
                        parentlevel = curlevel[k]
                        lastg = g
                        # Memorize current level (step down one level for next iteration)
                        curlevel = curlevel[k][g]
                    # Else it is an unnamed group, use the value as the node name
                    else:
                        if not g in curlevel:
                            # Create node for group value
                            curlevel[g] = {}
                        # Memorize the parent level
                        parentlevel = curlevel
                        lastg = g
                        # Memorize current level (step down one level for next iteration)
                        curlevel = curlevel[g]
                # End of tree structure construction
                # Create the leaf if not done already, as a list
                if not parentlevel[lastg]:
                    parentlevel[lastg] = []
                # Append the value (so if there are multiple files matching the same structure, they will be appended in this list)
                parentlevel[lastg].append([relfilepath, newfilepath])
    ptee.write("End of simulation. %i files matched." % len(files_list))
    # Regex test mode: just quit after the first match
    if test_flag:
        if return_report:
            return files_list, None
        else:
            return 0

    # == SIMULATION REPORT STEP
    ptee.write("Preparing simulation report, please wait a few seconds...")

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
    if noreport:
        reportfile = StringIO()
    else:
        reportfile = open(reportpath, 'w')
    try:
        reportfile.write("== REGEX PATH MATCHER SIMULATION REPORT ==\n")
        reportfile.write("Total number of files matched: %i\n" % len(files_list))
        reportfile.write("Parameters:\n")
        reportfile.write("- Input root: %s\n" % inputpath.encode('utf-8'))
        reportfile.write("- Input regex: %s\n" % regex_input)
        reportfile.write("- Output root: %s\n" % (outputpath.encode('utf-8') if outputpath else ''))
        reportfile.write("- Output regex: %s\n" % regex_output)
        reportfile.write("- Full arguments: %s" % ' '.join(sys.argv))
        reportfile.write("\r\n")
        reportfile.write("List of matched files:\n")
        for file_op in files_list:
            conflict1 = False
            conflict2 = False
            if outputpath:
                # Check if there was a conflict:
                # Type 1 - already existing output file (force overwrite?)
                fulloutpath = os.path.join(rootoutpath, file_op[1])
                if os.path.exists(fulloutpath):
                    conflict1 = True
                    conflict1_flag = True

                # Type 2 - two files will output with same name (bad regex)
                if outdict[file_op[1]] > 1:
                    conflict2 = True
                    conflict2_flag = True

            # Show relative or absolute paths?
            if show_fullpath:
                showinpath = os.path.join(rootfolderpath, file_op[0])
                showoutpath = os.path.join(rootoutpath, file_op[1]) if outputpath else None
            else:
                showinpath = file_op[0]
                showoutpath = file_op[1] if outputpath else None

            # Write into report file
            reportfile.write("* %s %s %s %s %s" % (showinpath, "-->" if (outputpath or delete_mode) else "", showoutpath if outputpath else "", "[ALREADY_EXIST]" if conflict1 else '', "[CONFLICT]" if conflict2 else ''))
            reportfile.write("\n")
        if noreport:
            reportfile.seek(0)
            print(reportfile.read())
    finally:
        try:
            reportfile.close()
        except ValueError as exc:
            pass
    # Open the simulation report with the system's default text editor
    if not (yes_flag or return_report or noreport):  # if --yes is supplied, just skip question and apply!
        ptee.write("Opening simulation report with your default editor, a new window should open.")
        open_with_default_app(reportpath)

    # == COPY/MOVE STEP
    if files_list and ( delete_mode or ((copy_mode or symlink_mode or move_mode or movefast_mode) and outputpath) ):
        # -- USER NOTIFICATION AND VALIDATION
        # Notify user of conflicts
        ptee.write("\n")
        if conflict1_flag:
            ptee.write("Warning: conflict type 1 (files already exist) has been detected. Please use --force if you want to overwrite them, else they will be skipped.\n")
        if conflict2_flag:
            ptee.write("Warning: conflict type 2 (collision) has been detected. If you continue, several files will have the same name due to the specified output regex (thus, some will be lost). You should cancel and check your regular expression for output.\n")
        if not conflict1_flag and not conflict2_flag:
            ptee.write("No conflict detected. You are good to go!")

        # Ask user if we should apply
        if not (yes_flag or return_report):  # if --yes is supplied, just skip question and apply!
            applycopy = input("Do you want to apply the result of the path reorganization simulation on %i files? [Y/N]: " % len(files_list))
            if applycopy.lower() != 'y':
                return 0

        # -- APPLY STEP
        ptee.write("Applying new path structure, please wait (total time depends on file sizes and matches count). Press CTRL+C to abort")
        for infilepath, outfilepath in tqdm(files_list, total=len(files_list), unit='files', leave=True):
            if verbose:
                ptee.write("%s --> %s" % (infilepath, outfilepath))
            # Copy the file! (User previously accepted to apply the simulation)
            fullinpath = os.path.join(rootfolderpath, infilepath)
            if outputpath:
                fulloutpath = os.path.join(rootoutpath, outfilepath)
                if movefast_mode:  # movefast: just move the file/directory tree
                    move_any(fullinpath, fulloutpath)
                else:  # else we first copy in any case, then delete old file if move_mode
                    copy_any(fullinpath, fulloutpath, only_missing=only_missing, symlink=True if symlink_mode else False)  # copy file
                    if move_mode:  # if move mode, then delete the old file. Copy/delete is safer than move because we can ensure that the file is fully copied (metadata/stats included) before deleting the old
                        remove_if_exist(fullinpath)
            if delete_mode:  # if delete mode, ensure that the original file is deleted!
                remove_if_exist(fullinpath)

    # == RETURN AND END OF MAIN
    ptee.write("Task done, quitting.")
    # Save the tree structure in a json file if --tree is enabled
    if tree_flag:
        with open('pathmatcher_tree.json', 'wb') as jsonout:
            jsonout.write(json.dumps(files_list_regroup, sort_keys=True, indent=4, separators=(',', ': ')))
        print('Tree structure saved in file pathmatcher_tree.json')
    # Script mode: return the matched files and their substitutions if available
    if return_report:
        if regroup:
            return files_list_regroup, [conflict1_flag, conflict2_flag]
        else:
            return files_list, [conflict1_flag, conflict2_flag]
    # Standalone mode: just return non error code
    else:
        return 0

# Calling main function if the script is directly called (not imported as a library in another program)
if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
