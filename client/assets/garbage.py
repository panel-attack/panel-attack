#   Given an image "garbage.png" that is three thickness high, splits
#   it into individual pieces
#   A placeholder face2 and double face is made even though it won't be right
#
#   The ideal generation image is 576 x 288 for 2x resolution.

from PIL import Image
img = Image.open("garbage.png")
w,h = img.size
print("Width: ", w)
print("Height: ", h)
panelSizeConst = 48
scale = h * 1.0 / (panelSizeConst * 3)
print("Scale: ", scale)
cornerWidth = 24 * scale
cornerHeight = 9 * scale
topBottomHeight = 6 * scale
leftRightWidth = 24 * scale
panelSize = panelSizeConst * scale
halfPanel = panelSize / 2
centerX = w / 2
centerY = h / 2

# crop takes, left, top, right, bottom params
img.crop((0,0,cornerWidth,cornerHeight)).save("topleft.png")
img.crop((w-cornerWidth,0,w,cornerHeight)).save("topright.png")
img.crop((0,h-cornerHeight,cornerWidth,h)).save("botleft.png")
img.crop((w-cornerWidth,h-cornerHeight,w,h)).save("botright.png")
img.crop((0,cornerHeight,leftRightWidth,h-cornerHeight)).save("left.png")
img.crop((w-leftRightWidth,cornerHeight,w,h-cornerHeight)).save("right.png")
img.crop((cornerWidth,0,w-cornerWidth,topBottomHeight)).save("top.png")
img.crop((cornerWidth,h-topBottomHeight,w-cornerWidth,h)).save("bot.png")
img.crop((cornerWidth,centerY-halfPanel,cornerWidth+panelSize,centerY+halfPanel)).save("filler1.png")
img.crop((cornerWidth+panelSize,centerY-halfPanel,cornerWidth+(2*panelSize),centerY+halfPanel)).save("filler2.png")
img.crop((centerX-halfPanel,centerY-halfPanel,centerX+halfPanel,centerY+halfPanel)).save("face.png")
img.crop((centerX-halfPanel,centerY-halfPanel,centerX+halfPanel,centerY+halfPanel)).save("face2.png")
img.crop((centerX-halfPanel,centerY-panelSize,centerX+halfPanel,centerY+panelSize)).save("doubleface.png")
