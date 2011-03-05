from PIL import Image
import _imaging
for imgn in xrange(1,9):
    img = Image.open("panel0%s.bmp"%imgn)
    for frame in xrange(7):
        cropped = img.crop((16*frame, 0, 16*frame+16, 16))
        cropped.save("panel%s%s.png"%(imgn, frame+1))
