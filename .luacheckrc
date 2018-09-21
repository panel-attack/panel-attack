--
-- Globals:
--
globals = {
    -- Used by Hammerspoon:
    "hs", "rawrequire", "ls", "spoon",
    -- Used by Hammerspoon Tests:
    "success", "assertIsEqual",
}

--
-- Warnings to ignore:
--
ignore = {
    "631", -- Line is too long.
    "111", -- setting non-standard global variable
    "112", -- setting non-standard global variable
    "113", -- accessing undefined variable
    "211", -- accessing undefined variable
    "213" -- accessing undefined variable
}
