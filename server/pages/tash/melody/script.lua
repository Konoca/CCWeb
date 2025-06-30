local M = {}

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
