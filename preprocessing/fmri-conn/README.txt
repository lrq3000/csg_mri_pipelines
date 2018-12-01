These are preprocessing pipelines for the CONN 18a toolbox, by the Coma Science Group - GIGA-Consciousness, University of Liège, Belgium.

It is advised to use either the unwarp or noreslice pipelines, but disadvised to use the reslice pipeline as it gives quite different results (and particularly diminished anti-correlations). These pipelines are not totally equivalent to the script one (because CONN management of files is different, and particularly the functional is realigned/coregistered by reference to the first scan instead of mean image as in our script pipeline), but the results are close.

To use these pipelines, copy them in your CONN folder inside: conn18a\utils\preprocessingpipelines\
