-- expects inventories connected via wired modem
-- config.HIDE_BROWSER = true
-- set config.OUTPUT to name of output inventory

local M = {}

local p = require('parser')
local r = require('renderer')
local c = require('config')

local modem = peripheral.find('modem')
local title = 'Inventory Manager'
local output = c['OUTPUT']

local search = ''

---------------------------------------------

local itemMap = {} -- { [idx] = { [containerName], [slot], [itemName], [quantity] } }
local function fetchItems()
    itemMap = {}

    p.window.clear()
    p.window.setCursorPos(1, 1)
    p.window.write('Fetching information...')

    p.window.setCursorPos(1, 6)
    p.window.write('LeftClick = 1 item')
    p.window.setCursorPos(1, 7)
    p.window.write('RightClick = 64 items')
    p.window.setCursorPos(1, 8)
    p.window.write('Click green button to deposit items!')

    p.window.setCursorPos(1, 9)
    p.window.write('Press ENTER to reload cache!')

    local containers = modem.getNamesRemote()
    local count = 0
    for _, name in pairs(containers) do
        p.window.setCursorPos(1, 3)
        p.window.write(('Completed %d/%d'):format(count, #containers))
        count = count + 1

        p.window.setCursorPos(1, 4)
        p.window.write('Checking '..name)

        if not modem.hasTypeRemote(name, 'inventory') then goto skip end
        if name == output then goto skip end

        local container = peripheral.wrap(name)
        local items = container.list()
        for slot, _ in pairs(items) do
            local item = container.getItemDetail(slot)
            table.insert(itemMap, {
                ['container'] = name,
                ['slot'] = slot,
                ['displayName'] = item.displayName,
                ['name'] = item.name,
                ['count'] = item.count,
            })
        end

        ::skip::
    end
end

local filteredItemMap = {}
local function filterItems()
    filteredItemMap = {}
    for idx, item in pairs(itemMap) do
        if search == '' or item.displayName:lower():match(search) == search then
            item.idx = idx
            table.insert(filteredItemMap, item)
        end
    end
end

local function updateItem(idx, i)
    local container = peripheral.wrap(i.container)
    local item = container.getItemDetail(i.slot)

    if i.idx ~= nil then idx = i.idx end
    itemMap[idx].count = item.count

    if item.count == 0 then
        table.remove(itemMap, idx)
    end

    filterItems()
end

local function setSearch(str)
    search = str
    p.startingLine = 1
end

local function addToSearch(char)
    setSearch(search..char)
end

local function searchBackspace()
    search = search:sub(1, -2)
    setSearch(search)

    if search == '' then
        filterItems()
        return
    end
end

local function depositItems()
    local container = peripheral.wrap(output)
    local items = container.list()

    for slot, item in pairs(items) do
        for idx, itemS in pairs(itemMap) do
            if itemS.name == item.name then
                container.pushItems(itemS.container, slot, item.count)
                updateItem(idx, itemS)
            end
        end
    end
end

---------------------------------------------

-- only runs once, runs when user opens page
function M.OnLoad()
    p.handleInit('white', 'black')
    setSearch('')
    fetchItems()
    filterItems()
end

-- runs every time before page is (re)rendered
function M.PreRender()
    r.currentMD = '\n\n'

    local items, y = '', 2
    for _, item in pairs(filteredItemMap) do
        local str = ('%s (x%d)\n'):format(item.displayName, item.count)
        items = items..str
        y = y + 1
    end

    r.currentMD = r.currentMD..items
end

-- runs every time after page is (re)rendered
function M.PostRender()
    local w, _ = p.window.getSize()

    p.window.setCursorPos(1, 1)
    p.handleBgColor(title..' ', 'green')

    local s, color = search, 'black'
    if search == '' or search == nil then s, color = 'Search...', 'gray' end
    p.handleC(' '..s..(' '):rep(w - #title - #s - 2), color, 'lightGray')

    p.window.setCursorPos(1, 2)
    p.handleC((' '):rep(w), color, 'black')
end

-- only runs once, runs when user leaves page
function M.OnUnload()
end

-- runs every time an event occurs
function M.OnEvent(event, p1, p2, p3)
    if event == 'key' then
        local key = keys.getName(p1)
        if #key == 1 then addToSearch(key) end
        if key == 'backspace' then searchBackspace() end
        if key == 'space' then addToSearch(' ') end

        if key == 'enter' then
            fetchItems()
            goto skip
        end

        filterItems()
        goto skip
    end

    if event == 'mouse_click' or event == 'monitor_touch' then
        local btn, x, y = p1, p2, p3
        if y == 2 then goto skip end

        if y == 1 and x >= 1 and x <= #title then
            depositItems()
            goto skip
        end

        local idx = y - 2 + (p.startingLine - 1)
        local item = filteredItemMap[idx]
        if item ~= nil then
            local amnt = 1
            if btn == 2 then amnt = 64 end

            peripheral.wrap(item.container).pushItems(output, item.slot, amnt)
            updateItem(idx, item)
        end
    end

    ::skip::
end

return M
