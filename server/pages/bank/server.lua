local PROTOCOL = 'cctp_banking'
local HOSTNAME = 'CCBank'

local USERS_DIR = '/users'
local CURRENCY = {
    -- KEEP IN ORDER OF LARGEST TO SMALLEST
    { name = 'minecraft:diamond', value = 1 },
    { name = 'betternether:cincinnasite_ingot', value = 0.01 },
}
local CURRENCY_MAP = {}
for _, currency in ipairs(CURRENCY) do
    CURRENCY_MAP[currency.name] = currency.value
end


local VAULT = peripheral.find('inventory', function(name, vault)
    return name:find('storagedrawers:controller_') ~= nil
end)

print('Starting up Banking server...')
print('Hostname: '..HOSTNAME)
print('ID: '..os.getComputerID())
print('Protocol: '..PROTOCOL)

print('Finding modem...')
peripheral.find('modem', rednet.open)

print('Registering hostname...')
rednet.host(PROTOCOL, HOSTNAME)

-- /users
---- /<username>
---@class User
---@field hashedPassword string -- hashed and salted password
---@field salt string
---@field funds number
---@field itemMap table
---@field transactions Transaction

---@class Transaction
---@field sender string
---@field receiver string
---@field funds number

---@class Request
---@field USER string
---@field PW string
---@field ACTION string
---@field ACTION_INPUT any -- depends on ACTION


local function simpleHash(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + str:byte(i)) % 2^32
    end
    return string.format('%08x', hash)
