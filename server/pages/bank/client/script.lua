local M = {}

local p = require('parser')
local r = require('renderer')
local c = require('config')


M.usernameInput = ''
M.passwordInput = ''
M.isLoggedIn = false
M.saveLoginLocally = false
M.error = ''

M.recipientInput = ''
M.fundInput = ''

local PROTOCOL = 'cctp_banking'
local HOSTNAME = 'CCBank'
local serverId = nil

local BUFFER_INV = c['BUFFER']
local STORED_USER = c['BANK_USER']
local STORED_PW = c['BANK_PW']


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
   \cbx{ }{saveLoginLocally} Remember me


\btn{%s}{onSubmitLogin}

\btn{%s}{onSubmitRegister}
]]):format(
        ('\n'):rep((h / 2) - 6),
        getHCenteredText('Sign in', w),
        getHCenteredText('Connected to Computer #'..serverId, w),
        w - 6, w - 6,
        getHCenteredText('Submit', w),
        getHCenteredText('Register', w)
    )

    r.currentMD = md
end

local function drawUserScreen(response)
    local w, _ = p.window.getSize()
    M.recipientInput = ''
    M.fundInput = ''

    local additionalText = ''
    if BUFFER_INV ~= nil then
        additionalText = ' | WITHDRAW'
    end

    local md = '\n\n'
    md = md..('Available funds: $%.2f'):format(response.FUNDS)

    md = md..'\n\nSend funds:'
    md = md..'\n\\input{recipientInput}{useless}{placeholder=Recipient username'..additionalText..'}'
    md = md..'\n\\input{fundInput}{useless}{placeholder=Amount to send}'
    md = md..'\n\\btn{'..getHCenteredText('Submit', w)..'}{onSubmitSend}'

    if BUFFER_INV ~= nil then
        md = md..'\n\\btn{'..getHCenteredText('Deposit', w)..'}{onSubmitDeposit}'
    end

    md = md..'\n\n\n'..getHCenteredText('Transaction History', w)..'\n'
    if response.TRANSACTIONS == nil or #response.TRANSACTIONS == 0 then
        md = md..'None'
    else
        for i = #response.TRANSACTIONS, 1, -1 do
            local v = response.TRANSACTIONS[i]
            md = md..('[%d] %s -> %s : $%.2f\n'):format(i, v.sender, v.receiver, v.funds)
        end
    end

    r.currentMD = md
end

---@return messageBody if no errors
---@return error
local function sendRequest(action, action_input)
    rednet.send(serverId, {
        ['USER'] = M.usernameInput,
        ['PW'] = M.passwordInput,
        ['ACTION'] = action,
        ['ACTION_INPUT'] = action_input,
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

local function saveLogin()
    if not M.saveLoginLocally then return end

    c['BANK_USER'] = M.usernameInput
    c['BANK_PW'] = M.passwordInput

    local file = fs.open('/config.lua', 'w')
    file.write('return {')
    for k, v in pairs(c) do
        local line = ("\n    ['%s'] = '%s',"):format(k, v)
        file.write(line)
    end
    file.write('\n}')
    file.close()
end

function M.onSubmitLogin()
    local response, error = sendRequest('LOGIN')

    if error ~= nil then
        r.currentMD = error
        return
    end

    saveLogin()

    M.isLoggedIn = true
    drawUserScreen(response)
end

function M.onSubmitRegister()
    local response, error = sendRequest('REGISTER')

    if error ~= nil then
        r.currentMD = error
        return
    end

    saveLogin()

    M.isLoggedIn = true
    drawUserScreen(response)
end

function M.useless()
    -- needs to exist, but doesnt do anything
end

function M.onSubmitSend()
    if M.recipientInput == '' then return end
    if M.fundInput == '' then return end

    local funds = tonumber(('%.2f'):format(M.fundInput))
    if funds == nil then return end

    local response, error = sendRequest('SEND', {
        ['USER'] = M.recipientInput,
        ['FUNDS'] = funds,
        ['BUFFER'] = BUFFER_INV,
    })

    if error ~= nil then
        r.currentMD = error
        return
    end

    drawUserScreen(response)
end

function M.onSubmitDeposit()
    local response, error = sendRequest('DEPOSIT', {
        ['BUFFER'] = BUFFER_INV,
    })

    if error ~= nil then
        r.currentMD = error
        return
    end

    drawUserScreen(response)
end


-- only runs once, runs when user opens page
function M.OnLoad()
    peripheral.find('modem', rednet.open)
    serverId = rednet.lookup(PROTOCOL, HOSTNAME)

    if serverId == nil then
        r.currentMD = 'Server could not be found...'
        return
    end

    if STORED_USER ~= nil and STORED_PW ~= nil then
        M.usernameInput = STORED_USER
        M.passwordInput = STORED_PW
        M.onSubmitLogin()
        return
    end

    drawLoginScreen()
end

-- only runs once, runs when user leaves page
function M.OnUnload()
    peripheral.find('modem', rednet.close)
end

-- runs every time after page is (re)rendered
function M.PostRender()
    if not M.isLoggedIn then return end

    local w, _ = p.window.getSize()
    local logout = 'Logout'

    p.window.setCursorPos(1, 1)
    p.handleC(' '..M.usernameInput..' ', 'black', 'green')

    p.handleBgColor((' '):rep(w - #M.usernameInput - #logout - 4), 'lightGray')

    p.window.setCursorPos(w - 6 - 1, 1)
    p.handleC(' Logout ', 'black', 'red')
end

function M.OnEvent(event, p1, p2, p3)
    if event == 'mouse_click' or event == 'monitor_touch' then
        -- btn, x, y = p1, p2, p3
        if p3 ~= 1 then return end

        local w, _ = p.window.getSize()
        if p2 >= w - 6 - 1 then
            M.usernameInput = ''
            M.passwordInput = ''
            M.isLoggedIn = false
            drawLoginScreen()
        end
    end
end

return M
