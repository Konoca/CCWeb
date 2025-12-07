-- config: ALL, BLANK, REQUEST = inventories
-- config: ITEM_START, ITEM_INPUT = inventories
-- config: TRIGGER_SIDE, COMPLETION_SIDE = string

local M = {}

local p = require('parser')
local r = require('renderer')
local c = require('config')

local ALL = peripheral.wrap(c['ALL'])
local BLANK = peripheral.wrap(c['BLANK'])
local REQUEST = c['REQUEST']

local ITEM_INPUT = peripheral.wrap(c['ITEM_INPUT'])
local ITEM_START = c['ITEM_START']

local TRIGGER_SIDE = c['TRIGGER_SIDE']
local COMPLETION_SIDE = c['COMPLETION_SIDE']

local initialMd = ''

local enchantmentMap = {}
local function getEnchantments()
    local md = initialMd
    enchantmentMap = {}
    for slot, _ in pairs(ALL.list()) do
        local i = ALL.getItemDetail(slot)
        local name = i.displayName
        local str = ('\n\\cbx{ %s }{boolean%s}'):format(name, name, name)
        md = md..str

        M['boolean'..name] = false
        enchantmentMap[name] = slot
    end
    r.currentMD = md
end

local function createSubmitBtn()
    local w, h = p.window.getSize()
    p.buttonTable[h] = {}
    p.window.setCursorPos(1, h)

    local txt = 'Submit'
    local postSpaces = (w / 2)
    local preSpaces = postSpaces - (#txt / 2)
    local spacedTxt = (' '):rep(preSpaces)..txt..(' '):rep(postSpaces)
    p.tagTable['\\btn'](spacedTxt, 'submitEnch')
end


function M.submitEnch()
    if (ITEM_INPUT.getItemDetail(1) == nil) then
        p.window.clear()
        p.window.setCursorPos(1, 2)
        p.window.write('Please place an item in the')
        p.window.setCursorPos(1, 3)
        p.window.write('first slot of the barrel')
        p.window.setCursorPos(1, 4)
        p.window.write('next to the screen!')

        sleep(3)
        return
    end
    p.window.clear()
    p.window.setCursorPos(1, 2)
    p.window.write('Queueing Selected Enchantments...')

    for name, slot in pairs(enchantmentMap) do
        if M['boolean'..name] then
            ALL.pushItems(REQUEST, slot)
        end
    end

    p.window.setCursorPos(1, 3)
    p.window.write('Feeding the Blaze...')
    redstone.setOutput(TRIGGER_SIDE, true)
    sleep(1)
    redstone.setOutput(TRIGGER_SIDE, false)

    sleep(4)
    p.window.setCursorPos(1, 4)
    p.window.write('Enchanting your item...')
    ITEM_INPUT.pushItems(ITEM_START, 1)

    while true do
        os.pullEvent('redstone')
        if redstone.getInput(COMPLETION_SIDE) then
            break
        end
    end

    p.window.setCursorPos(1, 5)
    p.window.write('Resetting the Blaze...')
    BLANK.pushItems(REQUEST, 1)
    redstone.setOutput(TRIGGER_SIDE, true)
    sleep(1)
    redstone.setOutput(TRIGGER_SIDE, false)

    sleep(5)
    getEnchantments()
end

function M.OnLoad()
    initialMd = r.currentMD
    getEnchantments()
end

function M.PostRender()
    createSubmitBtn()
end

return M
