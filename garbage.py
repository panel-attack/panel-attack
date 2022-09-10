#   Given an image "garbage.png" that is three thickness high, splits
#   it into individual pieces
#
#   The ideal generation image is 576 x 288 for 2x resolution.

from PIL import Image
img = Image.open("garbage.png")
w,h = img.size
scale = h / (48 * 2)
cornerWidth = 24 * scale
cornerHeight = 9 * scale
topBottomHeight = 6 * scale
leftRightWidth = 24 * scale
panelSize = 48 * scale

img.crop((0,0,cornerWidth,cornerHeight)).save("topleft.png")
img.crop((w-cornerWidth,0,cornerWidth,cornerHeight)).save("topright.png")
img.crop((0,h-cornerHeight,cornerWidth,cornerHeight)).save("botleft.png")
img.crop((w-cornerWidth,h-cornerHeight,cornerWidth,cornerHeight)).save("botright.png")
img.crop((0,topBottomHeight,leftRightWidth,h-(topBottomHeight*2))).save("left.png")
img.crop((w-leftRightWidth,topBottomHeight,leftRightWidth,h-(topBottomHeight*2))).save("right.png")
img.crop((cornerWidth,0,1,topBottomHeight)).save("top.png")
img.crop((cornerWidth,h-topBottomHeight,1,topBottomHeight)).save("bot.png")
img.crop((panelSize/2,topBottomHeight+panelSize,panelSize,panelSize)).save("filler1.png")
img.crop((panelSize/2,topBottomHeight,panelSize,panelSize)).save("filler2.png")
img.crop(((w/2)-(panelSize/2),0,panelSize,2*panelSize)).save("doubleface.png")
img.crop(((w/2)-(panelSize/2),panelSize/2,panelSize,panelSize)).save("face.png")
img.crop(((w/2)-(panelSize/2),panelSize/2,panelSize,panelSize)).save("face2.png")
