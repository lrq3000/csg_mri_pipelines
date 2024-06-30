% Helper functions for CONN 2nd-level covariates calculation

% standardize/z-transform a vector
conncentervec = @(a) (a - mean(a)) / std(a);
% standardize matrix
conncentermat = @(a) bsxfun(@rdivide, bsxfun(@minus, a, mean(a,1)), std(a, 0, 1));
% standardize vector but skipping 0/nan values meant to say missing value
conncentervecnull = @(a) (a(a>0 & a~=NaN) - mean(a(a>0 & a~=NaN))) / std(a(a>0 & a~=NaN));
% standardize vector, skipping 0/nan values and not mean centering
conncentervecnullnomean = @(a) (a(a>0 & a~=NaN) / std(a>0 & a~=NaN));
