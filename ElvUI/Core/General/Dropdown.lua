local E, L, V, P, G = unpack(ElvUI)

local _G = _G
local tinsert = tinsert

local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local ToggleFrame = ToggleFrame
local UIParent = UIParent

local PADDING = 10
local BUTTON_HEIGHT = 16
local BUTTON_WIDTH = 135

local function OnClick(btn)
	btn.func()
	btn:GetParent():Hide()
end

local function OnEnter(btn)
	btn.hoverTex:Show()
end

local function OnLeave(btn)
	btn.hoverTex:Hide()
end

function E:DropDown(list, frame, xOffset, yOffset)
	if not frame.buttons then
		frame.buttons = {}
		frame:SetFrameStrata('DIALOG')
		frame:SetClampedToScreen(true)
		tinsert(_G.UISpecialFrames, frame:GetName())
		frame:Hide()
	end

	xOffset = xOffset or 0
	yOffset = yOffset or 0

	for i = 1, #frame.buttons do
		frame.buttons[i]:Hide()
	end

	for i = 1, #list do
		if not frame.buttons[i] then
			frame.buttons[i] = CreateFrame('Button', nil, frame)

			frame.buttons[i].hoverTex = frame.buttons[i]:CreateTexture(nil, 'OVERLAY')
			frame.buttons[i].hoverTex:SetAllPoints()
			frame.buttons[i].hoverTex:SetTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
			frame.buttons[i].hoverTex:SetBlendMode('ADD')
			frame.buttons[i].hoverTex:Hide()

			frame.buttons[i].text = frame.buttons[i]:CreateFontString(nil, 'BORDER')
			frame.buttons[i].text:SetAllPoints()
			frame.buttons[i].text:FontTemplate(nil, nil, '')
			frame.buttons[i].text:SetJustifyH('LEFT')

			frame.buttons[i]:SetScript('OnEnter', OnEnter)
			frame.buttons[i]:SetScript('OnLeave', OnLeave)
		end

		frame.buttons[i]:Show()
		frame.buttons[i]:Height(BUTTON_HEIGHT)
		frame.buttons[i]:Width(BUTTON_WIDTH)
		frame.buttons[i].text:SetText(list[i].text)
		frame.buttons[i].func = list[i].func
		frame.buttons[i]:SetScript('OnClick', OnClick)

		if i == 1 then
			frame.buttons[i]:Point('TOPLEFT', frame, 'TOPLEFT', PADDING, -PADDING)
		else
			frame.buttons[i]:Point('TOPLEFT', frame.buttons[i-1], 'BOTTOMLEFT')
		end
	end

	frame:Height((#list * BUTTON_HEIGHT) + PADDING * 2)
	frame:Width(BUTTON_WIDTH + PADDING * 2)

	local x, y = GetCursorPosition()

	frame:ClearAllPoints()
	frame:Point('TOPLEFT', UIParent, 'BOTTOMLEFT', (x / E.uiscale) + xOffset, (y / E.uiscale) + yOffset)

	ToggleFrame(frame)
end
