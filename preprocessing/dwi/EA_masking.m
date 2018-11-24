function EA_masking(Mask,Im,New_Im)
%%% Mask the Image using Mask (all non zero voxel outside will be put to zero)
%% Mask and Im should have the same size
I=spm_vol(Im);
M=spm_vol(Mask);
Maskmat=spm_read_vols(M);
MaskIm=spm_read_vols(I);
MaskIm=MaskIm(:);
Maskmat=Maskmat(:);
tmp=MaskIm;
for i=1:length(MaskIm)
    if(Maskmat(i)==0 && MaskIm(i)~=0)
        tmp(i)=0;    
    end
end

I.fname = New_Im;
I.dt=[16,0];
tmp = reshape(tmp,I.dim);
spm_write_vol(I,tmp);

return;
