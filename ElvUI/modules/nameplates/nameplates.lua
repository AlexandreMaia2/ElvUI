local E, L, V, P, G = unpack(select(2, ...)); --Inport: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local mod = E:NewModule('NamePlates', 'AceHook-3.0', 'AceEvent-3.0', 'AceTimer-3.0')
local LSM = LibStub("LibSharedMedia-3.0")

function mod:ClassBar_Update(frame)
	if(not self.ClassBar) then return end
	local targetFrame = C_NamePlate.GetNamePlateForUnit("target")
	
	if(self.PlayerFrame) then
		frame = self.PlayerFrame.UnitFrame
		self.ClassBar:SetParent(frame)
		self.ClassBar:ClearAllPoints()
		self.ClassBar:ClearAllPoints()
		self.ClassBar:SetPoint("BOTTOM", frame.TopLevelFrame or frame.HealthBar, "TOP", 0, frame.TopOffset or 12)
		self.ClassBar:Show()		
	elseif(targetFrame) then
		frame = targetFrame.UnitFrame
		if(frame.UnitType == "FRIENDLY_NPC" or frame.UnitType == "FRIENDLY_PLAYER" or frame.UnitType == "HEALER") then
			self.ClassBar:Hide()
		else
			self.ClassBar:SetParent(frame)
			self.ClassBar:ClearAllPoints()
			self.ClassBar:SetPoint("BOTTOM", frame.TopLevelFrame or frame.HealthBar, "TOP", 0, frame.TopOffset or 12)
			self.ClassBar:Show()
		end
	else
		self.ClassBar:Hide()
	end	
end

function mod:SetFrameScale(frame, scale)
	if(frame.HealthBar.currentScale ~= scale) then
		if(frame.HealthBar.scale:IsPlaying()) then
			frame.HealthBar.scale:Stop()
		end	
		frame.HealthBar.scale.width:SetChange(self.db.units[frame.UnitType].healthbar.width  * scale)
		frame.HealthBar.scale.height:SetChange(self.db.units[frame.UnitType].healthbar.height * scale)	
		frame.HealthBar.scale:Play()
		frame.HealthBar.currentScale = scale
	end
end

function mod:SetTargetFrame(frame)
	--Match parent's frame level for targetting purposes. Best time to do it is here.
	local parent = C_NamePlate.GetNamePlateForUnit(frame.unit);
	frame:SetFrameLevel(parent:GetFrameLevel())
	
	if(UnitIsUnit(frame.unit, "target") and not frame.isTarget) then
		self:SetFrameScale(frame, self.db.targetScale)
		frame.isTarget = true
		if(self.db.units[frame.UnitType].healthbar.enable ~= true) then
			frame.Name:ClearAllPoints()
			frame.Level:ClearAllPoints()
			frame.HealthBar.r, frame.HealthBar.g, frame.HealthBar.b = nil, nil, nil
			frame.CastBar:Hide()
			self:ConfigureElement_HealthBar(frame)
			self:ConfigureElement_PowerBar(frame)
			self:ConfigureElement_CastBar(frame)
			self:ConfigureElement_Glow(frame)	

			self:ConfigureElement_Level(frame)
			self:ConfigureElement_Name(frame)
			self:RegisterEvents(frame, frame.unit)
			self:UpdateElement_All(frame, frame.unit, true)
		end
	elseif (frame.isTarget) then
		self:SetFrameScale(frame, frame.ThreatScale or 1)
		frame.isTarget = nil
		if(self.db.units[frame.UnitType].healthbar.enable ~= true) then
			local unit = frame.unit
			mod:NAME_PLATE_UNIT_REMOVED("NAME_PLATE_UNIT_REMOVED", unit)
			mod:NAME_PLATE_UNIT_ADDED("NAME_PLATE_UNIT_ADDED", unit)		
		end		
	end
	
	mod:ClassBar_Update(frame)
end

