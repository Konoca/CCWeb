local M = {}

local p = require('parser')
local r = require('renderer')
local c = require('config')


M.usernameInput = ''
M.passwordInput = ''
M.isLoggedIn = false
M.error = ''

local PROTOCOL = 'cctp_banking'
local HOSTNAME = 'CCBank'
local serverId = nil

local BUFFER_INV = c['BUFFER']


local function getHCenteredText(textToCenter, width)
    local postSpaces = (width / 2)
    local preSpaces = postSpaces - (#textToCenter / 2)
    return (' '):rep(preSpaces)..textToCenter..(' '):rep(postSpaces)
end


local function drawLoginScreen()
    local md = ''
    local w, h = p.window.getSize()

    md = ([[
%s
%s
%s


   \input{usernameInput}{useless}{placeholder=Enter Username...;width=%d}

   \input{passwordInput}{useless}{placeholder=Enter Password...;width=%d}


\btn{%s}{onSubmitLogin}

\btn{%s}{onSubmitRegister}
]]):format(
        ('\n'):rep((h / 2) - 5),
        getHCenteredText('Sign in', w),
        getHCenteredText('Connected to Computer #'..serverId, w),
        w - 6, w - 6,
        getHCenteredText('Submit', w),
        getHCenteredText('Register', w)
    )

    r.currentMD = md
end

---@return messageBody if no errors
---@return error
local function sendRequest(action)
    rednet.send(serverId, {
        ['USER'] = M.usernameInput,
        ['PW'] = M.passwordInput,
        ['ACTION'] = action
    }, PROTOCOL)

    local id, message = rednet.receive(PROTOCOL, 5)
    if not id then
        return nil, '\nConnection to server timed out.\nPlease try again later.'
    end
    if type(message) ~= 'table' then
        return nil, '\nBad Response from server.'
    end
    if message['ERROR'] ~= nil then
        return nil, '\n\\t{ERROR}{red}: '..message['ERROR']
    end

    return message, nil
end


function M.onSubmitLogin()
    local response, error = sendRequest('LOGIN')

    if error ~= nil then
        r.currentMD = error
        return
    end

    r.currentMD = ([[
Logged in!

username: %s

response: %s
]]):format(M.usernameInput, textutils.serialize(response))
end

function M.onSubmitRegister()
    local response, error = sendRequest('REGISTER')

    if error ~= nil then
        r.currentMD = error
        return
    end

    r.currentMD = ([[
Account created!

username: %s

response: %s
]]):format(M.usernameInput, textutils.serialize(response))
end

function M.useless()
    -- needs to exist, but doesnt do anything
end


-- only runs once, runs when user opens page
function M.OnLoad()
    peripheral.find('modem', rednet.open)
    serverId = rednet.lookup(PROTOCOL, HOSTNAME)

    if serverId == nil then
        r.currentMD = 'Server could not be found...'
        return
    end

    drawLoginScreen()
end

-- only runs once, runs when user leaves page
function M.OnUnload()
    peripheral.find('modem', rednet.close)
end

return M
