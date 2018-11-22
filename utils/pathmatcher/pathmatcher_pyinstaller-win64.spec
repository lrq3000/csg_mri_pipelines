# -*- mode: python -*-

block_cipher = None

import os, sys
cur_path = os.path.realpath('.')
sys.path.append(os.path.join(cur_path))  # for gooey spec file, because it does not support relative paths (yet?)

import gooey
gooey_root = os.path.dirname(gooey.__file__)
gooey_languages = Tree(os.path.join(gooey_root, 'languages'), prefix = 'gooey/languages')
gooey_images = Tree(os.path.join(gooey_root, 'images'), prefix = 'gooey/images')

a = Analysis([os.path.join('pathmatcher.py')],
             pathex=[os.path.join(cur_path)],
             binaries=[],
             datas=[],
             hiddenimports=[os.path.join(cur_path, 'gooey'), os.path.join(cur_path, 'tqdm')],
             hookspath=[],
             runtime_hooks=[],
             excludes=['pandas', 'numpy', 'matplotlib', 'mpl-data', 'zmq', 'IPython', 'ipykernel', 'tcl', 'Tkinter', 'jupyter_client', 'ipywidgets', 'unittest', 'ipython', 'ipython_genutils', 'jupyter_core'],
             win_no_prefer_redirects=False,
             win_private_assemblies=False,
             cipher=block_cipher)
pyz = PYZ(a.pure, a.zipped_data,
             cipher=block_cipher)
exe = EXE(pyz,
          a.scripts,
          a.binaries,
          a.zipfiles,
          a.datas,
          gooey_languages, # Add them in to collected files
          gooey_images, # Same here.
          name='pathmatcher',
          debug=False,
          strip=False,
          upx=True,
          windowed=True,
          console=True )
