function res=gen_slice_order(nslices, hstep, vstep, slice_order, reverse, unroll, multi, tr, slice_ids)
% res=gen_slice_order(nslices, hstep, vstep, slice_order, reversed, unroll, tr, multi)
% Compute a 2D slice order scheme based on given parameters
% slice_order can either be 'asc' or 'desc'.
% reverse=1 will reverse the row order (eg, instead of ascending 1, 3, ... 2, 4, ... we will get 2, 4, ... 1, 3, ...). You can also specify a vector with the original index of rows, eg: [2 1] to reverse, or more if you have more lines. This is useful for specific machines such as 3T MAGNETOM Prisma fit System which uses slice order ascending interleaved reversed when acquiring an even number of slices, and ascending interleaved (non-reversed) when acquiring an odd number.
% unroll=1 will unroll the whole matrix into one vector as expected by SPM.
% multi > 0 enables multiband EPI. multi can be either 1 for rows or 2 for columns. This will return time points in seconds instead of slice number without multiband.
% tr (in seconds) > 0 (tr = MRI sequence repetition time) will return slice time offsets (in ms, as expected by spm) instead of slice number.
% slice_ids is optional, you can provide your own custom slice indices with this argument, very useful for multiband with non linear schemes (if this exists?).
%
% by Stephen Larroque from the Coma Science Group, 2017-2024
% Licensed under MIT.
%
% v2.2.0
%
% Notices/Changelog:
% * v2.2.0 critical bugfix for tr, timing was not properly calculated (per column instead of on the full unrolled vector)
% * v2.1.1 mute display of res
% * v2.0 -> v2.1 critical bugfix for unroll == true, which prevented any unrolling (and thus scripts depending on interleaved sequences provided wrong slice order)
% * v1.1 -> v2.0 important fix in TR calculations! Previous calculations were based on wrong assumptions on conventions commonly used for slice order!
%

if ~exist('reverse', 'var')
    reverse = 0;
end

if ~exist('unroll', 'var')
    unroll = false;
end

if ~exist('multi', 'var')
    multi = 0;
end

if ~exist('tr', 'var')
    tr = 0;
end

% Compute horizontal vector
if strcmpi(slice_order, 'asc')
    hvec = [1:hstep:nslices];
else
    hvec = [nslices:-hstep:1];  % could also use fliplr()...
end %endif

% Compute vertical vector
vvec = [];
for v=1:vstep
    vvec = [vvec v:vstep:hstep];
end %endfor

% Mix them both to get a matrix
if ~exist('slice_ids', 'var')
    if strcmpi(slice_order, 'asc')
        slice_ids =  bsxfun(@plus, repmat(hvec, hstep, 1), (vvec'-1));
    else
        slice_ids =  bsxfun(@minus, repmat(hvec, hstep, 1), (vvec'-1));
    end %endif
end %endif
res = slice_ids;

% Reverse slice order acquisition
if reverse
    if isscalar(reverse) & reverse == 1
        res = res(size(res, 1):-1:1, :);
    elseif ~isscalar(reverse)
        res = res(reverse, :);
    end %endif
end %endif

% Multiband EPI: slices are acquired in parallel, either along rows or columns axis
if multi > 0
    if multi == 1
        % Columns are parallel
        res = bsxfun(@minus, res, (hvec - 1));
    elseif multi == 2
        % Rows
        res = bsxfun(@minus, res, (vvec - 1)');
        res = bsxfun(@minus, res, (hvec - 1));
        res = bsxfun(@plus, res, ([1:size(res, 2)] - 1));
    end %endif
end %endif

if tr > 0
    % Convert to time offset seconds
    % Old method: assume that the position in the vector is giving the slice number, and the number is the relative position it was acquired since beginning of scan
    % res = (res-1) .* (tr/max(max(res)));

    % New method: assume that the number is the slice number that was acquired, and the position in the vector of the number is the relative position since beginning of scan
    % First we need to make a vector, so that we can extract the time
    % position of each slice number
    res_vec = reshape(res', [], 1)'; % flatten matrix into a vector by appending rows. One-liner equivalent to res = res'; res = res(:)';
    [~, slices_idxs] = sort(res_vec); slices_abstiming = (slices_idxs-1) .* (tr/max(max(res_vec))); % sort and get back the indexes: this is the relative timing of each slice ; then feature scale all values proportionally to the TR, this gives the absolute timing for each slice.
    res = reshape(slices_abstiming, size(res, 1), size(res, 2)); % reshape the vector back into a matrix
end

% Unroll if necessary into one horizontal vector (as required by SPM)
if unroll
    if size(res, 1) == 1 | size(res, 2) == 1
        % Do not do anything if it is already a vector
        return;
    else
        if tr <= 0
            % Slice indices, we can just unroll the matrix into a vector
            %res = res';  % our matrix is made to have one acquisition session per row, but matlab unrolls per column, so we need to transpose
            %res = res(:)'; % transpose back to get a row vector
            res = reshape(res', [], 1)'; % flatten matrix into a vector by appending rows. One-liner equivalent to res = res'; res = res(:)';
        else
            % When using time offsets, we need to reorder the results in natural order (ie, 1 to nslices), with the time offset for respectively each slice id
            % Very useful for multiband EPI (SPM only supports time offsets for multiband EPI slice timing correction)
            [~, idx] = sort(slice_ids(:));
            res = res(:);
            res = res(idx)';
        end %endif
        % If number of slices is odd, we have to remove superfluous slice numbers outside of range
        if mod(nslices, 2) == 1
            if multi == 0
                res = res(res>=1 & res<=nslices);
            else
                fprintf('Unrolled odd number of slices is not implemented with multiband EPI yet.\n');
            end
        end
    end %endif
end %endif

end %endfunction