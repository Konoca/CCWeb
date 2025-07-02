local M = {}

local parser = require('parser')
local network = require('network')
local config = require('config')

local DEFAULT_PAGE = config['DEFAULT_PAGE']
local HIDE_BROWSER = config['HIDE_BROWSER']

M.currentPage = nil
M.currentMD = ''
M.currentLUA = ''
local loading = false

local screen = term.current()
local monitor = peripheral.find('monitor')
if monitor then screen = monitor end

local width, height = screen.getSize()

local windowOffset = 1
if HIDE_BROWSER then
    windowOffset = 0
end
parser.window = window.create(screen, 1, 1+windowOffset, width-windowOffset, height-windowOffset)

function M.fetchPage(page)
    local md, lua = network.fetchPage(page)
    M.currentPage = page

    if md ~= nil then
        M.currentMD = md
        M.currentLUA = lua
        loading = true
    end

    if parser.script ~= nil and parser.script.OnUnload ~= nil then
        parser.script.OnUnload()
    end
end

local function renderPage(page)
    if page == nil then
        page = DEFAULT_PAGE
    end

    if page ~= M.currentPage then
        M.fetchPage(page)
    end

    if loading then
        parser.script = load(M.currentLUA, M.currentPage, 't', _ENV)()
    end

    if loading and parser.script ~= nil and parser.script.OnLoad ~= nil then
        parser.script.OnLoad()
    end

    if parser.script ~= nil and parser.script.PreRender ~= nil then
        parser.script.PreRender()
    end

    loading = false
    parser.parseMarkdown(M.currentMD)

    if parser.script ~= nil and parser.script.PostRender ~= nil then
        parser.script.PostRender()
    end
end

local function renderBrowser()
    if HIDE_BROWSER then return end

    screen.setBackgroundColor(colors.lightGray)
    screen.setTextColor(colors.white)
    screen.clear()

    screen.setCursorPos(1, 1)
    screen.write('CCWeb')

    screen.setCursorPos(width, 1)
    screen.write('x')

    screen.setCursorPos(width, 2)
    screen.write('^')

    screen.setCursorPos(width, height)
    screen.write('v')
end

local function resetScreen()
    screen.setBackgroundColor(colors.black)
    screen.setTextColor(colors.white)

    screen.clear()
    screen.setCursorPos(1, 1)
end

function M.getLocalPages()
    local pages = {}

    if not fs.exists('/pages') then return pages end

    local files = fs.list('/pages')
    for i = 1, #files do
        local f = '/pages/'..files[i]
        if fs.isDir(f)
            and fs.exists(f..'/index.ccmd')
            and fs.exists(f..'/script.lua')
        then
            table.insert(pages, files[i])
        end
    end

    return pages
end

function M.renderLocalPage(page)
    M.currentPage = page

    local index = page..'/index.ccmd'
    local script = page..'/script.lua'

    local indexFile = io.input(index)
    if indexFile == nil then error('Index file not found.') end
    M.currentMD = indexFile:read('a')
    indexFile:close()

    local scriptFile = io.input(script)
    if scriptFile == nil then error('Script file not found.') end
    M.currentLUA = scriptFile:read('a')
    scriptFile:close()

    loading = true
end

function M.main()
    while true do
        local event, dir, x, y = os.pullEventRaw()

        if event == 'mouse_click' or event == 'monitor_touch' then
            if not HIDE_BROWSER then
                if x == width and y == 1 then
                    resetScreen()
                    return
                end

                if y == 1 and (x >= 1 and x <= 5) then
                    M.fetchPage(DEFAULT_PAGE)
                    parser.startingLine = 1
                    resetScreen()
                end

                if x == width and y == 2 then
                    parser.startingLine = parser.startingLine - 1
                    if parser.startingLine <= 1 then
                        parser.startingLine = 1
                    end
                end

                if x == width and y == height then
                    parser.startingLine = parser.startingLine + 1
                end
            end

            local offX, offY = x - windowOffset, y - windowOffset
            if parser.buttonTable[offY] ~= nil
                and parser.buttonTable[offY][offX] ~= nil then
                parser.buttonTable[offY][offX]()
            end
        end

        if event == 'mouse_scroll' then
            if dir == -1 then
                parser.startingLine = parser.startingLine - 1
                if parser.startingLine <= 1 then
                    parser.startingLine = 1
                end
            end

            if dir == 1 then
                parser.startingLine = parser.startingLine + 1
                if parser.startingLine > parser.maxLine - height + windowOffset then
                    parser.startingLine = parser.maxLine - height + windowOffset
                end
            end
        end

        if event == 'term_resize' or event == 'monitor_resize' then
            width, height = screen.getSize()
            parser.window.reposition(1, 1+windowOffset, width-windowOffset, height-windowOffset)
        end

        if event == 'terminate' then
            resetScreen()
            return
        end

        if event == 'rednet_message' then
            local sender, msg, protocol = dir, x, y
            if sender == config['SERVER_ID'] and protocol == config['PROTOCOL'] then
                M.currentMD = msg['md'] or ''
                M.currentLUA = msg['lua'] or ''
                loading = true
            end
        end

        if parser.eventTable[event] ~= nil then
            for i = 1, #parser.eventTable[event] do
                parser.eventTable[event][i](dir, x, y)
            end
        end

        if parser.script ~= nil and parser.script.OnEvent ~= nil then
            parser.script.OnEvent(event, dir, x, y)
        end

        renderBrowser()
        renderPage(M.currentPage)
    end
end

return M
