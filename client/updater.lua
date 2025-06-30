-- wget run http://files.konoca.com/code/mc/ccweb/client/updater.lua
-- wget http://files.konoca.com/code/mc/ccweb/client/updater.lua updater.lua

local server = 'http://files.konoca.com/code/mc/ccweb/client'
local files = {
    'updater.lua',
    'web.lua',
    'parser.lua',
    'renderer.lua',
    'network.lua',
    'editor.lua',
    'file_manager.lua',
    'pages/example/index.ccmd',
    'pages/example/script.lua',
    'pages/template/index.ccmd',
    'pages/template/script.lua',
}

local function fileExists(filePath)
    local f = io.open(filePath, 'r')
    if f ~= nil then
        io.close(f)
        return true
    end
    return false
end

if not fileExists('config.lua') then
    table.insert(files, 'config.lua')
end

if not fs.exists('pages') then
    fs.makeDir('pages/example')
    fs.makeDir('pages/template')
end

for _, file in pairs(files) do
    shell.execute('delete', file)
    shell.execute('wget', ('%s/%s'):format(server, file), file)
end
