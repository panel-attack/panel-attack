local normal = Animation(20, 40, 80, 120)
normal.createAnimation(
[[
    addFrame(1, 33)
    addFrame(2, 1)
    addFrame(3, 2)
    addFrame(2, 1)
    addFrame(1, 2)
    addFrame(2, 1)
    addFrame(3, 2)
    addFrame(2, 1)
    addFrame(1, 13)
    addFrame(2, 1)
    addFrame(3, 2)
    addFrame(2, 1)
    setLoopEnd()
]]
)

return {
    normal = normal
}
