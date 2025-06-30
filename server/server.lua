peripheral.find('modem', rednet.open)
local PROTOCOL = 'cctp'

local pageDir = 'pages/'
local index = '/index.ccmd'
local script = '/script.lua'

local function readFile(filePath)
    local file, err = io.open(filePath, 'r')
    if not file then
        print('Error opening file: ' .. err)
        return ''
    end

    local content = file:read('a')

    file:close()
    return content
end

local function fileExists(filePath)
    local f = io.open(filePath, 'r')
    if f ~= nil then
        io.close(f)
        return true
    end
    return false
end

while true do
    local id, message = rednet.receive(PROTOCOL)
    print(('[%d] Receieved %s'):format(id, message))

    local pagePath = pageDir..message

    if not fileExists(pagePath..index) then
        rednet.send(id, '', PROTOCOL)
        goto SKIP
    end

    local page = {}

    page['md'] = readFile(pagePath..index)
    page['lua'] = readFile(pagePath..script)

    rednet.send(id, page, PROTOCOL)

    ::SKIP::
end
