function Q = realignhelper(func)

% FORMAT realignhelper(func)
%
% Helper function to use the correct default flags for spm_realign() (since Python can't pass structs to Matlab)
%
% IN:
% - func      : list of filenames of all functional (or other modality) images to realign/coregister to the first image
%
% OUT:
% - The realignment parameters for each volume and saves them also in a rp_*.txt file
%__________________________________________________________________________
% v1.0.0
% License: MIT License
% Copyright (C) 2019 Stephen Karl Larroque - Coma Science Group - GIGA-Consciousness - University & Hospital of Liege
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:

% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.

% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.

%% Check inputs
if nargin<1 || isempty(func)
    error('No functional images were provided!');
end

% Set up flags, use default parameters from SPM12 GUI
flags.quality = 0.9;
flags.fwhm = 5;
flags.sep = 4;
flags.interp=2;

% Do the realignment
% Note: we use an output argument because spm_realign() has a different behavior if one is specified, in this case only the rp_*.txt file will be written and original images headers will not be modified (otherwise without an output argument the realignment WILL be saved in the functional images headers)
P = spm_realign(char(func), flags);  % VERY important: ensure that the input is a char, and not a cellstr, else the files will be coregistered separately (to nothing! + a bug will follow about the dot notation)

%-Save parameters as rp_*.txt files
%------------------------------------------------------------------
Q = save_parameters(P);

fprintf('Realignment done!\n');

%==========================================================================
% function save_parameters(V)
% from SPM12 spm_realign.m
% modified to return Q
%==========================================================================
function Q = save_parameters(V)
fname = spm_file(V(1).fname, 'prefix','rp_', 'ext','.txt');
n = length(V);
Q = zeros(n,6);
for j=1:n
    qq     = spm_imatrix(V(j).mat/V(1).mat);
    Q(j,:) = qq(1:6);
end
save(fname,'Q','-ascii');
