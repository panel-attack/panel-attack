local logger = require("logger")

local function migrateIfPossible()
  local os = love.system.getOS()
  local loveMajorVer = love.getVersion()
  if love.filesystem.isFused() and loveMajorVer == 12 and
    (os == "Linux" or os == "OS X") and
    not love.filesystem.exists("conf.json") then

    -- this means this is the first startup on a fused build (meaning the new native updater on mac/linux)
    -- we check if there is content in what would be the save directory in unfused mode
    local path = love.filesystem.getAppdataDirectory()
    if os == "Linux" then
      path = path .. "love/"
    elseif os == "OS X" then
      path = path .. "LOVE/"
    end
    path = path .. love.filesystem.getIdentity()
    logger.debug("Trying to mount old install under " .. path)

    if not love.filesystem.mountFullPath(path, "oldInstall") then
      -- if we couldn't mound that directory, that means there is no old install
      logger.debug("No old install found")
    else
      -- and if there is content copy over the directory to the new save directory

      -- it would obstruct the copy info
      love.setDeprecationOutput(false)
      local migrationThread = love.thread.newThread("migrationThread.lua")
      migrationThread:start("oldInstall", "")
      local msg = "Starting migration"
      while migrationThread:isRunning() do
        GAME:drawLoadingString("Migrating data from\n" .. path .. "\nto\n" .. love.filesystem.getSaveDirectory() .. "\nThis might take a while")
        msg = love.thread.getChannel("migration"):pop() or msg
        gprintf(msg, 0, canvas_height - 90, canvas_width, "center")
        coroutine.yield()
      end
      local timer = love.timer.getTime()
      while love.timer.getTime() < timer + 5 do
        GAME:drawLoadingString("Finished migrating data from\n" .. path .. "\nto\n" .. love.filesystem.getSaveDirectory())
        coroutine.yield()
      end

      love.filesystem.unmountFullPath(path)
      -- since we likely copied a conf.json with the migration, rerun everything related to conf setup
      readConfigFile(config)
      love.window.setMode(config.windowWidth, config.windowHeight,
        {
          x = config.windowX,
          y = config.windowY,
          fullscreen = config.fullscreen,
          borderless = config.borderless,
          displayindex = config.display
        })
      love.load()
    end
  end
end

return migrateIfPossible