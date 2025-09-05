local PROTOCOL = 'cctp_banking'
local HOSTNAME = 'CCBank'

local USERS_DIR = '/users'
local CURRENCY = {
    ['minecraft:diamond'] = 1
}

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
---@field vaultIds table -- {minecraft:barrel_1, minecraft:barrel_2, etc...}
---@field hashedPassword string -- hashed and salted password
---@field salt string
---@field funds table -- {<item>: <amount>}
---@field itemMap table
---@field transactions Transaction

---@class Transaction
---@field sender string
---@field receiver string
---@field funds table -- {<item>: <amount>}

---@class Request
---@field USER string
---@field PW string
---@field ACTION string


local function simpleHash(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + str:byte(i)) % 2^32
    end
    return string.format("%08x", hash)
end
local function generateSalt(length)
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local salt = ""
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
        ['vaultIds'] = user.vaultIds,
        ['hashedPassword'] = user.hashedPassword,
        ['salt'] = user.salt,
        ['transactions'] = user.transactions,
    })
    file:write(str)
    file:close()
end


---@param user User
local function getUserItems(user)
    local itemMap = {}
    local funds = {}

    for _, name in pairs(user.vaultIds) do
        local container = peripheral.wrap(name)
        local items = container.list()
        for slot, _ in pairs(items) do
            local item = container.getItemDetail(slot)
            table.insert(itemMap, {
                ['container'] = name,
                ['slot'] = slot,
                ['displayName'] = item.displayName,
                ['name'] = item.name,
                ['count'] = item.count,
            })

            if CURRENCY[item.name] ~= nil then
                if not funds[item.name] then funds[item.name] = 0 end
                funds[item.name] = funds[item.name] + item.count
            end
        end
    end

    return itemMap, funds
end

---@param req Request
---@return User?
local function getUser(req)
    local userFile = USERS_DIR..'/'..req.USER

    if not fileExists(userFile) then
        return nil
    end

    local user = readFile(userFile)
    user = textutils.unserializeJSON(user)

    if user == nil then
        return nil
    end

    if not verifyPassword(user.hashedPassword, user.salt, req.PW) then
        return nil
    end

    user.itemMap, user.funds = getUserItems(user)

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
        ['vaultIds'] = {},
        ['hashedPassword'] = hashedPassword,
        ['salt'] = salt,
        ['transactions'] = {},
    }
    return saveUser(path, user)
end

print('Awaiting request...')
while true do
    local id, message = rednet.receive(PROTOCOL)
    print(('[%d] Receieved %s'):format(id, textutils.serialize(message)))
    local response = {}

    if type(message) ~= 'table' then
        response['ERROR'] = 'Invalid Request Message'
        printError(response['ERROR'])
        rednet.send(id, response, PROTOCOL)
        goto SKIP
    end

    if message['USER'] == nil or message['PW'] == nil then
        response['ERROR'] = 'Missing Authentication Information'
        printError(response['ERROR'])
        rednet.send(id, response, PROTOCOL)
        goto SKIP
    end

    local user = getUser(message)
    local action = message.ACTION:lower()

    if user == nil and action ~= 'register' then
        response['ERROR'] = 'Invalid Login'
        printError(response['ERROR'])
        rednet.send(id, response, PROTOCOL)
        goto SKIP
    end

    if action == 'register' then
        local error = createUser(message.USER, message.PW)
        if error ~= nil then
            response['ERROR'] = error
            printError(error)
        end
    end

    if action == 'login' then
        response.FUNDS = user.funds
        response.ITEMS = user.itemMap
        response.TRANSACTIONS = user.transactions
    end

    rednet.send(id, response, PROTOCOL)

    ::SKIP::
end
