#!/usr/bin/env python
#
# reorientation_registration_helper.py
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
#        Reorientation and Registration helper
#                    Python 2.7.11
#                by Stephen Larroque
#                     License: MIT
#            Creation date: 2016-03-27
#=================================
#
#
#

from __future__ import print_function

__version__ = '0.3'

import argparse
import os
import random
import re
import shlex
import shutil
import sys
import traceback

from collections import OrderedDict
from itertools import izip_longest, product
from pathmatcher import pathmatcher

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
    user_choice = raw_input('Do this step? [C]ontinue (default), [S]kip to next, [A]bort: ')
    if user_choice.lower() == 'a':
        sys.exit(0)
    elif user_choice.lower() == 's':
        return False
    else:
        return True

def ask_next(filepath=''):
    '''Ask to user if s/he is ready to process next file'''
    user_choice = raw_input("\nLoad next file %s? [C]ontinue (default), [S]kip and go to next step, [A]bort: " % filepath)
    if user_choice.lower() == 'a':
        sys.exit(0)
    elif user_choice.lower() == 's':
        return False
    else:
        return True

def str_to_raw(str):
    '''Convert string received from commandline to raw (unescaping the string)'''
    try:  # Python 2
        return str.decode('string_escape')
    except:  # Python 3
        return str.encode().decode('unicode_escape')

def fullpath(relpath):
    '''Relative path to absolute'''
    if (type(relpath) is object or hasattr(relpath, 'read')): # relpath is either an object or file-like, try to get its name
        relpath = relpath.name
    return os.path.abspath(os.path.expanduser(relpath))

def grouper(n, iterable, fillvalue=None):
    "grouper(3, 'ABCDEFG', 'x') --> ABC DEF Gxx"
    args = [iter(iterable)] * n
    return izip_longest(fillvalue=fillvalue, *args)



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
Description: Automate the file selection process that is required in SPM between each reorientation/registration.

No more useless clicks, just do the reorientation/registration in batch, you don't need to worry about selecting the corresponding files, this helper will do it for you.

Also note that the program expects the anatomical images to be the same across all conditions. Thus, you will reorient the anatomical images only once per subject, and then they will be copied over all other conditions.
WARNING: if that's not the case (you have different anatomical images per condition), please DO NOT use this helper, or comment the reorientation step!

