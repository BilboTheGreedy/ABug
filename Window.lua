local _, ns = ...

local frame
local rows = {}
local shown = {}
local offset = 0
local selected
local onlyCurrent = true
local ROWS = 18

local KIND = {
	error = { 1, 0.35, 0.35 }, forbidden = { 1, 0.55, 0.2 }, blocked = { 1, 0.75, 0.3 },
	warning = { 0.9, 0.9, 0.4 }, macro = { 0.7, 0.7, 0.9 }, note = { 0.6, 0.8, 1 },
}

local function fill(f, r, g, b, a, layer)
	local t = f:CreateTexture(nil, layer or "BACKGROUND")
	t:SetColorTexture(r, g, b, a)
	t:SetAllPoints(f)
	return t
end

local function button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, 22)
	fill(b, 0.12, 0.125, 0.15, 1)
	fill(b, 1, 1, 1, 0.08, "HIGHLIGHT")
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.label:SetPoint("CENTER")
	b.label:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function collect()
	for i = #shown, 1, -1 do shown[i] = nil end
	local session = ns.Session()
	for i = #ns.errors, 1, -1 do
		local e = ns.errors[i]
		if not onlyCurrent or e.session == session then shown[#shown + 1] = e end
	end
end

local function refresh()
	if not frame or not frame:IsShown() then return end
	collect()
	local max = math.max(0, #shown - ROWS)
	if offset > max then offset = max end
	if offset < 0 then offset = 0 end
	local found = false
	for i = 1, ROWS do
		local row = rows[i]
		local e = shown[offset + i]
		row.entry = e
		if e then
			local c = KIND[e.kind] or KIND.error
			row.kind:SetText(e.count .. "x")
			row.kind:SetTextColor(c[1], c[2], c[3])
			row.text:SetText("|cffffd100" .. e.addon .. "|r  " .. e.msg:gsub("[Ii]nterface[/\\][Aa]dd[Oo]ns[/\\]", ""))
			row.sel:SetShown(e == selected)
			if e == selected then found = true end
			row:Show()
		else
			row:Hide()
		end
	end
	if not found then
		for _, e in ipairs(shown) do
			if e == selected then found = true break end
		end
	end
	if not found then selected = shown[1] end
	for i = 1, ROWS do rows[i].sel:SetShown(rows[i].entry ~= nil and rows[i].entry == selected) end
	frame.box:SetText(selected and ns.Text(selected) or "Nothing caught.")
	frame.box:SetCursorPosition(0)
	frame.count:SetText(#shown .. (onlyCurrent and " this session" or " in the last sessions"))
	frame.scope.label:SetText(onlyCurrent and "Show older" or "This session")
end

local function build()
	frame = CreateFrame("Frame", "ABugFrame", UIParent)
	frame:SetSize(860, 480)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	fill(frame, 0.06, 0.065, 0.08, 0.97)
	if UISpecialFrames then table.insert(UISpecialFrames, "ABugFrame") end

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 12, -9)
	title:SetText("ABug")
	title:SetTextColor(1, 0.35, 0.35)
	frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.count:SetPoint("LEFT", title, "RIGHT", 12, 0)

	local close = button(frame, "x", 24, function() frame:Hide() end)
	close:SetPoint("TOPRIGHT", -8, -6)
	local clear = button(frame, "Clear", 60, function()
		ns.Clear()
		selected = nil
	end)
	clear:SetPoint("RIGHT", close, "LEFT", -6, 0)
	frame.scope = button(frame, "Show older", 90, function()
		onlyCurrent = not onlyCurrent
		offset = 0
		refresh()
	end)
	frame.scope:SetPoint("RIGHT", clear, "LEFT", -6, 0)
	local all = button(frame, "Select text", 90, function()
		frame.box:SetFocus()
		frame.box:HighlightText()
	end)
	all:SetPoint("RIGHT", frame.scope, "LEFT", -6, 0)

	local list = CreateFrame("Frame", nil, frame)
	list:SetPoint("TOPLEFT", 8, -36)
	list:SetPoint("BOTTOMLEFT", 8, 8)
	list:SetWidth(330)
	fill(list, 0.09, 0.095, 0.115, 1)
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta)
		offset = offset - delta * 3
		refresh()
	end)
	for i = 1, ROWS do
		local row = CreateFrame("Button", nil, list)
		row:SetHeight(24)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
		row:SetPoint("RIGHT", 0, 0)
		row.sel = fill(row, 1, 0.82, 0, 0.16)
		fill(row, 1, 1, 1, 0.07, "HIGHLIGHT")
		row.kind = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.kind:SetPoint("LEFT", 6, 0)
		row.kind:SetWidth(30)
		row.kind:SetJustifyH("LEFT")
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.text:SetPoint("LEFT", 38, 0)
		row.text:SetPoint("RIGHT", -4, 0)
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(false)
		row:SetScript("OnClick", function(self)
			selected = self.entry
			refresh()
		end)
		rows[i] = row
	end

	local scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", list, "TOPRIGHT", 8, 0)
	scroll:SetPoint("BOTTOMRIGHT", -8, 8)
	fill(scroll, 0.03, 0.03, 0.04, 1)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject("GameFontHighlightSmall")
	box:SetWidth(500)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	scroll:SetScrollChild(box)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange() or 0
		local v = (self:GetVerticalScroll() or 0) - delta * 40
		if v < 0 then v = 0 end
		if v > range then v = range end
		self:SetVerticalScroll(v)
	end)
	scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
	frame.box = box
	frame:Hide()
end

function ns.Toggle()
	if not frame then build() end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		refresh()
	end
end

ns.OnChange(refresh)
