﻿local E, L, V, P, G = unpack(select(2, ...)); --Inport: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local mod = E:NewModule('NamePlates', 'AceHook-3.0', 'AceEvent-3.0', 'AceTimer-3.0')
local LSM = LibStub("LibSharedMedia-3.0")

--Cache global variables
--Lua functions
local select = select
local next = next
local unpack = unpack
local ipairs = ipairs
local tonumber = tonumber
local strsplit = strsplit
local pairs, type = pairs, type
local twipe = table.wipe
local tsort = table.sort
local tinsert = table.insert
local format = string.format
local match = string.match
--WoW API / Variables
local CreateFrame = CreateFrame
local C_NamePlate_GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local C_NamePlate_GetNamePlates = C_NamePlate.GetNamePlates
local C_NamePlate_SetNamePlateEnemyClickThrough = C_NamePlate.SetNamePlateEnemyClickThrough
local C_NamePlate_SetNamePlateFriendlyClickThrough = C_NamePlate.SetNamePlateFriendlyClickThrough
local C_NamePlate_SetNamePlateSelfClickThrough = C_NamePlate.SetNamePlateSelfClickThrough
local C_NamePlate_SetNamePlateFriendlySize = C_NamePlate.SetNamePlateFriendlySize
local C_NamePlate_SetNamePlateEnemySize = C_NamePlate.SetNamePlateEnemySize
local C_NamePlate_SetNamePlateSelfSize = C_NamePlate.SetNamePlateSelfSize
local C_Timer_After = C_Timer.After
local GetArenaOpponentSpec = GetArenaOpponentSpec
local GetBattlefieldScore = GetBattlefieldScore
local GetNumArenaOpponentSpecs = GetNumArenaOpponentSpecs
local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetSpecializationInfoByID = GetSpecializationInfoByID
local hooksecurefunc = hooksecurefunc
local IsInInstance = IsInInstance
local RegisterUnitWatch = RegisterUnitWatch
local SetCVar = SetCVar
local UnitAffectingCombat = UnitAffectingCombat
local UnitCanAttack = UnitCanAttack
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsDead = UnitIsDead
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitName = UnitName
local UnitPowerType = UnitPowerType
local UnitGUID = UnitGUID
local UnitLevel = UnitLevel
local UnitReaction = UnitReaction
local UnregisterUnitWatch = UnregisterUnitWatch
local UNKNOWN = UNKNOWN

--Global variables that we don't cache, list them here for the mikk's Find Globals script
-- GLOBALS: NamePlateDriverFrame, UIParent, InterfaceOptionsNamesPanelUnitNameplates

--Taken from Blizzard_TalentUI.lua
local healerSpecIDs = {
	105,	--Druid Restoration
	270,	--Monk Mistweaver
	65,		--Paladin Holy
	256,	--Priest Discipline
	257,	--Priest Holy
	264,	--Shaman Restoration
}

mod.HealerSpecs = {}
mod.Healers = {};

--Get localized healing spec names
for _, specID in pairs(healerSpecIDs) do
	local _, name = GetSpecializationInfoByID(specID)
	if name and not mod.HealerSpecs[name] then
		mod.HealerSpecs[name] = true
	end
end

function mod:CheckBGHealers()
	local name, _, talentSpec
	for i = 1, GetNumBattlefieldScores() do
		name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, talentSpec = GetBattlefieldScore(i);
		if name then
			name = name:match("(.+)%-.+") or name
			if name and self.HealerSpecs[talentSpec] then
				self.Healers[name] = talentSpec
			elseif name and self.Healers[name] then
				self.Healers[name] = nil;
			end
		end
	end
end

function mod:CheckArenaHealers()
	local numOpps = GetNumArenaOpponentSpecs()
	if not (numOpps > 1) then return end

	for i=1, 5 do
		local name = UnitName(format('arena%d', i))
		if name and name ~= UNKNOWN then
			local s = GetArenaOpponentSpec(i)
			local _, talentSpec = nil, UNKNOWN
			if s and s > 0 then
				_, talentSpec = GetSpecializationInfoByID(s)
			end

			if talentSpec and talentSpec ~= UNKNOWN and self.HealerSpecs[talentSpec] then
				self.Healers[name] = talentSpec
			end
		end
	end
end

function mod:PLAYER_ENTERING_WORLD()
	twipe(self.Healers)
	local inInstance, instanceType = IsInInstance()
	if inInstance and instanceType == 'pvp' and self.db.units.ENEMY_PLAYER.markHealers then
		self.CheckHealerTimer = self:ScheduleRepeatingTimer("CheckBGHealers", 3)
		self:CheckBGHealers()
	elseif inInstance and instanceType == 'arena' and self.db.units.ENEMY_PLAYER.markHealers then
		self:RegisterEvent('UNIT_NAME_UPDATE', 'CheckArenaHealers')
		self:RegisterEvent("ARENA_OPPONENT_UPDATE", 'CheckArenaHealers');
		self:CheckArenaHealers()
	else
		self:UnregisterEvent('UNIT_NAME_UPDATE')
		self:UnregisterEvent("ARENA_OPPONENT_UPDATE")
		if self.CheckHealerTimer then
			self:CancelTimer(self.CheckHealerTimer)
			self.CheckHealerTimer = nil;
		end
	end
	if self.db.units.PLAYER.useStaticPosition then
		mod:UpdateVisibility()
	end
end

