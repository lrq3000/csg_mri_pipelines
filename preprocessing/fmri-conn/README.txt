These are preprocessing pipelines for the CONN 18b toolbox, by the Coma Science Group - GIGA-Consciousness, University of Liège, Belgium.

It is advised to use either the unwarp or noreslice pipelines, but disadvised to use the reslice pipeline as it gives quite different results (and particularly diminished anti-correlations). Furthermore, for a maximal similarity to our custom SPM pipeline, when running the pipeline, the option "rtm" aka "realignment to mean image" should be selected during the realignment step. These pipelines are not totally equivalent to the script one (because CONN management of files is different, and particularly the functional is realigned/coregistered by reference to the first scan instead of mean image as in our script pipeline), but the results are close.

Experimental pipelines using "Masked smoothing", which is to apply a gaussian smoothing only to the grey matter in order to avoid noise spillage from white matter and CSF, are also available.

To use these pipelines, copy them in your CONN folder inside: conn\utils\preprocessingpipelines\

Author: Stephen Karl Larroque, 2018-2019