end
local function generateSalt(length)
    local charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local salt = ''
    for i = 1, length do
        local rand = math.random(1, #charset)
        salt = salt .. charset:sub(rand, rand)
    end
    return salt
end
local function hashPassword(input)
    local salt = generateSalt(8)
    local hash = simpleHash(salt..input)
    return salt, hash
end
local function verifyPassword(hashedPassword, salt, input)
    local inputHash = simpleHash(salt..input)
    return hashedPassword == inputHash
end


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

---@param user User
local function saveUser(filePath, user)
    local file, err  = io.open(filePath, 'w')
    if file == nil then
        printError('Error opening file: '..err)
        return err
    end

    local str = textutils.serializeJSON({
        hashedPassword = user.hashedPassword,
        salt = user.salt,
        transactions = user.transactions,
        funds = user.funds,
    })
    file:write(str)
    file:close()
end

---@param req Request
---@param bypassPassword boolean
---@return User?
local function getUser(req, bypassPassword)
    local userFile = USERS_DIR..'/'..req.USER

    if not fileExists(userFile) then
        return nil
    end

    local user = readFile(userFile)
    user = textutils.unserializeJSON(user)

    if user == nil then
        return nil
    end

    if not bypassPassword and not verifyPassword(user.hashedPassword, user.salt, req.PW) then
        return nil
    end

    return user
end

---@return error
local function createUser(username, password)
    local path = USERS_DIR..'/'..username
    if fileExists(path) then
        return 'User already exists'
    end

    print('Creating new user: '..username)
    print('Using path: '..path)

    local salt, hashedPassword = hashPassword(password)
    local user = {
        hashedPassword = hashedPassword,
        salt = salt,
        transactions = {},
        funds = 0,
    }
    return saveUser(path, user)
end


print('Ensuring logging users exist...')
createUser('WITHDRAW', '')
createUser('DEPOSIT', '')
createUser('TRANSACTIONS', '')


local function round(num, precision)
    local mult = 10 ^ (precision or 2)
    return math.floor(num * mult + 0.5) / mult
end

local function setError(id, errorMsg)
    printError(errorMsg)

    local response = {ERROR = errorMsg}
    rednet.send(id, response, PROTOCOL)
end

local function logTransaction(username, transaction)
    local user = getUser({['USER']=username}, true)
    table.insert(user.transactions, transaction)
    saveUser(USERS_DIR..'/'..username, user)
end


print('Awaiting request...')
while true do
    local id, message = rednet.receive(PROTOCOL)
    local response = {}

    if type(message) ~= 'table' then
        print(('[%d] Receieved invalid request'):format(id))
        setError('Invalid Request Message')
        goto SKIP
    end

    print(('[%d] Receieved: {USER: %s, ACTION: %s}'):format(id, message.USER, message.ACTION))

    local msgUser = message.USER
    local msgPw = message.PW
    local action = message.ACTION:lower()

    if msgUser == nil or msgPw == nil then
        setError('Missing Authentication Information')
        goto SKIP
    end

    local user = getUser(message)

    if user == nil and action ~= 'register' then
        setError('Invalid Login')
        goto SKIP
    end

    if action == 'register' then
        local error = createUser(message.USER, message.PW)
        if error ~= nil then
            response.ERROR = error
            printError(error)
        else
            user = getUser(message)
            action = 'login'
        end
    end

    if action == 'login' then
        response.FUNDS = user.funds
        response.TRANSACTIONS = user.transactions
    end

    if action == 'send' then
        local actionIn = message.ACTION_INPUT
        local userToSend = actionIn.USER
        local funds = actionIn.FUNDS
        local buffer = actionIn.BUFFER

        local receiverUser = getUser({['USER']=userToSend}, true)
        if not receiverUser then
            setError('Invalid recipient.')
            goto SKIP
        end

        if type(funds) ~= 'number' or funds <= 0 then
            setError('Bad input.')
            goto SKIP
        end

        if funds > user.funds then
            setError('Insufficient funds.')
            goto SKIP
        end

        user.funds = user.funds - funds
        receiverUser.funds = receiverUser.funds + funds

        local transaction = {
            sender = message.USER,
            receiver = userToSend,
            funds = funds,
        }

        if userToSend == 'WITHDRAW' and buffer ~= nil then
            local fundsToWithdraw = funds

            local itemsInVault = {}
            for slot, item in pairs(VAULT.list()) do
                itemsInVault[item.name] = {
                    slot = slot,
                    count = item.count,
                }
            end

            for _, currency in ipairs(CURRENCY) do
                local item = itemsInVault[currency.name]
                local value = currency.value

                fundsToWithdraw = round(fundsToWithdraw, 2)
                local maxAvailable = item and item.count or 0
                local needed = math.floor(fundsToWithdraw / value)
                local usable = math.min(needed, maxAvailable)

                if usable > 0 then
                    VAULT.pushItems(buffer, item.slot, usable)
                end
                fundsToWithdraw = round(fundsToWithdraw - (usable * value), 2)
            end
            receiverUser.funds = receiverUser.funds - funds
        end

        table.insert(user.transactions, transaction)
        saveUser(USERS_DIR..'/'..message.USER, user)

        table.insert(receiverUser.transactions, transaction)
        saveUser(USERS_DIR..'/'..userToSend, receiverUser)

        logTransaction('TRANSACTIONS', transaction)


        response.FUNDS = user.funds
        response.TRANSACTIONS = user.transactions
    end

    if action == 'deposit' then
        local buffer = message.ACTION_INPUT.BUFFER

        local funds = 0
        local b = peripheral.wrap(buffer)
        for slot, item in pairs(b.list()) do
            if CURRENCY_MAP[item.name] ~= nil then
                funds = funds + (CURRENCY_MAP[item.name] * item.count)
                VAULT.pullItems(buffer, slot, item.count)
            end
        end
        local transaction = {
            sender = 'DEPOSIT',
            receiver = message.USER,
            funds = funds,
        }

        user.funds = user.funds + funds
        table.insert(user.transactions, transaction)
        saveUser(USERS_DIR..'/'..message.USER, user)

        logTransaction('DEPOSIT', transaction)
        logTransaction('TRANSACTIONS', transaction)

        response.FUNDS = user.funds
        response.TRANSACTIONS = user.transactions
    end

    rednet.send(id, response, PROTOCOL)

    ::SKIP::
end
