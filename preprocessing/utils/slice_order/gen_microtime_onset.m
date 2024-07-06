function [microtime_onset, microtime_resolution, refslice] = gen_microtime_onset(slice_order, refslice, min_microtime_resolution, max_microtime_resolution)
% [microtime_onset, microtime_resolution, refslice] = gen_microtime_onset(slice_order, refslice, min_microtime_resolution)
% Calculates the appropriate microtime_onset for a statistical test in SPM given the slice_order, min_microtime_resolution and reference slice
% input: slice_order is the slice order used for slice timing correction.
% input: refslice is the spatial reference slice used in slice timing correction. Value can be either: 'first', 'middle', 'last' or any slice number or slice timing.
% optional input: min_microtime_resolution: minimal microtime resolution you want, the script will return the smallest microtime resolution above this minimum that can perfectly align with this refslice (default in SPM12 = 16)
% optional input: max_microtime_resolution: maximal microtime resolution you want, if the result need to have a higher microtime resolution to be precise, with this option the onset will be approximated to the nearest previous microtime block (default=0 disabled).
%
% by Stephen Larroque from the Coma Science Group, 2017
% Licensed under MIT.
%
% v1.0
%
% Notices/Changelog:
% * v1.0: first release
%

    if ~exist('min_microtime_resolution', 'var')
        min_microtime_resolution = 16;  % SPM12 default
    end
    if ~exist('max_microtime_resolution', 'var')
        max_microtime_resolution = 0;
    end

    % Helper condition for easy refslice setting
    if strcmpi(refslice, 'first') | refslice == slice_order(1)
        % special case, we do not need to compute anything
        refslice = slice_order(1);
        microtime_resolution = min_microtime_resolution;
        microtime_onset = 1;
        return;
    elseif strcmpi(refslice, 'middle')
        refslice = slice_order(ceil(numel(slice_order)/2));
    elseif strcmpi(refslice, 'last')
        refslice = slice_order(end);
    %else refslice is an integer or a float, which is the slice spatial number we want to use as refslice
    end %endif

    % Convert refslice from spatial convention (number is slice position is space and position in array is position in time) to temporal convention (position in array is position in space and number is position in time)
    temporal_refslice = find(slice_order == refslice) - 1;  % minus 1 because we want to set onset at the start of the slice, so in fact before this slice. Here this will give us the last microtime that belong to the previous slice.
    % Calculate the ratio compared to the number of slices (to get the relative position from the start of the array)
    microtime_onset_ratio = temporal_refslice / numel(slice_order);

    % Rescale to min_microtime_resolution
    [N, D] = rat(microtime_onset_ratio);
    if D < 16
        ratio_newT = ceil(min_microtime_resolution/D);
        microtime_resolution = D*ratio_newT;
        microtime_onset = N*ratio_newT + 1;  % plus 1 because N is at the last microtime block of the previous slice, so if we do +1 we will be at the start microtime block of the next slice (the refslice)
    else
        microtime_resolution = D;
        microtime_onset = N + 1;  % plus 1 for same reason, to move from last microtime block of previous slice to the start microtime block of the refslice
    end %endif

    % Approximate onset if resolution is above max_microtime_resolution
    if max_microtime_resolution > 0 & microtime_resolution > max_microtime_resolution
        microtime_onset = floor(microtime_onset/(microtime_resolution/max_microtime_resolution));
        microtime_resolution = max_microtime_resolution;
    end %endif

end
