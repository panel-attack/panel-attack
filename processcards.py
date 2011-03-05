from PIL import Image
import _imaging
def go(cropped):
    cropped = cropped.convert("RGBA")
    datas = cropped.getdata()
    newData = []
    for item in datas:
        if item[0] == 255 and item[1] == 0 and item[2] == 255:
            newData.append((255, 255, 255, 0))
        else:
            newData.append(item)
    cropped.putdata(newData)
    return cropped

img = Image.open("combocards.bmp")
for x in xrange(4,67):
    cropped = go(img.crop((16*x, 0, 16*x+16, 16)))
    cropped.save("combo%s%s.png"%(x/10,x%10))

img = Image.open("ChainCards.bmp")
for x in xrange(20):
    cropped = go(img.crop((16*x, 0, 16*x+16, 16)))
    cropped.save("chain%s%s.png"%(x/10,x%10))

