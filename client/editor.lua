local c = require('config')
c['HIDE_BROWSER'] = true

local r = require('renderer')
local p = require('parser')

r.currentPage = 'editor'
local md = '\\init{white}{black}CCWeb File Editor!\n'

r.currentMD = md
r.currentLUA = ''

local M = {}
M.newPageName = ''

function M.getLocalPages()
    r.currentMD = md

    local pages = r.getLocalPages()
    for i = 1, #pages do
        local page = pages[i]
        r.currentMD = r.currentMD..('\n\\btn{%s}{editPage%s}'):format(page, page)
        M['editPage'..page] = function() M.getLocalPageFiles(page) end
    end

    r.currentMD = r.currentMD..'\n\n\\btn{Add New Page}{startAddNewPage}'
end

function M.getLocalPageFiles(page)
    r.currentMD = (md..'/pages/%s\n\n\\btn{Back to Pages}{getLocalPages}'):format(page)

    local files = fs.list('/pages/'..page)
    for i = 1, #files do
        local file = files[i]
        r.currentMD = r.currentMD..('\n\\btn{%s}{editFile%s%s}'):format(file, page, file)
        M['editFile'..page..file] = function() M.editFile(page, file) end
    end
end

function M.startAddNewPage()
    M.newPageName = ''
    r.currentMD = md..'\nInput Folder Name\n\\input'
    r.currentMD = r.currentMD..'{newPageName}{onSubmitNewPage}{placeholder=Name of New Page Folder}'
    r.currentMD = r.currentMD..'\n\n\\btn{Back}{getLocalPages}'
end

function M.editFile(page, file)
    local path = ('/pages/%s/%s'):format(page, file)
    shell.execute('edit', path)
end

function M.onSubmitNewPage()
    local page = M.newPageName:gsub('%s+', ''):gsub('/', ''):gsub('\\', '')
    fs.copy('/pages/template', '/pages/'..page)
    M.getLocalPages()
end

p.handleInit('white', 'black')
M.getLocalPages()

p.script = M

r.main()
