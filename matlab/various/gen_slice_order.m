function res=gen_slice_order(nslices, hstep, vstep, slice_order, unroll)
% Compute a 2D slice order scheme based on given parameters
% slice order can either be 'asc' or 'desc'.
% by Stephen Larroque from the Coma Science Group, 2017
% licensed under MIT.

if ~exist('unroll', 'var')
    unroll = false;
end

% Compute horizontal vector
if strcmpi(slice_order, 'asc')
    hvec = [1:hstep:nslices];
else
    hvec = [nslices:-hstep:1];  % could also use fliplr()...
end %endif

% Optimization using pre-allocation, but way less flexible and reliable...
%vvec = zeros(1, hstep);
%stepratio = hstep/vstep;
%for v=1:vstep
    %if v < vstep
    %    endpos = v*round(stepratio);
    %else
    %    endpos = v*stepratio;
    %end
    %vvec(1, round(1+((v-1)*stepratio)):endpos) = v:vstep:hstep;
%end

% Compute vertical vector
vvec = [];
for v=1:vstep
    vvec = [vvec v:vstep:hstep];
end

% Mix them both to get a matrix
if strcmpi(slice_order, 'asc')
    res =  bsxfun(@plus, repmat(hvec, hstep, 1), (vvec'-1));
else
    res =  bsxfun(@minus, repmat(hvec, hstep, 1), (vvec'-1));
end %endif

% Unroll if necessary into one horizontal vector (as required by SPM)
if unroll
    res = res';
    res = res(:)';
end

end %endfunction