function mod:StyleFrame(frame, useBackdrop)
	local parent = frame
	if(parent:GetObjectType() == "Texture") then
		parent = frame:GetParent()
	end
	if(useBackdrop) then
		frame.backdropTex = parent:CreateTexture(nil, "BACKGROUND")
		frame.backdropTex:SetAllPoints()
		frame.backdropTex:SetColorTexture(0.1, 0.1, 0.1, 0.85)
	end
	
	frame.top = parent:CreateTexture(nil, "BORDER")
	frame.top:SetPoint("TOPLEFT", frame, "TOPLEFT", -self.mult, self.mult)
	frame.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", self.mult, self.mult)
	frame.top:SetHeight(self.mult)
	frame.top:SetColorTexture(0, 0, 0, 1)
	frame.top:SetDrawLayer("BORDER", 1)

	frame.bottom = parent:CreateTexture(nil, "BORDER")
	frame.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -self.mult, -self.mult)
	frame.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", self.mult, -self.mult)
	frame.bottom:SetHeight(self.mult)
	frame.bottom:SetColorTexture(0, 0, 0, 1)
	frame.bottom:SetDrawLayer("BORDER", 1)

	frame.left = parent:CreateTexture(nil, "BORDER")
	frame.left:SetPoint("TOPLEFT", frame, "TOPLEFT", -self.mult, self.mult)
	frame.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", self.mult, -self.mult)
	frame.left:SetWidth(self.mult)
	frame.left:SetColorTexture(0, 0, 0, 1)
	frame.left:SetDrawLayer("BORDER", 1)

	frame.right = parent:CreateTexture(nil, "BORDER")
	frame.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", self.mult, self.mult)
	frame.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -self.mult, -self.mult)
	frame.right:SetWidth(self.mult)
	frame.right:SetColorTexture(0, 0, 0, 1)
	frame.right:SetDrawLayer("BORDER", 1)
end


function mod:DISPLAY_SIZE_CHANGED()
	self.mult = E.mult --[[* UIParent:GetScale()]]	
end

function mod:CheckUnitType(frame)
	local unit = frame.unit
	local role = UnitGroupRolesAssigned(unit)
	local CanAttack = UnitCanAttack("player", unit)

	if(role == "HEALER" and frame.UnitType ~= "HEALER") then
		mod:NAME_PLATE_UNIT_REMOVED("NAME_PLATE_UNIT_REMOVED", unit)
		mod:NAME_PLATE_UNIT_ADDED("NAME_PLATE_UNIT_ADDED", unit)	
	elseif(frame.UnitType == "FRIENDLY_PLAYER" or frame.UnitType == "FRIENDLY_NPC" or frame.UnitType == "HEALER") then
		if(CanAttack) then
			mod:NAME_PLATE_UNIT_REMOVED("NAME_PLATE_UNIT_REMOVED", unit)
			mod:NAME_PLATE_UNIT_ADDED("NAME_PLATE_UNIT_ADDED", unit)
		end
	elseif(frame.UnitType == "ENEMY_PLAYER" or frame.UnitType == "ENEMY_NPC") then
		if(not CanAttack) then
			mod:NAME_PLATE_UNIT_REMOVED("NAME_PLATE_UNIT_REMOVED", unit)
			mod:NAME_PLATE_UNIT_ADDED("NAME_PLATE_UNIT_ADDED", unit)
		end	
	end
end

function mod:NAME_PLATE_UNIT_ADDED(event, unit)
	local frame = C_NamePlate.GetNamePlateForUnit(unit);
	frame.UnitFrame.unit = unit
	
	local CanAttack = UnitCanAttack(unit, "player")
	local isPlayer = UnitIsPlayer(unit)
	
	if(UnitIsUnit(unit, "player")) then
		frame.UnitFrame.UnitType = "PLAYER"
	elseif(not CanAttack and isPlayer) then
		local role = UnitGroupRolesAssigned(unit)
		if(role == "HEALER") then
			frame.UnitFrame.UnitType = role
		else
			frame.UnitFrame.UnitType = "FRIENDLY_PLAYER"
		end
	elseif(not CanAttack and not isPlayer) then
		frame.UnitFrame.UnitType = "FRIENDLY_NPC"
	elseif(CanAttack and isPlayer) then
		frame.UnitFrame.UnitType = "ENEMY_PLAYER"
	else
		frame.UnitFrame.UnitType = "ENEMY_NPC"
	end

	if(frame.UnitFrame.UnitType == "PLAYER") then
		mod.PlayerFrame = frame
	end
	
	if(self.db.units[frame.UnitFrame.UnitType].healthbar.enable) then
		self:ConfigureElement_HealthBar(frame.UnitFrame)
		self:ConfigureElement_PowerBar(frame.UnitFrame)
		self:ConfigureElement_CastBar(frame.UnitFrame)
		self:ConfigureElement_Glow(frame.UnitFrame)	
	end
	
	self:ConfigureElement_Level(frame.UnitFrame)
	self:ConfigureElement_Name(frame.UnitFrame)

	self:RegisterEvents(frame.UnitFrame, unit)
	self:UpdateElement_All(frame.UnitFrame, unit)
	frame.UnitFrame:Show()
end

