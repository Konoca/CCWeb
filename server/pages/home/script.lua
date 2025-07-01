local M = {}

local r = require('renderer')
local p = require('parser')

local speaker = peripheral.find('speaker')

local function playSound()
    if speaker == nil then return end
    speaker.playNote('bell', 3, 12)
end

local function resetParser()
    p.startingLine = 1
    p.defaultTextColor = colors.white
    p.defaultBgColor = colors.black
end

local function nav(page)
    playSound()
    r.fetchPage(page)
    resetParser()
end

local function navLocal(page)
    playSound()
    r.renderLocalPage('/pages/'..page)
    resetParser()
end

function M.navStorageTutorial()
    nav('kona/storagetutorial')
end

function M.navOasisCafe()
    nav('oasis/honeybeecafe')
end

function M.openEditor()
    multishell.setTitle(multishell.getCurrent(), 'Browser')
    local id = shell.openTab('editor')
    shell.switchTab(id)
end

function M.OnLoad()
    r.currentMD = r.currentMD..'\n-- Local Pages'

    local localPages = r.getLocalPages()

    for i = 1, #localPages do
        local page = localPages[i]
        r.currentMD = r.currentMD..('\n\\btn{%s}{%s}'):format(page, 'navLocal'..page)
        M['navLocal'..page] = function() navLocal(page) end
    end
end

return M