function mod:ClassBar_Update(frame)
	if(not self.ClassBar) then return end

	if(self.db.classbar.enable) then
		local targetFrame = self:GetNamePlateForUnit("target")

		if(self.PlayerFrame and self.db.classbar.attachTo == "PLAYER" and not UnitHasVehicleUI("player")) then
			frame = self.PlayerFrame.UnitFrame
			self.ClassBar:SetParent(frame)
			self.ClassBar:ClearAllPoints()

			if(self.db.classbar.position == "ABOVE") then
				self.ClassBar:SetPoint("BOTTOM", frame.TopLevelFrame or frame.HealthBar, "TOP", 0, frame.TopOffset or 15)
			else
				if(frame.CastBar:IsShown()) then
					frame.BottomOffset = -8
					frame.BottomLevelFrame = frame.CastBar
				elseif(frame.PowerBar:IsShown()) then
					frame.BottomOffset = nil
					frame.BottomLevelFrame = frame.PowerBar
				else
					frame.BottomOffset = nil
					frame.BottomLevelFrame = frame.HealthBar
				end
				self.ClassBar:SetPoint("TOP", frame.BottomLevelFrame or frame.CastBar, "BOTTOM", 3, frame.BottomOffset or -2)
			end
			self.ClassBar:Show()
		elseif(targetFrame and self.db.classbar.attachTo == "TARGET" and not UnitHasVehicleUI("player")) then
			frame = targetFrame.UnitFrame
			if(frame.UnitType == "FRIENDLY_NPC" or frame.UnitType == "FRIENDLY_PLAYER" or frame.UnitType == "HEALER") then
				self.ClassBar:Hide()
			else
				self.ClassBar:SetParent(frame)
				self.ClassBar:ClearAllPoints()

				if(self.db.classbar.position == "ABOVE") then
					self.ClassBar:SetPoint("BOTTOM", frame.TopLevelFrame or frame.HealthBar, "TOP", 0, frame.TopOffset or 15)
				else
					if(frame.CastBar:IsShown()) then
						frame.BottomOffset = -8
						frame.BottomLevelFrame = frame.CastBar
					elseif(frame.PowerBar:IsShown()) then
						frame.BottomOffset = nil
						frame.BottomLevelFrame = frame.PowerBar
					else
						frame.BottomOffset = nil
						frame.BottomLevelFrame = frame.HealthBar
					end
					self.ClassBar:SetPoint("TOP", frame.BottomLevelFrame or frame.CastBar, "BOTTOM", 3, frame.BottomOffset or -2)
				end
				self.ClassBar:Show()
			end
		else
			self.ClassBar:Hide()
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

function mod:GetNamePlateForUnit(unit)
	if(unit == "player" and self.db.units.PLAYER.useStaticPosition and self.db.units.PLAYER.enable) then
		return self.PlayerFrame__
	else
		return C_NamePlate_GetNamePlateForUnit(unit)
	end
end

function mod:SetTargetFrame(frame)
	--Match parent's frame level for targetting purposes. Best time to do it is here.
	local parent = self:GetNamePlateForUnit(frame.unit);
	if(parent) then
		if frame:GetFrameLevel() < 100 then
			frame:SetFrameLevel(parent:GetFrameLevel() + 100)
		end

		frame:SetFrameLevel(parent:GetFrameLevel() + 3)
		frame.Glow:SetFrameLevel(parent:GetFrameLevel() + 1)
		frame.Buffs:SetFrameLevel(parent:GetFrameLevel() + 2)
		frame.Debuffs:SetFrameLevel(parent:GetFrameLevel() + 2)
	end

	local targetExists = UnitExists("target")
	if(UnitIsUnit(frame.unit, "target") and not frame.isTarget) then
		frame:SetFrameLevel(parent:GetFrameLevel() + 5)
		frame.Glow:SetFrameLevel(parent:GetFrameLevel() + 3)
		frame.Buffs:SetFrameLevel(parent:GetFrameLevel() + 4)
		frame.Debuffs:SetFrameLevel(parent:GetFrameLevel() + 4)

		if(self.db.useTargetScale) then
			self:SetFrameScale(frame, self.db.targetScale)
		end
		frame.isTarget = true
		if(self.db.units[frame.UnitType].healthbar.enable ~= true and self.db.alwaysShowTargetHealth) then
			frame.Name:ClearAllPoints()
			frame.NPCTitle:ClearAllPoints()
			frame.Level:ClearAllPoints()
			frame.HealthBar.r, frame.HealthBar.g, frame.HealthBar.b, frame.HealthBar.a = nil, nil, nil, nil
			frame.CastBar:Hide()
			self:ConfigureElement_HealthBar(frame)
			self:ConfigureElement_PowerBar(frame)
			self:ConfigureElement_CastBar(frame)
			self:ConfigureElement_Glow(frame)
			self:ConfigureElement_Elite(frame)
			self:ConfigureElement_Detection(frame)
			self:ConfigureElement_Highlight(frame)
			self:ConfigureElement_Level(frame)
			self:ConfigureElement_Name(frame)
			self:ConfigureElement_NPCTitle(frame)
			self:RegisterEvents(frame, frame.unit)
			self:UpdateElement_All(frame, frame.unit, true)
		end

		if(targetExists) then
			frame:SetAlpha(1)
		end
	elseif (frame.isTarget) then
		if(self.db.useTargetScale) then
			self:SetFrameScale(frame, frame.ThreatScale or 1)
		end
		frame.isTarget = nil
		if(self.db.units[frame.UnitType].healthbar.enable ~= true) then
			self:UpdateAllFrame(frame)
		end

		if(targetExists and not UnitIsUnit(frame.unit, "player")) then
			frame:SetAlpha(1 - self.db.nonTargetTransparency)
		else
			frame:SetAlpha(1)
		end
	else
		if(targetExists and not UnitIsUnit(frame.unit, "player"))  then
			frame:SetAlpha(1 - self.db.nonTargetTransparency)
		else
			frame:SetAlpha(1)
		end
	end

	mod:ClassBar_Update(frame)

	if (self.db.displayStyle == "TARGET" and not frame.isTarget and frame.UnitType ~= "PLAYER") then
		--Hide if we only allow our target to be displayed and the frame is not our current target and the frame is not the player nameplate
		frame:Hide()
	elseif (frame.UnitType ~= "PLAYER" or not self.db.units.PLAYER.useStaticPosition) then --Visibility for static nameplate is handled in UpdateVisibility
		frame:Show()
	end
end

function mod:StyleFrame(frame, useMainFrame)
	local parent = frame

	if(parent:GetObjectType() == "Texture") then
		parent = frame:GetParent()
	end

	if useMainFrame then
		parent:SetTemplate("Transparent")
		return
	end

	parent:CreateBackdrop("Transparent")
end


function mod:DISPLAY_SIZE_CHANGED()
	self.mult = E.mult --[[* UIParent:GetScale()]]
end

function mod:CheckUnitType(frame)
	local role = UnitGroupRolesAssigned(frame.unit)
	local CanAttack = UnitCanAttack(self.playerUnitToken, frame.displayedUnit)

	if(role == "HEALER" and frame.UnitType ~= "HEALER") then
		self:UpdateAllFrame(frame)
	elseif(role ~= "HEALER" and frame.UnitType == "HEALER") then
		self:UpdateAllFrame(frame)
	elseif frame.UnitType == "FRIENDLY_PLAYER" then
		--This line right here is likely the cause of the fps drop when entering world
		--CheckUnitType is being called about 1000 times because the "UNIT_FACTION" event is being triggered this amount of times for some insane reason
		self:UpdateAllFrame(frame)
	elseif(frame.UnitType == "FRIENDLY_NPC" or frame.UnitType == "HEALER") then
		if(CanAttack) then
			self:UpdateAllFrame(frame)
		end
	elseif(frame.UnitType == "ENEMY_PLAYER" or frame.UnitType == "ENEMY_NPC") then
		if(not CanAttack) then
			self:UpdateAllFrame(frame)
		end
	end
