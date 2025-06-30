local M = {}

local p = require('parser')
local r = require('renderer')
local c = require('config')

-- function used for button
local speaker = peripheral.find('speaker')
function M.exampleFunction()
    if speaker == nil then return end
    speaker.playNote('harp', 3, 12)
end

-- variables for text input boxes
M.inputText = ''
M.inputText2 = ''

-- functions for text input submit
function M.onSubmitInput()
    r.currentMD = r.currentMD..'\n-'..M.inputText
    p.startingLine = p.startingLine + 2
    M.inputText = ''
end

function M.onSubmitInput2()
    r.currentMD = r.currentMD..'\n-'..M.inputText2
    p.startingLine = p.startingLine + 2
    M.inputText2 = ''
end

-- only runs once, runs when user opens page
function M.OnLoad()
end

-- runs every time before page is (re)rendered
function M.PreRender()
end

-- runs every time after page is (re)rendered
function M.PostRender()
end

-- only runs once, runs when user leaves page
function M.OnUnload()
end

-- runs every time an event occurs
function M.OnEvent(event, p1, p2, p3)
end

return M
