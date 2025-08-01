-- wget run https://raw.githubusercontent.com/Konoca/CCWeb/refs/heads/main/client/updater.lua
-- wget https://raw.githubusercontent.com/Konoca/CCWeb/refs/heads/main/client/updater.lua updater.lua

local server = 'https://raw.githubusercontent.com/Konoca/CCWeb/refs/heads/main/client'
local files = {
    'updater.lua',
    'web.lua',
    'parser.lua',
    'renderer.lua',
    'network.lua',
    'editor.lua',
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