function mod:NAME_PLATE_UNIT_REMOVED(event, unit, ...)
	local frame = C_NamePlate.GetNamePlateForUnit(unit);
	frame.UnitFrame.unit = nil
	
	local unitType = frame.UnitFrame.UnitType
	if(frame.UnitFrame.UnitType == "PLAYER") then
		mod.PlayerFrame = nil
	end

	frame.UnitFrame:UnregisterAllEvents()
	frame.UnitFrame.Glow.r, frame.UnitFrame.Glow.g, frame.UnitFrame.Glow.b = nil, nil, nil
	frame.UnitFrame.Glow:Hide()	
	frame.UnitFrame.HealthBar.r, frame.UnitFrame.HealthBar.g, frame.UnitFrame.HealthBar.b = nil, nil, nil
	frame.UnitFrame.HealthBar:Hide()
	frame.UnitFrame.PowerBar:Hide()
	frame.UnitFrame.CastBar:Hide()
	frame.UnitFrame.AbsorbBar:Hide()
	frame.UnitFrame.HealPrediction:Hide()
	frame.UnitFrame.PersonalHealPrediction:Hide()
	frame.UnitFrame.Name:ClearAllPoints()
	frame.UnitFrame.Level:ClearAllPoints()
	frame.UnitFrame.Level:SetText("")
	frame.UnitFrame.Name:SetText("")
	frame.UnitFrame:Hide()
	frame.UnitFrame.isTarget = nil
	frame.ThreatData = nil
	frame.UnitFrame.UnitType = nil
	
	if(self.ClassBar) then
		if(unitType == "PLAYER") then
			mod:ClassBar_Update(frame)
		end
	end
end

function mod:ForEachPlate(functionToRun, ...)
	for _, frame in pairs(C_NamePlate.GetNamePlates()) do
		if(frame) then
			self[functionToRun](frame.UnitFrame, ...)
		end
	end
end

function mod:SetBaseNamePlateSize()
	local self = mod
	local baseWidth = self.db.units["ENEMY_NPC"].healthbar.width
	local baseHeight = self.db.units["ENEMY_NPC"].castbar.height + self.db.units["ENEMY_NPC"].healthbar.height + 30
	NamePlateDriverFrame:SetBaseNamePlateSize(baseWidth, baseHeight)
end

function mod:UpdateElement_All(frame, unit, noTargetFrame)
	mod:UpdateElement_MaxHealth(frame)
	mod:UpdateElement_Health(frame)
	mod:UpdateElement_HealthColor(frame)
	mod:UpdateElement_Name(frame)
	mod:UpdateElement_Level(frame)
	mod:UpdateElement_Glow(frame)
	mod:UpdateElement_Cast(frame)
	mod:UpdateElement_Auras(frame)
	mod:UpdateElement_RaidIcon(frame)
	mod:UpdateElement_HealPrediction(frame)
	
	if(self.db.units[frame.UnitType].powerbar.enable) then
		frame.PowerBar:Show()
		mod.OnEvent(frame, "UNIT_DISPLAYPOWER", unit)
	end
	
	if(not noTargetFrame) then --infinite loop lol
		mod:SetTargetFrame(frame)
	end
end

function mod:NAME_PLATE_CREATED(event, frame)
	frame.UnitFrame = CreateFrame("BUTTON", frame:GetName().."UnitFrame", UIParent);
	frame.UnitFrame:EnableMouse(false);
	frame.UnitFrame:SetAllPoints(frame)
	frame.UnitFrame:SetFrameStrata("BACKGROUND")
	frame.UnitFrame:SetScript("OnEvent", mod.OnEvent)

	frame.UnitFrame.HealthBar = self:ConstructElement_HealthBar(frame.UnitFrame)
	frame.UnitFrame.PowerBar = self:ConstructElement_PowerBar(frame.UnitFrame)
	frame.UnitFrame.CastBar = self:ConstructElement_CastBar(frame.UnitFrame)
	frame.UnitFrame.Level = self:ConstructElement_Level(frame.UnitFrame)
	frame.UnitFrame.Name = self:ConstructElement_Name(frame.UnitFrame)
	frame.UnitFrame.Glow = self:ConstructElement_Glow(frame.UnitFrame)
	frame.UnitFrame.Buffs = self:ConstructElement_Auras(frame.UnitFrame, 5, "LEFT")
	frame.UnitFrame.Debuffs = self:ConstructElement_Auras(frame.UnitFrame, 5, "RIGHT")
	frame.UnitFrame.RaidIcon = self:ConstructElement_RaidIcon(frame.UnitFrame)
end

