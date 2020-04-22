local Config = require('opus.config')
local Util   = require('opus.util')

local fs         = _G.fs
local kernel     = _G.kernel
local multishell = _ENV.multishell
local window     = _G.window

if not multishell then
    return
end

local config = Config.load('saver', {
	enabled = false,
    timeout = 60,
    random = true,
    specific = nil,
})

local BASE   = '/packages/screenSaver'
local SAVERS = fs.combine(BASE, 'savers')

local timer = config.enabled and os.startTimer(config.timeout)
local saverUid

local function showScreenSaver()
    timer = nil

    local files = fs.list(SAVERS)
    local saver = config.specific or fs.combine(SAVERS, files[math.random(1, #files)])

    local w, h = kernel.terminal.getSize()
    local win = window.create(kernel.terminal, 1, 1, w, h, true)
    saverUid = multishell.openTab({
        path = saver,
        focused = true,
        title = 'Saver',
        window = win,
    })
end

kernel.hook({ 'mouse_up', 'mouse_drag', 'key_up', 'mouse_scroll' }, function()
    if config.enabled then
        if timer then
            os.cancelTimer(timer)
            timer = os.startTimer(config.timeout)
        elseif saverUid then
            multishell.terminate(saverUid)
            saverUid = nil
            timer = os.startTimer(config.timeout)
        end
    end
end)

kernel.hook('timer', function(_, eventData)
    if timer and eventData[1] == timer then
        showScreenSaver()
    end
end)

kernel.hook('config_update', function(_, eventData)
    if eventData[1] == 'saver' then
        Util.merge(config, eventData[2])
        if timer then
            os.cancelTimer(timer)
            timer = nil
        end
        if config.enabled then
            timer = os.startTimer(config.timeout)
        end
    end
end)