end

function mod:NAME_PLATE_UNIT_ADDED(_, unit, frame)
	local frame = frame or self:GetNamePlateForUnit(unit);
	frame.UnitFrame.unit = unit
	frame.UnitFrame.displayedUnit = unit
	self:UpdateInVehicle(frame, true)

	local CanAttack = UnitCanAttack(unit, self.playerUnitToken)
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
		self:UpdateElement_HealerIcon(frame.UnitFrame)
	else
		frame.UnitFrame.UnitType = "ENEMY_NPC"
	end

	if(frame.UnitFrame.UnitType == "PLAYER") then
		self.PlayerFrame = frame
		self.PlayerNamePlateAnchor:SetParent(frame)
		self.PlayerNamePlateAnchor:SetAllPoints(frame.UnitFrame)
		self.PlayerNamePlateAnchor:Show()
	end

	if(self.db.units[frame.UnitFrame.UnitType].healthbar.enable or self.db.displayStyle ~= "ALL") then
		self:ConfigureElement_HealthBar(frame.UnitFrame)
		self:ConfigureElement_PowerBar(frame.UnitFrame)
		self:ConfigureElement_CastBar(frame.UnitFrame)
		self:ConfigureElement_Glow(frame.UnitFrame)

		if(self.db.units[frame.UnitFrame.UnitType].buffs.enable) then
			frame.UnitFrame.Buffs.db = self.db.units[frame.UnitFrame.UnitType].buffs
			self:UpdateAuraIcons(frame.UnitFrame.Buffs)
		end

		if(self.db.units[frame.UnitFrame.UnitType].debuffs.enable) then
			frame.UnitFrame.Debuffs.db = self.db.units[frame.UnitFrame.UnitType].debuffs
			self:UpdateAuraIcons(frame.UnitFrame.Debuffs)
		end
	end

	self:ConfigureElement_Portrait(frame.UnitFrame)
	self:ConfigureElement_Level(frame.UnitFrame)
	self:ConfigureElement_Name(frame.UnitFrame)
	self:ConfigureElement_NPCTitle(frame.UnitFrame)
	self:ConfigureElement_Elite(frame.UnitFrame)
	self:ConfigureElement_Detection(frame.UnitFrame)
	self:ConfigureElement_Highlight(frame.UnitFrame)
	self:RegisterEvents(frame.UnitFrame, unit)
	self:UpdateElement_All(frame.UnitFrame, unit, nil, true)

	if (self.db.displayStyle == "TARGET" and not frame.UnitFrame.isTarget and frame.UnitFrame.UnitType ~= "PLAYER") then
		--Hide if we only allow our target to be displayed and the frame is not our current target and the frame is not the player nameplate
		frame.UnitFrame:Hide()
	elseif (frame.UnitType ~= "PLAYER" or not self.db.units.PLAYER.useStaticPosition) then --Visibility for static nameplate is handled in UpdateVisibility
		frame.UnitFrame:Show()
	end

	self:UpdateElement_Filters(frame.UnitFrame)
end

function mod:NAME_PLATE_UNIT_REMOVED(_, unit, frame)
	local frame = frame or self:GetNamePlateForUnit(unit);
	frame.UnitFrame.unit = nil

	local unitType = frame.UnitFrame.UnitType
	if(frame.UnitFrame.UnitType == "PLAYER") then
		self.PlayerFrame = nil
		self.PlayerNamePlateAnchor:Hide()
	end

	self:HideAuraIcons(frame.UnitFrame.Buffs)
	self:HideAuraIcons(frame.UnitFrame.Debuffs)
	frame.UnitFrame:UnregisterAllEvents()
	frame.UnitFrame.Glow.r, frame.UnitFrame.Glow.g, frame.UnitFrame.Glow.b = nil, nil, nil
	frame.UnitFrame.Glow:Hide()
	frame.UnitFrame.HealthBar.r, frame.UnitFrame.HealthBar.g, frame.UnitFrame.HealthBar.b, frame.UnitFrame.HealthBar.a = nil, nil, nil,nil
	frame.UnitFrame.HealthBar:Hide()
	frame.UnitFrame.PowerBar:Hide()
	frame.UnitFrame.CastBar:Hide()
	frame.UnitFrame.AbsorbBar:Hide()
	frame.UnitFrame.HealPrediction:Hide()
	frame.UnitFrame.PersonalHealPrediction:Hide()
	frame.UnitFrame.Level:ClearAllPoints()
	frame.UnitFrame.Level:SetText("")
	frame.UnitFrame.Name:ClearAllPoints()
	frame.UnitFrame.Name:SetText("")
	frame.UnitFrame.NPCTitle:ClearAllPoints()
	frame.UnitFrame.NPCTitle:SetText("")
	frame.UnitFrame.Elite:Hide()
	frame.UnitFrame.DetectionModel:Hide()
	frame.UnitFrame:Hide()
	frame.UnitFrame.isTarget = nil
	frame.UnitFrame.displayedUnit = nil
	frame.ThreatData = nil
	frame.UnitFrame.UnitType = nil
	frame.UnitFrame.TopLevelFrame = nil

	if(self.ClassBar) then
		if(unitType == "PLAYER") then
			mod:ClassBar_Update(frame)
		end
	end
end

function mod:UpdateAllFrame(frame)
	if(frame == self.PlayerFrame__) then return end

	local unit = frame.unit
	mod:NAME_PLATE_UNIT_REMOVED("NAME_PLATE_UNIT_REMOVED", unit)
	mod:NAME_PLATE_UNIT_ADDED("NAME_PLATE_UNIT_ADDED", unit)
end

function mod:ConfigureAll()
	if E.private.nameplates.enable ~= true then return; end

	--We don't allow player nameplate health to be disabled
	self.db.units.PLAYER.healthbar.enable = true

	self:ForEachPlate("UpdateAllFrame")
	self:UpdateCVars()
	self:TogglePlayerDisplayType()
	self:SetNamePlateClickThrough()
end

