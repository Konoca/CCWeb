-- expects two barrels and a monitor to be connected via wired modem
-- config.HIDE_BROWSER = true
-- config.INPUT = inventoryName, config.OUTPUT = inventoryName

local M = {}

local p = require('parser')
local r = require('renderer')
local c = require('config')

local monitor = peripheral.find('monitor')

local input = peripheral.wrap(c['INPUT'])
local output = peripheral.wrap(c['OUTPUT'])

local name = 'Honeybee Cafe'

local slotTable = {}

-- only runs once, runs when user opens page
function M.OnLoad()
    if monitor then monitor.setTextScale(0.5) end
    p.handleInit('pink', 'white')
end

-- runs every time before page is (re)rendered
function M.PreRender()
    if monitor then monitor.setTextScale(0.5) end
    local w, _ = p.window.getSize()
    r.currentMD = '\n'..(' '):rep((w/2) - (#name/2))..name..'\n\n'

    local items = ''
    local y = 4
    for slot, item in pairs(input.list()) do
        local i = input.getItemDetail(slot)
        local str = ('[%d] %s (x%d)'):format(slot, i.displayName, item.count)
        items = items..str..'\n'
        slotTable[y] = slot
        y = y + 1
    end
    r.currentMD = r.currentMD..items
end

-- runs every time after page is (re)rendered
function M.PostRender()
end

-- only runs once, runs when user leaves page
function M.OnUnload()
    if monitor then monitor.setTextScale(1) end
end

-- runs every time an event occurs
function M.OnEvent(event, _, _, y)
    if event ~= 'mouse_click' and event ~= 'monitor_touch' then return end

    if y < 4 then return end

    local slot = slotTable[y]
    if not slot then return end

    local item = input.getItemDetail(slot)
    if not item then return end

    input.pushItems(peripheral.getName(output), slot, 1)
end

return M
