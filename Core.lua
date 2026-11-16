local ADDON, ns = ...

ABug = {}

local MAX = 300
local errors = {}
local index = {}
local session = 0
local busy = false
local lastNotice = 0
local listeners = {}

ns.errors = errors

function ns.OnChange(fn)
	listeners[#listeners + 1] = fn
end

local function changed()
	for i = 1, #listeners do pcall(listeners[i]) end
end

local function addonOf(text)
	if type(text) ~= "string" then return nil end
	return text:match("[Ii]nterface[/\\][Aa]dd[Oo]ns[/\\]([^/\\]+)[/\\]")
end

local function clock()
	if date then
		local ok, v = pcall(date, "%Y-%m-%d %H:%M:%S")
		if ok then return v end
	end
	return ""
end

local function state()
	local parts = {}
	if InCombatLockdown then
		local ok, v = pcall(InCombatLockdown)
		parts[#parts + 1] = "combat=" .. tostring(ok and v and true or false)
	end
	if GetRealZoneText then
		local ok, v = pcall(GetRealZoneText)
		if ok and type(v) == "string" then parts[#parts + 1] = "zone=" .. v end
	end
	if IsInInstance then
		local ok, inside, kind = pcall(IsInInstance)
		if ok then parts[#parts + 1] = "instance=" .. tostring(kind or inside) end
	end
	return table.concat(parts, " ")
end

local function record(kind, msg, stack, locals)
	msg = tostring(msg or "")
	local key = kind .. msg
	local e = index[key]
	if e then
		e.count = e.count + 1
		e.last = clock()
	else
		e = {
			kind = kind, msg = msg, stack = stack or "", locals = locals or "",
			addon = addonOf(msg) or addonOf(stack) or "?",
			count = 1, time = clock(), last = clock(), session = session, state = state(),
		}
		index[key] = e
		errors[#errors + 1] = e
		while #errors > MAX do
			local old = table.remove(errors, 1)
			index[old.kind .. old.msg] = nil
		end
		local now = GetTime and GetTime() or 0
		if ABugDB and ABugDB.notify ~= false and now - lastNotice > 5 then
			lastNotice = now
			print("|cffff5555ABug|r: " .. kind .. " in |cffffd100" .. e.addon .. "|r  -  /abug")
		end
	end
	changed()
	return e
end

local function handler(msg)
	if busy then return end
	busy = true
	local stack, locals = "", ""
	if debugstack then
		local ok, s = pcall(debugstack, 3, 30, 30)
		if ok and type(s) == "string" then stack = s end
	end
	if debuglocals then
		local ok, l = pcall(debuglocals, 3)
		if ok and type(l) == "string" then locals = l:sub(1, 4000) end
	end
	pcall(record, "error", msg, stack, locals)
	busy = false
end

if seterrorhandler then pcall(seterrorhandler, handler) end

function ABug.Log(kind, msg)
	local stack = ""
	if debugstack then
		local ok, s = pcall(debugstack, 2, 20, 20)
		if ok and type(s) == "string" then stack = s end
	end
	return record(kind or "note", msg, stack)
end

function ABug.Count(current)
	if not current then return #errors end
	local n = 0
	for _, e in ipairs(errors) do
		if e.session == session then n = n + 1 end
	end
	return n
end

function ns.Session()
	return session
end

function ns.Clear()
	for i = #errors, 1, -1 do errors[i] = nil end
	for k in pairs(index) do index[k] = nil end
	changed()
end

function ns.Text(e)
	local lines = {
		e.count .. "x  [" .. e.kind .. "]  " .. e.addon .. "  " .. e.time .. (e.count > 1 and ("  (last " .. e.last .. ")") or ""),
		e.msg,
	}
	if e.state and e.state ~= "" then lines[#lines + 1] = e.state end
	if e.stack and e.stack ~= "" then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Stack:"
		lines[#lines + 1] = e.stack
	end
	if e.locals and e.locals ~= "" then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Locals:"
		lines[#lines + 1] = e.locals
	end
	return table.concat(lines, "\n")
end

local frame = CreateFrame("Frame")
local function reg(event)
	pcall(frame.RegisterEvent, frame, event)
end
reg("ADDON_LOADED")
reg("PLAYER_LOGIN")
reg("ADDON_ACTION_BLOCKED")
reg("ADDON_ACTION_FORBIDDEN")
reg("MACRO_ACTION_BLOCKED")
reg("MACRO_ACTION_FORBIDDEN")
reg("LUA_WARNING")

frame:SetScript("OnEvent", function(_, event, a, b)
	if event == "ADDON_LOADED" then
		if a ~= ADDON then return end
		ABugDB = ABugDB or {}
		local db = ABugDB
		db.session = (db.session or 0) + 1
		session = db.session
		local old = db.errors or {}
		local early = {}
		for i, e in ipairs(errors) do early[i] = e end
		for i = #errors, 1, -1 do errors[i] = nil end
		for k in pairs(index) do index[k] = nil end
		for _, e in ipairs(old) do
			if type(e) == "table" and e.msg and session - (e.session or 0) <= 10 then
				errors[#errors + 1] = e
				index[(e.kind or "error") .. e.msg .. "#" .. (e.session or 0)] = e
			end
		end
		for _, e in ipairs(early) do
			e.session = session
			errors[#errors + 1] = e
			index[e.kind .. e.msg] = e
		end
		while #errors > MAX do table.remove(errors, 1) end
		db.errors = errors
		local build = GetBuildInfo and { GetBuildInfo() } or {}
		db.client = tostring(build[1]) .. " " .. tostring(build[2]) .. " " .. tostring(build[4])
		changed()
	elseif event == "PLAYER_LOGIN" then
		if ACore and ACore.Register then
			ACore.Register({
				name = "ABug", title = "ABug", slash = "/abug", desc = "error catcher",
				toggle = function() ns.Toggle() end,
			})
		end
		local n = ABug.Count(true)
		if n > 0 then
			print("|cffff5555ABug|r: " .. n .. (n == 1 and " problem" or " problems") .. " while loading  -  /abug")
		end
	elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		local stack = ""
		if debugstack then
			local ok, s = pcall(debugstack, 2, 30, 30)
			if ok and type(s) == "string" then stack = s end
		end
		local kind = event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked"
		local e = record(kind, "Interface/AddOns/" .. tostring(a) .. "/: tried to call protected function '" .. tostring(b) .. "'", stack)
		if e then e.addon = tostring(a) end
	elseif event == "MACRO_ACTION_BLOCKED" or event == "MACRO_ACTION_FORBIDDEN" then
		record("macro", "macro tried to call protected function '" .. tostring(a) .. "'", "")
	elseif event == "LUA_WARNING" then
		record("warning", tostring(b or a), "")
	end
end)

SLASH_ABUG1 = "/abug"
SlashCmdList["ABUG"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "clear" then
		ns.Clear()
		print("|cffff5555ABug|r: cleared")
	elseif msg == "quiet" then
		ABugDB.notify = ABugDB.notify == false
		print("|cffff5555ABug|r: chat notices " .. (ABugDB.notify and "on" or "off"))
	elseif msg == "test" then
		local t = nil
		local x = t.missing
	else
		ns.Toggle()
	end
end
