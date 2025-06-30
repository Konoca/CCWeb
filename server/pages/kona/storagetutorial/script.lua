local M = {}

local p = require('parser')
local r = require('renderer')
local c = require('config')

M.outputName = ''
function M.onSubmit()
end

function M.updateConfig()
    c['DEFAULT_PAGE'] = 'kona/storage'
    c['HIDE_BROWSER'] = true
    c['OUTPUT'] = M.outputName

    local file = fs.open('/config.lua', 'w')
    file.write('return {')
    for k, v in pairs(c) do
        local line = ("\n    ['%s'] = '%s',"):format(k, v)
        file.write(line)
    end
    file.write('\n}')
    file.close()

    os.reboot()
end

return M
