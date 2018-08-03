#!/usr/bin/python
import nipype.interfaces.mrtrix as mrt
tck2trk = mrt.MRTrix2TrackVis()
tck2trk.inputs.in_file = 'Allbrain.tck'
tck2trk.inputs.out_filename = 'Allbrain.trk'
tck2trk.inputs.image_file = 'dwicorr.nii'
tck2trk.run()    
quit()
