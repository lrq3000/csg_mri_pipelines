#!/usr/bin/env python
#
# reorientation_registration_helper.py
# Copyright (C) 2016-2020 Stephen Karl Larroque
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
#        Reorientation and Registration helper
#                    Python 3.7.0 (previously 2.7.15)
#                by Stephen Karl Larroque
#                     License: MIT
#            Creation date: 2016-03-27
#=================================
#
#
#

from __future__ import print_function
from __future__ import absolute_import
from __future__ import division
from __future__ import unicode_literals

from future import standard_library
standard_library.install_aliases()
from builtins import next
from builtins import input
from builtins import str
from builtins import range
from past.builtins import basestring
from builtins import object
__version__ = '1.7.0'

import sys
PY3 = (sys.version_info >= (3,0,0))

import argparse
import os
import random
import re
import shlex
import shutil
import traceback

if PY3:
    import pathmatcher
else:
    from . import pathmatcher

from collections import OrderedDict

if PY3:
    from itertools import zip_longest
else:
    try:
        from itertools import izip_longest as zip_longest
    except ImportError as exc:
        from itertools import zip_longest

# for saving movement parameters as csv
import numpy as np
import itertools
import csv, codecs

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



#***********************************
#                       AUX
#***********************************

def ask_step():
    '''Ask to user if s/he is ready to do the step'''
    while 1:
        user_choice = input('Do this step? [C]ontinue (default), [S]kip to next, [A]bort: ')
        if user_choice.lower() == 'a':
            sys.exit(0)
        elif user_choice.lower() == 's':
            return False
        elif len(user_choice) == 0 or user_choice.lower() == 'c':
            return True
        else:
            print("Incorrect entry. Please type one of the proposed choices.")

def ask_next(filepath='', msg=None, customchoices=[]):
    '''Ask to user if s/he is ready to process next file'''
    if not msg:
        msg = "\nLoad next file %s? [C]ontinue (default), [S]kip to next step, [N]ext file, [A]bort: " % filepath

    while 1:
        user_choice = input(msg)
        if user_choice.lower() == 'a':
            sys.exit(0)
        elif user_choice.lower() == 's':
            return None
        elif user_choice.lower() == 'n':
            return False
        elif len(user_choice) == 0 or user_choice.lower() == 'c':
            return True
        elif 'int' in customchoices and is_int(user_choice):
            return int(user_choice)
        elif user_choice.lower() in customchoices:
            return user_choice.lower()
        else:
            print("Incorrect entry. Please type one of the proposed choices.")

def str_to_raw(str):
    '''Convert string received from commandline to raw (unescaping the string, turning it into a literal)'''
    return repr(str)
    # Old method, which failed on string containing "\0" by converting them to a null byte when it was in fact part of the path
    #try:  # Python 2
    #    return str.decode('string_escape')
    #except:  # Python 3
    #    return str.encode().decode('unicode_escape').replace("'", "\\'")

def filestr_to_raw(str):
    '''Convert a filepath to raw string only if resulting filepath exist
    This is necessary when passing any path to mlab matlab functions'''
    escaped = str_to_raw(str)
    return escaped if os.path.exists(escaped) else str

def fullpath(relpath):
    '''Relative path to absolute'''
    if (type(relpath) is object or hasattr(relpath, 'read')): # relpath is either an object or file-like, try to get its name
        relpath = relpath.name
    return os.path.abspath(os.path.expanduser(relpath))

def grouper(n, iterable, fillvalue=None):
    '''grouper(3, 'ABCDEFG', 'x') --> ABC DEF Gxx'''
    # From Python documentation
    args = [iter(iterable)] * n
    return zip_longest(fillvalue=fillvalue, *args)

def is_int(s):
    try: 
        int(s)
        return True
    except (ValueError, TypeError) as exc:
        return False