function mod:SetNamePlateClickThrough()
	self:SetNamePlateSelfClickThrough()
	self:SetNamePlateFriendlyClickThrough()
	self:SetNamePlateEnemyClickThrough()
end

function mod:SetNamePlateSelfClickThrough()
	C_NamePlate_SetNamePlateSelfClickThrough(self.db.clickThrough.personal)
	self.PlayerFrame__:EnableMouse(not self.db.clickThrough.personal)
end

function mod:SetNamePlateFriendlyClickThrough()
	C_NamePlate_SetNamePlateFriendlyClickThrough(self.db.clickThrough.friendly)
end

function mod:SetNamePlateEnemyClickThrough()
	C_NamePlate_SetNamePlateEnemyClickThrough(self.db.clickThrough.enemy)
end

function mod:ForEachPlate(functionToRun, ...)
	for _, frame in pairs(C_NamePlate_GetNamePlates()) do
		if(frame and frame.UnitFrame) then
			self[functionToRun](self, frame.UnitFrame, ...)
		end
	end
end

function mod:SetBaseNamePlateSize()
	local self = mod
	local baseWidth = self.db.clickableWidth
	local baseHeight = self.db.clickableHeight
	self.PlayerFrame__:SetSize(baseWidth, baseHeight)

	-- this wont taint like NamePlateDriverFrame.SetBaseNamePlateSize
	C_NamePlate_SetNamePlateFriendlySize(baseWidth, baseHeight);
	C_NamePlate_SetNamePlateEnemySize(baseWidth, baseHeight);
	C_NamePlate_SetNamePlateSelfSize(baseWidth, baseHeight);
end

function mod:UpdateInVehicle(frame, noEvents)
	if ( UnitHasVehicleUI(frame.unit) ) then
		if ( not frame.inVehicle ) then
			frame.inVehicle = true;
			if(UnitIsUnit(frame.unit, "player")) then
				frame.displayedUnit = "vehicle"
			else
				local prefix, id, suffix = match(frame.unit, "([^%d]+)([%d]*)(.*)")
				frame.displayedUnit = prefix.."pet"..id..suffix;
			end
			if(not noEvents) then
				self:RegisterEvents(frame, frame.unit)
				self:UpdateElement_All(frame)
			end
		end
	else
		if ( frame.inVehicle ) then
			frame.inVehicle = false;
			frame.displayedUnit = frame.unit;
			if(not noEvents) then
				self:RegisterEvents(frame, frame.unit)
				self:UpdateElement_All(frame)
			end
		end
	end
end

local function filterAura(names, icons, mustHaveAll, missing)
	local total, count = 0, 0
	for name, value in pairs(names) do
		if value == true then --only if they are turned on
			total = total + 1 --keep track of the names
		end
		for frameNum, icon in pairs(icons) do
			if icons[frameNum]:IsShown() and icon.name and icon.name == name and value == true then
				count = count + 1 --keep track of how many matches we have
			end
		end
	end
	return (total == 0) -- no selected auras
	or ((mustHaveAll and not missing) and total == count)				-- [x] Check for all [ ] Missing: total needs to match count
	or ((not mustHaveAll and not missing) and count > 0)				-- [ ] Check for all [ ] Missing: count needs to be greater than zero
	or ((not mustHaveAll and missing) and count == 0)					-- [ ] Check for all [x] Missing: count needs to be zero
	or ((mustHaveAll and missing) and (total ~= count) and count > 0)	-- [x] Check for all [x] Missing: count needs to be greater than zero and not match total
end

local function HidePlayerNamePlate()
	mod.PlayerFrame__.UnitFrame:Hide()
	mod.PlayerNamePlateAnchor:Hide()
end

local filterVisibility --[[ 0=hide 1=show 2=noTrigger ]]
function mod:FilterStyle(frame, actions)
	if actions.hide then
		if frame.UnitType == 'PLAYER' then
			filterVisibility = 0
			if self.db.units.PLAYER.useStaticPosition then
				HidePlayerNamePlate()
			else
				E:LockCVar("nameplatePersonalShowAlways", "0")
				frame:Hide()
			end
		else
			frame:Hide()
		end
		return --We hide it. Lets not do other things (no point)
	else
		if frame.UnitType == 'PLAYER' then
			filterVisibility = 1
			if self.db.units.PLAYER.useStaticPosition then
				self.PlayerNamePlateAnchor:Show()
			else
				E:LockCVar("nameplatePersonalShowAlways", "1")
			end
		end
		frame:Show()
	end
	if self.db.units[frame.UnitType].healthbar.enable then
		if actions.color and actions.color.health then
			frame.HealthBar:SetStatusBarColor(actions.color.healthColor.r, actions.color.healthColor.g, actions.color.healthColor.b, actions.color.healthColor.a);
			frame.HealthBar.r, frame.HealthBar.g, frame.HealthBar.b, frame.HealthBar.a = actions.color.healthColor.r, actions.color.healthColor.g, actions.color.healthColor.b, actions.color.healthColor.a;
		end
		if actions.color and actions.color.border and frame.HealthBar.backdrop then
			frame.BorderChanged = true
			frame.HealthBar.backdrop:SetBackdropBorderColor(actions.color.borderColor.r, actions.color.borderColor.g, actions.color.borderColor.b, actions.color.borderColor.a);
		end
		if actions.texture and actions.texture.enable then
			frame.TextureChanged = true
			frame.Highlight:SetTexture(LSM:Fetch("statusbar", actions.texture.texture))
			frame.HealthBar:SetStatusBarTexture(LSM:Fetch("statusbar", actions.texture.texture))
		end
		if actions.scale and actions.scale ~= 1 then
			local scale = actions.scale
			if frame.isTarget and self.db.useTargetScale then
				scale = scale * self.db.targetScale
			end
			frame.ThreatScale = scale
			self:SetFrameScale(frame, scale)
		end
	end
end

local filterList = {}
local function filterSort(a,b)
	if a[2] and b[2] then
		return a[2]>b[2] --sort by priority
	end
end

