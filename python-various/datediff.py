#!/usr/bin/env python
#
# datediff.py
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
#                        datediff
#                    Python 2.7.11
#                by Stephen Larroque
#                     License: MIT
#            Creation date: 2016-05-11
#=================================
#
# Description: this scripts make the difference between the first date and all subsequent date as provided in a list of lists. The first date of a sublist is always the reference point, all the subsequent dates will be considered as happening in the future.
#

from __future__ import print_function

__version__ = '0.1'

from datetime import datetime
from pprint import pprint

# Parameter - EDIT ME
dates_list = {
'SUBJ1': ['2014-09-12', '2015-09-15', '2015-09-23'],
'SUBJ2': ['2015-03-18', '2016-05-16', '2016-07-04'],
                   }

def compare_two_dates(ref, future, format='%Y-%m-%d'):
    '''Compare two dates and return the difference of days'''
    a = datetime.strptime(ref, format)
    b = datetime.strptime(future, format)
    return b - a

# Main program
res = {}
datetemplate = '%Y-%m-%d'  # see http://strftime.org/
for id, dlist in dates_list.items():
    refdate = datetime.strptime(dlist[0], datetemplate)
    res[id] = [str((datetime.strptime(fdate, datetemplate) - refdate).days) + ' days' for fdate in dlist]

# Display result nicely
for id in dates_list.keys():
    print(id + ' return date ' + dates_list[id][0] + ':')
    for j in xrange(1, len(dates_list[id])):
        print((' ' * 4) + dates_list[id][j] + ': ' + res[id][j])
