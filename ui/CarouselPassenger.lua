local CarouselPassenger = class(function(self, id, image, text)
  self.id = id
  self.image = image
  self.text = text
  assert(id and image and text, "A carousel passenger needs to have an id, an image and a text!")
end)

return CarouselPassenger

