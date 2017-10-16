function res=gen_slice_order(nslices, hstep, vstep, slice_order, reverse, unroll, multi, tr, slice_ids)
% res=gen_slice_order(nslices, hstep, vstep, slice_order, reversed, unroll, tr, multi)
% Compute a 2D slice order scheme based on given parameters
% slice_order can either be 'asc' or 'desc'.
% reverse=1 will reverse the row order (eg, instead of ascending 1, 3, ... 2, 4, ... we will get 2, 4, ... 1, 3, ...). You can also specify a vector with the original index of rows, eg: [2 1] to reverse, or more if you have more lines. This is useful for specific machines such as 3T MAGNETOM Prisma fit System which uses slice order ascending interleaved reversed when acquiring an even number of slices, and ascending interleaved (non-reversed) when acquiring an odd number.
% unroll=1 will unroll the whole matrix into one vector as expected by SPM.
% multi > 0 enables multiband EPI. multi can be either 1 for rows or 2 for columns. This will return time points in seconds instead of slice number without multiband.
% tr (in seconds) > 0 will return slice time offsets (in ms, as expected by spm) instead of slice number.
% slice_ids is optional, you can provide your own custom slice indices with this argument, very useful for multiband with non linear schemes (if this exists?).
% by Stephen Larroque from the Coma Science Group, 2017
% Licensed under MIT.
%
% v1.1
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
if reverse ~= 0
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
    res = (res-1) .* (tr.*1000/max(max(res)));
end

% Unroll if necessary into one horizontal vector (as required by SPM)
if unroll
    if tr <= 0
        % Slice indices, we can just unroll the matrix into a vector
        res = res';  % our matrix is made to have one acquisition session per row, but matlab unrolls per column, so we need to transpose
        res = res(:)'; % transpose back to get a row vector
    else
        % When using time offsets, we need to reorder the results in natural order (ie, 1 to nslices), with the time offset for respectively each slice id
        % Very useful for multiband EPI (SPM only supports time offsets for multiband EPI slice timing correction)
        [vals, idx] = sort(slice_ids(:));
        res = res(:);
        res = res(idx)';
    end %endif
    % If number of slices is odd, we have to remove superfluous slice numbers outside of range
    if mod(nslices, 2) == 1
        if multi == 0
            res = res(res>=1 & res<=nslices)
        else
            fprintf('Unrolled odd number of slices is not implemented with multiband EPI yet.\n')
        end
    end
end %endif

end %endfunction