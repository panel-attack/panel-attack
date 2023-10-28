spectators_string = ""

-- quits the game
function exit_game(...)
  love.event.quit()
end

-- quit handling
function love.quit()
  if PROFILING_ENABLED then
    GAME.profiler.report("profiler.log")
  end
  if network_connected() then
    json_send({logout = true})
  end
  love.audio.stop()
  if love.window.getFullscreen() then
    _, _, config.display = love.window.getPosition()
  else
    config.windowX, config.windowY, config.display = love.window.getPosition()
    config.windowX = math.max(config.windowX, 0)
    config.windowY = math.max(config.windowY, 30) --don't let 'y' be zero, or the title bar will not be visible on next launch.
  end

  config.windowWidth, config.windowHeight, _ = love.window.getMode( )
  config.maximizeOnStartup = love.window.isMaximized()
  config.fullscreen = love.window.getFullscreen()
  write_conf_file()
end
