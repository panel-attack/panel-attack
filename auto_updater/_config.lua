updater_config = {
    auto_update= true,
    launch_check_interval= 6 * 3600, -- in seconds (default 6h) will check for updates at launch if interval has passed (it will always check for updates ingame in background)
    launch_check_timeout= 0.4, -- in seconds (default 400ms) time before aborting the check for updates request at launch, it will always take all the time needed ingame in background
    server_url= "http://panelattack.com/updates",
    force_version= "", -- ex: "panel-2019-11-17.love"
}