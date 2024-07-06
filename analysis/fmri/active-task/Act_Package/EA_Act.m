function EA_Act()
%%%%% HOW TO...
% In order to use this script you should have a "global folder" in which you have one subfolder per group, and inside one subfolder per subject/patient
% Inside each patient folder you MUST have a subfolder named 'data', inside you must have one or several subfolder for each session (named as you want), and inside you must have (otherwise the script won't run):
% 1) A folder named "mprage" in which you have JUST the structural files .nii or .img and .hdr (ex. s-12463236.img s-12234567.hdr). 
% your raw structural files must have an s as first letter. 
% 2) Other folders named by activation task (ex. Tennis Spatial Tennis2 )
% in which you have JUST the functional files .nii or .img and .hdr (ex f-12435467.img f-12453645.hdr) 
% Note that the script is agnostic to the type of scan there is, and also to the names of folders, so it does not care if you have a "rest" folder, it will process it as an active task!
%
% Basically, if you follow a BIDS-like structure, then you should be good
% to go! Something like this would be fine:
% group_controls/subject1/data/session_1/(mprage|tennis|navigation)/*.(nii|img)
% 
% The script will create, inside these activation folders, another subfolder in which you
% will have design matrix with classical preprocessing.
%
%% It's better to launch the auto_reorient script and checkreg [manually] the functional on the structural before launching this script.
%% If you want to double check or do again the analysis, it's better to make a copy of the global folder before launching, e reanalyze that 
%%(it's better don't put spam files in the folder structure aforementioned)

%%To Launch just type EA_Act in the Matlab command window. The program will
%%ask you to input the path of the global folder (then press Enter), the
%%number of first volumes to discard (then press Enter), the onset to
%%choose (then press Enter)
%%Enjoy!
%E.A. (Enrico Amico, original author)
%
% It is advised to skip_preproc and instead to use the smri or fmri pipelines to preprocess using CAT12 (in addition to auto and manual reorienting and coregistration) before running the current script.
%
% Updated on 2017-02-11 and in 2019-01-30 by Stephen Larroque (and on from this date on)
% Last update: 2024
% v0.3.0b1
% NO DISCARD!!!
%
% TODO:
% * migrate to SPM12 to support multiband (else only slice order, and NOT slice timing in seconds, can be specified)
%

clear all;
close all;
% clc;
%discard=3;
AllDir = 'G:\Topreproc\Cosmo2019Tasks\workingFiles_cosmo_task_fMRI\workingFiles'; % input('Type the path of the global folder: ', 's');
path_to_spm8 = 'C:\matlab_tools\spm8'; %TODO: can update to spm12 by just using OldSeg and OldNorm
Template = fullfile(path_to_spm8, 'canonical', 'single_subj_T1.nii'); % for the normalization step
normalize = 1; % normalize the subject's structural MRI before doing the fMRI active task analyses? Note: even if you skip_preproc, you should set this to 1 if you use normalized images, because this parameter changes the regex to find the volumes to include.
tr = 2.0;
slice_order = [1:2:42 2:2:42];
refslice = []; % set to empty to use first reference slice automatically
skip_preproc = 1; % to skip preprocessing if it is already done and you just want to re-run the statistical test - it is advised to skip_preproc and instead to use the smri or fmri pipelines to preprocess using CAT12 before running the current script.
hrfTimeDispersionDerivative = [1 1]; % enable time (peak time shift + or - 1s) or time + dispersion derivative (peak time shift and width also) by respectively setting [1 0] or [1 1]. To disable totally use [0 0].
% Prefix to find the preprocessed functional images (normalized or not)
fprefixnorm = 'swr'; % normalized (MNI template space)
fprefix = 'sr'; % non-normalized (subject space)

% --- Start of main script
fprintf(1, '\n=== ACTIVE TASK ANALYSIS SINGLE-CASE ===\n');
% Temporarily restore factory path and set path to SPM and its toolboxes, this avoids conflicts when having different versions of SPM installed on the same machine
bakpath = path; % backup the current path variable
restoredefaultpath(); matlabpath(strrep(matlabpath, userpath, '')); % clean up the path
addpath(path_to_spm8); % add the path to SPM8

%prompt = ('\n Number of first functional volumes to discard : \n'); 
%discard = input(prompt);
prompt2 = ('Which onset do you want? Type 1 for MiracleCase, 2 for Actigait Onset: \n');  %%% Miracle Case: 165 volumes
FlagOnset = input(prompt2);
% For each group
AllGroups = dir(AllDir);
for h=3:length(AllGroups)
    % For each subject
    AllSubjects = dir(fullfile(AllDir, AllGroups(h).name));
    % clear up first two folders found, because they are "." and ".." which are
    % special folders to go to parent or to current folder
    AllSubjects(1).name=[];
    AllSubjects(2).name=[];

    spm_jobman('initcfg'); % init the jobman
    for i=3:length(AllSubjects)
        % for each session
        AllSessions = dir(fullfile(AllDir, AllGroups(h).name, AllSubjects(i).name, 'data'));
        for j=3:length(AllSessions)
            Tmp_folder=fullfile(AllDir, AllGroups(h).name, AllSubjects(i).name, 'data', AllSessions(j).name);
            if(isdir(Tmp_folder)==1)
                % for each task
                count=1;
                fprintf('Processing group %s subject %s sessions %s \n', AllGroups(h).name, AllSubjects(i).name, AllSessions(j).name);
                Subfolders= dir(Tmp_folder);
                Subfolders(1).name=[];
                Subfolders(2).name=[];
                for k=3:length(Subfolders)
                    Tmp=fullfile(AllDir, AllGroups(h).name, AllSubjects(i).name, 'data', AllSessions(j).name, Subfolders(k).name);
                    % find the structural
                    if(strfind(Subfolders(k).name,'mprage')==1)
                        structDir=Tmp;
                    % find all functional task folders
                    elseif(isdir(Tmp))
                        FunDir{count}=  Tmp;
                        count=count+1;
                    end %endif
                end %endfor

                % Select structural image
                S = spm_select('FPList',structDir, '^.*\.(img|nii)$');
                % S = spm_select('FPList',structDir, '^s.*\.nii$');
                S= cellstr(S);

                for act=1:length(FunDir)
                    [pathstr, name_act, ext] = fileparts(FunDir{act});
                    fprintf('Processing activation %s \n',name_act );
                    F = spm_select('FPList',FunDir{act}, '^.*\.(img|nii)$'); %%%here you can change the filter
                    %F(1:discard,:)=[];
                    F= cellstr(F);

                    %Art_Dir=[FunDir{act} '\Art_Repair'];

                    %                F_Images = spm_select('FPList',FunDir{act}, '^f.*');
                    %                F_Images(1:(discard*2),:)=[];
                    %                F_Images= cellstr(F_Images);
                    %               

                    % Select functional images
                    funDir = FunDir{act};
                    if normalize
                        if ~skip_preproc
                            enrico_classical_preprocess_norm(F, S, path_to_spm8, tr, slice_order, refslice);
                        end
                        SR = spm_select('FPList',funDir,  '^' fprefixnorm '.*\.(img|nii)$'); %%%% this is for normalized images
                    else
                        if ~skip_preproc
                            enrico_classical_preprocess(F, S, path_to_spm8, tr, slice_order, refslice);
                        end
                        SR = spm_select('FPList',funDir,  '^' fprefix '.*\.(img|nii)$');
                    end % endif

                    clear matlabbatch;

                    %                F_Images = spm_select('FPList', Art_Dir, '^f.*\.(img|nii)$');
                     %F_Images(1:discard,:)=[];
                     %R_Images = spm_select('FPList', Art_Dir, '^r.*\.(img|nii)$');

                    if (FlagOnset==1)
                        %Onset = [(15-discard):30:(length(F)-30)]; 
                        Onset = [15 45 75 105 135];
                        %Audrey's [12 42 72 102 132]
                    elseif(FlagOnset==2)
                        Onset = [5 21 37 53 85]; %%% Paradigma Actigait
                    end % endif
                    funDir = FunDir{act};
                    %funDir = funDir{1};
                    activation_name=name_act;
                    enrico_classical_stat;
                    %clearvars -except count discard AllDir AllSubjects FunDir SubFolders;
                    clear matlabbatch;
                    close all;
                end %enfor
                clear FunDir;
            end %endif
        end %endfor
    end %endfor
end %endfor

% == All done!
fprintf(1, 'All jobs done! Restoring path and exiting... \n');
path(bakpath); % restore the path to the previous state

end % end script


%%%%Extra code
% art_motionregress( dirPath, '^sr.*\.img$', dirPath, ['^' strPref '.*\.(img|nii)$'])
% mdataImages = spm_select('FPList', dirPath, '^ms.*\.(img|nii)$');
% rdataImages = spm_select('FPList', dirPath, '^r.*\.txt$');
% art_global(mdataImages,rdataImages,4,1);
% vdataImages = spm_select('FPList', dirPath, '^v.*\.(img|nii)$');
% art_despike(vdataImages,1,4)

%                copyfile([FunDir{act} '\rf*'],Art_Dir);
%                copyfile([FunDir{act} '\rp*'],Art_Dir);
%                 for cp=1:length(F_Images)
%                copyfile(F_Images{cp},Art_Dir);
%                end


%  F_Images = '^f.*\.(img|nii)$'; 
%                  R_Images = '^r.*\.(img|nii)$';
%                art_motionregress( Art_Dir,R_Images, Art_Dir,  F_Images);
%                
%                mdataImages = spm_select('FPList', Art_Dir, '^mrf.*\.(img|nii)$');
%                rdataImages = spm_select('FPList', Art_Dir, '^rp.*\.txt$');
%                art_global(mdataImages,rdataImages,4,1);


%                V = spm_select('FPList', Art_Dir, '^v.*\.(img|nii)$');
%                V = cellstr(V);
%                enrico_artrep_preprocess;
%                clear matlabbatch
%                SV=spm_select('FPList', Art_Dir, '^sv.*\.(img|nii)$');
%                SV = cellstr(SV);
%                enrico_artrep_stat;
