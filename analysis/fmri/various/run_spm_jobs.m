function run_spm_jobs(matlabbatchall, parallel_processing, matlabbatchall_infos, pathtoset)
% run_spm_jobs(matlabbatchall, parallel_processing, matlabbatchall_infos)
% run in SPM a cell array of batch jobs, sequentially or in parallel
% matlabbatchall_infos is optional, it is a cell array of strings
% containing additional info to print for each job
% pathtoset is optional and allows to provide a path to set inside the
% parfor loop before running the jobs
    if exist('matlabbatchall_infos','var') % check if variable was provided, for parfor transparency we need to check existence before
        minfos_flag = true;
    else
        minfos_flag = false;
    end

    if parallel_processing
        fprintf(1, 'PARALLEL PROCESSING MODE\n');
        if exist('pathtoset', 'var') % not transparent, can't check variable existence in parfor loop
            pathtoset_flag = true;
        else
            pathtoset_flag = false;
        end
        parfor jobcounter = 1:numel(matlabbatchall)
        %parfor jobcounter = 1:1 % test on 1 job
            if minfos_flag
                fprintf(1, '\n---- PROCESSING JOB %i/%i FOR %s ----\n', jobcounter, numel(matlabbatchall), matlabbatchall_infos{jobcounter});
            else
                fprintf(1, '\n---- PROCESSING JOB %i/%i ----\n', jobcounter, numel(matlabbatchall));
            end
            % Set the path if provided, since in the parfor loop the
            % default path is restored. No need to backup because no need
            % to restore at the end of the thread, it will be destroyed
            if pathtoset_flag
                path(pathtoset)
            end
            % Init the SPM jobman inside the parfor loop
            spm_jobman('initcfg');
            % Load the batch for this iteration
            matlabbatch = matlabbatchall{jobcounter};
            % Run the preprocessing pipeline for current subject!
            spm_jobman('run', matlabbatch)
            %spm_jobman('serial',artbatchall{matlabbatchall_counter}); %serial and remove spm defaults
            % Close all windows
            fclose all;
            close all;
        end
    else
        fprintf(1, 'SEQUENTIAL PROCESSING MODE\n');
        % Set the path if provided
        if exist('pathtoset', 'var')
            bakpath = path; % backup the current path variable
            restoredefaultpath(); matlabpath(strrep(matlabpath, userpath, '')); % clean up the path
            path(pathtoset);
        end
        % Initialize the SPM jobman
        spm_jobman('initcfg');
        % Run the jobs sequentially
        for jobcounter = 1:numel(matlabbatchall)
        %for jobcounter = 1:1 % test on 1 job
            if minfos_flag
                fprintf(1, '\n---- PROCESSING JOB %i/%i FOR %s ----\n', jobcounter, numel(matlabbatchall), matlabbatchall_infos{jobcounter});
            else
                fprintf(1, '\n---- PROCESSING JOB %i/%i ----\n', jobcounter, numel(matlabbatchall));
            end
            matlabbatch = matlabbatchall{jobcounter};
            % Run the preprocessing pipeline for current subject!
            spm_jobman('run', matlabbatch)
            %spm_jobman('serial',artbatchall{matlabbatchall_counter}); %serial and remove spm defaults
            % Close all windows
            fclose all;
            close all;
        end
        % Restore the path
        path(bakpath);
    end
end %endfunction