function mod:UpdateElement_Filters(frame)
	local trigger, triggerByUnit, triggerByReactionType, triggerByNameOrSpellID, name, guid, npcid, inCombat, level, mylevel, reaction;

	if frame.TextureChanged then
		frame.TextureChanged = nil
		frame.Highlight:SetTexture(LSM:Fetch("statusbar", self.db.statusbar))
		frame.HealthBar:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.statusbar))
	end
	if frame.BorderChanged then
		frame.BorderChanged = nil
		frame.HealthBar.backdrop:SetBackdropBorderColor(unpack(E.media.bordercolor))
	end

	if frame.UnitType == 'PLAYER' then
		filterVisibility = 2
	end

	twipe(filterList)

	for filterName, filter in pairs(E.global.nameplate.filters) do
		if filter.triggers and filter.triggers.enable then
			tinsert(filterList, {filterName, filter.triggers.priority or 1})
		end
	end

	if not next(filterList) then
		return --if all triggers are disabled just stop
	end

	tsort(filterList, filterSort) --sort by priority

	for filterName, filter in ipairs(filterList) do
		filter = E.global.nameplate.filters[filterList[filterName][1]];
		if not filter then
			return
		end
		trigger = filter.triggers

		if trigger.names and next(trigger.names) then
			triggerByNameOrSpellID = 0
			for unitName, value in pairs(trigger.names) do
				if value == true then --only check names that are checked
					triggerByNameOrSpellID = 1 --theres something on the list enabled
					if tonumber(unitName) then
						guid = UnitGUID(frame.displayedUnit)
						if guid then
							npcid = select(6, strsplit('-', guid))
							if tonumber(unitName) == tonumber(npcid) then
								triggerByNameOrSpellID = 2
								break
							end
						end
					else
						name = UnitName(frame.displayedUnit)
						if unitName and unitName ~= "" and unitName == name then
							triggerByNameOrSpellID = 2
							break
						end
					end
				end
			end
			if triggerByNameOrSpellID == 1 then
				return -- pass filter if: 0) all are unchecked  2) a checked one matches
			end
		end

		inCombat = UnitAffectingCombat("player")
		if not (trigger.inCombat and trigger.outOfCombat) then --ignore if both are checked (same as both unchecked)
			if (trigger.inCombat and not inCombat) or (trigger.outOfCombat and inCombat) then
				return
			end
		end

		if frame.displayedUnit ~= "player" then
			inCombat = UnitAffectingCombat(frame.displayedUnit)
			if not (trigger.inCombatUnit and trigger.outOfCombatUnit) then --ignore if both are checked (same as both unchecked)
				if (trigger.inCombatUnit and not inCombat) or (trigger.outOfCombatUnit and inCombat) then
					return
				end
			end
		end

		if not (trigger.isTarget and trigger.notTarget) then --ignore if both are checked (same as both unchecked)
			if (trigger.isTarget and not frame.isTarget) or (trigger.notTarget and frame.isTarget) then
				return
			end
		end

		level = UnitLevel(frame.displayedUnit)
		if trigger.level and level then
			if trigger.mylevel then
				if frame.displayedUnit ~= "player" then
					mylevel = UnitLevel("player")
					if level ~= mylevel then return end
				end
			else
				if (trigger.curlevel and trigger.curlevel ~= 0) and trigger.curlevel ~= level then
					return
				end
				if (trigger.minlevel and trigger.minlevel ~= 0) and trigger.minlevel > level then
					return
				end
				if (trigger.maxlevel and trigger.maxlevel ~= 0) and trigger.maxlevel < level then
					return
				end
			end
		end

		if trigger.nameplateType and trigger.nameplateType.enable then
			triggerByUnit = false

			if trigger.nameplateType.friendlyPlayer and frame.UnitType == 'FRIENDLY_PLAYER' then
				triggerByUnit = true
			end
			if trigger.nameplateType.friendlyNPC and frame.UnitType == 'FRIENDLY_NPC' then
				triggerByUnit = true
			end
			if trigger.nameplateType.enemyPlayer and frame.UnitType == 'ENEMY_PLAYER' then
				triggerByUnit = true
			end
			if trigger.nameplateType.enemyNPC and frame.UnitType == 'ENEMY_NPC' then
				triggerByUnit = true
			end
			if trigger.nameplateType.healer and frame.UnitType == 'HEALER' then
				triggerByUnit = true
			end
			if trigger.nameplateType.player and frame.UnitType == 'PLAYER' then
				triggerByUnit = true
			end

			if triggerByUnit ~= true then
				return
			end
		end

		if trigger.reactionType and trigger.reactionType.enable then
			reaction = (trigger.reactionType.reputation and UnitReaction(frame.displayedUnit, 'player')) or UnitReaction('player', frame.displayedUnit)
			triggerByReactionType = false

			if trigger.reactionType.hated and reaction == 1 then
				triggerByReactionType = true
			end
			if trigger.reactionType.hostile and reaction == 2 then
				triggerByReactionType = true
			end
			if trigger.reactionType.unfriendly and reaction == 3 then
				triggerByReactionType = true
			end
			if trigger.reactionType.neutral and reaction == 4 then
				triggerByReactionType = true
			end
			if trigger.reactionType.friendly and reaction == 5 then
				triggerByReactionType = true
			end
			if trigger.reactionType.honored and reaction == 6 then
				triggerByReactionType = true
			end
			if trigger.reactionType.revered and reaction == 7 then
				triggerByReactionType = true
			end
			if trigger.reactionType.exalted and reaction == 8 then
				triggerByReactionType = true
			end

			if triggerByReactionType ~= true then
				return
			end
		end

		if trigger.buffs and trigger.buffs.names and next(trigger.buffs.names) then
			if not filterAura(trigger.buffs.names, frame.Buffs and frame.Buffs.icons, trigger.buffs.mustHaveAll, trigger.buffs.missing) then
				return
			end
		end
		if trigger.debuffs and trigger.debuffs.names and next(trigger.debuffs.names) then
			if not filterAura(trigger.debuffs.names, frame.Debuffs and frame.Debuffs.icons, trigger.debuffs.mustHaveAll, trigger.debuffs.missing) then
				return
			end
		end

		self:FilterStyle(frame, filter.actions);
	end
end