function mod:OnEvent(event, unit, ...)
	if(event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT") then
		mod:UpdateElement_Health(self)
		mod:UpdateElement_HealPrediction(self)
	elseif(event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_PREDICTION") then
		mod:UpdateElement_HealPrediction(self)
	elseif(event == "UNIT_MAXHEALTH") then
		mod:UpdateElement_MaxHealth(self)
		mod:UpdateElement_HealPrediction(self)
	elseif(event == "UNIT_NAME_UPDATE") then
		mod:UpdateElement_Name(self)
		mod:UpdateElement_HealthColor(self) --Unit class sometimes takes a bit to load
	elseif(event == "UNIT_LEVEL") then
		mod:UpdateElement_Level(self)
	elseif(event == "UNIT_THREAT_LIST_UPDATE") then
		mod:Update_ThreatList(self)
		mod:UpdateElement_HealthColor(self)
		mod:UpdateElement_Glow(self)
	elseif(event == "PLAYER_TARGET_CHANGED") then
		mod:SetTargetFrame(self)
		mod:UpdateElement_Glow(self)
		mod:UpdateElement_HealthColor(self)
	elseif(event == "UNIT_AURA") then
		mod:UpdateElement_Auras(self)
		if(self.IsPlayerFrame) then
			mod:ClassBar_Update(self)
		end
	elseif(event == "PLAYER_ROLES_ASSIGNED" or event == "UNIT_FACTION") then
		mod:CheckUnitType(self)
	elseif(event == "RAID_TARGET_UPDATE") then
		mod:UpdateElement_RaidIcon(self)
	elseif(event == "UNIT_MAXPOWER") then
		mod:UpdateElement_MaxPower(self)
	elseif(event == "UNIT_POWER" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER") then
		local powerType, powerToken = UnitPowerType(unit)
		local arg1 = ...
		self.PowerToken = powerToken
		self.PowerType = powerType
		if(event == "UNIT_POWER" or event == "UNIT_POWER_FREQUENT") then
			if mod.ClassBar and arg1 == powerToken then
				mod:ClassBar_Update(self)
			end
		end
		
		if arg1 == powerToken or event == "UNIT_DISPLAYPOWER" then
			mod:UpdateElement_Power(self)
		end
	else
		mod:UpdateElement_Cast(self, event, unit, ...)
	end
end

function mod:RegisterEvents(frame, unit)
	if(self.db.units[frame.UnitType].healthbar.enable or frame.isTarget) then
		frame:RegisterUnitEvent("UNIT_MAXHEALTH", unit);
		frame:RegisterUnitEvent("UNIT_HEALTH", unit);
		frame:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", unit);
		frame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", unit);
		frame:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", unit);
		frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", unit);
	end
	
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", unit);
	frame:RegisterUnitEvent("UNIT_LEVEL", unit);

	if(self.db.units[frame.UnitType].healthbar.enable or frame.isTarget) then
		if(frame.UnitType == "ENEMY_NPC") then
			frame:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", unit);
		end
		
		if(self.db.units[frame.UnitType].powerbar.enable) then
			frame:RegisterUnitEvent("UNIT_POWER", unit)
			frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", unit)
			frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
			frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
		end

		if(self.db.units[frame.UnitType].castbar.enable) then
			frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED");
			frame:RegisterEvent("UNIT_SPELLCAST_DELAYED");
			frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START");
			frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE");
			frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP");
			frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE");
			frame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE");	
			frame:RegisterUnitEvent("UNIT_SPELLCAST_START", unit);
			frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit);
			frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit);	
		end
		
		frame:RegisterEvent("PLAYER_ENTERING_WORLD");
		frame:RegisterUnitEvent("UNIT_AURA", unit)
		frame:RegisterEvent("RAID_TARGET_UPDATE")	
		mod.OnEvent(frame, "PLAYER_ENTERING_WORLD")	
	end
	
	frame:RegisterEvent("PLAYER_TARGET_CHANGED");	
	frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	frame:RegisterEvent("UNIT_FACTION")
end

function mod:SetClassNameplateBar(frame)
	mod.ClassBar = frame
	if(frame) then
		frame:SetScale(1.35)
	end
end

function mod:Initialize()
	self.db = E.db["nameplate"]
	if E.private["nameplate"].enable ~= true then return end
	E.NamePlates = NP

	NamePlateDriverFrame:UnregisterAllEvents()
	NamePlateDriverFrame.ApplyFrameOptions = E.noop
	self:RegisterEvent("NAME_PLATE_CREATED");
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED");
	self:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
	self:RegisterEvent("DISPLAY_SIZE_CHANGED");
	
	--Best to just Hijack Blizzard's nameplate classbar
	self.ClassBar = NamePlateDriverFrame.nameplateBar
	if(self.ClassBar) then
		self.ClassBar:SetScale(1.35)
	end
	hooksecurefunc(NamePlateDriverFrame, "SetClassNameplateBar", mod.SetClassNameplateBar)

	self:DISPLAY_SIZE_CHANGED() --Run once for good measure.
	self:SetBaseNamePlateSize()
end


E:RegisterModule(mod:GetName())