local CarouselPassenger = class(function(self, id, image, text)
  self.id = id
  if image then
    self.image = image
  else
    self.image = themes[config.theme].images.IMG_random_stage
  end
  self.text = text
  assert(id and text, "A carousel passenger needs to have an id, an image and a text!")
end)

return CarouselPassenger