function mod:UpdateElement_All(frame, unit, noTargetFrame, filterIgnore)
	if(self.db.units[frame.UnitType].healthbar.enable or (self.db.displayStyle ~= "ALL") or (frame.isTarget and self.db.alwaysShowTargetHealth)) then
		mod:UpdateElement_MaxHealth(frame)
		mod:UpdateElement_Health(frame)
		mod:UpdateElement_HealthColor(frame)
		mod:UpdateElement_Cast(frame)
		mod:UpdateElement_Auras(frame)
		mod:UpdateElement_HealPrediction(frame)
		if(self.db.units[frame.UnitType].powerbar.enable) then
			frame.PowerBar:Show()
			mod.OnEvent(frame, "UNIT_DISPLAYPOWER", unit or frame.unit)
		else
			frame.PowerBar:Hide()
		end
		mod:UpdateElement_Glow(frame) -- this needs to run after we show the powerbar or not to place the new glow2 properly
	else
		-- make sure we hide the arrows and/or glow after disabling the healthbar
		if frame.TopArrow and frame.TopArrow:IsShown() then frame.TopArrow:Hide() end
		if frame.LeftArrow and frame.LeftArrow:IsShown() then frame.LeftArrow:Hide() end
		if frame.RightArrow and frame.RightArrow:IsShown() then frame.RightArrow:Hide() end
		if frame.Glow2 and frame.Glow2:IsShown() then frame.Glow2:Hide() end
	end
	mod:UpdateElement_RaidIcon(frame)
	mod:UpdateElement_HealerIcon(frame)
	mod:UpdateElement_Name(frame)
	mod:UpdateElement_NPCTitle(frame)
	mod:UpdateElement_Level(frame)
	mod:UpdateElement_Elite(frame)
	mod:UpdateElement_Detection(frame)
	mod:UpdateElement_Highlight(frame)
	mod:UpdateElement_Portrait(frame)

	if(not noTargetFrame) then --infinite loop lol
		mod:SetTargetFrame(frame)
	end

	if(not filterIgnore) then
		mod:UpdateElement_Filters(frame)
	end
end

function mod:NAME_PLATE_CREATED(_, frame)
	frame.UnitFrame = CreateFrame("BUTTON", "ElvUI"..frame:GetName().."UnitFrame", UIParent);
	frame.UnitFrame:EnableMouse(false);
	frame.UnitFrame:SetAllPoints(frame)
	frame.UnitFrame:SetFrameStrata("BACKGROUND")
	frame.UnitFrame:SetScript("OnEvent", mod.OnEvent)

	frame.UnitFrame.HealthBar = self:ConstructElement_HealthBar(frame.UnitFrame)
	frame.UnitFrame.PowerBar = self:ConstructElement_PowerBar(frame.UnitFrame)
	frame.UnitFrame.CastBar = self:ConstructElement_CastBar(frame.UnitFrame)
	frame.UnitFrame.Level = self:ConstructElement_Level(frame.UnitFrame)
	frame.UnitFrame.Name = self:ConstructElement_Name(frame.UnitFrame)
	frame.UnitFrame.NPCTitle = self:ConstructElement_NPCTitle(frame.UnitFrame)
	frame.UnitFrame.Glow = self:ConstructElement_Glow(frame.UnitFrame)
	frame.UnitFrame.Buffs = self:ConstructElement_Auras(frame.UnitFrame, "LEFT")
	frame.UnitFrame.Debuffs = self:ConstructElement_Auras(frame.UnitFrame, "RIGHT")
	frame.UnitFrame.HealerIcon = self:ConstructElement_HealerIcon(frame.UnitFrame)
	frame.UnitFrame.RaidIcon = self:ConstructElement_RaidIcon(frame.UnitFrame)
	frame.UnitFrame.Elite = self:ConstructElement_Elite(frame.UnitFrame)
	frame.UnitFrame.DetectionModel = self:ConstructElement_Detection(frame.UnitFrame)
	frame.UnitFrame.Highlight = self:ConstructElement_Highlight(frame.UnitFrame)
	frame.UnitFrame.Portrait = self:ConstructElement_Portrait(frame.UnitFrame)
end

