# coding: utf-8
# DTI final image generator, by Stephen Larroque
# v0.1.4
#
# Usage: you need to use Trackvis to save screenshots of each view (front.png, left.png, right.png and top.png), and then place this script and the dependencies in the same folder as these images, and call it. You will then just need to input the patient's name, and the final image will be generated.
#

from __future__ import division
from PIL import Image, ImageChops, ImageDraw, ImageFont

def trim(im):
    bg = Image.new(im.mode, im.size, im.getpixel((0,0)))
    diff = ImageChops.difference(im, bg)
    diff = ImageChops.add(diff, diff, 2.0, -100)
    bbox = diff.getbbox()
    if bbox:
        return im.crop(bbox)

def resize_height(img, baseheight):
    baseheight = int(baseheight)
    hpercent = (baseheight/float(img.size[1]))
    wsize = int((float(img.size[0])*float(hpercent)))
    return img.resize((wsize, baseheight), Image.ANTIALIAS)

def resize_width(img, basewidth):
    basewidth = int(basewidth)
    wpercent = (basewidth/float(img.size[0]))
    hsize = int((float(img.size[1])*float(wpercent)))
    return img.resize((basewidth, hsize), Image.ANTIALIAS)

def paste_align(im, paste, posx, posy, align='center'):
    if align == 'left':
        return im.paste(paste, (posx,posy))
    elif align == 'right':
        return im.paste(paste, (posx-int(paste.size[0]),posy))
    else:
        return im.paste(paste, (posx-int(paste.size[0]/2),posy))

controlsheight = 375  # controls images height (to resize patient images to the same size)
center_pos = 1300
patient_name = raw_input("Please enter patient's name: ")

# Loading images
im_front = Image.open("front.png")
im_left = Image.open("left.png")
im_right = Image.open("right.png")
im_top = Image.open("top.png")
im_dti_template = Image.open("dti-template-blank.png")

# Preprocessing all images parts
im_parts = []
for img in (im_front, im_left, im_right, im_top):
    # Hide rotation cube in bottom right corner
    draw = ImageDraw.Draw(img)
    draw.rectangle((img.size[0]*0.9, img.size[1]*0.9, img.size[0], img.size[1]), fill='black')
    # Trim black borders and resize to the height of control's images
    im_parts.append(resize_height(trim(img), controlsheight))

# == Final image generation

# Place all image parts of patient into the right position (below corresponding control's image)
paste_align(im_dti_template, im_parts[0], 305, 840, 'center')
paste_align(im_dti_template, im_parts[1], 954, 840, 'center')
paste_align(im_dti_template, im_parts[2], 1620, 840, 'center')
paste_align(im_dti_template, im_parts[3], 2334, 840, 'center')

# Draw text for control and patient name
d = ImageDraw.Draw(im_dti_template)
fnt = ImageFont.truetype('arialbold.ttf', 64)
# Write control
tw, th = d.textsize('CONTROL'.upper(), font=fnt)  # calculate text size to center position
d.text((int(center_pos - tw/2),66), 'CONTROL'.upper(), font=fnt, fill=(255, 255, 255, 255))
# Write patient name
tw, th = d.textsize(patient_name.upper(), font=fnt)  # calculate text size to center position
d.text((int(center_pos - tw/2),705), patient_name.upper(), font=fnt, fill=(255, 255, 255, 255))

# Save!
im_dti_template.save('dti-%s.png' % patient_name)
