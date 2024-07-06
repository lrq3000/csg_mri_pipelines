function [slice_order, TR, nslices, slice_order_type, slice_timing] = autodetect_sliceorder(image_filepath, verbose, slice_timing)
% [slice_order, TR, nslices, slice_order_type, slice_timing] = autodetect_sliceorder(image_filepath, verbose, slice_timing)
% Returns slice order and timing information from a neuroimage file.
% Requires SPM12 (or SPM8).
% input: image_filepath can either be a DICOM or a NIFTI-2 or a BIDS (JSON) file
% optional input: verbose = true will display the slice order name at the end in addition to return the value (following nifti conventions)
% optional input: slice_timing can be provided for debugging.
% output: slice_order will sometimes get returned to show the exact slice order of your file (with dicoms of Siemens machines only)
% output 2: TR the time of repetition between two EPI volumes.
% output 3: nslices the number of slices per volume, if available.
% output 4: slice_order_type, an integer between [0, 6] with 0 unknown, and > 0 following nifti convention: http://nifti.nimh.nih.gov/pub/dist/src/niftilib/nifti1.h
% output 5: slice_timing, a vector of the exact slice times (either as extracted from file headers, or from nifti calculated from slice order and TR). Note that for nifti, this is only an approximation, the real slice timing as extracted from dicom or bids can be quite different (because scanners tend to round off in their own way to have nicer numbers and thus more reliably acquire slices at the same relative timing)
% Note that to work on dicoms, you must select an EP2D BOLD volume after the first one (because the first won't have the slice timing infos).
%
% created on 2017-11-06 by Stephen Larroque, Coma Science Group, University and Hospital of Liege
% MIT License
% v1.3.2
%
% TODO:
% * For MATLAB > 2016, use native jsonload!
% * Detect if NIFTI-1 then raise error and return
% * autodetect if multiband
%

% Load jsonlab, to support BIDS on MATLAB < R2016
curpath = fileparts(mfilename('fullpath'));
addpath([curpath '/jsonlab']);

% Init optional arguments
if ~exist('verbose', 'var')
    verbose = 0;
end

if ~exist('slice_timing', 'var')
    slice_timing = [];
end

% Init vars
slice_order_type = 0; % Initialize slice order to "unknown"
slice_order = [];
TR = 0;
nslices = 0;
used_nifti = false; % flag if we use nifti, because then we approximate

%nifti slice order convention: http://nifti.nimh.nih.gov/pub/dist/src/niftilib/nifti1.h
kNIFTI_SLICE_UNKNOWN = 0; %AUTO DETECT
kNIFTI_SLICE_SEQ_INC = 1; %1,2,3,4
kNIFTI_SLICE_SEQ_DEC = 2; %4,3,2,1
kNIFTI_SLICE_ALT_INC = 3; %1,3,2,4 Siemens: interleaved with odd number of slices, interleaved for other vendors
kNIFTI_SLICE_ALT_DEC = 4; %4,2,3,1 descending interleaved with odd number of slices (odd-last)
kNIFTI_SLICE_ALT_INC2 = 5; %2,4,1,3 Siemens interleaved with even number of slices 
kNIFTI_SLICE_ALT_DEC2 = 6; %3,1,4,2 Siemens interleaved descending with even number of slices (even-last)
kNIFTI_SLICE_CUSTOM = 99; % custom type (such as Philips central, reverse central, interleaved or for multi-band)

% Names cellarray for the different slice orders
slice_order_type_names = { ...
'type 0: unknown', ...
'type 1: sequential ascending (1 2 3 4)', ...
'type 2: sequential descending (4 3 2 1)', ...
'type 3: interleaving ascending odd-first (1 3 2 4)', ...
'type 4: interleaving descending odd-last (4 2 3 1)', ...
'type 5: interleaving ascending even-first (2 4 1 3)', ...
'type 6: interleaving descending even-last (3 1 4 2)', ...
};
slice_order_type_names_custom = 'type 99: custom type (see detailed slice_order)';

% Break filepath into parts and clean it
[pth,nam,ext,vol] = spm_fileparts( deblank(image_filepath(1,:)));
image_filepath_cleaned = fullfile(pth,[ nam, ext]); %'img.nii,1' -> 'img.nii'

% Detecting slice order
if strcmpi(ext, '.dcm') | strcmpi(ext, '.ima') | strcmpi(ext, '.json') | ~isempty(slice_timing)
    % DICOM and BIDS will both return slice timings, we both support them here
    % This is actually more precise since there can be a lot of different schemes, more than specified in the nifti convention (eg, Philips central, reverse central or max interleaved, multi-band fast acquisition, etc.)

    % Extracting slice timing
    if strcmpi(ext, '.dcm') | strcmpi(ext, '.ima')
        % For dicoms (only for (some) Siemens machines)
        % Open file headers using SPM
        hdr = spm_dicom_headers(image_filepath_cleaned);
        if ~strcmpi(strtrim(hdr{1}.Manufacturer), 'SIEMENS')
            fprintf('ERROR: Autodetection of slice order from DICOMs is only supported for Siemens machines at the moment.\n');
            return;
        end %endif
        % Extract the slice times (as uint8 symbols)
        slice_timing = hdr{1}.Private_0019_1029;
        if round(slice_timing(1)) == slice_timing(1) & round(slice_timing(2)) == slice_timing(2) % cannot test directly if it is a double or integer, because spm/matlab always load this dicom field as double! So we need to test two slices, because one of them can be the 1st slice so it will be 0 and an integer!
            % If not already a double, we got packs of 8 integer symbols that we need to convert to doubles
            % Convert each pack of 8 symbols into one double, we now have our slice times!
            slice_timing = typecast(uint8(slice_timing), 'double');
        end %endif
        % Get TR
        TR = hdr{1}.RepetitionTime;
        nslices = numel(slice_timing);
    elseif strcmpi(ext, '.json')
        % For JSON BIDS
        hdr = loadjson(image_filepath_cleaned);
        slice_timing = hdr.SliceTiming;
        TR = hdr.RepetitionTime;
        nslices = numel(slice_timing);
    end %endif

    % Slice order type detection
    if ~isempty(slice_timing)
        % Sort the slice times to get the slice order
        [~, slice_order] = sort(slice_timing);
        % Summarize what slice order type we have here
        if slice_order(1)+1 == slice_order(2) & slice_order(1) == 1 & (slice_order == sort(slice_order,'ascend') | slice_order == sort(slice_order,'descend')) % prevent mixup with Philips central or reverse central or interleaved modes
            slice_order_type = kNIFTI_SLICE_SEQ_INC;
        elseif slice_order(1)-1 == slice_order(2) & slice_order(1) == max(slice_order) & (slice_order == sort(slice_order,'ascend') | slice_order == sort(slice_order,'descend'))
            slice_order_type = kNIFTI_SLICE_SEQ_DEC;
        elseif slice_order(1)+2 == slice_order(2)
            if mod(slice_order(1), 2)
                % odd-first
                slice_order_type = kNIFTI_SLICE_ALT_INC;
            else
                % even-first
                slice_order_type = kNIFTI_SLICE_ALT_INC2;
            end %endif
        elseif slice_order(1)-2 == slice_order(2)
            if mod(slice_order(end), 2)
                %odd-last
                slice_order_type = kNIFTI_SLICE_ALT_DEC;
            else
                % even-last
                slice_order_type = kNIFTI_SLICE_ALT_DEC2;
            end %endif
        else
            % Custom type not covered by nifti conventions (such as Philips central, reverse central, interleaved or multi-band)
            slice_order_type = kNIFTI_SLICE_CUSTOM;
        end %endif
    end %endif
elseif strcmpi(ext, '.nii') | strcmpi(ext, '.hdr') | strcmpi(ext, '.img')
    % nifti slice order extraction, should work on all nifti files as long as the dicom to nifti converter that was used conserved the info during the conversion
    used_nifti = true;

    % Slice order type is given in nifti
    fid = fopen(image_filepath_cleaned);
    fseek(fid,122,'bof');
    slice_order_type = fread(fid,1,'uint8');
    fclose(fid);

    % TR and number of slices extraction from nifti
    hdr = spm_vol([image_filepath_cleaned ',1']);
    nslices = hdr.dim(3);
    try
        TR = hdr.private.timing.tspace;
    catch ERR
    % Failed, probably because it is a 3D nifti file (img/hdr instead of nii)? Try with a private field, else fail
        try
            TR = hdr.private.diminfo.slice_time.duration * max(hdr.private.diminfo.slice_time.start, hdr.private.diminfo.slice_time.end); % there are some converters that do not conserve the time of repetition info when converted to nifti but split in two files (hdr/img), because then the volumes are not 4D but 3D, and it seems some converters then "forget" to add the time of repetition.
        catch ERR
            % do nothing, the TR won't be defined
            % TODO: read slice_duration*nslices or pixdim[5] to get the TR directly from the nifti, but it's complicated to support all nifti files versions because of byteswapping and such, should use another library.
            % see https://brainder.org/2015/04/03/the-nifti-2-file-format/
            % and http://www.neuro.mcw.edu/~chumphri/matlab/readnifti.m
            % and https://www.nitrc.org/forum/forum.php?thread_id=2070&forum_id=1941
            % and https://www.rdocumentation.org/packages/AnalyzeFMRI/versions/1.1-16/topics/f.complete.hdr.nifti.list.create
        end %endtry
    end %endtry

    % Calculate the slice order and slice times, using the slice order type
    if slice_order_type > kNIFTI_SLICE_UNKNOWN
        if slice_order_type == kNIFTI_SLICE_SEQ_INC
            %1,2,3,4
            slice_order = [1:1:nslices];
        elseif slice_order_type == kNIFTI_SLICE_SEQ_DEC
            %4,3,2,1
            slice_order = [nslices:-1:1];
        elseif slice_order_type == kNIFTI_SLICE_ALT_INC
            %1,3,2,4 Siemens: interleaved with odd number of slices, interleaved for other vendors
            slice_order = [1:2:nslices 2:2:nslices-1];
        elseif slice_order_type == kNIFTI_SLICE_ALT_DEC
            %4,2,3,1 descending interleaved
            slice_order = fliplr([1:2:nslices 2:2:nslices-1]);
        elseif slice_order_type == kNIFTI_SLICE_ALT_INC2
            %2,4,1,3 Siemens interleaved with even number of slices 
            slice_order = [2:2:nslices 1:2:nslices-1];
        elseif slice_order_type == kNIFTI_SLICE_ALT_DEC2
            %3,1,4,2 Siemens interleaved descending with even number of slices
            slice_order = fliplr([2:2:nslices 1:2:nslices-1]);
        end %endif

        % Generate the slice timing
        if ~isempty(slice_order) & TR > 0
            [~, tmp] = sort(slice_order);
            slice_timing = (tmp-1) .* (TR/max(max(tmp)));
        end %endif
    end %endif
end %endif

% Last touch: some scanners store in dicoms the TR and slice_timing in ms instead of s, we convert if we detect this case
if TR > 100.0
    TR = TR / 1000;
end %endif
if max(slice_timing) > 100.0
    slice_timing = slice_timing ./ 1000;
end %endif

% verbose mode: display the results
if verbose
    if slice_order_type < numel(slice_order_type_names)
        slice_order_type_str = slice_order_type_names{slice_order_type+1};
    elseif slice_order_type == kNIFTI_SLICE_CUSTOM;
        slice_order_type_str = slice_order_type_names_custom;
    else
        slice_order_type_str = 'Unhandled bug!';
    end
    fprintf('Autodetected slice order type: %s\n', slice_order_type_str);
    fprintf('TR (in s): %g - nslices: %i\n', TR, nslices);
    fprintf('Slice order detailed: %s\n', ['[' sprintf('%i, ', slice_order) ']']);
    fprintf('Slice timing (in s): %s\n', ['[' sprintf('%g, ', slice_timing) ']']);
    if used_nifti
        fprintf('NOTICE: detection was done on a nifti file, the returned values can be false or anonymized. Note also that even if all was correct, the slice timing is only an approximation from extracted slice order, which is assuming perfect delay between slices, the real slice timing as extracted from dicom or bids can be quite different (because scanners tend to round off in their own way to have nicer numbers and thus more reliably acquire slices at the same relative timing).\n');
    end %endif
end %endif

end %endfunction
