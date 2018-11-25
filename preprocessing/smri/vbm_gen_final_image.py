# coding: utf-8
# VBM final image generator, by Stephen Karl Larroque, 2017-2018
# v0.1.7

from __future__ import division
import os, sys
from PIL import Image, ImageChops, ImageEnhance

def trim(im):
    '''Trim borders of a picture automatically'''
    bg = Image.new(im.mode, im.size, im.getpixel((0,0)))
    diff = ImageChops.difference(im, bg)
    diff = ImageChops.add(diff, diff, 1.0, -100)
    bbox = diff.getbbox()
    if bbox:
        return im.crop(bbox)

def resize_height(img, baseheight):
    '''Resize by height and keep width ratio'''
    baseheight = int(baseheight)
    hpercent = (baseheight/float(img.size[1]))
    wsize = int((float(img.size[0])*float(hpercent)))
    return img.resize((wsize, baseheight), Image.ANTIALIAS)

def resize_width(img, basewidth):
    '''Resize by width and keep height ratio'''
    basewidth = int(basewidth)
    wpercent = (basewidth/float(img.size[0]))
    hsize = int((float(img.size[1])*float(wpercent)))
    return img.resize((basewidth, hsize), Image.ANTIALIAS)


# Configuration parameters (edit me)
im_width = im_height = 1000  # Final image height and width
brightness = 2.0  # how much to raise brightness of the bottom images
contrast = 1.5

# Get arguments
if len(sys.argv) < 0:
    raise ValueError('Not enough arguments supplied: need to specify 2 arguments: the rootpath of the images and the images prefix')
impath = sys.argv[1]
imprefix = sys.argv[2]

# Loading images
im1 = Image.open(os.path.join(impath, imprefix+"1.png"))
im2 = Image.open(os.path.join(impath, imprefix+"2.png"))
im3 = Image.open(os.path.join(impath, imprefix+"3.png"))
im4 = Image.open(os.path.join(impath, imprefix+"4.png"))

# == Image 1: brain section with VBM damages correlations
im1_crop = im1.crop((0, int(im1.size[1]/2), im1.size[0], im1.size[1]))
im1_trimmed = trim(im1_crop)

# == Image 2: brain rendering spm96 old in 3D sections
im2_crop = im2.crop((0, int(im2.size[1]/2), im2.size[0], im2.size[1]))
# Separate the 2 columns
im2_col1 = im2_crop.crop((im2_crop.size[0]/8, 0, (im2_crop.size[0]/8) * 3, im2_crop.size[1]))
im2_col2 = im2_crop.crop((im2_crop.size[0]/8 * 5, 0, (im2_crop.size[0]/8) * 7, im2_crop.size[1]))
# Join them (they should be tighter now)
im2_new = Image.new('RGB', (im2_col1.size[0] + im2_col2.size[0], max(im2_col1.size[1], im2_col2.size[1])))
im2_new.paste(im2_col1, (0, 0))
im2_new.paste(im2_col2, (im2_col1.size[0], 0))

# == Images 3 and 4: patient's unnormalized T1 and age-sex-matched control
im3_crop = im3.crop((0, 0, im3.size[0], int(im3.size[1]/5*2.7)))
im3_trimmed = trim(im3_crop)
im4_crop = im4.crop((0, 0, im4.size[0], int(im4.size[1]/5*2.8)))
im4_trimmed = trim(im4_crop)
# Raise brightness
im3_enhancer_b = ImageEnhance.Brightness(im3_trimmed)
im4_enhancer_b = ImageEnhance.Brightness(im4_trimmed)
im3_trimmed = im3_enhancer_b.enhance(brightness)
im4_trimmed = im4_enhancer_b.enhance(brightness)
# Raise contrast
im3_enhancer_c = ImageEnhance.Contrast(im3_trimmed)
im4_enhancer_c = ImageEnhance.Contrast(im4_trimmed)
im3_trimmed = im3_enhancer_c.enhance(contrast)
im4_trimmed = im4_enhancer_c.enhance(contrast)

# == Final image generation

# Resize top images by height and bottom images by width
im_parts_top = [resize_height(img, im_height/2) for img in (im1_trimmed, im2_new)]
im_parts_bottom = [resize_width(img, (im_width/2)*0.9) for img in (im3_trimmed, im4_trimmed)]

# Create final image and stitch image parts together (one in each corner)
im_full = Image.new('RGB', size=(im_width, im_height), color=(0,0,0,0))
im_full.paste(im_parts_top[0], (0,0))
im_full.paste(im_parts_top[1], (im_width-im_parts_top[1].size[0],0))
im_full.paste(im_parts_bottom[0], (10,int((im_height/2)*1.1)))
im_full.paste(im_parts_bottom[1], (im_width-im_parts_bottom[1].size[0]-10,int((im_height/2)*1.1)))
# Last trim
im_full = trim(im_full)

# And save!
im_full.save(os.path.join(impath, imprefix+"final.png"))

sys.exit(0)