function mod:OnEvent(event, unit, ...)
	if (unit and self.displayedUnit and (not UnitIsUnit(unit, self.displayedUnit) and not ((unit == "vehicle" or unit == "player") and (self.displayedUnit == "vehicle" or self.displayedUnit == "player")))) then
		return
	end

	if(event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT") then
		mod:UpdateElement_Health(self)
		mod:UpdateElement_HealPrediction(self)
		mod:UpdateElement_Glow(self)
		if unit == "vehicle" or unit == "player" then
			mod:UpdateVisibility()
		end
	elseif(event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_PREDICTION") then
		mod:UpdateElement_HealPrediction(self)
	elseif(event == "UNIT_MAXHEALTH") then
		mod:UpdateElement_MaxHealth(self)
		mod:UpdateElement_HealPrediction(self)
		mod:UpdateElement_Glow(self)
	elseif(event == "UNIT_NAME_UPDATE") then
		mod:UpdateElement_Name(self)
		mod:UpdateElement_NPCTitle(self)
		mod:UpdateElement_HealthColor(self) --Unit class sometimes takes a bit to load
		mod:UpdateElement_Filters(self)
	elseif(event == "UNIT_LEVEL") then
		mod:UpdateElement_Level(self)
	elseif(event == "UNIT_THREAT_LIST_UPDATE") then
		mod:Update_ThreatList(self)
		mod:UpdateElement_HealthColor(self)
		mod:UpdateElement_Filters(self)
	elseif(event == "PLAYER_TARGET_CHANGED") then
		mod:SetTargetFrame(self)
		mod:UpdateElement_Glow(self)
		mod:UpdateElement_HealthColor(self)
		mod:UpdateElement_Filters(self)
		mod:UpdateVisibility()
	elseif(event == "UNIT_AURA") then
		mod:UpdateElement_Auras(self)
		if(self.IsPlayerFrame) then
			mod:ClassBar_Update(self)
		end
		mod:UpdateElement_HealthColor(self)
		mod:UpdateElement_Filters(self)
	elseif(event == "PLAYER_ROLES_ASSIGNED" or event == "UNIT_FACTION") then
		mod:CheckUnitType(self)
	elseif(event == "RAID_TARGET_UPDATE") then
		mod:UpdateElement_RaidIcon(self)
	elseif(event == "UNIT_MAXPOWER") then
		mod:UpdateElement_MaxPower(self)
	elseif(event == "UNIT_POWER" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER") then
		local powerType, powerToken = UnitPowerType(self.displayedUnit)
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
	elseif ( event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" or event == "UNIT_PET" ) then
		mod:UpdateInVehicle(self)
		mod:UpdateElement_All(self, unit, true)
	elseif(event == "UPDATE_MOUSEOVER_UNIT") then
		mod:UpdateElement_Highlight(self)
	elseif(event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" or event == "UNIT_CONNECTION") then
		mod:UpdateElement_Portrait(self)
	else
		mod:UpdateElement_Cast(self, event, unit, ...)
	end
end

function mod:RegisterEvents(frame, unit)
	local displayedUnit;
	if ( unit ~= frame.displayedUnit ) then
		displayedUnit = frame.displayedUnit;
	end

	if(self.db.units[frame.UnitType].healthbar.enable or (frame.isTarget and self.db.alwaysShowTargetHealth)) then
		frame:RegisterUnitEvent("UNIT_MAXHEALTH", unit, displayedUnit);
		frame:RegisterUnitEvent("UNIT_HEALTH", unit, displayedUnit);
		frame:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", unit, displayedUnit);
		frame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", unit, displayedUnit);
		frame:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", unit, displayedUnit);
		frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", unit, displayedUnit);
	end

	frame:RegisterEvent("UNIT_NAME_UPDATE");
	frame:RegisterUnitEvent("UNIT_LEVEL", unit, displayedUnit);

	--if(self.db.units[frame.UnitType].portrait.enable) then
		frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", unit, displayedUnit);
		frame:RegisterUnitEvent("UNIT_MODEL_CHANGED", unit, displayedUnit);
		frame:RegisterUnitEvent("UNIT_CONNECTION", unit, displayedUnit);
	--end

	if(self.db.units[frame.UnitType].healthbar.enable or (frame.isTarget and self.db.alwaysShowTargetHealth)) then
		if(frame.UnitType == "ENEMY_NPC") then
			frame:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", unit, displayedUnit);
		end

		if(self.db.units[frame.UnitType].powerbar.enable) then
			frame:RegisterUnitEvent("UNIT_POWER", unit, displayedUnit)
			frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", unit, displayedUnit)
			frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit, displayedUnit)
			frame:RegisterUnitEvent("UNIT_MAXPOWER", unit, displayedUnit)
		end

		if(self.db.units[frame.UnitType].castbar.enable) then
			frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED");
			frame:RegisterEvent("UNIT_SPELLCAST_DELAYED");
			frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START");
			frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE");
			frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP");
			frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE");
			frame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE");
			frame:RegisterUnitEvent("UNIT_SPELLCAST_START", unit, displayedUnit);
			frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit, displayedUnit);
			frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit, displayedUnit);
		end

		frame:RegisterEvent("PLAYER_ENTERING_WORLD");

		if(self.db.units[frame.UnitType].buffs.enable or self.db.units[frame.UnitType].debuffs.enable) then
			frame:RegisterUnitEvent("UNIT_AURA", unit, displayedUnit)
		end
		mod.OnEvent(frame, "PLAYER_ENTERING_WORLD")
	end

	frame:RegisterEvent("RAID_TARGET_UPDATE")
	frame:RegisterEvent("UNIT_ENTERED_VEHICLE")
	frame:RegisterEvent("UNIT_EXITED_VEHICLE")
	frame:RegisterEvent("UNIT_PET")
	frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	frame:RegisterEvent("UNIT_FACTION")
	frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
end

function mod:SetClassNameplateBar(frame)
	mod.ClassBar = frame
	if(frame) then
		frame:SetScale(1.35)
	end
end

function mod:UpdateCVars()
	E:LockCVar("nameplateMotion", self.db.motionType == "STACKED" and "1" or "0")
	E:LockCVar("nameplateShowAll", self.db.displayStyle ~= "ALL" and "0" or "1")
	E:LockCVar("nameplateShowFriendlyMinions", self.db.units.FRIENDLY_PLAYER.minions == true and "1" or "0")
	E:LockCVar("nameplateShowEnemyMinions", self.db.units.ENEMY_PLAYER.minions == true and "1" or "0")
	E:LockCVar("nameplateShowEnemyMinus", self.db.units.ENEMY_NPC.minors == true and "1" or "0")

	E:LockCVar("nameplateMaxDistance", self.db.loadDistance)
	E:LockCVar("nameplateOtherTopInset", self.db.clampToScreen and "0.08" or "-1")
	E:LockCVar("nameplateOtherBottomInset", self.db.clampToScreen and "0.1" or "-1")

	--Player nameplate
	if filterVisibility ~= 1 then --Forced shown, using filters visibility instead.
		E:LockCVar("nameplateShowSelf", (self.db.units.PLAYER.useStaticPosition == true or self.db.units.PLAYER.enable ~= true) and "0" or "1")
		E:LockCVar("nameplatePersonalShowAlways", (self.db.units.PLAYER.visibility.showAlways == true and "1" or "0"))
		E:LockCVar("nameplatePersonalShowInCombat", (self.db.units.PLAYER.visibility.showInCombat == true and "1" or "0"))
		E:LockCVar("nameplatePersonalShowWithTarget", (self.db.units.PLAYER.visibility.showWithTarget == true and "1" or "0"))
		E:LockCVar("nameplatePersonalHideDelaySeconds", self.db.units.PLAYER.visibility.hideDelay)
	end
end

local function CopySettings(from, to)
	for setting, value in pairs(from) do
		if(type(value) == "table") then
			CopySettings(from[setting], to[setting])
		else
			if(to[setting] ~= nil) then
				to[setting] = from[setting]
			end
		end
	end
end

function mod:ResetSettings(unit)
	CopySettings(P.nameplates.units[unit], self.db.units[unit])
end

function mod:CopySettings(from, to)
	if(from == to) then return end

	CopySettings(self.db.units[from], self.db.units[to])
end

function mod:TogglePlayerDisplayType()
	if(self.db.units.PLAYER.enable and self.db.units.PLAYER.useStaticPosition) then
		self.PlayerFrame__:Show()
		RegisterUnitWatch(self.PlayerFrame__)
		E:EnableMover("PlayerNameplate")
		self:NAME_PLATE_UNIT_ADDED("NAME_PLATE_UNIT_ADDED", "player", self.PlayerFrame__)
		self.PlayerNamePlateAnchor:SetParent(self.PlayerFrame__)
		self.PlayerNamePlateAnchor:SetAllPoints(self.PlayerFrame__.UnitFrame)
		self:UpdateVisibility()
	else
		UnregisterUnitWatch(self.PlayerFrame__)
		E:DisableMover("PlayerNameplate")
		if(self.PlayerFrame__:IsShown()) then
			self:NAME_PLATE_UNIT_REMOVED("NAME_PLATE_UNIT_REMOVED", "player", self.PlayerFrame__)
			self.PlayerFrame__:Hide()
			self.PlayerNamePlateAnchor:Hide()
		end
	end
end

function mod:UpdateVehicleStatus()
	if ( UnitHasVehicleUI("player") ) then
		self.playerUnitToken = "vehicle"
	else
		self.playerUnitToken = "player"
	end
end

function mod:PLAYER_REGEN_DISABLED()
	if(self.db.showFriendlyCombat == "TOGGLE_ON") then
		SetCVar("nameplateShowFriends", 1);
	elseif(self.db.showFriendlyCombat == "TOGGLE_OFF") then
		SetCVar("nameplateShowFriends", 0);
	end

	if(self.db.showEnemyCombat == "TOGGLE_ON") then
		SetCVar("nameplateShowEnemies", 1);
	elseif(self.db.showEnemyCombat == "TOGGLE_OFF") then
		SetCVar("nameplateShowEnemies", 0);
	end

	if self.db.units.PLAYER.useStaticPosition then
		self:UpdateVisibility()
	end
end

function mod:PLAYER_REGEN_ENABLED()
	if(self.db.showFriendlyCombat == "TOGGLE_ON") then
		SetCVar("nameplateShowFriends", 0);
	elseif(self.db.showFriendlyCombat == "TOGGLE_OFF") then
		SetCVar("nameplateShowFriends", 1);
	end

	if(self.db.showEnemyCombat == "TOGGLE_ON") then
		SetCVar("nameplateShowEnemies", 0);
	elseif(self.db.showEnemyCombat == "TOGGLE_OFF") then
		SetCVar("nameplateShowEnemies", 1);
	end
	self:UpdateVisibility()
end

function mod:UpdateVisibility()
	local frame = self.PlayerFrame__
	if self.db.units.PLAYER.useStaticPosition then
		if filterVisibility ~= 2 then return end --Using filters visibility instead.
		if (self.db.units.PLAYER.visibility.showAlways) then
			frame.UnitFrame:Show()
			self.PlayerNamePlateAnchor:Show()
		else
			local curHP, maxHP = UnitHealth("player"), UnitHealthMax("player")
			local inCombat = UnitAffectingCombat("player")
			local hasTarget = UnitExists("target")
			local canAttack = UnitCanAttack("player", "target")

			if (curHP ~= maxHP) or (self.db.units.PLAYER.visibility.showInCombat and inCombat) or (self.db.units.PLAYER.visibility.showWithTarget and hasTarget and canAttack) then
				frame.UnitFrame:Show()
				self.PlayerNamePlateAnchor:Show()
			elseif frame.UnitFrame:IsShown() then
				if (self.db.units.PLAYER.visibility.hideDelay > 0) then
					C_Timer_After(self.db.units.PLAYER.visibility.hideDelay, HidePlayerNamePlate)
				else
					HidePlayerNamePlate()
				end
			end
		end
	else
		frame.UnitFrame:Hide()
	end
end

function mod:Initialize()
	self.db = E.db["nameplates"]
	if E.private["nameplates"].enable ~= true then return end

	--We don't allow player nameplate health to be disabled
	self.db.units.PLAYER.healthbar.enable = true

	self:UpdateVehicleStatus()

	--Hacked Nameplate
	self.PlayerFrame__ = CreateFrame("BUTTON", "ElvNamePlate", E.UIParent, "SecureUnitButtonTemplate")
	self.PlayerFrame__:SetAttribute("unit", "player")
	self.PlayerFrame__:RegisterForClicks("LeftButtonDown", "RightButtonDown")
	self.PlayerFrame__:SetAttribute("*type1", "target")
	self.PlayerFrame__:SetAttribute("*type2", "togglemenu")
	self.PlayerFrame__:SetAttribute("toggleForVehicle", true)
	self.PlayerFrame__:SetPoint("TOP", UIParent, "CENTER", 0, -150)
	self.PlayerFrame__:Hide()

	--Create anchor frame for the default player resource bar, the one that moves around
	--Other addons can anchor stuff to this frame to make sure it follows the movement of the resource bar
	--Request: http://git.tukui.org/Elv/elvui/issues/1708
	self.PlayerNamePlateAnchor = CreateFrame("Frame", "ElvUIPlayerNamePlateAnchor", E.UIParent)
	self.PlayerNamePlateAnchor:Hide()

	self:UpdateCVars()
	InterfaceOptionsNamesPanelUnitNameplates:Kill()
	NamePlateDriverFrame:UnregisterAllEvents()
	NamePlateDriverFrame.ApplyFrameOptions = E.noop --This taints and prevents default nameplates in dungeons and raids

	--We need to re-register these in order for default nameplates to show in dungeons and raids
	-- NamePlateDriverFrame:RegisterEvent("FORBIDDEN_NAME_PLATE_CREATED")
	-- NamePlateDriverFrame:RegisterEvent("FORBIDDEN_NAME_PLATE_UNIT_ADDED")
	-- NamePlateDriverFrame:RegisterEvent("FORBIDDEN_NAME_PLATE_UNIT_REMOVED")

	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	self:RegisterEvent("NAME_PLATE_CREATED");
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED");
	self:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
	self:RegisterEvent("DISPLAY_SIZE_CHANGED");
	self:RegisterEvent("UNIT_ENTERED_VEHICLE", "UpdateVehicleStatus")
	self:RegisterEvent("UNIT_EXITED_VEHICLE", "UpdateVehicleStatus")
	self:RegisterEvent("UNIT_PET", "UpdateVehicleStatus")

	--Best to just Hijack Blizzard's nameplate classbar
	self.ClassBar = NamePlateDriverFrame.nameplateBar
	if(self.ClassBar) then
		self.ClassBar:SetScale(1.35)
	end
	hooksecurefunc(NamePlateDriverFrame, "SetClassNameplateBar", mod.SetClassNameplateBar)

	self:DISPLAY_SIZE_CHANGED() --Run once for good measure.
	self:SetBaseNamePlateSize()

	self:NAME_PLATE_CREATED("NAME_PLATE_CREATED", self.PlayerFrame__)
	self:NAME_PLATE_UNIT_ADDED("NAME_PLATE_UNIT_ADDED", "player", self.PlayerFrame__)
	self:NAME_PLATE_UNIT_REMOVED("NAME_PLATE_UNIT_REMOVED", "player", self.PlayerFrame__)
	E:CreateMover(self.PlayerFrame__, "PlayerNameplate", L["Player Nameplate"])
	self:TogglePlayerDisplayType()
	self:SetNamePlateClickThrough()

	self:RegisterEvent("PLAYER_ENTERING_WORLD")

	E.NamePlates = self
end

local function InitializeCallback()
	mod:Initialize()
end

E:RegisterModule(mod:GetName(), InitializeCallback)