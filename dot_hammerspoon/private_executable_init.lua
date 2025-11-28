-- Load the KanataLayerSwitcher Spoon
hs.loadSpoon("KanataLayerSwitcher")

-- Start the KanataLayerSwitcher
spoon.KanataLayerSwitcher:start()

-- Keep Hammerspoon alive
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "R", function()
    hs.reload()
    hs.alert.show("Config reloaded")
end)
hs.loadSpoon('EmmyLua')
