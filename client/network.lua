local M = {}

local config = require('config')

local PROTOCOL = config['PROTOCOL']
local SERVER_ID = config['SERVER_ID']
local SERVER_URL = config['SERVER_URL']
local USE_URL = config['USE_URL']

local index = 'index.ccmd'
local script = 'script.lua'

if not USE_URL then
    peripheral.find('modem', rednet.open)
end

function M.fetchPage(page)
    if not USE_URL then
        rednet.send(SERVER_ID, page, PROTOCOL)
        return
    end

    local url = ('%s/%s/'):format(SERVER_URL, page)
    local indexFile = http.get(url..index)
    local scriptFile = http.get(url..script)

    if indexFile == nil then
        return
    end

    local md = indexFile:readAll()

    local lua = nil
    if scriptFile ~= nil then
        lua = scriptFile:readAll()
    end

    return md, lua

end

return M
