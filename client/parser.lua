local M = {}

M.window = term
M.defaultTextColor = colors.white
M.defaultBgColor = colors.black
M.startingLine = 1
M.maxLine = 1

M.script = nil
M.buttonTable = {} -- { y: { x: func() } }
M.eventTable = {} -- { event: { func(), func(), ... } }

M.tagTable = {
    ['\\init'] = function(...) M.handleInit(...) end,
    ['\\t'] = function(...) M.handleTextColor(...) end,
    ['\\bg'] = function(...) M.handleBgColor(...) end,
    ['\\c'] = function(...) M.handleC(...) end,
    ['\\blit'] = function(...) M.handleBlit(...) end,
    ['\\btn'] = function(...) M.handleBtn(...) end,
    ['\\input'] = function(...) M.handleInput(...) end,
    ['\\cbx'] = function(...) M.handleCbx(...) end,
}

M.defaultStyling = {
    ['btn'] = {
        ['text'] = M.defaultBgColor,
        ['background'] = M.defaultTextColor,
    },
    ['input'] = {
        ['text'] = colors.gray,
        ['text-focused'] = colors.black,
        ['background'] = colors.lightGray,
        ['background-focused'] = colors.white,
    },
    ['cbx'] = {
        ['text'] = M.defaultTextColor,
        ['on'] = colors.green,
        ['off'] = colors.red
    }
}
M.styling = M.defaultStyling

-- \init{textColor}{bgColor}
function M.handleInit(textColorStr, bgColorStr)
    local textColor = colors[textColorStr]
    local bgColor = colors[bgColorStr]

    M.defaultTextColor = textColor
    M.defaultBgColor = bgColor

    M.window.setTextColor(textColor)
    M.window.setBackgroundColor(bgColor)

    M.window.clear()
    M.window.setCursorPos(1, 1)
end

-- \t{text}{textColor}
function M.handleTextColor(text, textColorStr)
    local textColor = colors[textColorStr]
    M.window.setTextColor(textColor)
    M.window.write(text)
    M.window.setTextColor(M.defaultTextColor)
end

-- \bg{text}{textColor}
function M.handleBgColor(text, bgColorStr)
    local bgColor = colors[bgColorStr]
    M.window.setBackgroundColor(bgColor)
    M.window.write(text)
    M.window.setBackgroundColor(M.defaultBgColor)
end