class UnicodeWriter(object):
    """
    A CSV writer which will write rows to CSV file "f",
    which is encoded in the given encoding.
    from https://docs.python.org/2/library/csv.html
    """

    def __init__(self, f, dialect=csv.excel, encoding="utf-8", **kwds):
        # Redirect output to a queue
        self.queue = StringIO()
        self.writer = csv.writer(self.queue, dialect=dialect, **kwds)
        self.stream = f
        self.encoder = codecs.getincrementalencoder(encoding)()

    def writerow(self, row):
        self.writer.writerow([s.encode("utf-8") if isinstance(s, basestring) else s for s in row])
        # Fetch UTF-8 output from the queue ...
        data = self.queue.getvalue()
        data = data.decode("utf-8")
        # ... and reencode it into the target encoding
        data = self.encoder.encode(data)
        # write to the target stream
        self.stream.write(data)
        # empty queue
        self.queue.truncate(0)

    def writerows(self, rows):
        for row in rows:
            self.writerow(row)



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
def main(argv=None, return_report=False):
    if argv is None: # if argv is empty, fetch from the commandline
        argv = sys.argv[1:]
    elif isinstance(argv, _str): # else if argv is supplied but it's a simple string, we need to parse it to a list of arguments before handing to argparse or any other argument parser
        argv = shlex.split(argv) # Parse string just like argv using shlex

    #==== COMMANDLINE PARSER ====

    #== Commandline description
    desc = '''Reorientation and registration helper v%s
Description: Guide and automate the file selection process that is required in SPM between each reorientation/registration.

No more useless clicks, just do the reorientation/registration in batch, you don't need to worry about selecting the corresponding files, this helper will do it for you.

If you have tqdm installed, a nice progress bar will tell you how many subjects are remaining to be processed and how much time will it take at your current pace.

Note: you need to `pip install mlab` before using this script.
Note2: you need to have set both spm and spm_auto_reorient in your path in MATLAB before using this script.
Note3: you need the pathmatcher.py library (see lrq3000 github).

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
                        help='Path to the input folder (the root directory where you placed the files, the default supported tree structure being: "Condition/subject_id/data/(sess_id)?/(mprage|rest)/*.(img|nii)". You can also use --regex_anat and --regex_func to define your own directory layout.', **widget_dir)

    # Optional general arguments
    main_parser.add_argument('-ra', '--regex_anat', metavar='"(reg_expr)+/anat\.(img|nii)"', type=str, required=False, default=None,
                        help='Regular expression to match anatomical images (default: Liege CRC scheme). Use regex groups to match with functional regex (if you want to do step 4 - manual coreg). Note: should target nii or img, not hdr.', **widget_text)
    main_parser.add_argument('-rf', '--regex_func', metavar='"(reg_expr)+/func\.(img|nii)"', type=str, required=False, default=None,
                        help='Regular expression to match functional images (default: Liege CRC scheme). Regex groups will be matched with the anatomical regex, so you should provide the same groups for both regex. Note: should target nii or img, not hdr (using non-capturing group, eg: ".*\.(?:img|nii)". If a named group (?P<func>...) is specified, this will allow to separately coregister any file matching this group, which will be removed from the list of regex groups (thus this group is additional, it does not count in the "same number of groups" rule).', **widget_text)
    main_parser.add_argument('-rp', '--regex_motion', metavar='"(reg_expr)+/rp_.+\.txt"', type=str, required=False, default=None,
                        help='Regular expression to match motion parameter files rp_*.txt as generated by spm_realign. If this argument is provided, motion parameters will be fetched from these files directly instead of recalculating from functional images. The regex needs to contain at least one group in parentheses to define a key for the output excel file.', **widget_text)
    main_parser.add_argument('-v', '--verbose', action='store_true', required=False, default=False,
                        help='Verbose mode (show more output).')


    #== Parsing the arguments
    args = main_parser.parse_args(argv) # Storing all arguments to args

    #-- Set variables from arguments
    inputpath = fullpath(args.input)
    rootfolderpath = inputpath
    regex_anat = args.regex_anat
    regex_func = args.regex_func
    regex_motion = args.regex_motion
    verbose = args.verbose
    checkreg_display_count = 6  # number of anatomical images that will be displayed at the same time during step 3.

    # -- Sanity checks
    if os.path.isfile(inputpath): # if inputpath is a single file (instead of a folder), then define the rootfolderpath as the parent directory (for correct relative path generation, else it will also truncate the filename!)
        rootfolderpath = os.path.dirname(inputpath)

    # Strip trailing slashes to ensure we correctly format paths afterward
    if rootfolderpath:
        rootfolderpath = rootfolderpath.rstrip('/\\')

    if not os.path.isdir(rootfolderpath):
        raise NameError("Specified input path does not exist. Please check the specified path: %s" % rootfolderpath)

    # Define default regular expressions to find images
    if regex_anat is None:
        regex_anat = r'(\dir)/(\dir)/data/(\dir/)?mprage/[^\\/]+\.(?:img|nii)'  # canonical example: COND/SUBJID/data/(SESSID)?/mprage/struct.(img|nii)
    if regex_func is None:
        regex_func = r'(\dir)/(\dir)/data/(?P<func>\dir/)?rest/[^\\/]+\.(?:img|nii)'  # canonical example: COND/SUBJID/data/(SESSID)?/rest/func_01.(img|nii)
    if regex_motion is None:
        regex_motion = r'(\dir)/(\dir)/data/(?P<motion>\dir/)?rest/rp_[^\\/]+\.txt'  # canonical example: COND/SUBJID/data/(SESSID)?/rest/rp_*.txt

    # -- Preprocess regular expression to add aliases
    # Directory alias
    regex_anat = regex_anat.replace('\dir', r'[^\\/]*?')
    regex_func = regex_func.replace('\dir', r'[^\\/]*?')
    regex_motion = regex_motion.replace('\dir', r'[^\\/]*?')

    ### Main program
    print("\n== Reorientation and registration helper started ==\n")
    print("Parameters:")
    print("- Input root: %s" % inputpath)
    print("\n")

    # == Prepare list of conditions and string template vars
    conditions_list = next(walk(rootfolderpath))[1]
    conditions_list.sort()  # Make sure the folders order is the same every time we launch the application, in order for the user to be able to restart and skip steps and still work on the same files
    template_vars = {'inputpath': rootfolderpath,
                     'firstcond': conditions_list[0],
                     'regex_anat': regex_anat,
                     'regex_func': regex_func,
                     'regex_motion': regex_motion,
                    }

    # == IMPORT MLAB (LOAD MATLAB BRIDGE)
    print("Launching MATLAB, please wait a few seconds...")
    os.chdir(os.path.dirname(os.path.abspath(__file__)))  # Change Python current directory before launching MATLAB, this will change the initial dir of MATLAB, this will allow to find the auxiliay functions
    #matlab.cd(rootfolderpath)  # FIXME: Does not work: Change MATLAB's current dir to root of project's folder, will be easier for user to load other images if needed
    try:
        #from matlab_wrapper import matlab_wrapper
        from mlabwrap import mlabwrap  # pure python implementation without using ctypes nor external dlls such as libssl, ported to Python 3
        # start a Matlab session
        mlab = mlabwrap.init()
        # same for matlab_wrapper
        #mlab = matlab_wrapper.MatlabSession()
        # add current folder to the path to have access to helper .m scripts, this needs to be done before each command call
        mlab.addpath(filestr_to_raw(os.path.dirname(os.path.abspath(__file__))))
        # using matlab_wrapper
        #mlab.workspace.addpath(filestr_to_raw(os.path.dirname(os.path.abspath(__file__))))
        # python-matlab-bridge
        #mlab.set_variable('curfolder', filestr_to_raw(os.path.dirname(os.path.abspath(__file__))))
        #mlab.run_code('addpath(curfolder);')
        # mlab
        #mlab.addpath(filestr_to_raw(os.path.dirname(os.path.abspath(__file__))))  # add current folder to the path to have access to helper .m scripts, this needs to be done before each command call, alternative for other libraries
        # Nota bene: to add the auxiliary local matlab scripts to be accessible in mlab, we need to do two things: 1. os.chdir() in the local directory with Python before launching mlab, 2. addpath in matlab afterwards (with filepath converted to raw path format). Anything else would raise a bug at some point!
    except ImportError as exc:
        print("You need to install a matlab wrapper and to add SPM12 in your MATLAB path to use this script. For Python 2.7, use https://github.com/mrkrd/matlab_wrapper, or it should work with some limited changes on any mlabwrap based library such as: https://github.com/arokem/python-matlab-bridge (the most reliable python-matlab wrapper interface in our experience, but has limited support for graphical interface, but great for debugging since it never fails), https://github.com/ewiger/mlab or https://github.com/cpbotha/mlabwrap-purepy or . For Python 3.x, use https://github.com/deeuu/matlab_wrapper/tree/python3 , https://github.com/arokem/python-matlab-bridge or https://github.com/decacent/mlab")
        raise(exc)

    # == Anatomical files walking
    print("Please wait while the directories are scanned to find anatomical images...")
    anat_list, conflict_flags = pathmatcher.main(r' -i "{inputpath}" -ri "{regex_anat}" --silent '.format(**template_vars), True)
    anat_list = [file[0] for file in anat_list]  # extract only the input match, there's no output anyway
    anat_list = [os.path.join(rootfolderpath, file) for file in anat_list]  # calculate full absolute path instead of relative (since we need to pass them to MATLAB)
    print("Found %i anatomical images." % len(anat_list))

    # == AUTOMATIC REORIENTATION VIA SPM_AUTO_REORIENT
    # Get the list of anatomical images
    print("\n=> STEP1: SPM_AUTO_REORIENT OF STRUCTURAL MRI")
    print("Please make sure to install SPM12 and spm_auto_reorient.m tool beforehand, from: https://github.com/lrq3000/spm_auto_reorient")
    print("NOTE: if you already did this step and began STEP2 (manual reorient), then SKIP THIS STEP to avoid losing your manual progress!")
    if ask_step():  # Wait for user to be ready
        print("Starting the auto-reorienting process, please wait (this can take a while)...")
        # Auto reorient anatomical images
        for file in tqdm(anat_list, leave=True, unit='files'):
            if verbose: print("- Processing file: %s" % file)
            try:
                #mlab.workspace.spm_auto_reorient(file, nout=0)
                #mlab.run_func('spm_auto_reorient.m', file)  # python-matlab-bridge
                mlab.spm_auto_reorient(file)  # alternative for other libraries
            except Exception as exc:
                print('ERROR: an exception happened while auto-reorienting file %s' % file)
                print(exc)
                print('Skipping this file and continuing.')

    # == CHECK REORIENT AND MANUAL ADJUSTMENT
    print("\n=> STEP2: MANUAL REORIENT/CHECK OF STRUCTURAL MRI")
    print("Anatomical will now be displayed. Please check that they are correctly oriented, if not, please adjust manually.")
    if ask_step():  # Wait for user to be ready
        for file in tqdm(anat_list, leave=True, unit='files'):
            if verbose: print("- Processing file: %s" % file)
            uchoice = ask_next(file)  # ask user if we load the next file? If not, we don't have to load the bridge and file, can just skip
            if uchoice is None: break
            if uchoice == False: continue
            #matlab.cd(os.path.dirname(file))  # FIXME: does not work...
            os.chdir(os.path.dirname(file))  # Workaround: Change Python and MATLAB's path to the folder where the anatomical file is, so that user just needs to click on it
            #matlab.spm_image('display', filestr_to_raw(file))  # Convert path to raw string to avoid \0 MATLAB string termination character
            #matlab.spm_orthviews('AddContext')  # add the contextual menu (right-click) with additional options such as intensity histogram equalization  # mlab is not thread-safe, this cannot work because it needs to get the figure handle...
            # add current folder to the path to have access to helper .m scripts, this needs to be done before each custom command call
            #mlab.workspace.addpath(filestr_to_raw(os.path.dirname(os.path.abspath(__file__))))
            # python-matlab-bridge
            #mlab.set_variable('curfolder', filestr_to_raw(os.path.dirname(os.path.abspath(__file__))))
            #mlab.run_code('addpath(curfolder);')
            # combination of the two previous commands in a matlab function so that we workaround the thread issue of the mlab module (which prevents it from managing figures handles)
            #mlab.workspace.reorienthelper(filestr_to_raw(file), nout=0)
            #mlab.run_func('reorienthelper.m', filestr_to_raw(file))  # python-matlab-bridge, also make sure to change reorienthelper to return an output variable to make the call blocking (else python-matlab-bridge will make the call in a non-blocking fashion)
            # alternative for other libraries
            mlab.addpath(filestr_to_raw(os.path.dirname(os.path.abspath(__file__))))
            mlab.reorienthelper(filestr_to_raw(file))

    # == CHECK MULTIPLE IMAGES TOGETHER
    print("\n=> STEP3: SIDE-BY-SIDE CHECK MULTIPLE SUBJECTS")
    print("Multiple subjects' anatomical images will be displayed side by side as a sanity check of correct reorientation. Please check that they are all reoriented correctly (check ventricles, skull boundaries when sliding cursor to the edges, random points in images).")
    if ask_step():  # Wait for user to be ready
        imgs_pack_by = 6
        for files in tqdm(grouper(checkreg_display_count, anat_list), total=int(len(anat_list)/imgs_pack_by), leave=True, unit='files'):
            files = [f for f in files if f is not None]  # remove None filler files in case the remaining files are fewer than the number we want to show
            if len(files) < imgs_pack_by:  # if we have less remaining files than what we want to compare, let's sample randomly more pictures from the original files list
                files.extend([random.choice(anat_list) for _ in range(imgs_pack_by - len(files))])
            if verbose: print("- Processing files: %s" % repr(files))
            uchoice = ask_next()  # ask user if we load the next file?
            if uchoice is None: break
            if uchoice == False: continue
            #mlab.workspace.spm_check_registration(*files, nout=0)
            #mlab.run_func('spm_check_registration.m', *files)  # python-matlab-bridge
            mlab.spm_check_registration(*files)  # alternative for other libraries

    # DEPRECATED: was too specific for one special case, should be avoided in the general case.
    # == COPY ANATOMICAL TO OTHER CONDITIONS
    # print("\n=> STEP4: COPYING ANATOMICAL IMAGES")
    # print("Anatomical images will now be copied onto other conditions, please wait a few minutes...")
    # if ask_step():  # Wait for user to be ready
        # for condition in conditions_list[1:]:  # skip first condition, this is where we will copy the anatomical images from, to the other conditions
            # template_vars["tocond"] = condition
            # os.chdir(rootfolderpath)  # reset to rootfolder to generate the simulation report there
            # pathmatcher.main(r' -i "{inputpath}/{firstcond}" -ri "([^\/]+)/data/mprage/" -o "{inputpath}/{tocond}" -ro "\1/data/mprage/" --copy --force --yes --silent '.format(**template_vars), True)

    # == DETECT FUNCTIONAL IMAGES
    print("\n=> STEP4: DETECTION OF FUNCTIONAL IMAGES")
    print("Functional images will now be detected and associated with their relative structural images.\nPlease press ENTER and wait (can be a bit long)...")
    input()
    # -- Walk files and detect functional images (we already got structural)
    os.chdir(rootfolderpath)  # reset to rootfolder to generate the simulation report there
    func_list, conflict_flags = pathmatcher.main(r' -i "{inputpath}" -ri "{regex_func}" --silent '.format(**template_vars), True)
    func_list = [file[0] for file in func_list]  # extract only the input match, there's no output anyway
    print("Found %i functional images." % len(func_list))

    # -- Precomputing to pair together anatomical images and functional images of the same patient for the same condition
    # Technically, we construct a lookup table where the key is the concatenation of all regex groups
    # For this we use two regex that we apply on file paths: one for anatomical images and one for functional images.
    # The regex groups are then used as the key to assign this file in the lookup table, and then assigned to a subdict 'anat' or 'func' depending on the regex used.
    # This is both flexible because user can provide custom regex and precise because the key is normally unique
    # (this is more flexible than previous approach to walk both anat and func files at once because it would necessitate a 3rd regex)
    im_table = OrderedDict()  # Init lookup table. Always use an OrderedDict so that we walk the subjects id by the same order every time we launch the program (allows to skip already processed subjects)
    RE_anat = re.compile(regex_anat)
    RE_func = re.compile(regex_func)
    for img_list in [anat_list, func_list]:
        if img_list == anat_list:
            im_type = 'anat'
        else:
            im_type = 'func'

        for file in img_list:
            # Match the regex on each file path, to detect the regex groups (eg, condition, subject id and type of imagery)
            # Note: use re.search() to allow for partial match (like pathmatcher), not re.match()
            if im_type == 'anat':
                m = RE_anat.search(file)
            else:  # im_type == 'func':
                m = RE_func.search(file)
            if m is None:
                print('Error: no regex match found for type %s file: %s' % (im_type, file))
            # Use these metadata to build our images lookup table, with every images grouped and organized according to these parameters
            # TODO: maybe use a 3rd party lib to do this more elegantly? To group strings according to values in the string that match together?
            mdict = m.groupdict()
            if im_type == 'anat' or im_type not in mdict:
                im_key = '_'.join(filter(None, m.groups()))  # Note: you can use non-capturing groups like (?:non-captured) to avoid capturing things you don't want but you still want to group (eg, for an OR)
            else:
                # A named group for func is present
                mgroups = list(m.groups())
                # Remove the value matched by 'func' from the non-dict groups
                mgroups.remove(mdict[im_type])
                # Use the non-dict groups as the key
                im_key = '_'.join(filter(None, mgroups))
            # Create entry if does not exist
            if im_key not in im_table:
                # Creade node
                im_table[im_key] = {}
            if im_type not in im_table[im_key]:
                if im_type == 'func' and im_type in mdict:
                    # Create node
                    im_table[im_key][im_type] = {}
                else:
                    # Create leaf
                    im_table[im_key][im_type] = []
            if im_type == 'func' and im_type in mdict and mdict[im_type] not in im_table[im_key][im_type]:
                # Create leaf
                im_table[im_key][im_type][mdict[im_type]] = []
            # Append file path to the table at its correct place
            # Note that no conflict is possible here (no file can overwrite another), because we just append them all.
            # But files that are not meant to be grouped can be grouped in the end, so you need to make sure your regex is correct (can use pathmatcher or --verbose to check).
            if im_type == 'anat' or im_type not in mdict:
                im_table[im_key][im_type].append(os.path.join(rootfolderpath, file))
            else:
                # Named group for func is present, we create a subfolder for each value (so that multiple func folders can be stored)
                im_table[im_key][im_type][mdict[im_type]].append(os.path.join(rootfolderpath, file))

    # Precompute total number of subjects user will have to process (to show progress bar)
    total_func_images = len(im_table)

    # Expand 4D nifti images (get the volume numbers for them, so that we do not simply consider them as a single image)
    # for each key (can be each subject)
    for im_key in tqdm(im_table.keys(), total=total_func_images, leave=True, unit='subjects', desc='4DEXPAND'):
        # check if there is both anatomical and structural images available, if one is missing we simply skip
        if 'func' not in im_table[im_key]:
            continue
        # prepare the functional images list (there might be multiple folders)
        if isinstance(im_table[im_key]['func'], dict):
            # multiple folders
            for im_key_func in im_table[im_key]['func'].keys():
                if not 'func_expanded' in im_table[im_key]:
                    im_table[im_key]['func_expanded'] = {}
                #im_table[im_key]['func_expanded'][im_key_func] = mlab.workspace.expandhelper(im_table[im_key]['func'][im_key_func]).tolist()  # for matlab_wrapper
                mlab._dont_proxy["cell"] = True  # enable autoconversion for cell arrays and char arrays in mlabwrap based libraries (else we would get a MLabWrapProxy object which we can't do anything with in Python)
                im_table[im_key]['func_expanded'][im_key_func] = mlab.expandhelper(im_table[im_key]['func'][im_key_func])  # for mlabwrap based libraries
                if isinstance(im_table[im_key]['func_expanded'][im_key_func], basestring):
                    # If there is only one file, matlab will return a char, thus a string, so we need to convert back to a list to be consistent
                    im_table[im_key]['func_expanded'][im_key_func] = [im_table[im_key]['func_expanded'][im_key_func]]
                # Remove the anatomical file if the provided functional regular expression is also matching the anatomical files (this would still work but it defeats the purpose of doing the reorientation steps before...)
                if 'anat' in im_table[im_key]:
                    try:
                        im_table[im_key]['func'][im_key_func].remove(im_table[im_key]['anat'][0])
                        im_table[im_key]['func_expanded'][im_key_func].remove(im_table[im_key]['anat'][0])
                    except ValueError as exc:
                        pass
        else:
            # only one folder
            #im_table[im_key]['func_expanded'] = mlab.workspace.expandhelper(im_table[im_key]['func']).tolist()  # for matlab_wrapper
            mlab._dont_proxy["cell"] = True  # enable autoconversion for cell arrays and char arrays in mlabwrap based libraries (else we would get a MLabWrapProxy object which we can't do anything with in Python)
            im_table[im_key]['func_expanded'] = mlab.expandhelper(im_table[im_key]['func'])  # for mlabwrap based libraries
            if isinstance(im_table[im_key]['func_expanded'], basestring):
                # If there is only one file, matlab will return a char, thus a string, so we need to convert back to a list to be consistent
                im_table[im_key]['func_expanded'] = [im_table[im_key]['func_expanded']]
            # Remove the anatomical file if the provided functional regular expression is also matching the anatomical files (this would still work but it defeats the purpose of doing the reorientation steps before...)
            if 'anat' in im_table[im_key]:
                try:
                    im_table[im_key]['func'].remove(im_table[im_key]['anat'][0])
                    im_table[im_key]['func_expanded'].remove(im_table[im_key]['anat'][0])
                except ValueError as exc:
                    pass

    # == AUTOMATIC COREGISTRATION
    print("\n=> STEP5: AUTOMATIC COREGISTRATION OF FUNCTIONAL IMAGES")
    print("Functional images will be automatically coregistered to their relative structural image.")
    print("NOTE: if you already did this step and began STEP6 (manual coregistration), then SKIP THIS STEP to avoid losing your manual progress!")
    if ask_step():  # Wait for user to be ready
        # -- Proceeding to automatic coregistration
        current_image = 0
        # for each key (for each subject)
        for im_key in tqdm(im_table.keys(), total=total_func_images, initial=current_image, leave=True, unit='subjects'):
            current_image += 1
            # check if there is both anatomical and structural images available, if one is missing we simply skip
            if 'anat' not in im_table[im_key] or 'func' not in im_table[im_key]:
                continue
            # prepare the functional images list (there might be multiple folders)
            if isinstance(im_table[im_key]['func'], dict):
                # multiple folders
                funclists = im_table[im_key]['func'].values()
            else:
                # only one folder, we simply put it in a list so that we don't break the loop
                funclists = [im_table[im_key]['func']]
            # For each functional image subfolder
            for funclist in funclists:
                # Sort images
                im_table[im_key]['anat'].sort()
                funclist.sort()
                # Pick the image
                im_anat = im_table[im_key]['anat'][0]  # pick the first T1
                im_func = funclist[0]  # pick first EPI BOLD, this will be the source
                if len(funclist) > 1:
                    im_func_others = funclist[1:]  # pick other functional images, these will be the "others" images that will also be transformed the same as source
                else:
                    # 4D nifti support: there might be only one nifti file
                    im_func_others = []
                if verbose: print("- Processing files: %s and %s" % (os.path.relpath(im_anat, rootfolderpath), os.path.relpath(im_func, rootfolderpath)))
                # Support for 4D nifti: select the first volume of the functional image that will be used as the source for coregistration
                # Also we do not use the expanded functional images list, since there is only one header for all volumes in a 4D nifti, we need to apply the coregistration translation on only the first volume, this will be propagated to all others
                im_func += ',1'
                # Send to MATLAB checkreg!
                #mlab.workspace.functionalcoreg(im_anat, im_func, im_func_others, nout=0)  # matlab_wrapper
                #mlab.run_func('functionalcoreg.m', im_anat, im_func, im_func_others)  # python-matlab-bridge
                # Alternative for other libraries
                matlab.cd(os.path.dirname(im_func))  # Change MATLAB current directory to the functional images dir (no real reason)
                matlab.functionalcoreg(im_anat, im_func, im_func_others)

    # == MANUAL COREGISTRATION
    print("\n=> STEP6: MANUAL COREGISTRATION OF FUNCTIONAL IMAGES")
    print("The first functional image for each session will now be displayed (bottom) along the corresponding anatomical image (top). Please reorient the functional image to match the anatomical image, and select all functional images to apply the reorientation.")
    print("This step is very important, because the automatic coregistration algorithms are not optimal (they cannot be, the problem is non-linear), and thus they can fall in local optimums. A good manual coregistration ensures the automatic coregistration will be on-the-spot!")
    print("NOTE: you need to right-click on the bottom image, then click on Reorient Images > Current image. Red contours of the bottom functional image will be overlaid on the top anatomical image, and a side menu will open to allow you to reorient the bottom image and apply on other functional images.")
    print("NOTE2: you can also enhance the contrasts by right-clicking on functional image and select Zoom > This image non zero, by setting the number of contours to 2 instead of 3, and by right-clicking on the anatomical image and select Image > Intensity Mapping > local > Equalised squared-histogram (you can also do the same intensity mapping change on the functional image, the contours will adapt according to the greater contrast).")

    if ask_step():  # Wait for user to be ready
        # -- Proceeding to MATLAB checkreg
        current_image = 0
        # for each key (for each subject)
        for im_key in tqdm(im_table.keys(), total=total_func_images, initial=current_image, leave=True, unit='subjects'):
            current_image += 1
            # check if there is both anatomical and structural images available, if one is missing we simply skip
            if 'anat' not in im_table[im_key] or 'func_expanded' not in im_table[im_key]:
                continue
            # prepare the functional images list (there might be multiple folders)
            if isinstance(im_table[im_key]['func_expanded'], dict):
                # for multiple folders, no change needed
                funclists = im_table[im_key]['func_expanded']
            else:
                # only one folder, we simply put it in a list so that we don't break the loop
                funclists = {'0': im_table[im_key]['func_expanded']}
            # For each functional image subfolder
            for i, k in enumerate(funclists.keys()):
                funclist = funclists[k]
                # Wait for user to be ready
                uchoice = ask_next(msg='Open next registration for subject %s session %s (%i/%i)? Enter to [c]ontinue, Skip to [n]ext session, [S]kip to next subject, [A]bort: ' % (im_key, str(k), i+1, len(funclists)))  # ask user if we load the next file?
                if uchoice is None: break
                if uchoice == False: continue
                select_t2_nb = 0  # for user to specify a specific T2 image, by default the first image (because in general we coregister the first volume on structural)
                while 1:
                    # Pick a T1 and T2 images for this subject
                    if select_t2_nb is not None:
                        # Pick a specific image specified by user
                        im_table[im_key]['anat'].sort()  # first, sort the lists of files
                        funclist.sort()
                        # Pick the image
                        im_anat = im_table[im_key]['anat'][0]  # pick the first T1
                        im_func = funclist[select_t2_nb]  # then pick the selected functional image
                    else:
                        # Randomly choose one anatomical image (there should be only one anyway) and one functional image
                        im_anat = random.choice(im_table[im_key]['anat'])
                        im_func = random.choice(funclist)
                    if verbose: print("- Processing files: %s and %s" % (os.path.relpath(im_anat, rootfolderpath), os.path.relpath(im_func, rootfolderpath)))
                    # Basic support for 4D nifti: select the first image
                    #if len(im_table[im_key]['func']) == 1:
                    #im_func += ',1'
                    # Send to MATLAB checkreg!
                    #mlab.workspace.cd(os.path.dirname(im_func))  # Change MATLAB current directory to the functional images dir, so that it will be easy and quick to apply transformation to all other images
                    #mlab.workspace.spm_check_registration(im_anat, im_func, nout=0)
                    #mlab.workspace.spm_orthviews('reorient','context_init',[2], nout=0)  # directly open the coregistration menu and outlines
                    # Alternative for python-matlab-bridge
                    #mlab.run_func('cd.m', os.path.dirname(im_func))  # Change MATLAB current directory to the functional images dir, so that it will be easy and quick to apply transformation to all other images
                    #mlab.run_func('spm_check_registration.m', im_anat, im_func)
                    # Alternative for other libraries
                    mlab.cd(os.path.dirname(im_func))  # Change MATLAB current directory to the functional images dir, so that it will be easy and quick to apply transformation to all other images
                    mlab.spm_check_registration(im_anat, im_func)
                    mlab.spm_orthviews('reorient','context_init',[2], nout=0)  # directly open the coregistration menu and outlines
                    # Allow user to select another image if not enough contrast
                    im_func_total = len(funclist) - 1  # total number of functional images
                    uchoice = ask_next(msg="Not enough contrasts? Want to load another T2 image? [R]andomly select another T2 or [first] or [last] or any number (bounds: 0-%i) or [auto]-coregister again, [autonopre], or Enter to [c]ontinue to next session or subject: " % (im_func_total), customchoices=['r', 'first', 'last', 'int', 'auto', 'autonopre'])
                    if uchoice is True:  # continue if pressed enter or c
                        break
                    elif uchoice == 'r':  # select a random image
                        select_t2_nb = None
                    elif uchoice == 'first':  # select first image
                        select_t2_nb = 0
                    elif uchoice == 'last':  # select last image
                        select_t2_nb = -1
                    elif is_int(uchoice) and uchoice is not False:  # Select specific image by number
                        newchoice = int(uchoice)
                        # Check the number is between bounds, else select a random image
                        if not (0 <= newchoice <= im_func_total):
                            print("Warning: Selected volume number is out of bounds, please select another. Fallback to displaying same volume.")
                        else:
                            select_t2_nb = newchoice
                            print("Number : %i" % select_t2_nb)
                    elif uchoice == 'auto' or uchoice == 'autonopre':  # auto-coregister again
                        print('Auto-coregistering functional on structural, please wait...')
                        # Sort images
                        im_table[im_key]['anat'].sort()
                        funclist.sort()
                        # Pick the image
                        im_anat = im_table[im_key]['anat'][0]  # pick the first T1
                        funclist = im_table[im_key]['func'][k]  # get images from the 'func' list, not 'func_expanded', to support for 4D niftis
                        im_func = funclist[0]  # pick first EPI BOLD, this will be the source
                        if len(funclist) > 1:
                            im_func_others = funclist[1:]  # pick other functional images, these will be the "others" images that will also be transformed the same as source
                        else:
                            # 4D nifti support: there might be only one nifti file
                            im_func_others = []
                        # Support for 4D nifti: select the first volume of the functional image that will be used as the source for coregistration
                        # Also we do not use the expanded functional images list, since there is only one header for all volumes in a 4D nifti, we need to apply the coregistration translation on only the first volume, this will be propagated to all others
                        im_func += ',1'
                        # Send to MATLAB checkreg!
                        if uchoice == 'auto':
                            #mlab.workspace.functionalcoreg(im_anat, im_func, im_func_others, 'mi', nout=0)  # matlab_wrapper
                            mlab.functionalcoreg(im_anat, im_func, im_func_others, 'mi')
                        else:
                            #mlab.workspace.functionalcoreg(im_anat, im_func, im_func_others, 'minoprecoreg', nout=0)
                            mlab.functionalcoreg(im_anat, im_func, im_func_others, 'minoprecoreg')

    # == MOTION CALCULATIONS
    print("\n=> STEP7: CALCULATE MOTION PARAMETERS")
    if regex_motion:
        print("Motion paramaters will be loaded from already generated rp_*.txt files, as detected by the provided -rp argument.")
    else:
        print("Realignment (without saving) will be applied on the functional images to calculate the motion files (rp_*.txt) and an excel file with the max, min, mean and variance of translation and rotation movement parameters will be saved (this file can then be used to exclude subjects based on motion).")

    if ask_step():  # Wait for user to be ready
        # -- Proceeding to MATLAB spm_realign and calculate motion parameters
        # prepare the list to store all movement parameters for each subject/session
        cols = ['_'.join(x) for x in itertools.product(['diff', 'std', 'mean', 'median', 'mad'], ['translation', 'rotation'], ['x', 'y', 'z'])]
        mov_list = []
        mov_list.append(['id', 'session', 'path'] + ['sumdiff_translation', 'sumdiff_rotation'] + ['mad_translation_sum', 'mad_rotation_sum'] + cols)

        def calc_motion_metrics(movement_params):
            # Compute framewise displacement (= frame-by-frame difference)
            movement_params = np.diff(movement_params, axis=0)
            # Compute statistical metrics to summarize the movement parameters
            mov_diff = np.max(movement_params, axis=0) - np.min(movement_params, axis=0)
            mov_sumdiff = [sum(mov_diff[0:3]), sum(mov_diff[3:6])]
            mov_std = np.std(movement_params, axis=0)
            mov_mean = np.mean(movement_params, axis=0)
            mov_median = np.median(movement_params, axis=0)
            mov_mad = np.median(np.abs(movement_params - np.median(movement_params, axis=0)), axis=0)  # median absolute deviation = median(abs(Xi - median(X)))
            mov_madsum = [sum(mov_mad[0:3]), sum(mov_mad[3:6])]
            return mov_sumdiff + mov_madsum + mov_diff.tolist() + mov_std.tolist() + mov_mean.tolist() + mov_median.tolist() + mov_mad.tolist()

        if regex_motion:
            # Get list of rp files
            rp_list, conflict_flags = pathmatcher.main(r' -i "{inputpath}" -ri "{regex_motion}"  --silent '.format(**template_vars), True)
            rp_list = [file[0] for file in rp_list]  # extract only the input match, there's no output anyway
            rp_list = [os.path.join(rootfolderpath, file) for file in rp_list]  # calculate full absolute path instead of relative (since we need to pass them to MATLAB)
            # Get the key and reorganize by key so that we can know if there are multiple sessions per subject
            RE_motion = re.compile(regex_motion)
            rp_listreorg = {}
            for rpi in rp_list:
                m = RE_motion.search(rpi)
                if m:
                    rpkey = m.group(1)
                    if rpkey not in rp_listreorg:
                        rp_listreorg[rpkey] = []
                    rp_listreorg[rpkey].append(rpi)
            # Extract a key for each
            for rpkey in tqdm(rp_listreorg.keys(), leave=True, unit='subjects'):
                for i, rpfile in enumerate(rp_listreorg[rpkey]):
                    # Get motion parameters from the rp file
                    movement_params = np.loadtxt(fname=rpfile)
                    # Calculate motion metrics
                    mov_metrics = calc_motion_metrics(movement_params)
                    # Build metadata info (subject name, session, what path, etc)
                    func_metadata = [rpkey, i, rpfile]
                    # Append to our list of movement parameters
                    mov_list.append(func_metadata + mov_metrics)
        else:
            current_image = 0 # TODO: to delete?
            # for each key (can be each condition, session, subject, or even a combination of all those and more)
            for im_key in tqdm(im_table.keys(), total=total_func_images, initial=current_image, leave=True, unit='subjects'):
                current_image += 1
                # check if there is both anatomical and structural images available, if one is missing we simply skip
                if 'anat' not in im_table[im_key] or 'func_expanded' not in im_table[im_key]:
                    continue
                # prepare the functional images list (there might be multiple folders)
                if isinstance(im_table[im_key]['func_expanded'], dict):
                    # multiple folders
                    funclists = im_table[im_key]['func_expanded'].values()
                else:
                    # only one folder, we simply put it in a list so that we don't break the loop
                    funclists = [im_table[im_key]['func_expanded']]
                # For each functional image subfolder
                for i, funclist in enumerate(funclists):
                    if len(funclist) == 1:
                        # If there is only one image, we cannot compute motion, so just skip
                        continue
                    if verbose: print("- Processing files: %s" % (os.path.relpath(funclist[0], rootfolderpath)))
                    #mlab.workspace.cd(os.path.dirname(os.path.join(rootfolderpath, funclist[0])))  # Change MATLAB current directory to the functional images dir, to ensure output files will be written in same directory (not sure how SPM handles what folder to use)
                    # Compute movement parameters (will also create a rp_*.txt file, but NOT modify the nifti files headers
                    #movement_params = mlab.workspace.realignhelper([os.path.join(rootfolderpath, imf) for imf in funclist])

                    # ALternative for python-matlab-bridge
                    #mlab.run_func('cd.m', os.path.dirname(os.path.join(rootfolderpath, funclist[0])))
                    #mlab.run_func('realignhelper.m', [os.path.join(rootfolderpath, imf) for imf in funclist])
                    # Alternative for other libraries based on mlabwrap
                    mlab.cd(os.path.dirname(os.path.join(rootfolderpath, funclist[0])))  # Change MATLAB current directory to the functional images dir, to ensure output files will be written in same directory (not sure how SPM handles what folder to use)
                    movement_parameters = mlab.realignhelper([os.path.join(rootfolderpath, imf) for imf in funclist])

                    # Calculate motion metrics
                    mov_metrics = calc_motion_metrics(movement_params)
                    # Build metadata info (subject name, session, what path, etc)
                    func_metadata = [im_key, i, os.path.dirname(os.path.join(rootfolderpath, funclist[0]))]
                    # Append to our list of movement parameters
                    mov_list.append(func_metadata + mov_metrics)
        # Save the list as a csv
        with open(os.path.join(rootfolderpath, 'movement_parameters.csv'), 'wb') as f:
            csv_handler = UnicodeWriter(f, delimiter=';', quoting=csv.QUOTE_ALL, encoding='utf-8-sig')
            csv_handler.writerows(mov_list)

    # == END: now user must execute the standard preprocessing script
    #mlab.stop()  # stop Matlab session
    print("\nAll done. You should now use the standard preprocessing script. Quitting.")
    _ = input("Press any key to quit.")  # IMPORTANT: if we don't wait, the last task will be closed because the program is closing!

    return 0

# Calling main function if the script is directly called (not imported as a library in another program)
if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