Note: you need to `pip install mlab` before using this script.

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
                        help='Path to the input folder (the root directory where you placed the files with a tree structure of [Condition]/[id]/data/(mprage|rest)/*.(nii|hdr|img)', **widget_dir)

    # Optional general arguments
    main_parser.add_argument('-v', '--verbose', action='store_true', required=False, default=False,
                        help='Verbose mode (show more output).')


    #== Parsing the arguments
    args = main_parser.parse_args(argv) # Storing all arguments to args
    
    #-- Set variables from arguments
    inputpath = fullpath(args.input)
    rootfolderpath = inputpath
    verbose = args.verbose
    checkreg_display_count = 6  # number of anatomical images that will be displayed at the same time during step 3.

    # -- Sanity checks
    if os.path.isfile(inputpath): # if inputpath is a single file (instead of a folder), then define the rootfolderpath as the parent directory (for correct relative path generation, else it will also truncate the filename!)
        rootfolderpath = os.path.dirname(inputpath)

    if not os.path.isdir(rootfolderpath):
        raise NameError("Specified input path does not exist. Please check the specified path: %s" % rootfolderpath)

    ### Main program
    print("\n== Reorientation and registration helper started ==\n")
    print("Parameters:")
    print("- Input root: %s" % inputpath)
    print("\n")

    # == Prepare list of conditions and string template vars
    conditions_list = next(os.walk(rootfolderpath))[1]
    conditions_list.sort()  # Make sure the folders order is the same every time we launch the application, in order for the user to be able to restart and skip steps and still work on the same files
    template_vars = {'inputpath': rootfolderpath,
                                    'firstcond': conditions_list[0],
                                    }

    # == IMPORT MLAB (LOAD MATLAB BRIDGE)
    print("Launching MATLAB, please wait a few seconds...")
    os.chdir(rootfolderpath)  # Change Python current directory before launching MATLAB, this will change the initial dir of MATLAB
    try:
        from mlab.releases import latest_release as matlab
        from mlab import mlabraw
    except ImportError as exc:
        print("You need to install https://github.com/ewiger/mlab to use this script!")
        raise(exc)
    #matlab.cd(rootfolderpath)  # FIXME: Does not work: Change MATLAB's current dir to root of project's folder, will be easier for user to load other images if needed

    # == Files walking
    print("Please wait while the directories are scanned to find anatomical images...")
    files_list, conflict_flags = pathmatcher.main(r' -i "{inputpath}" -ri "{firstcond}/(\d+)/data/mprage/[^\.]+\.(img|nii)" --silent '.format(**template_vars), True)
    files_list = [file[0] for file in files_list]  # extract only the input match, there's no output anyway
    files_list = [os.path.join(rootfolderpath, file) for file in files_list]  # calculate full absolute path instead of relative (since we need to pass them to MATLAB)

    # == SPM_AUTO_REORIENT
    # Get the list of anatomical images
    print("\n=> STEP1: SPM_AUTO_REORIENT")
    if ask_step():  # Wait for user to be ready
        print("Starting the auto-reorienting process, please wait (this can take a while)...")
        # Auto reorient anatomical images
        for file in tqdm(files_list, leave=True, unit='files'):
            if verbose: print("- Processing file: %s" % file)
            matlab.spm_auto_reorient(file)

    # == CHECK REORIENT AND MANUAL ADJUSTMENT
    print("\n=> STEP2: CHECK REORIENT AND ADJUST MANUALLY")
    print("Anatomical will now be displayed. Please check that they are correctly oriented, if not, please adjust manually.")
    if ask_step():  # Wait for user to be ready
        for file in tqdm(files_list, leave=True, unit='files'):
            if verbose: print("- Processing file: %s" % file)
            if not ask_next(file): break  # ask for use to load the next file? Becaus else, the bridge does not wait and loads all files one after the other
            #matlab.cd(os.path.dirname(file))  # FIXME: does not work...
            os.chdir(os.path.dirname(file))  # Workaround: Change Python and MATLAB's path to the folder where the anatomical file is, so that user just needs to click on it
            matlab.spm_image('display', str_to_raw(file))  # Convert path to raw string to avoid \0 MATLAB string termination character

    # == CHECK MULTIPLE IMAGES TOGETHER
    print("\n=> STEP3: CHECK MULTIPLE IMAGES TOGETHER")
    print("Multiple anatomical images will be displayed side by side as a sanity check of correct reorientation. Please check that they are all reoriented correctly.")
    if ask_step():  # Wait for user to be ready
        for files in tqdm(grouper(checkreg_display_count, files_list), total=int(len(files_list)/6), leave=True, unit='files'):
            if verbose: print("- Processing files: %s" % repr(files))
            if not ask_next(): break  # ask for use to load the next file? Becaus else, the bridge does not wait and loads all files one after the other
            matlab.spm_check_registration(*files)

    # == COPY ANATOMICAL TO OTHER CONDITIONS
    print("\n=> STEP4: COPYING ANATOMICAL IMAGES")
    print("Anatomical images will now be copied onto other conditions, please wait a few minutes...")
    if ask_step():  # Wait for user to be ready
        for condition in conditions_list[1:]:  # skip first condition, this is where we will copy the anatomical images from, to the other conditions
            template_vars["tocond"] = condition
            os.chdir(rootfolderpath)  # reset to rootfolder to generate the simulation report there
            pathmatcher.main(r' -i "{inputpath}/{firstcond}" -ri "(\d+)/data/mprage/" -o "{inputpath}/{tocond}" -ro "\1/data/mprage/" --copy --force --yes --silent '.format(**template_vars), True)

    # == REGISTRATION
    print("\n=> STEP5: REGISTRATION OF FUNCTIONAL IMAGES")
    print("A randomly selected functional image will now be displayed (bottom) along the corresponding anatomical image (top). Please reorient the functional image to match the anatomical image, and select all functional images to apply the reorientation.")
    print("NOTE: you need to right-click on the bottom image, then click on Reorient Images > Current image. Red contours of the bottom functional image will be overlaid on the top anatomical image, and a side menu will open to allow you to reorient the bottom image and apply on other functional images.")

    if ask_step():  # Wait for user to be ready
        # -- Walk files and detect all anatomical and functional images (based on directories layout)
        os.chdir(rootfolderpath)  # reset to rootfolder to generate the simulation report there
        images_list, conflict_flags = pathmatcher.main(r' -i "{inputpath}" -ri "([^\\/]+)/(\d+)/data/(mprage|rest)/[^\.]+\.(img|nii)" --silent '.format(**template_vars), True)
        images_list = [file[0] for file in images_list]  # extract only the input match, there's no output anyway

        # -- Precomputing to pair together anatomical images and functional images of the same patient for the same condition
        im_table = OrderedDict()  # images lookup table, organized by condition type, then id, then type of imagery (anatomical or functional)
        RE_images = re.compile(r'([^\\/]+)/(\d+)/data/(mprage|rest)/')
        for file in images_list:
            # Match the regex on each file path, to detect the condition, subject id and type of imagery
            m = RE_images.match(file)
            # Use these metadata to build our images lookup table, with every images grouped and organized according to these parameters
            # TODO: maybe use a 3rd party lib to do this more elegantly? To group strings according to values in the string that match together?
            cond, id, im_type = m.group(1), m.group(2), m.group(3)
            # Create entry if does not exist
            if cond not in im_table:
                im_table[cond] = OrderedDict()  # always use an OrderedDict so that we walk the subjects id by the same order every time we launch the program (allows to skip already processed subjects)
            if id not in im_table[cond]:
                im_table[cond][id] = OrderedDict()
            if im_type not in im_table[cond][id]:
                im_table[cond][id][im_type] = []

            # Append file path to the table at its correct place
            im_table[cond][id][im_type].append(file)

        # Precompute total number of elements user will have to process (to show progress bar)
        total_images_step5 = 0
        for cond in im_table:
            for id in im_table[cond]:
                total_images_step5 += 1

        # -- Processing to MATLAB checkreg
        current_image_step5 = 0
        for cond in im_table:  # for each condition
            for id in tqdm(im_table[cond], total=total_images_step5, initial=current_image_step5, leave=True, unit='subjects'):  # for each subject id in each condition
                current_image_step5 += 1
                # Randomly choose one anatomical image (there should be only one anyway) and one functional image
                im_anat = random.choice(im_table[cond][id]['mprage'])
                im_func = random.choice(im_table[cond][id]['rest'])
                if verbose: print("- Processing files: %s and %s" % (im_anat, im_func))
                # Build full absolute path for MATLAB
                im_anat = os.path.join(rootfolderpath, im_anat)
                im_func = os.path.join(rootfolderpath, im_func)
                # Wait for user to be ready
                user_choice = raw_input('Open next registration for condition %s, subject id %s? Enter to continue, [S]kip to next condition, [N]ext subject, [A]bort: ' % (cond, id))
                if user_choice.lower() == 's':
                    break
                elif user_choice.lower() == 'n':
                    continue
                elif user_choice.lower() == 'a':
                    return 0
                # Send to MATLAB checkreg!
                matlab.cd(os.path.dirname(im_func))  # Change MATLAB current directory to the functional images dir, so that it will be easy and quick to apply transformation to all other images
                matlab.spm_check_registration(im_anat, im_func)

    # == END: now user must execute the standard preprocessing script
    print("\nAll done. You should now use the standard preprocessing script. Quitting.")

    return 0

# Calling main function if the script is directly called (not imported as a library in another program)
if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