-- \c{text}{textColor}{bgColor}
function M.handleC(text, textColorStr, bgColorStr)
    local textColor = colors[textColorStr]
    local bgColor = colors[bgColorStr]

    local textBlit = colors.toBlit(textColor)
    local bgBlit = colors.toBlit(bgColor)

    M.window.blit(text, string.rep(textBlit, #text), string.rep(bgBlit, #text))
end

-- \blit{text}{textColorRaw}{bgColorRaw}
function M.handleBlit(text, textColorStr, bgColorStr)
    M.window.blit(text, textColorStr, bgColorStr)
end

-- \btn{text}{functioName}
function M.handleBtn(text, functionName)
    local styling = M.styling['btn']
    M.window.setBackgroundColor(styling['background'])
    M.window.setTextColor(styling['text'])

    local startX, startY = M.window.getCursorPos()
    M.window.write(text)
    local endX, _ = M.window.getCursorPos()

    M.window.setTextColor(M.defaultTextColor)
    M.window.setBackgroundColor(M.defaultBgColor)

    if M.script ~= nil then
        local func = M.script[functionName]
        M.buttonTable[startY] = M.buttonTable[startY] or {}
        for i=startX, endX-1, 1 do
            M.buttonTable[startY][i] = func
        end
    end
end

-- \cbx{text}{booleanName}
function M.handleCbx(text, booleanName)
    if M.script == nil or M.script[booleanName] == nil then
        return
    end

    local bool = M.script[booleanName]
    local styling = M.styling['cbx']

    local color = bool and styling['on'] or styling['off']
    M.window.setBackgroundColor(color)
    M.window.setTextColor(styling['text'])

    local startX, startY = M.window.getCursorPos()
    M.window.write(text)
    local endX, _ = M.window.getCursorPos()

    M.window.setTextColor(M.defaultTextColor)
    M.window.setBackgroundColor(M.defaultBgColor)

    local func = function() M.script[booleanName] = not bool end
    M.buttonTable[startY] = M.buttonTable[startY] or {}
    for i=startX, endX-1, 1 do
        M.buttonTable[startY][i] = func
    end
end

-- \input{variable}{onSubmit}{options}
-- options = {width=number;placeholder=string}
M.focusedInput = nil
function M.handleInput(var, onSubmit, optionsRaw)
    local styling = M.styling['input']

    local options = {}
    for key, value in optionsRaw:gmatch('(%w+)=([^;]+)') do
        options[key] = value
    end

    local placeholder = options['placeholder'] or ''
    local width = tonumber(options['width']) or 0
    if width == 0 then width, _ = M.window.getSize() end

    local isFocused = M.focusedInput == var and '-focused' or ''
    local text = M.focusedInput == var and '' or placeholder
    local color = colors.toBlit(styling['text'..isFocused])
    local bgColor = colors.toBlit(styling['background'..isFocused])

    if M.script[var] == nil then
        M.script[var] = ''
    end

    if M.script ~= nil and M.script[var] ~= '' then
        text = M.script[var]
    end

    local startX, startY = M.window.getCursorPos()
    M.handleBlit(' '..text..(' '):rep(width - #text - 1), color:rep(width), bgColor:rep(width))
    local endX, _ = M.window.getCursorPos()

    if M.script ~= nil and M.script[onSubmit] ~= nil then
        if M.focusedInput == var then

            if M.eventTable['key'] == nil then M.eventTable['key'] = {} end
            table.insert(M.eventTable['key'], function(p1)
                local key = keys.getName(p1)

                if key == 'backspace' and #M.script[var] > 0 then
                    M.script[var] = M.script[var]:sub(1, -2)
                end

                if key == 'enter' then
                    M.script[onSubmit]()
                    M.focusedInput = nil
                end
            end)

            if M.eventTable['char'] == nil then M.eventTable['char'] = {} end
            table.insert(M.eventTable['char'], function(p1)
                M.script[var] = M.script[var]..p1
            end)

            if M.eventTable['mouse_click'] == nil then
                M.eventTable['mouse_click'] = {}
            end
            table.insert(M.eventTable['mouse_click'], function()
                M.focusedInput = nil
            end)
        else
            M.buttonTable[startY] = M.buttonTable[startY] or {}
            for i=startX, endX-1, 1 do
                M.buttonTable[startY][i] = function() M.focusedInput = var end
            end
        end
    end
end

local regex = '(\\[a-z]+)({[^}]+})({[^}]+})({?[^}\\]*}?)'
function M.parseLine(line)
    local inBackticks = false

    local tagTable = {}
    local currTag = 1

    for tag, text, inp1, inp2 in line:gmatch(regex) do
        if not inp2:match('({[^}]+})') then
            inp2 = ''
        end

        table.insert(tagTable, {
            ['tag'] = tag,
            ['text'] = text,
            ['inp1'] = inp1,
            ['inp2'] = inp2
        })
        line = line:gsub(tag..text..inp1..inp2, '\\', 1)
    end

    for c in line:gmatch('.') do
        if c:match('`') then
            inBackticks = not inBackticks
        end

        if c:match('\\') then
            local t = tagTable[currTag]
            currTag = currTag + 1

            if inBackticks then
                M.window.write(t.tag..t.text..t.inp1..t.inp2)
                goto forEnd
            end

            local tag = t.tag
            local text = t.text
            local inp1 = t.inp1
            local inp2 = t.inp2

            text = text:gsub('{([^}]*)}', '%1')
            inp1 = inp1:gsub('{([^}]*)}', '%1')
            inp2 = inp2:gsub('{([^}]*)}', '%1')

            local tagFunc = M.tagTable[tag]
            if tagFunc then
                tagFunc(text, inp1, inp2)
            end

            goto forEnd
        end

        M.window.write(c)
        ::forEnd::
    end
end

function M.parseMarkdown(md)
    local y = 1
    M.window.clear()
    M.window.setCursorPos(1, y)

    M.buttonTable = {}
    M.eventTable = {}

    local currLine = 1
    for line in md:gmatch('([^\n]*)\n?') do
        if currLine < M.startingLine then goto skipLine end

        M.parseLine(line)
        y = y + 1
        M.window.setCursorPos(1, y)

        ::skipLine::
        currLine = currLine + 1
        M.maxLine = currLine
    end
end

return M
