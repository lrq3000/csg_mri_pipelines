# Originally made by Enrico Amico for the Coma Science Group
# Modified to fit in a pipeline by Stephen Larroque

from __future__ import print_function

import os
import subprocess

rootfolder = "/home/brain/neuro-csg-pipelines/enrico-scripts-allinone/Patient_Name_2016/"

def run_command(command):
    p = subprocess.Popen(command,
                         stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT)
    return iter(p.stdout.readline, b'')

def run_command_full(command):
    if os.name == 'nt':
        p = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    elif os.name == 'posix':
        # Run the command supporting .bashrc
        subprocess.call([os.getenv('SHELL'), '-i', '-c', command], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        # Retrieve the terminal
        os.tcsetpgrp(0,os.getpgrp())
    out, err = p.communicate()
    return out, err

out, err = run_command_full(r'mrinfo "' + rootfolder + r'" -force -export_grad_mrtrix grad.txt -export_grad_fsl grad.bvecs grad.bvals')
