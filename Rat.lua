--########### Raid Ability Tracker
--########### By Atreyyo @ VanillaGaming.org - Modified by Mithadana @ Turtle-wow.org
--##########################################

local HAS_SUPERWOW = (type(SUPERWOW_VERSION) == "string")
local HAS_NAMPOWER = (type(GetNampowerVersion) == "function")
if not HAS_SUPERWOW then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Rat]|r SuperWoW not detected. Addon disabled.")
    return  -- stops executing the rest of the file
end


local RAT_GUID_TO_NAME = {}
local RAT_NAME_TO_GUID = {}
local RAT_NAME_TO_CLASS = {}

-- Reverse lookup: English value → localized key (for O(1) normalize)
local L_REVERSE = {}

local function Rat_BuildRaidGUIDIndex()
	for k in pairs(RAT_GUID_TO_NAME) do RAT_GUID_TO_NAME[k] = nil end
	for k in pairs(RAT_NAME_TO_GUID) do RAT_NAME_TO_GUID[k] = nil end
	for k in pairs(RAT_NAME_TO_CLASS) do RAT_NAME_TO_CLASS[k] = nil end

    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        for i=1, GetNumRaidMembers() do
            local unit = "raid"..i
            local name = UnitName(unit)
            local exists, guid = UnitExists(unit)
            if exists and name and guid then
                RAT_GUID_TO_NAME[guid] = name
                RAT_NAME_TO_GUID[name] = guid
                local class = UnitClass(unit)
                if class then RAT_NAME_TO_CLASS[name] = class end
            end
        end
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
        for i=1, GetNumPartyMembers() do
            local unit = "party"..i
            local name = UnitName(unit)
            local exists, guid = UnitExists(unit)
            if exists and name and guid then
                RAT_GUID_TO_NAME[guid] = name
                RAT_NAME_TO_GUID[name] = guid
                local class = UnitClass(unit)
                if class then RAT_NAME_TO_CLASS[name] = class end
            end
        end
    end
    -- always include player
    local exists, guid = UnitExists("player")
    local name = UnitName("player")
    if exists and name and guid then
        RAT_GUID_TO_NAME[guid] = name
        RAT_NAME_TO_GUID[name] = guid
    end
    local playerClass = UnitClass("player")
    if name and playerClass then RAT_NAME_TO_CLASS[name] = playerClass end
end

Rat = CreateFrame("Button", "Rat", UIParent); -- Create first frame
Rat.Mainframe = CreateFrame("Frame","RMF",UIParent) -- Create Mainframe
Rat.Options = CreateFrame("Frame","ROF",UIParent) -- Create Optionsframe
Rat.Minimap = CreateFrame("Frame",nil,Minimap) -- Minimap Frame
Rat.Version = CreateFrame("Frame","RVF",UIParent) -- Create Versionframe
Rat.ReadyFrame = CreateFrame("Frame","RRF",UIParent) -- Create ReadyFrame
Rat_Version = GetAddOnMetadata("Rat", "Version")

-- Variables

RAT_CP_OBJ=nil
RAT_CP_TYPE=nil
Rat_unit = UnitName("player")
Rat_Debug = false
local Rat_dirty = true
local Rat_spellCdThrottle = 0
local Rat_bagCdThrottle = 0

-- loacalization
local L = {}

if (GetLocale() == "deDE") then
	L = {
		["Anregen"] = "Innervate",
		["Herausforderndes Gebrüll"] = "Challenging Roar",
		["Herausforderungsruf"] = "Challenging Shout",
		["Wiedergeburt"] = "Rebirth",
		["Schildwall"] = "Shield Wall",
		["Todeswunsch"] = "Death Wish",
		["Zuschlagen"] = "Pummel",
		["Entwaffnen"] = "Disarm",
		["Erheblicher Seelenstein"] = "Major Soulstone",
		["Handauflegung"] = "Lay on Hands",
		["Segen des Schutzes"] = "Blessing of Protection",
		["Gottesschild"] = "Divine Shield",
		["Göttlicher Eingriff"] = "Divine Intervention",
		["Einlullender Schuss"] = "Tranquilizing Shot",
		["Tritt"] = "Kick",
		["Reinkarnation"] = "Reincarnation",
		["Bollwerk der Rechtschaffenen"] = "Bulwark of the Righteous",
		["Ruhe"] = "Tranquility",
		["Gegenzauber"] = "Counterspell",
		["Erdschock"] = "Earth Shock",
		["Lichtschacht"] = "Lightwell",
		["Rasende Regeneration"] = "Frenzied Regeneration",
		["Geisterverbindung"] = "Spirit Link",
		["Rindenhaut (Wild)"] = "Barkskin (Feral)",
        ["Spott"] = "Taunt",
        ["Knurren"] = "Growl",
        ["Hand der Abrechnung"] = "Hand of Reckoning",
        ["Erdbebenhieb"] = "Earthshaker Slam",
        ["Powerful Smelling Salts"] = "Powerful Smelling Salts", -- TODO: add German translation
        ["Furchtschutzung"] = "Fear Ward", -- TODO: verify German translation
	}
elseif (GetLocale() == "frFR") then
	L = {
		["Innervation"] = "Innervate",
		["Rugissement provocateur"] = "Challenging Roar",
		["Cri de défi"] = "Challenging Shout",
		["Renaissance"] = "Rebirth",
		["Mur protecteur"] = "Shield Wall",
		["Souhait de mort"] = "Death Wish",
		["Volée de coups"] = "Pummel",
		["Désarmement"] = "Disarm",
		["pierre d'âme supérieure"] = "Major Soulstone",
		["Imposition des mains"] = "Lay on Hands",
		["Bénédiction de protection"] = "Blessing of Protection",
		["Bouclier divin"] = "Divine Shield",
		["Intervention divine"] = "Divine Intervention",
		["Tir Tranquillisant"] = "Tranquilizing Shot",
		["Coup de pied"] = "Kick",
		["Réincarnation"] = "Reincarnation",
		["Rempart des Justes"] = "Bulwark of the Righteous",
		["Tranquillité"] = "Tranquility",
		["Contresort"] = "Counterspell",
		["Choc terrestre"] = "Earth Shock",
		["Puits de lumière"] = "Lightwell",
		["Régénération frénétique"] = "Frenzied Regeneration",
		["Lien spirituel"] = "Spirit Link",
		["Écorce (sauvage)"] = "Barkskin (Feral)",
        ["Provocation"] = "Taunt",
        ["Grondement"] = "Growl",
        ["Main de justification"] = "Hand of Reckoning",
        ["Frappe du secoueur de terre"] = "Earthshaker Slam",
        ["Powerful Smelling Salts"] = "Powerful Smelling Salts", -- TODO: add French translation
        ["Gardien de peur"] = "Fear Ward", -- TODO: verify French translation
	}
else -- Default to English
	L = {
		["Innervate"] = "Innervate",
		["Challenging Roar"] = "Challenging Roar",
		["Challenging Shout"] = "Challenging Shout",
		["Taunt"] = "Taunt",
		["Growl"] = "Growl",
		["Hand of Reckoning"] = "Hand of Reckoning",
		["Rebirth"] = "Rebirth",
		["Shield Wall"] = "Shield Wall",
		["Death Wish"] = "Death Wish",
		["Pummel"] = "Pummel",
		["Disarm"] = "Disarm",
		["Major Soulstone"] = "Major Soulstone",
		["Lay on Hands"] = "Lay on Hands",
		["Blessing of Protection"] = "Blessing of Protection",
		["Divine Shield"] = "Divine Shield",
		["Divine Intervention"] = "Divine Intervention",
		["Tranquilizing Shot"] = "Tranquilizing Shot",
		["Kick"] = "Kick",
		["Reincarnation"] = "Reincarnation",
		["Bulwark of the Righteous"] = "Bulwark of the Righteous",
		["Tranquility"] = "Tranquility",
		["Counterspell"] = "Counterspell",
		["Earth Shock"] = "Earth Shock",
		["Lightwell"] = "Lightwell",
		["Frenzied Regeneration"] = "Frenzied Regeneration",
		["Spirit Link"] = "Spirit Link",
		["Barkskin (Feral)"] = "Barkskin (Feral)",
        ["Earthshaker Slam"] = "Earthshaker Slam", -- Added
        ["Powerful Smelling Salts"] = "Powerful Smelling Salts",
        ["Fear Ward"] = "Fear Ward",
	}
end

-- Build L_REVERSE: maps English value → localized key for O(1) normalize
local function Rat_BuildLReverse()
	for k in pairs(L_REVERSE) do L_REVERSE[k] = nil end
	for localizedName, englishName in pairs(L) do
		L_REVERSE[englishName] = localizedName
		L_REVERSE[localizedName] = localizedName  -- localized key maps to itself
	end
end
Rat_BuildLReverse()

local RAT_COOLDOWN = {
  -- Short Cooldowns (< 1 minute)
  ["Earth Shock"]             = 6,     -- 6s
  ["Earthshaker Slam"]        = 10,    -- 10s
  ["Growl"]                   = 10,    -- 10s
  ["Hand of Reckoning"]       = 10,    -- 10s
  ["Kick"]                    = 10,    -- 10s
  ["Pummel"]                  = 10,    -- 10s
  ["Taunt"]                   = 10,    -- 10s
  ["Tranquilizing Shot"]      = 20,    -- 20s
  ["Counterspell"]            = 30,    -- 30s
  ["Fear Ward"]               = 30,    -- 30s
  ["Disarm"]                  = 60,    -- 1m

  -- Medium Cooldowns (1-10 minutes)
  ["Bulwark of the Righteous"]= 180,   -- 3m
  ["Death Wish"]              = 180,   -- 3m
  ["Blessing of Protection"]  = 300,   -- 5m
  ["Divine Shield"]           = 300,   -- 5m
  ["Frenzied Regeneration"]   = 300,   -- 5m
  ["Innervate"]               = 360,   -- 6m
  ["Spirit Link"]             = 360,   -- 6m
  ["Barkskin (Feral)"]        = 600,   -- 10m
  ["Challenging Roar"]        = 600,   -- 10m
  ["Challenging Shout"]       = 600,   -- 10m
  ["Lightwell"]               = 600,   -- 10m

  -- Long Cooldowns (> 10 minutes)
  ["Powerful Smelling Salts"] = 21600, -- 6h
  ["Major Soulstone"]         = 1800,  -- 30m
  ["Rebirth"]                 = 1800,  -- 30m
  ["Shield Wall"]             = 1800,  -- 30m
  ["Tranquility"]             = 1800,  -- 30m
  ["Divine Intervention"]     = 3600,  -- 60m
  ["Lay on Hands"]            = 3600,  -- 60m
  ["Reincarnation"]           = 3600,  -- 60m
}
-- Optional: warn if RAT_COOLDOWN and L get out of sync
do
  local missing, unknown = {}, {}
  for en,_ in pairs(L) do if not RAT_COOLDOWN[en] then table.insert(missing, en) end end
  for en,_ in pairs(RAT_COOLDOWN) do if not L[en] then table.insert(unknown, en) end end
  if next(missing) then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Rat]|r Missing cooldown entries: "..table.concat(missing, ", "))
  end
  if next(unknown) then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF9900[Rat]|r Unknown keys in RAT_COOLDOWN: "..table.concat(unknown, ", "))
  end
end

-- Load custom spells from saved settings into L and RAT_COOLDOWN
function Rat_LoadCustomSpells()
	Rat_Settings["custom_spells"] = Rat_Settings["custom_spells"] or {}
	for _, entry in ipairs(Rat_Settings["custom_spells"]) do
		if entry.name and entry.cd then
			L[entry.name] = entry.name
			RAT_COOLDOWN[entry.name] = entry.cd
			if Rat_Settings[entry.name] == nil then
				Rat_Settings[entry.name] = 1
			end
		end
	end
	Rat_BuildLReverse()
end

-- Tables

RatTbl = {}
RatVersionTbl = {}
VersionFTbl = {}
getThrottle = {}
sendThrottle = {}
RatFrames = {}
RatReadyFrames = {}
Rat_SeenSpells = {}
Rat_Settings = Rat_Settings or {}

cdtbl = {
	["Innervate"] = "Interface\\Icons\\Spell_Nature_Lightning",
	["Challenging Roar"] = "Interface\\Icons\\Ability_Druid_ChallangingRoar",
	["Challenging Shout"] = "Interface\\Icons\\Ability_BullRush",
    ["Taunt"] = "Interface\\Icons\\Spell_Nature_Reincarnation", -- Added
    ["Growl"] = "Interface\\Icons\\Ability_Physical_Taunt", -- Added
    ["Hand of Reckoning"] = "Interface\\Icons\\Spell_Holy_UnyieldingFaith", -- Added (Verify icon path)
	["Rebirth"] = "Interface\\Icons\\Spell_Nature_Reincarnation",
	["Earthshaker Slam"] = "Interface\\Icons\\Spell_Nature_Earthquake",
	["Shield Wall"] = "Interface\\Icons\\Ability_Warrior_ShieldWall",
	["Death Wish"] = "Interface\\Icons\\Spell_Shadow_DeathPact",
	["Pummel"] = "Interface\\Icons\\INV_Gauntlets_04",
	["Disarm"] = "Interface\\Icons\\Ability_Warrior_Disarm",
	["Major Soulstone"] = "Interface\\Icons\\INV_Misc_Orb_04",
	["Lay on Hands"] = "Interface\\Icons\\Spell_Holy_LayOnHands",
	["Blessing of Protection"] = "Interface\\Icons\\Spell_Holy_SealOfProtection",
	["Divine Shield"] = "Interface\\Icons\\Spell_Holy_DivineIntervention",
	["Divine Intervention"] = "Interface\\Icons\\Spell_Nature_TimeStop",
	["Tranquilizing Shot"] = "Interface\\Icons\\Spell_Nature_Drowsy",
	["Kick"] = "Interface\\Icons\\Ability_Kick",
	["Reincarnation"] = "Interface\\Icons\\Spell_Nature_Reincarnation",
	["Bulwark of the Righteous"] = "Interface\\Icons\\Ability_Warrior_VictoryRush",
	["Tranquility"] = "Interface\\Icons\\Spell_Nature_Tranquility",
	["Counterspell"] = "Interface\\Icons\\Spell_Frost_IceShock",
	["Earth Shock"] = "Interface\\Icons\\Spell_Nature_EarthShock",
	["Lightwell"] = "Interface\\Icons\\Spell_Holy_SummonLightwell",
	["Fear Ward"] = "Interface\\Icons\\Spell_Holy_Excorcism",
	["Frenzied Regeneration"] = "Interface\\Icons\\Ability_BullRush",
	["Spirit Link"] = "Interface\\Icons\\Spell_Shaman_SpiritLink",
	["Barkskin (Feral)"] = "Interface\\Icons\\Spell_Nature_StoneClawTotem",
	["Powerful Smelling Salts"] = "Interface\\Icons\\INV_Misc_Ammo_Gunpowder_01",
}

-- BigWigs SpellRequests short name → Rat ability key
local RAT_BW_SPELL_MAP = {
	["bop"] = "Blessing of Protection",
	["ivate"] = "Innervate",
	["spiritlink"] = "Spirit Link",
	["tranquility"] = "Tranquility",
	["cshout"] = "Challenging Shout",
	["brez"] = "Rebirth",
	["fearward"] = "Fear Ward",
	["sunwell"] = "Grace of the Sunwell",
}

-- BigWigs CommonAuras sync token → Rat ability key
local RAT_BW_AURA_MAP = {
	["BWCASW"] = "Shield Wall",
	["BWCACS"] = "Challenging Shout",
	["BWCACR"] = "Challenging Roar",
	["BWCASL"] = "Spirit Link",
	["BWCADI"] = "Divine Intervention",
}

local RAT_CLASS_SPELLS = {
	["Warrior"] = {"Shield Wall", "Challenging Shout", "Taunt", "Pummel", "Disarm"},
	["Paladin"] = {"Lay on Hands", "Blessing of Protection", "Divine Shield", "Divine Intervention", "Hand of Reckoning"},
	["Druid"]   = {"Innervate", "Rebirth", "Challenging Roar", "Growl", "Tranquility", "Barkskin (Feral)", "Frenzied Regeneration"},
	["Shaman"]  = {"Reincarnation", "Earth Shock", "Earthshaker Slam"},
	["Priest"]  = {"Lightwell", "Fear Ward"},
	["Mage"]    = {"Counterspell"},
	["Rogue"]   = {"Kick"},
	["Hunter"]  = {"Tranquilizing Shot"},
	["Warlock"] = {"Major Soulstone"},
}

local RAT_NONBASELINE = {
	["Death Wish"] = true,
	["Bulwark of the Righteous"] = true,
	["Spirit Link"] = true,
	["Powerful Smelling Salts"] = true,
}

-- Item ID → ability key for tracking item-use cooldowns (spellId == 0)
local RAT_ITEM_MAP = {
	[16896] = "Major Soulstone",
}

-- Spell ID → ability key fallback for item-triggered spells
local RAT_SPELLID_MAP = {
	[20765] = "Major Soulstone",
}

Rat_Font = {
	[1] = "ABF",
	[2] = "Accidental Presidency",
	[3] = "Adventure",
	[4] = "Avqest",
	[5] = "Bazooka",
	[6] = "BigNoodleTitling",
	[7] = "BigNoodleTitling-Oblique",
	[8] = "BlackChancery",
	[9] = "Emblem",
	[10] = "Enigma__2",
	[11] = "Movie_Poster-Bold",
	[12] = "Porky",
	[13] = "rm_midse",
	[14] = "Tangerin",
	[15] = "Tw_Cen_MT_Bold",
	[16] = "Ultima_Campagnoli",
	[17] = "VeraSe",
	[18] = "visitor2",
	[19] = "Yellowjacket",
}

Rat_FontSize = {
	[1] = 12,
	[2] = 13,
	[3] = 10,
	[4] = 11,
	[5] = 11,
	[6] = 12,
	[7] = 12,
	[8] = 12,
	[9] = 11,
	[10] = 11,
	[11] = 20,
	[12] = 10,
	[13] = 12,
	[14] = 12,
	[15] = 12,
	[16] = 12,
	[17] = 11,
	[18] = 12,
	[19] = 10,
}

Rat_BarTexture = {
	[1] = "Aluminium",
	[2] = "Armory",
	[3] = "BantoBar",
	[4] = "Glaze2",
	[5] = "Gloss",
	[6] = "Graphite",
	[7] = "Grid",
	[8] = "Healbot",
	[9] = "LiteStep",
	[10] = "Minimalist",
	[11] = "normTex",
	[12] = "Otravi",
	[13] = "Outline",
	[14] = "Perl",
	[15] = "Round",
	[16] = "Smooth",
}


-- Default setting check

function RatDefault()
	if Rat_Settings["Warrior"] == nil then
		Rat_Settings["Warrior"] = 1
	elseif Rat_Settings["Warrior"] == 1 then
		Rat.Mainframe.WarriorFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
	elseif Rat_Settings["Warrior"] == 0 then
		Rat.Mainframe.WarriorFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
	end

	if Rat_Settings["Druid"] == nil then
		Rat_Settings["Druid"] = 1
	elseif Rat_Settings["Druid"] == 1 then
		Rat.Mainframe.DruidFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
	elseif Rat_Settings["Druid"] == 0 then
		Rat.Mainframe.DruidFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
	end

	if Rat_Settings["Paladin"] == nil then
		Rat_Settings["Paladin"] = 1
	elseif Rat_Settings["Paladin"] == 1 then
		Rat.Mainframe.PaladinFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
	elseif Rat_Settings["Paladin"] == 0 then
		Rat.Mainframe.PaladinFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
	end

	if Rat_Settings["Hunter"] == nil then
		Rat_Settings["Hunter"] = 1
	elseif Rat_Settings["Hunter"] == 1 then
		Rat.Mainframe.HunterFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
	elseif Rat_Settings["Hunter"] == 0 then
		Rat.Mainframe.HunterFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
	end

	if Rat_Settings["Shaman"] == nil then
		Rat_Settings["Shaman"] = 1
	elseif Rat_Settings["Shaman"] == 1 then
		Rat.Mainframe.ShamanFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
	elseif Rat_Settings["Shaman"] == 0 then
		Rat.Mainframe.ShamanFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
	end

	if Rat_Settings["Rogue"] == nil then
		Rat_Settings["Rogue"] = 1
	elseif Rat_Settings["Rogue"] == 1 then
		Rat.Mainframe.RogueFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
	elseif Rat_Settings["Rogue"] == 0 then
		Rat.Mainframe.RogueFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
	end

	if Rat_Settings["Warlock"] == nil then
		Rat_Settings["Warlock"] = 1
	elseif Rat_Settings["Warlock"] == 1 then
		Rat.Mainframe.WarlockFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
	elseif Rat_Settings["Warlock"] == 0 then
		Rat.Mainframe.WarlockFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
	end

	if Rat_Settings["Mage"] == nil then
		Rat_Settings["Mage"] = 1
	elseif Rat_Settings["Mage"] == 1 then
		Rat.Mainframe.MageFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
	elseif Rat_Settings["Mage"] == 0 then
		Rat.Mainframe.MageFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
	end

	if Rat_Settings["Priest"] == nil then
		Rat_Settings["Priest"] = 1
	elseif Rat_Settings["Priest"] == 1 then
		Rat.Mainframe.PriestFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
	elseif Rat_Settings["Priest"] == 0 then
		Rat.Mainframe.PriestFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
	end

	if Rat_unit == nil then
		Rat_unit = UnitName("player")
	end

	if Rat_Settings["showhide"] == nil then
		Rat_Settings["showhide"] = 1
	end
	if Rat_Settings["scale"] == nil then
		Rat_Settings["scale"] = 1
	end
end
-- Register events

Rat:RegisterEvent("ADDON_LOADED")
Rat:RegisterEvent("RAID_ROSTER_UPDATE")
Rat:RegisterEvent("PARTY_MEMBERS_CHANGED")
Rat:RegisterEvent("SPELL_UPDATE_COOLDOWN")
Rat:RegisterEvent("BAG_UPDATE_COOLDOWN")
Rat:RegisterEvent("UNIT_CASTEVENT")
Rat:RegisterEvent("CHAT_MSG_ADDON")
if HAS_NAMPOWER then
	Rat:RegisterEvent("SPELL_GO_OTHER")
	Rat:RegisterEvent("SPELL_GO_SELF")
end
-- function to handle events

function Rat:OnEvent()
	if (event == "ADDON_LOADED") and (arg1 == "Rat" or arg1 == "rat" or arg1 == "RAT") then
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A RaidAbilityTracker:|r Loaded!")
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r type |cFFFFFF00 /Rat show|r to show frame",1,1,1)
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r type |cFFFFFF00 /Rat hide|r to hide frame",1,1,1)
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r type |cFFFFFF00 /Rat options|r to show options menu",1,1,1)
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r type |cFFFFFF00 /rat topbar hide|r to hide only the top bar",1,1,1)
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r type |cFFFFFF00 /rat clear|r to clear saved cooldowns",1,1,1)
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r type |cFFFFFF00 /rat ready|r to toggle ready spells list",1,1,1)
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r hold |cFFFFFF00 'Alt'|r to move RAT",1,1,1)
		Rat.Mainframe:ConfigFrame()
		Rat.ReadyFrame:ConfigFrame()
		RatDefault()
		Rat.Options:ConfigFrame()
		Rat.Version:ConfigFrame()
		Rat.Minimap:CreateMinimapIcon()
		Rat_LoadCustomSpells()
		getSpells()
		getInvCd()

		-- Detect non-baseline spells for local player (scan spellbook, not global DB)
		if not Rat_SeenSpells[Rat_unit] then Rat_SeenSpells[Rat_unit] = {} end
		for spell, _ in pairs(RAT_NONBASELINE) do
			if spell == "Powerful Smelling Salts" then
				for bag = 0, 4 do
					for slot = 1, GetContainerNumSlots(bag) do
						local link = GetContainerItemLink(bag, slot)
						if link and string.find(link, "Powerful Smelling Salts") then
							Rat_SeenSpells[Rat_unit][spell] = true
						end
					end
				end
			else
				-- Scan the player's actual spellbook
				local spellIdx = 1
				local sName = GetSpellName(spellIdx, BOOKTYPE_SPELL)
				while sName do
					local normalized = L[sName] or sName
					if normalized == spell then
						Rat_SeenSpells[Rat_unit][spell] = true
						break
					end
					spellIdx = spellIdx + 1
					sName = GetSpellName(spellIdx, BOOKTYPE_SPELL)
				end
			end
		end

		Rat:Update(true)

		if HAS_NAMPOWER then
			SetCVar("NP_EnableSpellGoEvents", "1")
		end
		-- broadcast version to group
		local channel = (GetNumRaidMembers() > 0 and "RAID") or (GetNumPartyMembers() > 0 and "PARTY") or nil
		if channel then
			SendAddonMessage("RAT_VER", Rat_Version, channel)
			-- Request cooldown sync from other Rat users
			SendAddonMessage("RAT_CDREQ", "", channel)
			-- Request from BigWigs users (RAID only, BigWigs doesn't use PARTY)
			if channel == "RAID" then
				for bwSpell, _ in pairs(RAT_BW_SPELL_MAP) do
					SendAddonMessage("BigWigs", "BWSRCDREQ " .. bwSpell .. ";" .. Rat_unit, "RAID")
				end
			end
		end

	elseif (event == "RAID_ROSTER_UPDATE") then
		Rat_BuildRaidGUIDIndex()
		getSpells()
		getInvCd()
		Rat:Cleardb()
		Rat:HideVersionNameFrames()
		Rat:Update(true)
		-- broadcast version on roster change
		local channel = (GetNumRaidMembers() > 0 and "RAID") or (GetNumPartyMembers() > 0 and "PARTY") or nil
		if channel then
			SendAddonMessage("RAT_VER", Rat_Version, channel)
		end

	-- added so leaving/joining party updates roster and resorts cooldowns
	elseif (event == "PARTY_MEMBERS_CHANGED") then
		Rat_BuildRaidGUIDIndex()
		getSpells()
		getInvCd()
		Rat:Cleardb()
		Rat:HideVersionNameFrames()
		Rat:Update(true)
		-- broadcast version on roster change
		local channel = (GetNumRaidMembers() > 0 and "RAID") or (GetNumPartyMembers() > 0 and "PARTY") or nil
		if channel then
			SendAddonMessage("RAT_VER", Rat_Version, channel)
		end

	elseif (event == "SPELL_UPDATE_COOLDOWN") then
		local now = GetTime()
		if now - Rat_spellCdThrottle >= 0.5 then
			Rat_spellCdThrottle = now
			getSpells()
			getInvCd()
			Rat:Cleardb()
			Rat_dirty = true
		end
	elseif (event == "BAG_UPDATE_COOLDOWN") then
		local now = GetTime()
		if now - Rat_bagCdThrottle >= 0.5 then
			Rat_bagCdThrottle = now
			getInvCd()
			Rat_dirty = true
		end
	elseif (event == "UNIT_CASTEVENT") then
		Rat:OnUnitCastEvent(arg1, arg2, arg3, arg4, arg5) -- casterGUID, targetGUID, eventType, spellID, castDuration
	elseif (event == "SPELL_GO_OTHER") then
		Rat:OnSpellGoOther(arg1, arg2, arg3, arg4, arg5, arg6, arg7) -- itemId, spellId, casterGuid, targetGuid, castFlags, numHit, numMissed
	elseif (event == "SPELL_GO_SELF") then
		Rat:OnSpellGoSelf(arg1, arg2, arg3, arg4) -- itemId, spellId, targetGuid, castFlags
	elseif (event == "CHAT_MSG_ADDON") then
		Rat:OnAddonMessage(arg1, arg2, arg3, arg4) -- prefix, message, channel, sender
	end
end


-- function to check version

function Rat.Version:Check()
	if Rat.Version:IsVisible() then
		local count = 0
		local xaxis = 0
		local yaxis = 0
		for name, version in pairs(RatVersionTbl) do
			if count >= 30 then
				xaxis = 320
				yaxis = -450
			elseif count >= 20 then
				xaxis = 220
				yaxis = -300
			elseif count >= 10 then
				xaxis = 120
				yaxis = -150
			end
			VersionFTbl[name] = VersionFTbl[name] or Rat.Version:Insert(name)
			local frame = VersionFTbl[name]
			frame:SetPoint("TOPLEFT",1+xaxis,-(1+(15*count)+yaxis))
			frame.text:SetText(name.." |cFFFFFFFFv"..version)
			frame.text:SetTextColor(1,1,1,1)
			frame.texture:SetTexture(Rat:GetClassColors(name))
			frame:Show()
			Rat.Version:SetWidth(123+(xaxis))
			if count < 10 then
				Rat.Version:SetHeight(18+(15*count))
			else
				Rat.Version:SetHeight(153)
			end
			Rat.Version.close:SetPoint("CENTER",0,-((Rat.Version:GetHeight()/2)+6))
			count = count+1
		end
	end
end

-- function to create nameframes for the version check

function Rat.Version:Insert(name)
	local frame = CreateFrame('Button', name, Rat.Version)
	frame:SetWidth(120)
	frame:SetHeight(15)
	frame:SetBackdropColor(1,1,1,0.6)
	frame.texture = frame:CreateTexture(nil, 'ARTWORK')
	frame.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	frame.texture:SetWidth(118)
	frame.texture:SetHeight(13)
	frame.texture:SetPoint('TOPLEFT', 1, -1)
	frame.texture:SetTexture("Interface/TargetingFrame/UI-StatusBar")
	frame.text = frame:CreateFontString(nil, "OVERLAY")
	frame.text:SetPoint("CENTER",0, 0)
	frame.text:SetFont("Fonts\\FRIZQT__.TTF", 12)
	frame.text:SetTextColor(1, 1, 1, 1)
	frame.text:SetShadowOffset(1,-1)
	frame.text:SetText("name")
	return frame
end

-- function to config versionframe

function Rat.Version:ConfigFrame()

	backdrop = {
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		tile="true",
		tileSize="8",
		edgeSize="8",
		insets={
				left="2",
				right="2",
				top="2",
				bottom="2"
			}
	}

	self:SetFrameStrata("HIGH")
	self:SetWidth(120) -- Set these to whatever height/width is needed
	self:SetHeight(100) -- for your Texture
	self:SetPoint("CENTER",0,0)
	self:SetMovable(1)
	self:EnableMouse(1)
	self:EnableMouseWheel(1)
	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0,0,0,1)
	self:SetMovable(true)
	self:SetResizable(enable)
	self:SetMinResize(400, 120)

	-- close button

	self.close = CreateFrame("Button",nil,self,"UIPanelButtonTemplate")
	self.close:SetPoint("CENTER",0,-((self:GetHeight()/2)+5))
	self.close:SetFrameStrata("HIGH")
	self.close:SetWidth(79)
	self.close:SetHeight(18)
	self.close:SetText("Close")
	self.close:SetScript("OnClick", function() PlaySound("igMainMenuOptionCheckBoxOn"); self:Hide(); end)

	self:Hide()
end

-- function to config mainframe

function Rat.Mainframe:ConfigFrame()
	if Rat_Settings["topbarcolor"] == nil then
		Rat_Settings["topbarcolor"] = {["r"] = 0.1, ["g"] = 0.1, ["b"] = 1}
	end
	if Rat_Settings["abilitybarcolor"] == nil then
		Rat_Settings["abilitybarcolor"] = {["r"] = 0.0, ["g"] = 0.44, ["b"] = 0.87}
	end
	if Rat_Settings["abilitytextcolor"] == nil then
		Rat_Settings["abilitytextcolor"] = {["r"] = 1, ["g"] = 1, ["b"] = 1}
	end
	if Rat_Settings["font"] == nil then
		Rat_Settings["font"] = 1
	end
	if Rat_Settings["bartexture"] == nil then
		Rat_Settings["bartexture"] = 1
	end
	Rat.Mainframe.options = {}
	function Rat.Mainframe.options:StartMoving()
		this:StartMoving()
		this.drag = true
	end

	function Rat.Mainframe.options:StopMovingOrSizing()
		this:StopMovingOrSizing()
		this.drag = false
	end

	backdrop = {
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile="false",
			tileSize="8",
			edgeSize="8",
			insets={
				left="2",
				right="2",
				top="2",
				bottom="2"
			}
	}
	self:SetFrameStrata("LOW")
	self:SetWidth(300) -- Set these to whatever height/width is needed
	self:SetHeight(21) -- for your Texture
	self:SetPoint("CENTER",0,0)
	self:SetMovable(1)
	self:EnableMouse(1)
	self:RegisterForDrag("LeftButton")
	self:SetBackdrop(backdrop)

	self:SetScript("OnDragStart", Rat.Mainframe.options.StartMoving)
	self:SetScript("OnDragStop", Rat.Mainframe.options.StopMovingOrSizing)
	self:SetScript("OnUpdate", function()
		this:EnableMouse(IsAltKeyDown())
		if not IsAltKeyDown() and this.drag then
			self.options:StopMovingOrSizing()
		end
	end)

	self.Background = {}
	self.Background.Top = CreateFrame("Frame",nil,self) -- top frame
	self.Background.Tab1 = CreateFrame("Frame",nil,self) -- mid frame

	-- create top background
	local backdrop = {
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile="false",
			tileSize="4",
			edgeSize="4",
			insets={
				left="2",
				right="2",
				top="2",
				bottom="2"
			}
	}
	self.Background.Top:SetFrameStrata('BACKGROUND')
	self.Background.Top:SetWidth(self:GetWidth()-2)
	self.Background.Top:SetHeight(20)
	self.Background.Top:SetBackdrop(backdrop)
	self.Background.Top:SetBackdropColor(0,0,0,1)
	self.Background.Top:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -1)
	self.Background.Top:SetScript("OnEnter", function()
		GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT");
		GameTooltip:SetText("Hold 'Alt' key to move the window", 1, 1, 1, 1);
		GameTooltip:Show()
	end)
	self.Background.Top:SetScript("OnEnter", function()
		GameTooltip:Hide()
	end)

	topbg = self.Background.Top:CreateTexture(nil, 'ARTWORK',self)
	topbg:SetPoint("TOPLEFT",1,-1)
	topbg:SetWidth(self:GetWidth()-5)
	topbg:SetHeight(17)
	topbg:SetTexture(Rat_Settings["topbarcolor"]["r"],Rat_Settings["topbarcolor"]["g"],Rat_Settings["topbarcolor"]["b"])
	topbg:SetGradientAlpha("Vertical", 1,1,1, 0.25, 1, 1, 1, 1)

	self.Background.Top.Title = self.Background.Top:CreateFontString(nil, "ARTWORK")
	self.Background.Top.Title:SetPoint("LEFT", 22, 0)
	self.Background.Top.Title:SetFont("Interface\\AddOns\\Rat\\fonts\\"..Rat_Font[Rat_Settings["font"]]..".TTF", Rat_FontSize[Rat_Settings["font"]]+1)
	self.Background.Top.Title:SetTextColor(255, 255, 255, 1)
	self.Background.Top.Title:SetShadowOffset(2,-2)
	self.Background.Top.Title:SetText("RAT v"..Rat_Version)

	-- Druid option frame
	local r, l, t, b = Rat:ClassPos("Druid")
	self.DruidFrame = CreateFrame('Button', "Druid", self)
	self.DruidFrame:SetWidth(16)
	self.DruidFrame:SetHeight(16)
	self.DruidFrame:SetBackdropColor(0,0,0,1)
	self.DruidFrame:SetPoint('TOPRIGHT', -41, -1)
	self.DruidFrame:SetFrameStrata('MEDIUM')
	self.DruidFrame.Icon = self.DruidFrame:CreateTexture(nil, 'ARTWORK')
	self.DruidFrame.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.DruidFrame.Icon:SetTexCoord(r, l, t, b)
	self.DruidFrame.Icon:SetPoint('TOPRIGHT', -1, -1)
	self.DruidFrame.Icon:SetWidth(16)
	self.DruidFrame.Icon:SetHeight(16)
	self.DruidFrame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(self.DruidFrame, "ANCHOR_TOPRIGHT");
		GameTooltip:SetText(this:GetName(), 1, 0.49, 0.04, 1, 1);
		GameTooltip:Show()
		end)
	self.DruidFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.DruidFrame:SetScript("OnMouseDown", function()
			if (arg1 == "LeftButton") then
				if Rat_Settings[this:GetName()] == 1 then
					Rat_Settings[this:GetName()] = 0
					self.DruidFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
				else
					Rat_Settings[this:GetName()] = 1
					self.DruidFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
				end
			end
		end)

	-- Hunter option frame
	local r, l, t, b = Rat:ClassPos("Hunter")
	self.HunterFrame = CreateFrame('Button', "Hunter", self)
	self.HunterFrame:SetWidth(16)
	self.HunterFrame:SetHeight(16)
	self.HunterFrame:SetBackdropColor(0,0,0,1)
	self.HunterFrame:SetPoint('TOPRIGHT', -116, -1)
	self.HunterFrame:SetFrameStrata('MEDIUM')
	self.HunterFrame.Icon = self.HunterFrame:CreateTexture(nil, 'ARTWORK')
	self.HunterFrame.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.HunterFrame.Icon:SetTexCoord(r, l, t, b)
	self.HunterFrame.Icon:SetPoint('TOPRIGHT', -1, -1)
	self.HunterFrame.Icon:SetWidth(16)
	self.HunterFrame.Icon:SetHeight(16)
	self.HunterFrame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(self.HunterFrame, "ANCHOR_TOPRIGHT");
		GameTooltip:SetText(this:GetName(), 0.67, 0.83, 0.45, 1, 1);
		GameTooltip:Show()
		end)
	self.HunterFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.HunterFrame:SetScript("OnMouseDown", function()
			if (arg1 == "LeftButton") then
				if Rat_Settings[this:GetName()] == 1 then
					Rat_Settings[this:GetName()] = 0
					self.HunterFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
				else
					Rat_Settings[this:GetName()] = 1
					self.HunterFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
				end
			end
		end)

	-- Paladin option frame
	local r, l, t, b = Rat:ClassPos("Paladin")
	self.PaladinFrame = CreateFrame('Button', "Paladin", self)
	self.PaladinFrame:SetWidth(16)
	self.PaladinFrame:SetHeight(16)
	self.PaladinFrame:SetBackdropColor(0,0,0,1)
	self.PaladinFrame:SetPoint('TOPRIGHT', -79, -1)
	self.PaladinFrame:SetFrameStrata('MEDIUM')
	self.PaladinFrame.Icon = self.PaladinFrame:CreateTexture(nil, 'ARTWORK')
	self.PaladinFrame.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.PaladinFrame.Icon:SetTexCoord(r, l, t, b)
	self.PaladinFrame.Icon:SetPoint('TOPRIGHT', -1, -1)
	self.PaladinFrame.Icon:SetWidth(16)
	self.PaladinFrame.Icon:SetHeight(16)
	self.PaladinFrame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(self.PaladinFrame, "ANCHOR_TOPRIGHT");
		GameTooltip:SetText(this:GetName(), 0.96, 0.55, 0.73, 1, 1);
		GameTooltip:Show()
	end)
	self.PaladinFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.PaladinFrame:SetScript("OnMouseDown", function()
			if (arg1 == "LeftButton") then
				if Rat_Settings[this:GetName()] == 1 then
					Rat_Settings[this:GetName()] = 0
					self.PaladinFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
				else
					Rat_Settings[this:GetName()] = 1
					self.PaladinFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
				end
			end
		end)

	-- Shaman option frame
	local r, l, t, b = Rat:ClassPos("Shaman")
	self.ShamanFrame = CreateFrame('Button', "Shaman", self)
	self.ShamanFrame:SetWidth(16)
	self.ShamanFrame:SetHeight(16)
	self.ShamanFrame:SetBackdropColor(0,0,0,1)
	self.ShamanFrame:SetPoint('TOPRIGHT', -23, -1)
	self.ShamanFrame:SetFrameStrata('MEDIUM')
	self.ShamanFrame.Icon = self.ShamanFrame:CreateTexture(nil, 'ARTWORK')
	self.ShamanFrame.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.ShamanFrame.Icon:SetTexCoord(r, l, t, b)
	self.ShamanFrame.Icon:SetPoint('TOPRIGHT', -1, -1)
	self.ShamanFrame.Icon:SetWidth(16)
	self.ShamanFrame.Icon:SetHeight(16)
	self.ShamanFrame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(self.ShamanFrame, "ANCHOR_TOPRIGHT");
		GameTooltip:SetText(this:GetName(), 0.0, 0.44, 0.87, 1, 1);
		GameTooltip:Show()
	end)
	self.ShamanFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.ShamanFrame:SetScript("OnMouseDown", function()
		if (arg1 == "LeftButton") then
				if Rat_Settings[this:GetName()] == 1 then
					Rat_Settings[this:GetName()] = 0
					self.ShamanFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
				else
					Rat_Settings[this:GetName()] = 1
					self.ShamanFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
				end
			end
		end)


	-- Rogue option frame
	local r, l, t, b = Rat:ClassPos("Rogue")
	self.RogueFrame = CreateFrame('Button', "Rogue", self)
	self.RogueFrame:SetWidth(16)
	self.RogueFrame:SetHeight(16)
	self.RogueFrame:SetPoint('TOPRIGHT', -97, -1)
	self.RogueFrame:SetFrameStrata('MEDIUM')
	self.RogueFrame.Icon = self.RogueFrame:CreateTexture(nil, 'ARTWORK')
	self.RogueFrame.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.RogueFrame.Icon:SetTexCoord(r, l, t, b)
	self.RogueFrame.Icon:SetPoint('TOPRIGHT', -1, -1)
	self.RogueFrame.Icon:SetWidth(16)
	self.RogueFrame.Icon:SetHeight(16)
	self.RogueFrame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(self.RogueFrame, "ANCHOR_TOPRIGHT");
		GameTooltip:SetText(this:GetName(), 1.00, 0.96, 0.41, 1, 1);
		GameTooltip:Show()
		end)
	self.RogueFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.RogueFrame:SetScript("OnMouseDown", function()
			if (arg1 == "LeftButton") then
				if Rat_Settings[this:GetName()] == 1 then
					Rat_Settings[this:GetName()] = 0
					self.RogueFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
				else
					Rat_Settings[this:GetName()] = 1
					self.RogueFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
				end
			end
		end)

	-- Warlock option frame
	local r, l, t, b = Rat:ClassPos("Warlock")
	self.WarlockFrame = CreateFrame('Button', "Warlock", self)
	self.WarlockFrame:SetWidth(16)
	self.WarlockFrame:SetHeight(16)
	self.WarlockFrame:SetPoint('TOPRIGHT', -152, -1)
	self.WarlockFrame:SetFrameStrata('MEDIUM')
	self.WarlockFrame.Icon = self.WarlockFrame:CreateTexture(nil, 'ARTWORK')
	self.WarlockFrame.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.WarlockFrame.Icon:SetTexCoord(r, l, t, b)
	self.WarlockFrame.Icon:SetPoint('TOPRIGHT', -1, -1)
	self.WarlockFrame.Icon:SetWidth(16)
	self.WarlockFrame.Icon:SetHeight(16)
	self.WarlockFrame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(self.WarlockFrame, "ANCHOR_TOPRIGHT");
		GameTooltip:SetText(this:GetName(), 0.58, 0.51, 0.79, 1, 1);
		GameTooltip:Show()
		end)
	self.WarlockFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.WarlockFrame:SetScript("OnMouseDown", function()
			if (arg1 == "LeftButton") then
				if Rat_Settings[this:GetName()] == 1 then
					Rat_Settings[this:GetName()] = 0
					self.WarlockFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
				else
					Rat_Settings[this:GetName()] = 1
					self.WarlockFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
				end
			end
		end)


	-- Mage option frame
	local r, l, t, b = Rat:ClassPos("Mage")
	self.MageFrame = CreateFrame('Button', "Mage", self)
	self.MageFrame:SetWidth(16)
	self.MageFrame:SetHeight(16)
	self.MageFrame:SetPoint('TOPRIGHT', -134, -1)
	self.MageFrame:SetFrameStrata('MEDIUM')
	self.MageFrame.Icon = self.MageFrame:CreateTexture(nil, 'ARTWORK')
	self.MageFrame.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.MageFrame.Icon:SetTexCoord(r, l, t, b)
	self.MageFrame.Icon:SetPoint('TOPRIGHT', -1, -1)
	self.MageFrame.Icon:SetWidth(16)
	self.MageFrame.Icon:SetHeight(16)
	self.MageFrame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(self.MageFrame, "ANCHOR_TOPRIGHT");
		GameTooltip:SetText(this:GetName(), 0.25, 0.78, 0.92, 1, 1);
		GameTooltip:Show()
		end)
	self.MageFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.MageFrame:SetScript("OnMouseDown", function()
			if (arg1 == "LeftButton") then
				if Rat_Settings[this:GetName()] == 1 then
					Rat_Settings[this:GetName()] = 0
					self.MageFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
				else
					Rat_Settings[this:GetName()] = 1
					self.MageFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
				end
			end
		end)

	-- Warrior option frame
	local r, l, t, b = Rat:ClassPos("Warrior")
	self.WarriorFrame = CreateFrame('Button', "Warrior", self)
	self.WarriorFrame:SetWidth(16)
	self.WarriorFrame:SetHeight(16)
	self.WarriorFrame:SetPoint('TOPRIGHT', -171, -1)
	self.WarriorFrame:SetFrameStrata('MEDIUM')
	self.WarriorFrame.Icon = self.WarriorFrame:CreateTexture(nil, 'ARTWORK')
	self.WarriorFrame.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.WarriorFrame.Icon:SetTexCoord(r, l, t, b)
	self.WarriorFrame.Icon:SetPoint('TOPRIGHT', -1, -1)
	self.WarriorFrame.Icon:SetWidth(16)
	self.WarriorFrame.Icon:SetHeight(16)
	self.WarriorFrame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(self.WarriorFrame, "ANCHOR_TOPRIGHT");
		GameTooltip:SetText(this:GetName(), 0.78, 0.61, 0.43, 1, 1);
		GameTooltip:Show()
		end)
	self.WarriorFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.WarriorFrame:SetScript("OnMouseDown", function()
			if (arg1 == "LeftButton") then
				if Rat_Settings[this:GetName()] == 1 then
					Rat_Settings[this:GetName()] = 0
					self.WarriorFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
				else
					Rat_Settings[this:GetName()] = 1
					self.WarriorFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
				end
			end
		end)

	-- Priest option frame
	local r, l, t, b = Rat:ClassPos("Priest")
	self.PriestFrame = CreateFrame('Button', "Priest", self)
	self.PriestFrame:SetWidth(16)
	self.PriestFrame:SetHeight(16)
	self.PriestFrame:SetPoint('TOPRIGHT', -60, -1)
	self.PriestFrame:SetFrameStrata('MEDIUM')
	self.PriestFrame.Icon = self.PriestFrame:CreateTexture(nil, 'ARTWORK')
	self.PriestFrame.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.PriestFrame.Icon:SetTexCoord(r, l, t, b)
	self.PriestFrame.Icon:SetPoint('TOPRIGHT', -1, -1)
	self.PriestFrame.Icon:SetWidth(16)
	self.PriestFrame.Icon:SetHeight(16)
	self.PriestFrame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(self.PriestFrame, "ANCHOR_TOPRIGHT");
		GameTooltip:SetText(this:GetName(), 1.0, 1.0, 1.0, 1, 1);
		GameTooltip:Show()
		end)
	self.PriestFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.PriestFrame:SetScript("OnMouseDown", function()
			if (arg1 == "LeftButton") then
				if Rat_Settings[this:GetName()] == 1 then
					Rat_Settings[this:GetName()] = 0
					self.PriestFrame.Icon:SetVertexColor(0.5, 0.5, 0.5)
				else
					Rat_Settings[this:GetName()] = 1
					self.PriestFrame.Icon:SetVertexColor(1.0, 1.0, 1.0)
				end
			end
		end)

	-- create mid background
	local backdrop = {
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		tile="true",
		tileSize="8",
		edgeSize="22",
		insets={
				left="2",
				right="2",
				top="2",
				bottom="2"
			}
		}
	self.Background.Tab1:SetFrameStrata("BACKGROUND")
	self.Background.Tab1:SetWidth(self:GetWidth())
	self.Background.Tab1:SetHeight(22)
	self.Background.Tab1:SetBackdrop(backdrop)
	self.Background.Tab1:SetBackdropColor(0,0,0,0.5)
	self.Background.Tab1:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -1)

	-- create close button
	self.CloseButton = CreateFrame("Button",nil,self,"UIPanelCloseButton")
	self.CloseButton:SetPoint("TOPLEFT",self:GetWidth()-23,2)
	self.CloseButton:SetWidth(24)
	self.CloseButton:SetHeight(24)
	self.CloseButton:SetFrameStrata('MEDIUM')
	self.CloseButton:SetScript("OnMouseUp", function()
			if (arg1 == "LeftButton") then
				Rat_Settings["showhide"] = 0
			end
		end)

	-- icon
	self.Iconframe = CreateFrame('Button',"Iconframe",self)
	self.Iconframe:SetWidth(18)
	self.Iconframe:SetHeight(18)
	self.Iconframe:SetPoint("TOPLEFT",2,-1)
	self.Iconframe:SetFrameStrata('MEDIUM')
	self.Iconframe.Icon = self.Iconframe:CreateTexture(nil,'ARTWORK')
	self.Iconframe.Icon:SetWidth(18)
	self.Iconframe.Icon:SetHeight(18)
	self.Iconframe.Icon:SetPoint('TOPLEFT', 0, 0)
	self.Iconframe.Icon:SetTexture("Interface\\AddOns\\Rat\\media\\icon.tga")
	self.Iconframe:SetScript("OnEnter", function()
		self.Iconframe.Icon:SetVertexColor(0.5, 0.5, 0.5)
		GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT");
		GameTooltip:SetText("Options Menu", 1, 1, 1, 1);
		GameTooltip:Show()
	end)
	self.Iconframe:SetScript("OnLeave", function()
		self.Iconframe.Icon:SetVertexColor(1.0, 1.0, 1.0)
		GameTooltip:Hide()
	end)
	self.Iconframe:SetScript("OnMouseDown", function()
			if (arg1 == "LeftButton") then
				if Rat.Options:IsVisible() then
					Rat.Options:Hide()
				else
					Rat.Options:Show()
				end
			end
		end)
	Rat:SetTopBarVisible(not (Rat_Settings and Rat_Settings.topbar_hidden == 1))
end

-- function to congig the options frame


-- Show/hide just the top title strip (and its border) without affecting the cooldown lists
function Rat:SetTopBarVisible(show)
    Rat_Settings.topbar_hidden = show and 0 or 1

    local mf = Rat.Mainframe
    if not mf then return end

    -- Top bar background & title
    if mf.Background and mf.Background.Top then
        if show then mf.Background.Top:Show() else mf.Background.Top:Hide() end
    end

    -- Buttons on the top strip
    local topButtons = {
        mf.CloseButton, mf.Iconframe,
        mf.DruidFrame, mf.HunterFrame, mf.PaladinFrame, mf.ShamanFrame,
        mf.RogueFrame, mf.WarlockFrame, mf.MageFrame, mf.WarriorFrame, mf.PriestFrame
    }
    for _, f in ipairs(topButtons) do
        if f then if show then f:Show() else f:Hide() end end
    end

    -- Hide/restore the thin border around the top when bar is hidden
    if show then
        local backdrop = {
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = "false",
            tileSize = "8",
            edgeSize = "8",
            insets = { left = "2", right = "2", top = "2", bottom = "2" }
        }
        if mf.SetBackdrop then mf:SetBackdrop(backdrop) end
    else
        if mf.SetBackdrop then mf:SetBackdrop(nil) end
    end
end

-- ReadyFrame: shows spells that are available (not on cooldown)

function Rat.ReadyFrame:ConfigFrame()
	local rf = self
	rf.options = {}
	function rf.options:StartMoving()
		this:StartMoving()
		this.drag = true
	end
	function rf.options:StopMovingOrSizing()
		this:StopMovingOrSizing()
		this.drag = false
	end

	local backdrop = {
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = "false",
		tileSize = "8",
		edgeSize = "8",
		insets = { left = "2", right = "2", top = "2", bottom = "2" }
	}
	rf:SetFrameStrata("LOW")
	rf:SetWidth(300)
	rf:SetHeight(21)
	rf:SetPoint("CENTER", 310, 0)
	rf:SetMovable(1)
	rf:EnableMouse(1)
	rf:RegisterForDrag("LeftButton")
	rf:SetBackdrop(backdrop)

	rf:SetScript("OnDragStart", rf.options.StartMoving)
	rf:SetScript("OnDragStop", rf.options.StopMovingOrSizing)
	rf:SetScript("OnUpdate", function()
		this:EnableMouse(IsAltKeyDown())
		if not IsAltKeyDown() and this.drag then
			rf.options:StopMovingOrSizing()
		end
	end)

	rf.Background = {}
	rf.Background.Top = CreateFrame("Frame", nil, rf)
	rf.Background.Content = CreateFrame("Frame", nil, rf)

	-- top background
	local topBackdrop = {
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = "false",
		tileSize = "4",
		edgeSize = "4",
		insets = { left = "2", right = "2", top = "2", bottom = "2" }
	}
	rf.Background.Top:SetFrameStrata("BACKGROUND")
	rf.Background.Top:SetWidth(rf:GetWidth() - 2)
	rf.Background.Top:SetHeight(20)
	rf.Background.Top:SetBackdrop(topBackdrop)
	rf.Background.Top:SetBackdropColor(0, 0, 0, 1)
	rf.Background.Top:SetPoint("TOPLEFT", rf, "TOPLEFT", 1, -1)

	local topbg = rf.Background.Top:CreateTexture(nil, "ARTWORK", rf)
	topbg:SetPoint("TOPLEFT", 1, -1)
	topbg:SetWidth(rf:GetWidth() - 5)
	topbg:SetHeight(17)
	topbg:SetTexture(0.0, 0.6, 0.1)
	topbg:SetGradientAlpha("Vertical", 1, 1, 1, 0.25, 1, 1, 1, 1)

	rf.Background.Top.Title = rf.Background.Top:CreateFontString(nil, "ARTWORK")
	rf.Background.Top.Title:SetPoint("LEFT", 5, 0)
	rf.Background.Top.Title:SetFont("Fonts\\FRIZQT__.TTF", 11)
	rf.Background.Top.Title:SetTextColor(255, 255, 255, 1)
	rf.Background.Top.Title:SetShadowOffset(2, -2)
	rf.Background.Top.Title:SetText("RAT - Ready")

	-- content area
	rf.Background.Content:SetFrameStrata("BACKGROUND")
	rf.Background.Content:SetWidth(rf:GetWidth() - 2)
	rf.Background.Content:SetHeight(1)
	rf.Background.Content:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = "false",
		tileSize = "4",
		edgeSize = "4",
		insets = { left = "2", right = "2", top = "2", bottom = "2" }
	})
	rf.Background.Content:SetBackdropColor(0, 0, 0, 0.8)
	rf.Background.Content:SetPoint("TOPLEFT", rf, "TOPLEFT", 1, -21)

	rf:Hide()
end

function Rat:CreateReadyRow(playerName)
	local frame = CreateFrame("Button", "RatReady_" .. playerName, Rat.ReadyFrame.Background.Content)
	frame:SetBackdrop({ bgFile = [[Interface/Tooltips/UI-Tooltip-Background]] })
	frame:SetBackdropColor(0, 0, 0, 1)
	frame:SetWidth(Rat.ReadyFrame:GetWidth() - 4)
	frame:SetHeight(22)

	frame.unitbg = frame:CreateTexture(nil, "ARTWORK")
	frame.unitbg:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	frame.unitbg:SetWidth(60)
	frame.unitbg:SetHeight(20)
	frame.unitbg:SetPoint("TOPLEFT", 1, -1)
	frame.unitbg:SetTexture("Interface/TargetingFrame/UI-StatusBar")

	frame.unitname = frame:CreateFontString(nil, "ARTWORK")
	frame.unitname:SetPoint("LEFT", frame.unitbg, "LEFT", 2, 0)
	frame.unitname:SetFont("Fonts\\FRIZQT__.TTF", 10)
	frame.unitname:SetTextColor(255, 255, 255, 1)
	frame.unitname:SetShadowOffset(2, -2)
	frame.unitname:SetText(playerName)

	frame.icons = {}
	return frame
end

function Rat.Options:ConfigFrame()

	Rat.Options.Drag = { }
	function Rat.Options.Drag:StartMoving()
		this:StartMoving()
	end

	function Rat.Options.Drag:StopMovingOrSizing()
		this:StopMovingOrSizing()
	end

	local darkBackdrop = { bgFile="Interface/Tooltips/UI-Tooltip-Background", edgeFile="Interface/Tooltips/UI-Tooltip-Border", edgeSize=6, insets={left=1,right=1,top=1,bottom=1} }
	local panelBackdrop = { bgFile="Interface/Tooltips/UI-Tooltip-Background", edgeFile="Interface/Tooltips/UI-Tooltip-Border", edgeSize=4, insets={left=1,right=1,top=1,bottom=1} }
	local flatBackdrop = { bgFile="Interface/Tooltips/UI-Tooltip-Background" }

	local C_BG        = { 0.05, 0.05, 0.05, 0.95 }
	local C_PANEL     = { 0.08, 0.08, 0.08, 1 }
	local C_COLUMN    = { 0.06, 0.06, 0.06, 1 }
	local C_BORDER    = { 0.15, 0.15, 0.15, 1 }
	local C_TAB_ON    = { 0.12, 0.12, 0.12, 1 }
	local C_TAB_OFF   = { 0, 0, 0, 0 }
	local C_TAB_HOVER = { 0.18, 0.18, 0.18, 0.8 }
	local C_ACCENT    = { 0.3, 0.6, 1.0, 0.8 }
	local C_TEXT      = { 0.9, 0.9, 0.9, 1 }
	local C_TEXT_DIM  = { 0.6, 0.6, 0.6, 1 }

	local function StyleCheckbox(cb, icon)
		cb:SetNormalTexture("")
		cb:SetPushedTexture("")
		cb:SetHighlightTexture("")
		cb:SetCheckedTexture("")
		local check = cb:CreateTexture(nil, "OVERLAY")
		check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		check:SetWidth(20)
		check:SetHeight(20)
		check:SetPoint("BOTTOMRIGHT", 4, -4)
		if cb:GetChecked() then
			icon:SetVertexColor(1, 1, 1)
			check:Show()
		else
			icon:SetVertexColor(0.4, 0.4, 0.4)
			check:Hide()
		end
		local oldClick = cb:GetScript("OnClick")
		cb:SetScript("OnClick", function()
			if oldClick then oldClick() end
			if cb:GetChecked() then
				icon:SetVertexColor(1, 1, 1)
				check:Show()
			else
				icon:SetVertexColor(0.4, 0.4, 0.4)
				check:Hide()
			end
		end)
	end

	self:SetFrameStrata("BACKGROUND")
	self:SetWidth(1015)
	self:SetHeight(510)
	self:SetPoint("CENTER",UIParent,"CENTER",0,0)
	self:SetMovable(1)
	self:EnableMouse(1)
	self:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", Rat.Options.Drag.StartMoving)
	self:SetScript("OnDragStop", Rat.Options.Drag.StopMovingOrSizing)
	self:SetBackdrop(darkBackdrop)
	self:SetBackdropColor(unpack(C_BG))
	self:SetBackdropBorderColor(unpack(C_BORDER))

	-- background
	self.Background = {} -- Background Frame table

	self.Background.Topleft = CreateFrame("Frame",nil,self) -- Topleft Background Frame
	self.Background.Topright = CreateFrame("Frame",nil,self) -- Topright Background Frame
	self.Background.Topmid = CreateFrame("Frame",nil,self) -- Topleft Background Frame
	self.Background.Bottommid = CreateFrame("Frame",nil,self) -- Topright Background Frame
	self.Background.Bottomleft = CreateFrame("Frame",nil,self) -- Bottomleft Background Frame
	self.Background.Bottomright =  CreateFrame("Frame",nil,self) -- Bottomright Background Frame
	self.Background.Tab1 =  CreateFrame("Frame",nil,self) -- Mid Background Frame
	self.Background.Tab2 =  CreateFrame("Frame",nil,self) -- Mid Background Frame
	self.Background.Tab3 =  CreateFrame("Frame",nil,self) -- Custom spells tab
	self.Background.Button1 =  CreateFrame("Button",nil,self) -- Mid Background Frame
	self.Background.Button2 =  CreateFrame("Button",nil,self) -- Mid Background Frame
	self.Background.Button3 =  CreateFrame("Button",nil,self) -- Custom tab button

	-- Hide auction house textures (not needed with dark flat UI)
	self.Background.Topleft:Hide()
	self.Background.Topmid:Hide()
	self.Background.Topright:Hide()
	self.Background.Bottomleft:Hide()
	self.Background.Bottommid:Hide()
	self.Background.Bottomright:Hide()

	-- Tab1 Background Frame
	self.Background.Tab1:SetFrameStrata("LOW")
	self.Background.Tab1:SetWidth(1003)
	self.Background.Tab1:SetHeight(430)
	self.Background.Tab1:SetBackdrop(panelBackdrop)
	self.Background.Tab1:SetBackdropColor(unpack(C_PANEL))
	self.Background.Tab1:SetBackdropBorderColor(unpack(C_BORDER))
	self.Background.Tab1:SetPoint("TOPLEFT", self, "TOPLEFT", 6, -48)

	-- Tab2 Background Frame
	self.Background.Tab2:SetFrameStrata("LOW")
	self.Background.Tab2:SetWidth(1003)
	self.Background.Tab2:SetHeight(430)
	self.Background.Tab2:SetBackdrop(panelBackdrop)
	self.Background.Tab2:SetBackdropColor(unpack(C_PANEL))
	self.Background.Tab2:SetBackdropBorderColor(unpack(C_BORDER))
	self.Background.Tab2:SetPoint("TOPLEFT", self, "TOPLEFT", 6, -48)

	-- Tab3 Background Frame
	self.Background.Tab3:SetFrameStrata("LOW")
	self.Background.Tab3:SetWidth(1003)
	self.Background.Tab3:SetHeight(430)
	self.Background.Tab3:SetBackdrop(panelBackdrop)
	self.Background.Tab3:SetBackdropColor(unpack(C_PANEL))
	self.Background.Tab3:SetBackdropBorderColor(unpack(C_BORDER))
	self.Background.Tab3:SetPoint("TOPLEFT", self, "TOPLEFT", 6, -48)

	-- Tab buttons

	-- Tab button accent lines
	self.Background.Button1Accent = self.Background.Button1:CreateTexture(nil, "OVERLAY")
	self.Background.Button1Accent:SetHeight(1)
	self.Background.Button1Accent:SetPoint("BOTTOMLEFT", 0, 0)
	self.Background.Button1Accent:SetPoint("BOTTOMRIGHT", 0, 0)
	self.Background.Button1Accent:SetTexture(unpack(C_ACCENT))

	self.Background.Button2Accent = self.Background.Button2:CreateTexture(nil, "OVERLAY")
	self.Background.Button2Accent:SetHeight(1)
	self.Background.Button2Accent:SetPoint("BOTTOMLEFT", 0, 0)
	self.Background.Button2Accent:SetPoint("BOTTOMRIGHT", 0, 0)
	self.Background.Button2Accent:SetTexture(unpack(C_ACCENT))
	self.Background.Button2Accent:Hide()

	self.Background.Button3Accent = self.Background.Button3:CreateTexture(nil, "OVERLAY")
	self.Background.Button3Accent:SetHeight(1)
	self.Background.Button3Accent:SetPoint("BOTTOMLEFT", 0, 0)
	self.Background.Button3Accent:SetPoint("BOTTOMRIGHT", 0, 0)
	self.Background.Button3Accent:SetTexture(unpack(C_ACCENT))
	self.Background.Button3Accent:Hide()

	-- Button1
	self.Background.Button1:SetBackdrop(flatBackdrop)
	self.Background.Button1:SetBackdropColor(unpack(C_TAB_ON))
	self.Background.Button1:SetFrameStrata("MEDIUM")
	self.Background.Button1:SetPoint("TOPLEFT", self, "TOPLEFT", 80, -25)
	self.Background.Button1:SetWidth(85)
	self.Background.Button1:SetHeight(20)
	self.Background.Button1:SetScript("OnClick", function()
		self.Background.Tab1:Show()
		self.Background.Tab2:Hide()
		self.Background.Tab3:Hide()
		self.Background.Button1:SetBackdropColor(unpack(C_TAB_ON))
		self.Background.Button2:SetBackdropColor(unpack(C_TAB_OFF))
		self.Background.Button3:SetBackdropColor(unpack(C_TAB_OFF))
		self.Background.Button1Accent:Show()
		self.Background.Button2Accent:Hide()
		self.Background.Button3Accent:Hide()
	end)
	self.Background.Button1:SetScript("OnEnter", function()
		if not self.Background.Tab1:IsVisible() then
			self.Background.Button1:SetBackdropColor(unpack(C_TAB_HOVER))
		end
	end)
	self.Background.Button1:SetScript("OnLeave", function()
		if self.Background.Tab1:IsVisible() then
			self.Background.Button1:SetBackdropColor(unpack(C_TAB_ON))
		else
			self.Background.Button1:SetBackdropColor(unpack(C_TAB_OFF))
		end
	end)

	local text = self.Background.Button1:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 0)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Class options")

	-- Button2
	self.Background.Button2:SetBackdrop(flatBackdrop)
	self.Background.Button2:SetBackdropColor(unpack(C_TAB_OFF))
	self.Background.Button2:SetFrameStrata("MEDIUM")
	self.Background.Button2:SetPoint("TOPLEFT", self, "TOPLEFT", 180, -25)
	self.Background.Button2:SetWidth(60)
	self.Background.Button2:SetHeight(20)
	self.Background.Button2:SetScript("OnClick", function()
		self.Background.Tab2:Show()
		self.Background.Tab1:Hide()
		self.Background.Tab3:Hide()
		self.Background.Button2:SetBackdropColor(unpack(C_TAB_ON))
		self.Background.Button1:SetBackdropColor(unpack(C_TAB_OFF))
		self.Background.Button3:SetBackdropColor(unpack(C_TAB_OFF))
		self.Background.Button2Accent:Show()
		self.Background.Button1Accent:Hide()
		self.Background.Button3Accent:Hide()
	end)
	self.Background.Button2:SetScript("OnEnter", function()
		if not self.Background.Tab2:IsVisible() then
			self.Background.Button2:SetBackdropColor(unpack(C_TAB_HOVER))
		end
	end)
	self.Background.Button2:SetScript("OnLeave", function()
		if self.Background.Tab2:IsVisible() then
			self.Background.Button2:SetBackdropColor(unpack(C_TAB_ON))
		else
			self.Background.Button2:SetBackdropColor(unpack(C_TAB_OFF))
		end
	end)

	local text = self.Background.Button2:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 0)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Settings")

	-- Button3
	self.Background.Button3:SetBackdrop(flatBackdrop)
	self.Background.Button3:SetBackdropColor(unpack(C_TAB_OFF))
	self.Background.Button3:SetFrameStrata("MEDIUM")
	self.Background.Button3:SetPoint("TOPLEFT", self, "TOPLEFT", 255, -25)
	self.Background.Button3:SetWidth(60)
	self.Background.Button3:SetHeight(20)
	self.Background.Button3:SetScript("OnClick", function()
		self.Background.Tab3:Show()
		self.Background.Tab1:Hide()
		self.Background.Tab2:Hide()
		self.Background.Button3:SetBackdropColor(unpack(C_TAB_ON))
		self.Background.Button1:SetBackdropColor(unpack(C_TAB_OFF))
		self.Background.Button2:SetBackdropColor(unpack(C_TAB_OFF))
		self.Background.Button3Accent:Show()
		self.Background.Button1Accent:Hide()
		self.Background.Button2Accent:Hide()
	end)
	self.Background.Button3:SetScript("OnEnter", function()
		if not self.Background.Tab3:IsVisible() then
			self.Background.Button3:SetBackdropColor(unpack(C_TAB_HOVER))
		end
	end)
	self.Background.Button3:SetScript("OnLeave", function()
		if self.Background.Tab3:IsVisible() then
			self.Background.Button3:SetBackdropColor(unpack(C_TAB_ON))
		else
			self.Background.Button3:SetBackdropColor(unpack(C_TAB_OFF))
		end
	end)

	local text = self.Background.Button3:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 0)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Custom")

	self.Background.Tab2:Hide()
	self.Background.Tab3:Hide()

	-- Scale slider

	self.Background.Slider = CreateFrame("Slider", "Slider", self.Background.Tab2, 'OptionsSliderTemplate')
	self.Background.Slider:SetWidth(200)
	self.Background.Slider:SetHeight(20)
	self.Background.Slider:SetPoint("TOPLEFT", 70, -25)
	self.Background.Slider:SetMinMaxValues(0.5, 1.5)
	self.Background.Slider:SetValue(Rat_Settings["scale"])
	self.Background.Slider:SetValueStep(0.025)
	getglobal(self.Background.Slider:GetName() .. 'Low'):SetText('-100%')
	getglobal(self.Background.Slider:GetName() .. 'High'):SetText('100%')
	self.Background.Slider:SetScript("OnValueChanged", function()
		Rat_Settings["scale"] = this:GetValue()
		Rat.Mainframe:SetScale(Rat_Settings["scale"])
	end)
	self.Background.Slider:Show()
	Rat.Mainframe:SetScale(Rat_Settings["scale"])

	local text = self.Background.Slider:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 15)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Scale")

	-- Buttons for color picker

	local backdrop = {
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeSize=3,
			insets={left=1,right=1,top=1,bottom=1}
	}

	-- top bar
	self.Background.topbarcolor =  CreateFrame("Button","topbarcolor",self.Background.Tab2) --
	self.Background.topbarcolor:SetWidth(25)
	self.Background.topbarcolor:SetHeight(25)
	self.Background.topbarcolor:SetPoint("TOPLEFT", 400, -80)
	self.Background.topbarcolor:SetBackdrop(backdrop)
	self.Background.topbarcolor:SetScript("OnClick", function()
		Rat:OpenColorPicker(this, "topbarcolor")
	end)

	self.Background.topbarcolor.Texture = self.Background.topbarcolor:CreateTexture(nil, 'ARTWORK')
	self.Background.topbarcolor.Texture:SetTexture(Rat_Settings["topbarcolor"]["r"],Rat_Settings["topbarcolor"]["g"],Rat_Settings["topbarcolor"]["b"],1)
	self.Background.topbarcolor.Texture:SetPoint('TOPLEFT', 2, -2)
	self.Background.topbarcolor.Texture:SetWidth(21)
	self.Background.topbarcolor.Texture:SetHeight(21)

	local text = self.Background.topbarcolor:CreateFontString(nil, "OVERLAY")
	text:SetPoint("LEFT", 40, 0)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Title bar color")


	-- ability bar
	self.Background.abilitybarcolor =  CreateFrame("Button","abilitybarcolor",self.Background.Tab2) --
	self.Background.abilitybarcolor:SetWidth(25)
	self.Background.abilitybarcolor:SetHeight(25)
	self.Background.abilitybarcolor:SetPoint("TOPLEFT", 400, -130)
	self.Background.abilitybarcolor:SetBackdrop(backdrop)
	self.Background.abilitybarcolor:SetScript("OnClick", function()
		Rat:OpenColorPicker(this, "abilitybarcolor")
	end)

	self.Background.abilitybarcolor.Texture = self.Background.abilitybarcolor:CreateTexture(nil, 'ARTWORK')
	self.Background.abilitybarcolor.Texture:SetTexture(Rat_Settings["abilitybarcolor"]["r"],Rat_Settings["abilitybarcolor"]["g"],Rat_Settings["abilitybarcolor"]["b"],1)
	self.Background.abilitybarcolor.Texture:SetPoint('TOPLEFT', 2, -2)
	self.Background.abilitybarcolor.Texture:SetWidth(21)
	self.Background.abilitybarcolor.Texture:SetHeight(21)

	local text = self.Background.abilitybarcolor:CreateFontString(nil, "OVERLAY")
	text:SetPoint("LEFT", 40, 0)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Ability bar color")

	-- ability text
	self.Background.abilitytextcolor =  CreateFrame("Button","abilitytextcolor",self.Background.Tab2) --
	self.Background.abilitytextcolor:SetWidth(25)
	self.Background.abilitytextcolor:SetHeight(25)
	self.Background.abilitytextcolor:SetPoint("TOPLEFT", 400, -180)
	self.Background.abilitytextcolor:SetBackdrop(backdrop)
	self.Background.abilitytextcolor:SetScript("OnClick", function()
		Rat:OpenColorPicker(this, "abilitytextcolor")
	end)

	self.Background.abilitytextcolor.Texture = self.Background.abilitytextcolor:CreateTexture(nil, 'ARTWORK')
	self.Background.abilitytextcolor.Texture:SetTexture(Rat_Settings["abilitytextcolor"]["r"],Rat_Settings["abilitytextcolor"]["g"],Rat_Settings["abilitytextcolor"]["b"],1)
	self.Background.abilitytextcolor.Texture:SetPoint('TOPLEFT', 2, -2)
	self.Background.abilitytextcolor.Texture:SetWidth(21)
	self.Background.abilitytextcolor.Texture:SetHeight(21)

	local text = self.Background.abilitytextcolor:CreateFontString(nil, "OVERLAY")
	text:SetPoint("LEFT", 40, 0)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Ability text color")

	-- font dropdown

	self.FontDropdown = CreateFrame("Button", "Font Dropdown",self.Background.Tab2, "UIDropDownMenuTemplate")
	self.FontDropdown:SetPoint("TOPLEFT", 600 , -80)

	local text = self.FontDropdown:CreateFontString(nil, "OVERLAY")
	text:SetPoint("LEFT", 165, 2)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Font")

	UIDropDownMenu_Initialize(self.FontDropdown, Rat.Options.FontDrop)
	UIDropDownMenu_SetSelectedID(self.FontDropdown, Rat_Settings["font"])

	-- bartexture dropdown

	self.BarTextureDropdown = CreateFrame("Button", "Bar texture Dropdown",self.Background.Tab2, "UIDropDownMenuTemplate")
	self.BarTextureDropdown:SetPoint("TOPLEFT", 600 , -130)

	local text = self.BarTextureDropdown:CreateFontString(nil, "OVERLAY")
	text:SetPoint("LEFT", 165, 2)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Bar texture")

	UIDropDownMenu_Initialize(self.BarTextureDropdown, Rat.Options.BarTextureDrop)
	UIDropDownMenu_SetSelectedID(self.BarTextureDropdown, Rat_Settings["bartexture"])

	-- Accent separator line (top of tab content)
	self.accentLine = self.Background.Tab1:CreateTexture(nil, "BORDER")
	self.accentLine:SetHeight(1)
	self.accentLine:SetPoint('TOPLEFT', 5, -2)
	self.accentLine:SetPoint('TOPRIGHT', -5, -2)
	self.accentLine:SetTexture(unpack(C_ACCENT))

	-- Any (class-agnostic abilities)
	self.Any = CreateFrame("Frame",nil,self.Background.Tab1)
	self.Any:SetWidth(90)
	self.Any:SetHeight(420)
	self.Any:SetPoint('TOPLEFT', 7, -5)
	self.Any:SetBackdrop(panelBackdrop)
	self.Any:SetBackdropColor(unpack(C_COLUMN))
	self.Any:SetBackdropBorderColor(unpack(C_BORDER))
	self.Any.Icon = self.Any:CreateTexture(nil, 'ARTWORK')
	self.Any.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	self.Any.Icon:SetPoint('CENTER', 0, 160)
	self.Any.Icon:SetWidth(22)
	self.Any.Icon:SetHeight(22)

	-- Warrior
	local r, l, t, b = Rat:ClassPos("Warrior")
	self.Warrior = CreateFrame("Frame",nil,self.Background.Tab1)
	self.Warrior:SetWidth(90)
	self.Warrior:SetHeight(420)
	self.Warrior:SetPoint('TOPLEFT', 107, -5)
	self.Warrior:SetBackdrop(panelBackdrop)
	self.Warrior:SetBackdropColor(unpack(C_COLUMN))
	self.Warrior:SetBackdropBorderColor(unpack(C_BORDER))
	self.Warrior.Icon = self.Warrior:CreateTexture(nil, 'ARTWORK')
	self.Warrior.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.Warrior.Icon:SetTexCoord(r, l, t, b)
	self.Warrior.Icon:SetPoint('CENTER', 0, 160)
	self.Warrior.Icon:SetWidth(22)
	self.Warrior.Icon:SetHeight(22)
	local text = self.Warrior:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 190)
	text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
	text:SetText("Warrior")

	-- Warlock
	local r, l, t, b = Rat:ClassPos("Warlock")
	self.Warlock = CreateFrame("Frame",nil,self.Background.Tab1)
	self.Warlock:SetWidth(90)
	self.Warlock:SetHeight(420)
	self.Warlock:SetPoint('TOPLEFT', 207, -5)
	self.Warlock:SetBackdrop(panelBackdrop)
	self.Warlock:SetBackdropColor(unpack(C_COLUMN))
	self.Warlock:SetBackdropBorderColor(unpack(C_BORDER))
	self.Warlock.Icon = self.Warlock:CreateTexture(nil, 'ARTWORK')
	self.Warlock.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.Warlock.Icon:SetTexCoord(r, l, t, b)
	self.Warlock.Icon:SetPoint('CENTER', 0, 160)
	self.Warlock.Icon:SetWidth(22)
	self.Warlock.Icon:SetHeight(22)
	local text = self.Warlock:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 190)
	text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
	text:SetText("Warlock")

	-- Mage
	local r, l, t, b = Rat:ClassPos("Mage")
	self.Mage = CreateFrame("Frame",nil,self.Background.Tab1)
	self.Mage:SetWidth(90)
	self.Mage:SetHeight(420)
	self.Mage:SetPoint('TOPLEFT', 307, -5)
	self.Mage:SetBackdrop(panelBackdrop)
	self.Mage:SetBackdropColor(unpack(C_COLUMN))
	self.Mage:SetBackdropBorderColor(unpack(C_BORDER))
	self.Mage.Icon = self.Mage:CreateTexture(nil, 'ARTWORK')
	self.Mage.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.Mage.Icon:SetTexCoord(r, l, t, b)
	self.Mage.Icon:SetPoint('CENTER', 0, 160)
	self.Mage.Icon:SetWidth(22)
	self.Mage.Icon:SetHeight(22)
	local text = self.Mage:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 190)
	text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
	text:SetText("Mage")

	-- Rogue
	local r, l, t, b = Rat:ClassPos("Rogue")
	self.Rogue = CreateFrame("Frame",nil,self.Background.Tab1)
	self.Rogue:SetWidth(90)
	self.Rogue:SetHeight(420)
	self.Rogue:SetPoint('TOPLEFT', 407, -5)
	self.Rogue:SetBackdrop(panelBackdrop)
	self.Rogue:SetBackdropColor(unpack(C_COLUMN))
	self.Rogue:SetBackdropBorderColor(unpack(C_BORDER))
	self.Rogue.Icon = self.Rogue:CreateTexture(nil, 'ARTWORK')
	self.Rogue.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.Rogue.Icon:SetTexCoord(r, l, t, b)
	self.Rogue.Icon:SetPoint('CENTER', 0, 160)
	self.Rogue.Icon:SetWidth(22)
	self.Rogue.Icon:SetHeight(22)
	local text = self.Rogue:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 190)
	text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
	text:SetText("Rogue")

	-- Paladin
	local r, l, t, b = Rat:ClassPos("Paladin")
	self.Paladin = CreateFrame("Frame",nil,self.Background.Tab1)
	self.Paladin:SetWidth(90)
	self.Paladin:SetHeight(420)
	self.Paladin:SetPoint('TOPLEFT', 607, -5)
	self.Paladin:SetBackdrop(panelBackdrop)
	self.Paladin:SetBackdropColor(unpack(C_COLUMN))
	self.Paladin:SetBackdropBorderColor(unpack(C_BORDER))
	self.Paladin.Icon = self.Paladin:CreateTexture(nil, 'ARTWORK')
	self.Paladin.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.Paladin.Icon:SetTexCoord(r, l, t, b)
	self.Paladin.Icon:SetPoint('CENTER', 0, 160)
	self.Paladin.Icon:SetWidth(22)
	self.Paladin.Icon:SetHeight(22)
	local text = self.Paladin:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 190)
	text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
	text:SetText("Paladin")

	-- Hunter
	local r, l, t, b = Rat:ClassPos("Hunter")
	self.Hunter = CreateFrame("Frame",nil,self.Background.Tab1)
	self.Hunter:SetWidth(90)
	self.Hunter:SetHeight(420)
	self.Hunter:SetPoint('TOPLEFT', 507, -5)
	self.Hunter:SetBackdrop(panelBackdrop)
	self.Hunter:SetBackdropColor(unpack(C_COLUMN))
	self.Hunter:SetBackdropBorderColor(unpack(C_BORDER))
	self.Hunter.Icon = self.Hunter:CreateTexture(nil, 'ARTWORK')
	self.Hunter.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.Hunter.Icon:SetTexCoord(r, l, t, b)
	self.Hunter.Icon:SetPoint('CENTER', 0, 160)
	self.Hunter.Icon:SetWidth(22)
	self.Hunter.Icon:SetHeight(22)
	local text = self.Hunter:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 190)
	text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
	text:SetText("Hunter")

	-- Priest
	local r, l, t, b = Rat:ClassPos("Priest")
	self.Priest = CreateFrame("Frame",nil,self.Background.Tab1)
	self.Priest:SetWidth(90)
	self.Priest:SetHeight(420)
	self.Priest:SetPoint('TOPLEFT', 707, -5)
	self.Priest:SetBackdrop(panelBackdrop)
	self.Priest:SetBackdropColor(unpack(C_COLUMN))
	self.Priest:SetBackdropBorderColor(unpack(C_BORDER))
	self.Priest.Icon = self.Priest:CreateTexture(nil, 'ARTWORK')
	self.Priest.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.Priest.Icon:SetTexCoord(r, l, t, b)
	self.Priest.Icon:SetPoint('CENTER', 0, 160)
	self.Priest.Icon:SetWidth(22)
	self.Priest.Icon:SetHeight(22)
	local text = self.Priest:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 190)
	text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
	text:SetText("Priest")

	-- Druid
	local r, l, t, b = Rat:ClassPos("Druid")
	self.Druid = CreateFrame("Frame",nil,self.Background.Tab1)
	self.Druid:SetWidth(90)
	self.Druid:SetHeight(420)
	self.Druid:SetPoint('TOPLEFT', 807, -5)
	self.Druid:SetBackdrop(panelBackdrop)
	self.Druid:SetBackdropColor(unpack(C_COLUMN))
	self.Druid:SetBackdropBorderColor(unpack(C_BORDER))
	self.Druid.Icon = self.Druid:CreateTexture(nil, 'ARTWORK')
	self.Druid.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.Druid.Icon:SetTexCoord(r, l, t, b)
	self.Druid.Icon:SetPoint('CENTER', 0, 160)
	self.Druid.Icon:SetWidth(22)
	self.Druid.Icon:SetHeight(22)
	local text = self.Druid:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 190)
	text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
	text:SetText("Druid")

	-- Shaman
	local r, l, t, b = Rat:ClassPos("Shaman")
	self.Shaman = CreateFrame("Frame",nil,self.Background.Tab1)
	self.Shaman:SetWidth(90)
	self.Shaman:SetHeight(420)
	self.Shaman:SetPoint('TOPLEFT', 907, -5)
	self.Shaman:SetBackdrop(panelBackdrop)
	self.Shaman:SetBackdropColor(unpack(C_COLUMN))
	self.Shaman:SetBackdropBorderColor(unpack(C_BORDER))
	self.Shaman.Icon = self.Shaman:CreateTexture(nil, 'ARTWORK')
	self.Shaman.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	self.Shaman.Icon:SetTexCoord(r, l, t, b)
	self.Shaman.Icon:SetPoint('CENTER', 0, 160)
	self.Shaman.Icon:SetHeight(22)
	self.Shaman.Icon:SetWidth(22)
	local text = self.Shaman:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 190)
	text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
	text:SetText("Shaman")

	-- checkboxes

	-- Any --

	-- "Any" label
	local text = self.Any:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", 0, 190)
	text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
	text:SetText("Any")

	-- Powerful Smelling Salts
	local Checkbox = CreateFrame("CheckButton", "Powerful Smelling Salts", self.Any, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,80)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Powerful Smelling Salts"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Powerful Smelling Salts"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Powerful Smelling Salts"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Powerful Smelling Salts"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Any:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Smelling Salts")

	-- Warrior --

	-- Shield Wall
	local Checkbox = CreateFrame("CheckButton", "Shield Wall", self.Warrior, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,80)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Shield Wall"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Shield Wall"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Shield Wall"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Shield Wall"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Warrior:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Shield Wall")

	-- Challenging Shout
	local Checkbox = CreateFrame("CheckButton", "Challenging Shout", self.Warrior, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,35)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Challenging Shout"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Challenging Shout"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Challenging Shout"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Challenging Shout"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Warrior:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Challenging Shout")

		-- Taunt
	local Checkbox = CreateFrame("CheckButton", "Taunt", self.Warrior, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-10) -- Placed after Challenging Shout (Y=35)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Taunt"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Taunt"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Taunt"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Taunt"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Warrior:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Taunt")

	-- Death Wish
	local Checkbox = CreateFrame("CheckButton", "Death Wish", self.Warrior, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-55)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Death Wish"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Death Wish"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Death Wish"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Death Wish"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Warrior:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Death Wish")

	-- Pummel
	local Checkbox = CreateFrame("CheckButton", "Pummel", self.Warrior, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-100)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Pummel"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Pummel"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Pummel"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Pummel"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Warrior:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Pummel")

	-- Disarm
	local Checkbox = CreateFrame("CheckButton", "Disarm", self.Warrior, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-145)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Disarm"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Disarm"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Disarm"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Disarm"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Warrior:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Disarm")

	-- Warlock

	-- Major Soulstone
	local Checkbox = CreateFrame("CheckButton", "Major Soulstone", self.Warlock, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,80)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Major Soulstone"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Major Soulstone"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Major Soulstone"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Major Soulstone"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Warlock:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Major Soulstone")

	-- Mage

	-- Counterspell
	local Checkbox = CreateFrame("CheckButton", "Counterspell", self.Mage, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,80)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Counterspell"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Counterspell"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Counterspell"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Counterspell"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Mage:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Counterspell")

	-- Rogue

	-- Kick
	local Checkbox = CreateFrame("CheckButton", "Kick", self.Rogue, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,80)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Kick"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Kick"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Kick"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Kick"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Rogue:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Kick")

	-- Paladin

	-- Lay on Hands
	local Checkbox = CreateFrame("CheckButton", "Lay on Hands", self.Paladin, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,80)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Lay on Hands"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Lay on Hands"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Lay on Hands"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Lay on Hands"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Paladin:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Lay on Hands")

	-- Blessing of Protection
	local Checkbox = CreateFrame("CheckButton", "Blessing of Protection", self.Paladin, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,35)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Blessing of Protection"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Blessing of Protection"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Blessing of Protection"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Blessing of Protection"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Paladin:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Blessing of Protection")

	-- Divine Shield
	local Checkbox = CreateFrame("CheckButton", "Divine Shield", self.Paladin, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-10)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Divine Shield"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Divine Shield"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Divine Shield"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Divine Shield"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Paladin:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Divine Shield")

	-- Divine Intervention
	local Checkbox = CreateFrame("CheckButton", "Divine Intervention", self.Paladin, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-55)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Divine Intervention"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Divine Intervention"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Divine Intervention"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Divine Intervention"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Paladin:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Divine Intervention")

	-- Hand of Reckoning
	local Checkbox = CreateFrame("CheckButton", "Hand of Reckoning", self.Paladin, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-100) -- Adjust Y offset as needed (Divine Intervention is at Y=-55)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Hand of Reckoning"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Hand of Reckoning"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Hand of Reckoning"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Hand of Reckoning"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Paladin:CreateFontString(nil, "OVERLAY") -- Changed self.Warrior to self.Paladin
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Hand of Reckoning")

	-- Bulwark of the Righteous
	local Checkbox = CreateFrame("CheckButton", "Bulwark of the Righteous", self.Paladin, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-145)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Bulwark of the Righteous"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Bulwark of the Righteous"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Bulwark of the Righteous"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Bulwark of the Righteous"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Paladin:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Bulwark of the Righteous")

	-- Shaman

	-- Reincarnation
	local Checkbox = CreateFrame("CheckButton", "Reincarnation", self.Shaman, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,80)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Reincarnation"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Reincarnation"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Reincarnation"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Reincarnation"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Shaman:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Reincarnation")

	-- Earth Shock
	local Checkbox = CreateFrame("CheckButton", "Earth Shock", self.Shaman, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,35)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Earth Shock"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Earth Shock"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Earth Shock"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Earth Shock"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Shaman:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Earth Shock")

	-- Spirit Link
	local Checkbox = CreateFrame("CheckButton", "Spirit Link", self.Shaman, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-10)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Spirit Link"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Spirit Link"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Spirit Link"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Spirit Link"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Shaman:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Spirit Link")

	-- Earthshaker Slam
	local Checkbox = CreateFrame("CheckButton", "Earthshaker Slam", self.Shaman, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-55) -- Placed after Spirit Link (Y=-10)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Earthshaker Slam"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Earthshaker Slam"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Earthshaker Slam"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Earthshaker Slam"]) -- Make sure this matches the key in cdtbl
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Shaman:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Earthshaker Slam")

	-- Hunter

	-- Tranquilizing Shot
	local Checkbox = CreateFrame("CheckButton", "Tranquilizing Shot", self.Hunter, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,80)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Tranquilizing Shot"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Tranquilizing Shot"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Tranquilizing Shot"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Tranquilizing Shot"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Hunter:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Tranquilizing Shot")

	-- Druid

	-- Innervate
	local Checkbox = CreateFrame("CheckButton", "Innervate", self.Druid, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,80)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Innervate"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Innervate"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Innervate"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Innervate"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Druid:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Innervate")

	-- Rebirth
	local Checkbox = CreateFrame("CheckButton", "Rebirth", self.Druid, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,35)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Rebirth"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Rebirth"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Rebirth"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Rebirth"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Druid:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Rebirth")

	-- Challenging Roar
	local Checkbox = CreateFrame("CheckButton", "Challenging Roar", self.Druid, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-10)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Challenging Roar"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Challenging Roar"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Challenging Roar"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Challenging Roar"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Druid:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Challenging Roar")

	-- Growl
	local Checkbox = CreateFrame("CheckButton", "Growl", self.Druid, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-55) -- Adjust Y offset as needed (Challenging Roar is at Y=35)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Growl"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Growl"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Growl"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Growl"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Druid:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Growl")

	-- Tranquility
	local Checkbox = CreateFrame("CheckButton", "Tranquility", self.Druid, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-100)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Tranquility"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Tranquility"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Tranquility"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Tranquility"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Druid:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Tranquility")

	-- Barkskin (Feral)
	local Checkbox = CreateFrame("CheckButton", "Barkskin (Feral)", self.Druid, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-145)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Barkskin (Feral)"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Barkskin (Feral)"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Barkskin (Feral)"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Barkskin (Feral)"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Druid:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Barkskin (Feral)")

	-- Frenzied Regeneration
	local Checkbox = CreateFrame("CheckButton", "Frenzied Regeneration", self.Druid, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,-190)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Frenzied Regeneration"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Frenzied Regeneration"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Frenzied Regeneration"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Frenzied Regeneration"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Druid:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Frenzied Regeneration")

	-- Priest

	-- Lightwell
	local Checkbox = CreateFrame("CheckButton", "Lightwell", self.Priest, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,80)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Lightwell"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Lightwell"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Lightwell"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Lightwell"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Priest:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Lightwell")

	-- Fear Ward
	local Checkbox = CreateFrame("CheckButton", "Fear Ward", self.Priest, "UICheckButtonTemplate")
	Checkbox:SetPoint("CENTER",0,35)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("LOW")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Fear Ward"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Fear Ward"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Fear Ward"])
	local Icon = Checkbox:CreateTexture(nil, 'ARTWORK',1)
	Icon:SetTexture(cdtbl["Fear Ward"])
	Icon:SetWidth(30)
	Icon:SetHeight(30)
	Icon:SetPoint("CENTER",0,0)
	StyleCheckbox(Checkbox, Icon)
	local text = self.Priest:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", Checkbox, "CENTER", 0, 25)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(2,-2)
    text:SetText("Fear Ward")

	-- icon
	self.Icon = self:CreateTexture(nil, 'ARTWORK')
	self.Icon:SetTexture("Interface\\AddOns\\Rat\\media\\icon.tga")
	self.Icon:SetPoint('TOPLEFT', 4, -2)
	self.Icon:SetWidth(20)
	self.Icon:SetHeight(20)

	-- title text
	local text = self:CreateFontString(nil, "OVERLAY")
	text:SetPoint("TOP", 0, -8)
	text:SetFont("Fonts\\FRIZQT__.TTF", 13)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Raid Ability Tracker v"..Rat_Version)

	-- Header accent line
	self.headerAccent = self:CreateTexture(nil, "OVERLAY")
	self.headerAccent:SetHeight(1)
	self.headerAccent:SetPoint("TOPLEFT", 4, -24)
	self.headerAccent:SetPoint("TOPRIGHT", -4, -24)
	self.headerAccent:SetTexture(unpack(C_ACCENT))

	-- minimap option

	local Checkbox = CreateFrame("CheckButton", "Minimap", self.Background.Tab2, "UICheckButtonTemplate")
	Checkbox:SetPoint("TOPLEFT",70,-80)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("MEDIUM")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Minimap"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Minimap"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Turn on/off", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Minimap"])
	local text = Checkbox:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", 45, 0)
    text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
    text:SetText("Show minimap icon")

	-- notify option

	local Checkbox = CreateFrame("CheckButton", "Notify", self.Background.Tab2, "UICheckButtonTemplate")
	Checkbox:SetParent(self.Background.Tab2)
	Checkbox:SetPoint("TOPLEFT",70,-130)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("MEDIUM")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Notify"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Notify"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Notify when abilites are ready", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Notify"])
	local text = Checkbox:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", 45, 0)
    text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
    text:SetText("Ability notification")

	-- Invert abilities

	local Checkbox = CreateFrame("CheckButton", "Invert", self.Background.Tab2, "UICheckButtonTemplate")
	Checkbox:SetParent(self.Background.Tab2)
	Checkbox:SetPoint("TOPLEFT",70,-180)
	Checkbox:SetWidth(30)
	Checkbox:SetHeight(30)
	Checkbox:SetFrameStrata("MEDIUM")
	Checkbox:SetScript("OnClick", function ()
		if Checkbox:GetChecked() == nil then
			Rat_Settings["Invert"] = nil
		elseif Checkbox:GetChecked() == 1 then
			Rat_Settings["Invert"] = 1
		end
		end)
	Checkbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(Checkbox, "ANCHOR_RIGHT");
		GameTooltip:SetText("Invert abilites upwards", 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	Checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Checkbox:SetChecked(Rat_Settings["Invert"])
	local text = Checkbox:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", 45, 0)
    text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
    text:SetText("Invert abilities")

	-- Custom spells tab content (Tab3)

	Rat.Options.CustomSelectedClass = "Any"
	Rat.Options.CustomEntryFrames = {}
	Rat.Options.CustomScrollOffset = 0

	-- Class dropdown label
	local text = self.Background.Tab3:CreateFontString(nil, "OVERLAY")
	text:SetPoint("TOPLEFT", 35, -8)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Class")

	-- Class dropdown
	self.CustomClassDropdown = CreateFrame("Button", "RatCustomClassDropdown", self.Background.Tab3, "UIDropDownMenuTemplate")
	self.CustomClassDropdown:SetPoint("TOPLEFT", 10, -20)
	UIDropDownMenu_Initialize(self.CustomClassDropdown, Rat.Options.CustomClassDrop)
	UIDropDownMenu_SetSelectedID(self.CustomClassDropdown, 1)

	-- Spell Name label
	local text = self.Background.Tab3:CreateFontString(nil, "OVERLAY")
	text:SetPoint("TOPLEFT", 35, -55)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Spell Name")

	-- Spell Name editbox
	local editBd = {bgFile="Interface/Tooltips/UI-Tooltip-Background", edgeFile="Interface/Tooltips/UI-Tooltip-Border", edgeSize=4, insets={left=1,right=1,top=1,bottom=1}}
	self.CustomNameBox = CreateFrame("EditBox", "RatCustomName", self.Background.Tab3)
	self.CustomNameBox:SetWidth(200)
	self.CustomNameBox:SetHeight(20)
	self.CustomNameBox:SetPoint("TOPLEFT", 30, -70)
	self.CustomNameBox:SetFontObject(ChatFontNormal)
	self.CustomNameBox:SetAutoFocus(false)
	self.CustomNameBox:SetBackdrop(editBd)
	self.CustomNameBox:SetBackdropColor(unpack(C_COLUMN))
	self.CustomNameBox:SetBackdropBorderColor(unpack(C_BORDER))
	self.CustomNameBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	self.CustomNameBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)

	-- Spell ID label
	local text = self.Background.Tab3:CreateFontString(nil, "OVERLAY")
	text:SetPoint("TOPLEFT", 35, -95)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Spell ID (optional)")

	-- Spell ID editbox
	self.CustomIdBox = CreateFrame("EditBox", "RatCustomId", self.Background.Tab3)
	self.CustomIdBox:SetWidth(100)
	self.CustomIdBox:SetHeight(20)
	self.CustomIdBox:SetPoint("TOPLEFT", 30, -110)
	self.CustomIdBox:SetFontObject(ChatFontNormal)
	self.CustomIdBox:SetAutoFocus(false)
	self.CustomIdBox:SetNumeric(true)
	self.CustomIdBox:SetBackdrop(editBd)
	self.CustomIdBox:SetBackdropColor(unpack(C_COLUMN))
	self.CustomIdBox:SetBackdropBorderColor(unpack(C_BORDER))
	self.CustomIdBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	self.CustomIdBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)

	-- Cooldown label
	local text = self.Background.Tab3:CreateFontString(nil, "OVERLAY")
	text:SetPoint("TOPLEFT", 35, -135)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_TEXT))
	text:SetShadowOffset(1,-1)
	text:SetText("Cooldown (seconds)")

	-- Cooldown editbox
	self.CustomCdBox = CreateFrame("EditBox", "RatCustomCd", self.Background.Tab3)
	self.CustomCdBox:SetWidth(100)
	self.CustomCdBox:SetHeight(20)
	self.CustomCdBox:SetPoint("TOPLEFT", 30, -150)
	self.CustomCdBox:SetFontObject(ChatFontNormal)
	self.CustomCdBox:SetAutoFocus(false)
	self.CustomCdBox:SetNumeric(true)
	self.CustomCdBox:SetBackdrop(editBd)
	self.CustomCdBox:SetBackdropColor(unpack(C_COLUMN))
	self.CustomCdBox:SetBackdropBorderColor(unpack(C_BORDER))
	self.CustomCdBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	self.CustomCdBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)

	-- Add button
	self.CustomAddBtn = CreateFrame("Button", nil, self.Background.Tab3, "UIPanelButtonTemplate")
	self.CustomAddBtn:SetPoint("TOPLEFT", 30, -190)
	self.CustomAddBtn:SetWidth(79)
	self.CustomAddBtn:SetHeight(18)
	self.CustomAddBtn:SetText("Add")
	self.CustomAddBtn:SetScript("OnClick", function()
		local name = self.CustomNameBox:GetText()
		local idText = self.CustomIdBox:GetText()
		local cdText = self.CustomCdBox:GetText()

		if not name or name == "" then
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Rat]|r Spell name is required.")
			return
		end
		local cd = tonumber(cdText)
		if not cd or cd <= 0 then
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Rat]|r Cooldown must be a positive number.")
			return
		end

		-- Check for duplicates
		Rat_Settings["custom_spells"] = Rat_Settings["custom_spells"] or {}
		for _, existing in ipairs(Rat_Settings["custom_spells"]) do
			if existing.name == name then
				DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Rat]|r Spell '"..name.."' already exists.")
				return
			end
		end

		local entry = {
			name = name,
			spellId = tonumber(idText),
			cd = cd,
			class = Rat.Options.CustomSelectedClass
		}
		table.insert(Rat_Settings["custom_spells"], entry)
		Rat_LoadCustomSpells()
		Rat:RefreshCustomList()
		Rat:Update(true)

		-- Clear inputs
		self.CustomNameBox:SetText("")
		self.CustomIdBox:SetText("")
		self.CustomCdBox:SetText("")
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A[Rat]|r Added custom spell: "..name)
	end)

	-- Separator line
	local sep = self.Background.Tab3:CreateTexture(nil, "BORDER")
	sep:SetWidth(950)
	sep:SetHeight(1)
	sep:SetPoint("TOPLEFT", 20, -220)
	sep:SetTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.2)

	-- Custom Spells list header
	local text = self.Background.Tab3:CreateFontString(nil, "OVERLAY")
	text:SetPoint("TOPLEFT", 30, -230)
	text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	text:SetTextColor(unpack(C_ACCENT))
	text:SetShadowOffset(1,-1)
	text:SetText("Custom Spells")

	-- Mousewheel scrolling for the custom spell list
	self.Background.Tab3:EnableMouseWheel(1)
	self.Background.Tab3:SetScript("OnMouseWheel", function()
		if arg1 > 0 then
			Rat.Options.CustomScrollOffset = Rat.Options.CustomScrollOffset - 1
		else
			Rat.Options.CustomScrollOffset = Rat.Options.CustomScrollOffset + 1
		end
		Rat:RefreshCustomList()
	end)

	-- Initial list population
	Rat:RefreshCustomList()

	-- create close button
	self.CloseButton = CreateFrame("Button",nil,self,"UIPanelCloseButton")
	self.CloseButton:SetPoint("TOPLEFT",self:GetWidth()-23,2)
	self.CloseButton:SetWidth(24)
	self.CloseButton:SetHeight(24)
	self.CloseButton:SetFrameStrata('MEDIUM')

	--button

	self.version = CreateFrame("Button",nil,self,"UIPanelButtonTemplate")
	self.version:SetPoint("TOPRIGHT",-19,-1)
	self.version:SetWidth(89)
	self.version:SetHeight(16)
	self.version:SetText("Version Check")
	self.version:SetScript("OnClick", function()
	PlaySound("igMainMenuOptionCheckBoxOn");
	if sendThrottle["versioncheck"] == nil or (GetTime() - sendThrottle["versioncheck"]) > 10 then
		SendAddonMessage("RATVERSIONCHECK",0,"RAID");
		Rat.Version:Show()
		sendThrottle["versioncheck"] = GetTime()
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r Don't spam the check function!",1,1,1)
	end
	end)

	-- done button
	self.dbutton = CreateFrame("Button",nil,self)
	self.dbutton:SetPoint("BOTTOM",0,10)
	self.dbutton:SetFrameStrata("MEDIUM")
	self.dbutton:SetWidth(80)
	self.dbutton:SetHeight(24)
	self.dbutton:SetBackdrop(panelBackdrop)
	self.dbutton:SetBackdropColor(unpack(C_TAB_ON))
	self.dbutton:SetBackdropBorderColor(unpack(C_BORDER))
	self.dbutton.text = self.dbutton:CreateFontString(nil, "OVERLAY")
	self.dbutton.text:SetPoint("CENTER", 0, 0)
	self.dbutton.text:SetFont("Fonts\\FRIZQT__.TTF", 11)
	self.dbutton.text:SetTextColor(unpack(C_TEXT))
	self.dbutton.text:SetShadowOffset(1, -1)
	self.dbutton.text:SetText("Done")
	self.dbutton:SetScript("OnClick", function() PlaySound("igMainMenuOptionCheckBoxOn"); Rat.Options:Hide() end)
	self.dbutton:SetScript("OnEnter", function() self.dbutton:SetBackdropColor(unpack(C_TAB_HOVER)) end)
	self.dbutton:SetScript("OnLeave", function() self.dbutton:SetBackdropColor(unpack(C_TAB_ON)) end)

	self:Hide()
end

-- custom class dropdown init
function Rat.Options:CustomClassDrop()
	local classes = {"Any", "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid"}
	local info = {}
	for i = 1, 10 do
		info.text = classes[i]
		info.value = i
		info.func = function()
			UIDropDownMenu_SetSelectedID(Rat.Options.CustomClassDropdown, this:GetID())
			Rat.Options.CustomSelectedClass = classes[this:GetID()]
		end
		info.checked = nil
		info.checkable = nil
		UIDropDownMenu_AddButton(info, 1)
	end
end

-- refresh custom spell list display
function Rat:RefreshCustomList()
	local entries = Rat_Settings["custom_spells"] or {}
	local numEntries = 0
	for _ in ipairs(entries) do numEntries = numEntries + 1 end

	local maxVisible = 6
	local startY = -245
	local rowHeight = 30
	local maxOffset = numEntries - maxVisible
	if maxOffset < 0 then maxOffset = 0 end

	-- Clamp scroll offset
	if Rat.Options.CustomScrollOffset > maxOffset then
		Rat.Options.CustomScrollOffset = maxOffset
	end
	if Rat.Options.CustomScrollOffset < 0 then
		Rat.Options.CustomScrollOffset = 0
	end

	-- Hide all existing entry frames
	for i = 1, 20 do
		if Rat.Options.CustomEntryFrames[i] then
			Rat.Options.CustomEntryFrames[i]:Hide()
		end
	end

	-- Show visible entries
	local visibleCount = 0
	for idx = Rat.Options.CustomScrollOffset + 1, numEntries do
		if visibleCount >= maxVisible then break end
		visibleCount = visibleCount + 1
		local entry = entries[idx]
		local frame = Rat.Options.CustomEntryFrames[visibleCount]

		if not frame then
			frame = CreateFrame("Frame", nil, Rat.Options.Background.Tab3)
			frame:SetWidth(950)
			frame:SetHeight(28)

			-- Checkbox
			frame.cb = CreateFrame("CheckButton", "RatCustomCB"..visibleCount, frame, "UICheckButtonTemplate")
			frame.cb:SetPoint("LEFT", 0, 0)
			frame.cb:SetWidth(30)
			frame.cb:SetHeight(30)
			frame.cb:SetFrameStrata("MEDIUM")

			-- Icon inside checkbox
			frame.icon = frame.cb:CreateTexture(nil, "ARTWORK", 1)
			frame.icon:SetWidth(20)
			frame.icon:SetHeight(20)
			frame.icon:SetPoint("CENTER", 0, 0)

			-- Modern checkbox style
			frame.cb:SetNormalTexture("")
			frame.cb:SetPushedTexture("")
			frame.cb:SetHighlightTexture("")
			frame.cb:SetCheckedTexture("")
			frame.check = frame.cb:CreateTexture(nil, "OVERLAY")
			frame.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
			frame.check:SetWidth(20)
			frame.check:SetHeight(20)
			frame.check:SetPoint("BOTTOMRIGHT", 4, -4)

			-- Name text
			frame.nameText = frame:CreateFontString(nil, "OVERLAY")
			frame.nameText:SetPoint("LEFT", frame.cb, "RIGHT", 5, 0)
			frame.nameText:SetFont("Fonts\\FRIZQT__.TTF", 12)
			frame.nameText:SetTextColor(1, 1, 1, 1)
			frame.nameText:SetShadowOffset(2, -2)

			-- CD text
			frame.cdText = frame:CreateFontString(nil, "OVERLAY")
			frame.cdText:SetPoint("LEFT", frame.nameText, "RIGHT", 10, 0)
			frame.cdText:SetFont("Fonts\\FRIZQT__.TTF", 12)
			frame.cdText:SetTextColor(0.7, 0.7, 0.7, 1)
			frame.cdText:SetShadowOffset(2, -2)

			-- Remove button
			frame.removeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
			frame.removeBtn:SetPoint("RIGHT", -10, 0)
			frame.removeBtn:SetWidth(60)
			frame.removeBtn:SetHeight(18)
			frame.removeBtn:SetText("Remove")

			Rat.Options.CustomEntryFrames[visibleCount] = frame
		end

		-- Update frame position
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", Rat.Options.Background.Tab3, "TOPLEFT", 30, startY - ((visibleCount - 1) * rowHeight))

		-- Set checkbox state
		local entryName = entry.name
		frame.cb:SetChecked(Rat_Settings[entryName])
		frame.cb:SetScript("OnClick", function()
			if frame.cb:GetChecked() then
				Rat_Settings[entryName] = 1
				frame.icon:SetVertexColor(1, 1, 1)
				frame.check:Show()
			else
				Rat_Settings[entryName] = nil
				frame.icon:SetVertexColor(0.4, 0.4, 0.4)
				frame.check:Hide()
			end
		end)

		-- Set icon
		local texture = cdtbl[entryName] or "Interface\\Icons\\INV_Misc_QuestionMark"
		frame.icon:SetTexture(texture)

		-- Set initial dim/bright state
		if frame.cb:GetChecked() then
			frame.icon:SetVertexColor(1, 1, 1)
			frame.check:Show()
		else
			frame.icon:SetVertexColor(0.4, 0.4, 0.4)
			frame.check:Hide()
		end

		-- Set name and cooldown text
		frame.nameText:SetText(entryName)
		local cdStr = entry.cd .. "s"
		if entry.cd >= 3600 then
			cdStr = string.format("%.1fh", entry.cd / 3600)
		elseif entry.cd >= 60 then
			cdStr = string.format("%.0fm", entry.cd / 60)
		end
		frame.cdText:SetText("(" .. cdStr .. ")")

		-- Remove button handler
		frame.removeBtn:SetScript("OnClick", function()
			-- Find and remove entry by name
			local spells = Rat_Settings["custom_spells"]
			for j = 1, 100 do
				if not spells[j] then break end
				if spells[j].name == entryName then
					table.remove(spells, j)
					break
				end
			end
			-- Clean up tables
			L[entryName] = nil
			RAT_COOLDOWN[entryName] = nil
			Rat_Settings[entryName] = nil
			-- Clean up active tracking
			for playerName, abilities in pairs(RatTbl) do
				if abilities[entryName] then
					abilities[entryName] = nil
					local tname = playerName .. "." .. entryName
					if RatFrames[tname] then
						RatFrames[tname]:Hide()
						RatFrames[tname] = nil
					end
				end
			end
			Rat:RefreshCustomList()
			Rat:Update(true)
			DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A[Rat]|r Removed custom spell: " .. entryName)
		end)

		frame:Show()
	end
end

-- dropdown functions

function Rat.Options:FontDrop()
	local info={}
	local i=1
	for k,v in pairs(Rat_Font) do
		info.text=v
		info.value=i
		info.func= function () UIDropDownMenu_SetSelectedID(Rat.Options.FontDropdown, this:GetID())
			Rat_Settings["font"] = this:GetID()
			Rat.Mainframe.Background.Top.Title:SetFont("Interface\\AddOns\\Rat\\fonts\\"..Rat_Font[Rat_Settings["font"]]..".TTF", Rat_FontSize[Rat_Settings["font"]]+1)
		end
		info.checked = nil
		info.checkable = nil
		UIDropDownMenu_AddButton(info, 1)
		i=i+1
	end
end

function Rat.Options:BarTextureDrop()
	local info={}
	local i=1
	for k,v in pairs(Rat_BarTexture) do
		info.text=v
		info.value=i
		info.func= function () UIDropDownMenu_SetSelectedID(Rat.Options.BarTextureDropdown, this:GetID())
			Rat_Settings["bartexture"] = this:GetID()
		end
		info.checked = nil
		info.checkable = nil
		UIDropDownMenu_AddButton(info, 1)
		i=i+1
	end
end

-- function that creates the cooldown bars that will be shown in the Rat window

function Rat:CreateFrame(name)
	local frame = CreateFrame('Button', name, Rat.Mainframe.Background.Tab1)
	frame:SetBackdrop({ bgFile=[[Interface/Tooltips/UI-Tooltip-Background]] })
	frame:SetBackdropColor(0,0,0,1)
	frame.unit = frame:CreateTexture(nil, 'ARTWORK')
	frame.unit:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	frame.unit:SetWidth(60)
	frame.unit:SetHeight(20)
	frame.unit:SetPoint('TOPLEFT', 1, -1)
	frame.unit:SetTexture("Interface/TargetingFrame/UI-StatusBar")
	frame.unitname = frame:CreateFontString(nil, "ARTWORK")
	frame.unitname:SetPoint("LEFT", frame.unit, "LEFT", 2, 0)
	frame.unitname:SetFont("Fonts\\FRIZQT__.TTF", 10)
	frame.unitname:SetTextColor(255, 255, 255, 1)
	frame.unitname:SetShadowOffset(2,-2)
	frame.unitname:SetText("Name")
	frame.icon = frame:CreateTexture(nil, 'OVERLAY')
	frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	frame.icon:SetWidth(20)
	frame.icon:SetHeight(20)
	frame.icon:SetPoint('TOPLEFT', 62, -1)
	frame.bar = frame:CreateTexture(nil, 'ARTWORK')
	frame.bar:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	frame.bar:SetWidth(20)
	frame.bar:SetHeight(20)
	frame.bar:SetPoint('TOPLEFT', 83, -1)
	frame.bar:SetTexture(Rat_Settings["abilitybarcolor"]["r"],Rat_Settings["abilitybarcolor"]["g"],Rat_Settings["abilitybarcolor"]["b"],1)
	frame.timer = frame:CreateFontString(nil, "OVERLAY")
	frame.timer:SetPoint("LEFT", frame, "LEFT", 90, 0)
	frame.timer:SetFont("Fonts\\FRIZQT__.TTF", 10)
	frame.timer:SetTextColor(Rat_Settings["abilitytextcolor"]["r"],Rat_Settings["abilitytextcolor"]["g"],Rat_Settings["abilitytextcolor"]["b"], 1)
	frame.timer:SetShadowOffset(2,-2)
	frame.timer:SetText("1")
	frame.time = frame:CreateFontString(nil, "OVERLAY")
	frame.time:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
	frame.time:SetFont("Fonts\\FRIZQT__.TTF", 11)
	frame.time:SetTextColor(Rat_Settings["abilitytextcolor"]["r"],Rat_Settings["abilitytextcolor"]["g"],Rat_Settings["abilitytextcolor"]["b"], 1)
	frame.time:SetShadowOffset(2,-2)
	frame.time:SetText("1")
	frame.barglow = CreateFrame('Button', "glow", frame)
	frame.barglow:SetWidth(2)
	frame.barglow:SetHeight(20)
	frame.barglow.d = frame.barglow:CreateTexture(nil, "BORDER")
	frame.barglow.d:SetWidth(4)
	frame.barglow.d:SetHeight(20)
	frame.barglow.d:SetTexture(1, 1, 1, 0.7)
	frame.barglow.d:SetGradientAlpha("Horizontal", 1, 1, 1, 0, 1, 1, 1, 0.8)
	frame.barglow.u = frame.barglow:CreateTexture(nil, "BORDER")
	frame.barglow.u:SetWidth(4)
	frame.barglow.u:SetHeight(20)
	frame.barglow.u:SetTexture(1, 1, 1, 0.7)
	frame.barglow.u:SetGradientAlpha("Horizontal", 1, 1, 1, 0.8, 1, 1, 1, 0)
	frame.barglow.d:SetPoint("CENTER", -2, 0)
	frame.barglow.u:SetPoint("CENTER", 2, 0)
	frame:SetScript("OnClick", function()
		local playername = frame.unitname:GetText()
		local cooldowntimer = frame.time:GetText()
		local cooldownName = frame.timer:GetText()
		Rat:msg(playername.." has "..cooldowntimer.." cooldown left on ["..cooldownName.."]")
	end)
	return frame
end

-- minimap

function Rat.Minimap:CreateMinimapIcon()
	local Moving = false

	function self:OnMouseUp()
		Moving = false;
	end

	function self:OnMouseDown()
		PlaySound("igMainMenuOptionCheckBoxOn")
		Moving = false;
		if (arg1 == "LeftButton") then
			if Rat.Mainframe:IsVisible() then
				Rat.Mainframe:Hide()
				Rat_Settings["showhide"] = 0
			else
				Rat.Mainframe:Show()
				Rat_Settings["showhide"] = 1
			end
		elseif (arg1 == "RightButton") then
			if Rat.Options:IsVisible() then Rat.Options:Hide()
			else Rat.Options:Show() end
		else Moving = true;
		end
	end

	function self:OnUpdate()
		if Moving == true then
			local xpos,ypos = GetCursorPosition();
			local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom();
			xpos = xmin-xpos/UIParent:GetScale()+70;
			ypos = ypos/UIParent:GetScale()-ymin-70;
			local RATIconPos = math.deg(math.atan2(ypos,xpos));
			if (RATIconPos < 0) then
				RATIconPos = RATIconPos + 360
			end
			Rat_Settings["MinimapX"] = 54 - (78 * cos(RATIconPos));
			Rat_Settings["MinimapY"] = (78 * sin(RATIconPos)) - 55;

			Rat.Minimap:SetPoint(
			"TOPLEFT",
			"Minimap",
			"TOPLEFT",
			Rat_Settings["MinimapX"],
			Rat_Settings["MinimapY"]);
		end
	end

	function self:OnEnter()
		GameTooltip:SetOwner(Rat.Minimap, "ANCHOR_LEFT");
		GameTooltip:SetText("Raid Ability Tracker");
		GameTooltip:AddLine("Left Click to show/hide RAT.",1,1,1);
		GameTooltip:AddLine("Right Click to show/hide options menu.",1,1,1);
		GameTooltip:AddLine("Middle Button Click to move Icon.",1,1,1);
		GameTooltip:Show()
	end

	function self:OnLeave()
		GameTooltip:Hide()
	end

	self:SetFrameStrata("LOW")
	self:SetWidth(31) -- Set these to whatever height/width is needed
	self:SetHeight(31) -- for your Texture
	self:SetPoint("CENTER", -75, -20)

	self.Button = CreateFrame("Button",nil,self)
	self.Button:SetPoint("CENTER",0,0)
	self.Button:SetWidth(31)
	self.Button:SetHeight(31)
	self.Button:SetFrameLevel(8)
	self.Button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	self.Button:SetScript("OnMouseUp", self.OnMouseUp)
	self.Button:SetScript("OnMouseDown", self.OnMouseDown)
	self.Button:SetScript("OnUpdate", self.OnUpdate)
	self.Button:SetScript("OnEnter", self.OnEnter)
	self.Button:SetScript("OnLeave", self.OnLeave)

	local overlay = self:CreateTexture(nil, 'OVERLAY',self)
	overlay:SetWidth(53)
	overlay:SetHeight(53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint('TOPLEFT',0,0)

	local icon = self:CreateTexture(nil, "BACKGROUND")
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetTexture("Interface\\AddOns\\Rat\\Media\\Icon")
	icon:SetTexCoord(0.18, 0.82, 0.18, 0.82)
	icon:SetPoint('CENTER', 0, 0)
	self.icon = icon

	Rat.Minimap:SetPoint(
			"TOPLEFT",
			"Minimap",
			"TOPLEFT",
			Rat_Settings["MinimapX"],
			Rat_Settings["MinimapY"])

end

-- Color picker functions

function Rat:SetColor()
	local r,g,b = ColorPickerFrame:GetColorRGB();
	local swatch,frame;
	frame = getglobal(RAT_CP_OBJ:GetName());      -- enregistre la couleur
	frame.r = r;
	frame.g = g;
	frame.b = b;

	if RAT_CP_TYPE == "topbarcolor" then
		topbg:SetTexture(r,g,b)
		topbg:SetGradientAlpha("Vertical", 1,1,1, 0.25, 1, 1, 1, 1)
		Rat.Options.Background.topbarcolor.Texture:SetTexture(r,g,b)
		Rat_Settings[RAT_CP_TYPE]["r"] = r
		Rat_Settings[RAT_CP_TYPE]["g"] = g
		Rat_Settings[RAT_CP_TYPE]["b"] = b
	elseif RAT_CP_TYPE == "abilitybarcolor" then
		Rat.Options.Background.abilitybarcolor.Texture:SetTexture(r,g,b)
		Rat_Settings[RAT_CP_TYPE]["r"] = r
		Rat_Settings[RAT_CP_TYPE]["g"] = g
		Rat_Settings[RAT_CP_TYPE]["b"] = b
	elseif RAT_CP_TYPE == "abilitytextcolor" then
		Rat.Options.Background.abilitytextcolor.Texture:SetTexture(r,g,b)
		Rat_Settings[RAT_CP_TYPE]["r"] = r
		Rat_Settings[RAT_CP_TYPE]["g"] = g
		Rat_Settings[RAT_CP_TYPE]["b"] = b
	end
end

function Rat:CancelColor()
	local r = ColorPickerFrame.previousValues.r;
	local g = ColorPickerFrame.previousValues.g;
	local b = ColorPickerFrame.previousValues.b;
	local swatch,frame;

	frame = getglobal(RAT_CP_OBJ:GetName());      -- enregistre la couleur

	frame.r = r;
	frame.g = g;
	frame.b = b;

	if RAT_CP_TYPE == "topbarcolor" then
		topbg:SetTexture(r,g,b)
		topbg:SetGradientAlpha("Vertical", 1,1,1, 0.25, 1, 1, 1, 1)
		Rat.Options.Background.topbarcolor.Texture:SetTexture(r,g,b)
		Rat_Settings[RAT_CP_TYPE]["r"] = r
		Rat_Settings[RAT_CP_TYPE]["g"] = g
		Rat_Settings[RAT_CP_TYPE]["b"] = b
	elseif RAT_CP_TYPE == "abilitybarcolor" then
		Rat.Options.Background.abilitybarcolor.Texture:SetTexture(r,g,b)
		Rat_Settings[RAT_CP_TYPE]["r"] = r
		Rat_Settings[RAT_CP_TYPE]["g"] = g
		Rat_Settings[RAT_CP_TYPE]["b"] = b
	elseif RAT_CP_TYPE == "abilitytextcolor" then
		Rat.Options.Background.abilitytextcolor.Texture:SetTexture(r,g,b)
		Rat_Settings[RAT_CP_TYPE]["r"] = r
		Rat_Settings[RAT_CP_TYPE]["g"] = g
		Rat_Settings[RAT_CP_TYPE]["b"] = b
	end
end

function Rat:OpenColorPicker(obj, type)
	RAT_CP_OBJ = obj
	RAT_CP_TYPE = type

	button = getglobal(obj:GetName());

	ColorPickerFrame.func = Rat.SetColor -- button.swatchFunc;
	ColorPickerFrame:SetColorRGB(Rat_Settings[RAT_CP_TYPE]["r"], Rat_Settings[RAT_CP_TYPE]["g"], Rat_Settings[RAT_CP_TYPE]["b"]);
	ColorPickerFrame.previousValues = {r = button.r, g = button.g, b = button.b, opacity = button.opacity};
	ColorPickerFrame.cancelFunc = Rat.CancelColor

	ColorPickerFrame:SetPoint("TOPLEFT", obj, "TOPRIGHT", 0, 0)

	ColorPickerFrame:Show();
end

-- hypelink conversion to text

function Rat:hyperlink_name(hyperlink)
    local _, _, name = strfind(hyperlink, '|Hitem:%d+:%d+:%d+:%d+|h[[]([^]]+)[]]|h')
    return name
end

-- function to get chat type (say,party,raid,whisper)

function Rat:msg(text)
	local channel, chatnumber = ChatFrameEditBox.chatType
	if channel == "WHISPER" then
		chatnumber = ChatFrameEditBox.tellTarget
	elseif channel == "CHANNEL" then
		chatnumber = ChatFrameEditBox.channelTarget
	end
	SendChatMessage(text, channel, nil, chatnumber)
end

local function Rat_NormalizeAbilityName(localizedName)
    -- O(1) lookup via L_REVERSE: localized/English name → English value
    local key = L_REVERSE[localizedName]
    if key then
        return L[key]
    end
    return localizedName -- fallback so it still appears, if you add it later
end

-- functions to list all abilities on cooldown into our table

function getInvCd()
	if RatTbl[Rat_unit] == nil then RatTbl[Rat_unit] = { } end
    for rbag = 0,4 do
        if GetBagName(rbag) then
            for rslot = 1, GetContainerNumSlots(rbag) do
				local s_time, duration, enabled = GetContainerItemCooldown(rbag, rslot)
				if enabled == 1 then
					local itemName = Rat:hyperlink_name(GetContainerItemLink(rbag, rslot))
					local v = itemName and L[itemName]
					if v then
						if RatTbl[Rat_unit][v] == nil then RatTbl[Rat_unit][v] = { } end
						if duration > 2.5 then
							local timeleft = duration-(GetTime()-s_time)
							if (duration-math.floor(timeleft)) == 0 then
								RatTbl[Rat_unit][v]["duration"] = timeleft+GetTime()
								RatTbl[Rat_unit][v]["cd"] = duration
								sendThrottle[v] = GetTime()
							end
							if sendThrottle[v] == nil or (GetTime() - sendThrottle[v]) > 10 then
								RatTbl[Rat_unit][v]["duration"] = timeleft+GetTime()
								RatTbl[Rat_unit][v]["cd"] = duration
								sendThrottle[v] = GetTime()
							end
						elseif duration == 0 then
							if not RatTbl[Rat_unit][v]["duration"] or RatTbl[Rat_unit][v]["duration"] <= GetTime() then
								RatTbl[Rat_unit][v]["duration"] = 0
							end
						end
					end
				end
			end
		end
	end
end

function getSpells()
	if RatTbl[Rat_unit] == nil then RatTbl[Rat_unit] = { } end

	if HAS_NAMPOWER then
		-- Nampower path: GetSpellIdCooldown separates GCD from actual CD
		for k, v in pairs(L) do
			local spellId = GetSpellIdForName(k)
			if spellId then
				if RatTbl[Rat_unit][v] == nil then RatTbl[Rat_unit][v] = { } end
				local start, duration = GetSpellIdCooldown(spellId)
				if start and duration and duration > 3 then
					local timeleft = duration - (GetTime() - start)
					RatTbl[Rat_unit][v]["duration"] = timeleft + GetTime()
					RatTbl[Rat_unit][v]["cd"] = duration
					RatTbl[Rat_unit][v]["spellId"] = spellId
				else
					if not RatTbl[Rat_unit][v]["duration"] or RatTbl[Rat_unit][v]["duration"] <= GetTime() then
						RatTbl[Rat_unit][v]["duration"] = 0
					end
				end
			end
		end
	else
		-- Fallback: original heuristic for GCD detection
		local spellID = 1
		local spell = GetSpellName(spellID, BOOKTYPE_SPELL)
		local gcd = 0
		local totalSpells = 0
		while (spell) do
			local start, duration, hasCooldown = GetSpellCooldown(spellID, BOOKTYPE_SPELL)
			totalSpells = totalSpells + 1
			if hasCooldown and duration > 3 then
				gcd = gcd + 1
			end
			spellID = spellID + 1
			spell = GetSpellName(spellID, BOOKTYPE_SPELL)
		end

		if totalSpells > 0 and (gcd / totalSpells) > 0.5 then
			gcd = true
		else
			gcd = false
		end

		spellID = 1
		spell = GetSpellName(spellID, BOOKTYPE_SPELL)
		while (spell) do
			local v = L[spell]
			if v and not gcd then
				local start, duration, hasCooldown = GetSpellCooldown(spellID, BOOKTYPE_SPELL)
				if RatTbl[Rat_unit][v] == nil then RatTbl[Rat_unit][v] = { } end
				if hasCooldown == 1 and duration > 3 then
					local timeleft = duration - (GetTime() - start)
					RatTbl[Rat_unit][v]["duration"] = timeleft + GetTime()
					RatTbl[Rat_unit][v]["cd"] = duration
				else
					if not RatTbl[Rat_unit][v]["duration"] or RatTbl[Rat_unit][v]["duration"] <= GetTime() then
						RatTbl[Rat_unit][v]["duration"] = 0
					end
				end
			end
			spellID = spellID + 1
			spell = GetSpellName(spellID, BOOKTYPE_SPELL)
		end
	end
end

-- add an ability cooldown we got from a raidmember

function Rat:AddCd(name, cdname, cd, duration, spellId)
	if Rat_Debug then DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[Rat Debug]|r AddCd: name=" .. tostring(name) .. " ability=" .. tostring(cdname) .. " cd=" .. tostring(cd) .. " dur=" .. tostring(duration)) end
	if RAT_NONBASELINE[cdname] then
		if not Rat_SeenSpells[name] then Rat_SeenSpells[name] = {} end
		Rat_SeenSpells[name][cdname] = true
	end
	if RatTbl[name] == nil then RatTbl[name] = {} end
	if RatTbl[name][cdname] == nil then RatTbl[name][cdname] = {} end
	if duration > 3 then
		RatTbl[name][cdname]["duration"] = duration + GetTime()
		RatTbl[name][cdname]["cd"] = cd
		if spellId then
			RatTbl[name][cdname]["spellId"] = spellId
		end
		Rat_dirty = true
	end
end

-- function to check if a player is still in raid

-- O(1) raid check using cached name→guid table
function Rat:InRaidCheck(name)
	return RAT_NAME_TO_GUID[name] ~= nil
end

-- SAFER: clear bars/entries for people no longer in raid
function Rat:Cleardb()
	if GetRaidRosterInfo(1) then
		for name,_ in pairs(RatTbl) do
			if name ~= UnitName("player") and not RAT_NAME_TO_GUID[name] then
				for ability, _ in pairs(RatTbl[name]) do
					local rframe = name.."."..ability
					if RatFrames[rframe] then RatFrames[rframe]:Hide() end
				end
				RatTbl[name]=nil
			end
		end
	else
		for name,_ in pairs(RatTbl) do
			if name ~= UnitName("player") then
				for ability, _ in pairs(RatTbl[name]) do
					local rframe = name.."."..ability
					if RatFrames[rframe] then RatFrames[rframe]:Hide() end
				end
				RatTbl[name]=nil
			end
		end
	end
end


-- hides version frames for players not in raid anymore for our version check frame
function Rat:HideVersionNameFrames()
  if GetRaidRosterInfo(1) then
    for name, frame in pairs(VersionFTbl) do
      if name ~= UnitName("player") and not Rat:InRaidCheck(name) then
        if frame and frame.Hide then frame:Hide() end
        RatVersionTbl[name] = nil
      end
    end
  else
    for name, frame in pairs(VersionFTbl) do
      if name ~= UnitName("player") then
        if frame and frame.Hide then frame:Hide() end
        RatVersionTbl[name] = nil
      end
    end
  end
  Rat.Version:Check()
end

function Rat:OnUnitCastEvent(casterGUID, targetGUID, eventType, spellID, castDur)
    if Rat_Debug then DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Rat Debug]|r UNIT_CASTEVENT: type=" .. tostring(eventType) .. " spellID=" .. tostring(spellID) .. " guid=" .. tostring(casterGUID)) end
    if eventType ~= "CAST" and eventType ~= "CHANNEL" and eventType ~= "START" then
        return
    end
    local name = RAT_GUID_TO_NAME[casterGUID]
    if not name then
        Rat_BuildRaidGUIDIndex()
        name = RAT_GUID_TO_NAME[casterGUID]
        if not name then
            if Rat_Debug then DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Rat Debug]|r GUID not found: " .. tostring(casterGUID)) end
            return
        end
    end

    local sName
    if HAS_NAMPOWER then
        sName = GetSpellNameAndRankForId(spellID)
    else
        sName = SpellInfo(spellID)
    end
    if not sName then
        if Rat_Debug then DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Rat Debug]|r No spell name for ID: " .. tostring(spellID)) end
        return
    end

    local key = Rat_NormalizeAbilityName(sName)
    local cd = RAT_COOLDOWN[key]
    if Rat_Debug then DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Rat Debug]|r spell=" .. tostring(sName) .. " key=" .. tostring(key) .. " cd=" .. tostring(cd)) end

    -- Dynamic CD from Nampower spell data
    if HAS_NAMPOWER and spellID then
        local rec = GetSpellRecField(spellID, "recoveryTime") or 0
        local catRec = GetSpellRecField(spellID, "categoryRecoveryTime") or 0
        local dynamicCd = math.max(rec, catRec) / 1000
        if dynamicCd > 0 then cd = dynamicCd end
    end

    if not cd or cd <= 0 then return end

    -- Dynamic icon from Nampower
    if HAS_NAMPOWER and not cdtbl[key] then
        local iconId = GetSpellRecField(spellID, "spellIconID")
        if iconId then
            local icon = GetSpellIconTexture(iconId)
            if icon then cdtbl[key] = icon end
        end
    end

    Rat:AddCd(name, key, cd, cd, spellID)

    -- Broadcast to other Rat users
    local throttleKey = name .. ":" .. key
    if not sendThrottle[throttleKey] or (GetTime() - sendThrottle[throttleKey]) > 2 then
        local channel = (GetNumRaidMembers() > 0 and "RAID") or (GetNumPartyMembers() > 0 and "PARTY") or nil
        if channel then
            SendAddonMessage("RAT_CD", name .. ":" .. key .. ":" .. cd .. ":" .. (spellID or 0), channel)
            sendThrottle[throttleKey] = GetTime()
        end
    end
end

function Rat:OnSpellGoOther(itemId, spellId, casterGuid, targetGuid, castFlags, numHit, numMissed)
    if Rat_Debug then DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Rat Debug]|r SPELL_GO_OTHER: spellId=" .. tostring(spellId) .. " itemId=" .. tostring(itemId) .. " guid=" .. tostring(casterGuid)) end

    -- Handle item uses (spellId == 0)
    if (not spellId or spellId == 0) and itemId and RAT_ITEM_MAP[itemId] then
        local name = RAT_GUID_TO_NAME[casterGuid]
        if not name then
            Rat_BuildRaidGUIDIndex()
            name = RAT_GUID_TO_NAME[casterGuid]
        end
        if name then
            local key = RAT_ITEM_MAP[itemId]
            local cd = RAT_COOLDOWN[key]
            if cd and cd > 0 then
                Rat:AddCd(name, key, cd, cd)
                local throttleKey = name .. ":" .. key
                if not sendThrottle[throttleKey] or (GetTime() - sendThrottle[throttleKey]) > 2 then
                    local channel = (GetNumRaidMembers() > 0 and "RAID") or (GetNumPartyMembers() > 0 and "PARTY") or nil
                    if channel then
                        SendAddonMessage("RAT_CD", name .. ":" .. key .. ":" .. cd .. ":0", channel)
                        sendThrottle[throttleKey] = GetTime()
                    end
                end
            end
        end
        return
    end

    if not spellId or spellId == 0 then return end

    local name = RAT_GUID_TO_NAME[casterGuid]
    if not name then
        Rat_BuildRaidGUIDIndex()
        name = RAT_GUID_TO_NAME[casterGuid]
        if not name then return end
    end

    local sName = GetSpellNameAndRankForId(spellId)
    if not sName then return end

    local key = Rat_NormalizeAbilityName(sName)

    -- Spell ID fallback for item-triggered spells
    if not RAT_COOLDOWN[key] and RAT_SPELLID_MAP[spellId] then
        key = RAT_SPELLID_MAP[spellId]
    end

    -- Dynamic CD from Nampower spell data
    local rec = GetSpellRecField(spellId, "recoveryTime") or 0
    local catRec = GetSpellRecField(spellId, "categoryRecoveryTime") or 0
    local cd = math.max(rec, catRec) / 1000

    -- Fall back to hardcoded table
    if cd <= 0 then cd = RAT_COOLDOWN[key] end
    if not cd or cd <= 0 then return end

    -- Dynamic icon
    if not cdtbl[key] then
        local iconId = GetSpellRecField(spellId, "spellIconID")
        if iconId then
            local icon = GetSpellIconTexture(iconId)
            if icon then cdtbl[key] = icon end
        end
    end

    Rat:AddCd(name, key, cd, cd, spellId)

    -- Broadcast to other Rat users
    local throttleKey = name .. ":" .. key
    if not sendThrottle[throttleKey] or (GetTime() - sendThrottle[throttleKey]) > 2 then
        local channel = (GetNumRaidMembers() > 0 and "RAID") or (GetNumPartyMembers() > 0 and "PARTY") or nil
        if channel then
            SendAddonMessage("RAT_CD", name .. ":" .. key .. ":" .. cd .. ":" .. (spellId or 0), channel)
            sendThrottle[throttleKey] = GetTime()
        end
    end
end

function Rat:OnSpellGoSelf(itemId, spellId, targetGuid, castFlags)
    if Rat_Debug then DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Rat Debug]|r SPELL_GO_SELF: spellId=" .. tostring(spellId) .. " itemId=" .. tostring(itemId)) end

    -- Handle item uses (spellId == 0)
    if (not spellId or spellId == 0) and itemId and RAT_ITEM_MAP[itemId] then
        local name = Rat_unit
        if not name then name = UnitName("player") end
        local key = RAT_ITEM_MAP[itemId]
        local cd = RAT_COOLDOWN[key]
        if cd and cd > 0 then
            Rat:AddCd(name, key, cd, cd)
            local throttleKey = name .. ":" .. key
            if not sendThrottle[throttleKey] or (GetTime() - sendThrottle[throttleKey]) > 2 then
                local channel = (GetNumRaidMembers() > 0 and "RAID") or (GetNumPartyMembers() > 0 and "PARTY") or nil
                if channel then
                    SendAddonMessage("RAT_CD", name .. ":" .. key .. ":" .. cd .. ":0", channel)
                    sendThrottle[throttleKey] = GetTime()
                end
            end
        end
        return
    end

    if not spellId or spellId == 0 then return end

    local name = Rat_unit
    if not name then name = UnitName("player") end

    local sName = GetSpellNameAndRankForId(spellId)
    if not sName then return end

    local key = Rat_NormalizeAbilityName(sName)

    -- Spell ID fallback for item-triggered spells
    if not RAT_COOLDOWN[key] and RAT_SPELLID_MAP[spellId] then
        key = RAT_SPELLID_MAP[spellId]
    end

    -- Dynamic CD from Nampower spell data
    local rec = GetSpellRecField(spellId, "recoveryTime") or 0
    local catRec = GetSpellRecField(spellId, "categoryRecoveryTime") or 0
    local cd = math.max(rec, catRec) / 1000

    -- Fall back to hardcoded table
    if cd <= 0 then cd = RAT_COOLDOWN[key] end
    if not cd or cd <= 0 then return end

    -- Dynamic icon
    if not cdtbl[key] then
        local iconId = GetSpellRecField(spellId, "spellIconID")
        if iconId then
            local icon = GetSpellIconTexture(iconId)
            if icon then cdtbl[key] = icon end
        end
    end

    Rat:AddCd(name, key, cd, cd, spellId)

    -- Broadcast to other Rat users
    local throttleKey = name .. ":" .. key
    if not sendThrottle[throttleKey] or (GetTime() - sendThrottle[throttleKey]) > 2 then
        local channel = (GetNumRaidMembers() > 0 and "RAID") or (GetNumPartyMembers() > 0 and "PARTY") or nil
        if channel then
            SendAddonMessage("RAT_CD", name .. ":" .. key .. ":" .. cd .. ":" .. (spellId or 0), channel)
            sendThrottle[throttleKey] = GetTime()
        end
    end
end

function Rat:OnAddonMessage(prefix, message, channel, sender)
    if sender == Rat_unit then return end -- ignore own messages

    if prefix == "RAT_VER" then
        RatVersionTbl[sender] = message
        Rat.Version:Check()

    elseif prefix == "RAT_CD" then
        -- format: "casterName:abilityKey:cd:spellId"
        local parts = {}
        for part in string.gfind(message, "[^:]+") do
            table.insert(parts, part)
        end
        if table.getn(parts) >= 3 then
            local casterName = parts[1]
            local abilityKey = parts[2]
            local cd = tonumber(parts[3])
            local spellId = tonumber(parts[4])
            if casterName and abilityKey and cd and cd > 0 then
                -- Only accept if we don't already have a newer entry
                if not RatTbl[casterName] or not RatTbl[casterName][abilityKey]
                   or not RatTbl[casterName][abilityKey]["duration"]
                   or RatTbl[casterName][abilityKey]["duration"] < (cd + GetTime()) then
                    Rat:AddCd(casterName, abilityKey, cd, cd, spellId)
                end
            end
        end

    elseif prefix == "BigWigs" then
        -- BigWigs SpellRequests: BWSRCDRESP format
        -- "BWSRCDRESP spellShort;requester;playerName;cdSeconds"
        if string.sub(message, 1, 10) == "BWSRCDRESP" then
            local payload = string.sub(message, 12)
            local parts = {}
            for part in string.gfind(payload, "[^;]+") do
                table.insert(parts, part)
            end
            if table.getn(parts) >= 4 then
                local spellShort = parts[1]
                local playerName = parts[3]
                local cdSeconds = tonumber(parts[4])
                local abilityKey = RAT_BW_SPELL_MAP[spellShort]
                if abilityKey and RAT_COOLDOWN[abilityKey] and playerName and cdSeconds and cdSeconds > 0 then
                    local cd = RAT_COOLDOWN[abilityKey] or cdSeconds
                    Rat:AddCd(playerName, abilityKey, cd, cdSeconds)
                end
            end
        end

        -- BigWigs CommonAuras: BWCAxx format
        for syncToken, abilityKey in pairs(RAT_BW_AURA_MAP) do
            if string.sub(message, 1, string.len(syncToken)) == syncToken then
                local rest = string.sub(message, string.len(syncToken) + 1)
                rest = string.gsub(rest, "^%s+", "")
                local duration = tonumber(rest)
                if duration and duration > 0 and RAT_COOLDOWN[abilityKey] then
                    local cd = RAT_COOLDOWN[abilityKey] or duration
                    Rat:AddCd(sender, abilityKey, cd, duration)
                end
                break
            end
        end

    elseif prefix == "RAT_CDREQ" then
        -- Someone reloaded and wants our cooldown data
        if not sendThrottle["cdsync_resp"] or (GetTime() - sendThrottle["cdsync_resp"]) > 10 then
            sendThrottle["cdsync_resp"] = GetTime()
            local ch = (GetNumRaidMembers() > 0 and "RAID") or (GetNumPartyMembers() > 0 and "PARTY") or nil
            if ch then
                for name, abilities in pairs(RatTbl) do
                    for ability, data in pairs(abilities) do
                        if data["duration"] and data["cd"] then
                            local remaining = data["duration"] - GetTime()
                            if remaining > 3 then
                                local msg = name .. ":" .. ability .. ":" .. string.format("%.1f", remaining) .. ":" .. tostring(data["cd"])
                                if data["spellId"] then
                                    msg = msg .. ":" .. tostring(data["spellId"])
                                end
                                SendAddonMessage("RAT_CDRSP", msg, ch)
                            end
                        end
                    end
                end
            end
        end

    elseif prefix == "RAT_CDRSP" then
        -- Cooldown sync response: "name:ability:remaining:totalCd[:spellId]"
        local parts = {}
        for part in string.gfind(message, "[^:]+") do
            table.insert(parts, part)
        end
        if table.getn(parts) >= 4 then
            local casterName = parts[1]
            local abilityKey = parts[2]
            local remaining = tonumber(parts[3])
            local totalCd = tonumber(parts[4])
            local spellId = tonumber(parts[5])
            if casterName and abilityKey and remaining and remaining > 0 and totalCd and totalCd > 0 then
                local newExpiry = remaining + GetTime()
                -- Only accept if we don't already have a newer entry
                if not RatTbl[casterName] or not RatTbl[casterName][abilityKey]
                   or not RatTbl[casterName][abilityKey]["duration"]
                   or RatTbl[casterName][abilityKey]["duration"] < newExpiry then
                    Rat:AddCd(casterName, abilityKey, totalCd, remaining, spellId)
                end
            end
        end
    end
end

-- class color RGBA lookup table
local RAT_CLASS_COLORS_RGBA = {
	["Warrior"] = { 0.78, 0.61, 0.43, 1 },
	["Hunter"]  = { 0.67, 0.83, 0.45 },
	["Mage"]    = { 0.41, 0.80, 0.94 },
	["Rogue"]   = { 1.00, 0.96, 0.41 },
	["Warlock"] = { 0.58, 0.51, 0.79, 1 },
	["Druid"]   = { 1, 0.49, 0.04, 1 },
	["Shaman"]  = { 0.0, 0.44, 0.87 },
	["Priest"]  = { 1.00, 1.00, 1.00 },
	["Paladin"] = { 0.96, 0.55, 0.73 },
}
local RAT_CLASS_COLORS_HEX = {
	["Warrior"] = "|cffC79C6E",
	["Hunter"]  = "|cffABD473",
	["Mage"]    = "|cff69CCF0",
	["Rogue"]   = "|cffFFF569",
	["Warlock"] = "|cff9482C9",
	["Druid"]   = "|cffFF7D0A",
	["Shaman"]  = "|cff0070DE",
	["Priest"]  = "|cffFFFFFF",
	["Paladin"] = "|cffF58CBA",
}

-- function to get classcolors from a player (cached O(1))

function Rat:GetClassColors(name)
	local class = RAT_NAME_TO_CLASS[name]
	if class and RAT_CLASS_COLORS_RGBA[class] then
		local c = RAT_CLASS_COLORS_RGBA[class]
		return c[1], c[2], c[3], c[4]
	end
end

function Rat_GetClassColors(name)
	local class = RAT_NAME_TO_CLASS[name]
	if class and RAT_CLASS_COLORS_HEX[class] then
		return RAT_CLASS_COLORS_HEX[class] .. name .. "|r"
	end
end

-- function to get class of a player (cached O(1))

function Rat:GetClass(name)
	return RAT_NAME_TO_CLASS[name]
end

-- function to get correct coords for classes in the

function Rat:ClassPos(class)
	if(class=="Warrior") then return 0, 0.25, 0, 0.25;	end
	if(class=="Mage")    then return 0.25, 0.5, 0,	0.25;	end
	if(class=="Rogue")   then return 0.5,  0.75,    0,	0.25;	end
	if(class=="Druid")   then return 0.75, 1,       0,	0.25;	end
	if(class=="Hunter")  then return 0,    0.25,    0.25,	0.5;	end
	if(class=="Shaman")  then return 0.25, 0.5,     0.25,	0.5;	end
	if(class=="Priest")  then return 0.5,  0.75,    0.25,	0.5;	end
	if(class=="Warlock") then return 0.75, 1,       0.25,	0.5;	end
	if(class=="Paladin") then return 0,    0.25,    0.5,	0.75;	end
	return 0.25, 0.5, 0.5, 0.75	-- Returns empty next one, so blank
end

-- Cached path strings (rebuilt when settings change)
local Rat_cachedFontPath = nil
local Rat_cachedFontSize = nil
local Rat_cachedTitleFontSize = nil
local Rat_cachedBarTexPath = nil
local Rat_lastTimerTick = 0

local function Rat_RebuildPathCache()
	local fontName = Rat_Font[Rat_Settings["font"]]
	local fontSize = Rat_FontSize[Rat_Settings["font"]]
	Rat_cachedFontPath = "Interface\\AddOns\\Rat\\fonts\\" .. fontName .. ".TTF"
	Rat_cachedFontSize = fontSize
	Rat_cachedTitleFontSize = fontSize + 1
	local barTex = Rat_BarTexture[Rat_Settings["bartexture"]]
	Rat_cachedBarTexPath = "Interface\\AddOns\\Rat\\media\\bartextures\\" .. barTex .. ".tga"
end

-- Flat sorted list: reused table to avoid alloc each cycle
local Rat_flatSorted = {}

local function Rat_BuildFlatSorted()
	-- Wipe reused table
	local n = table.getn(Rat_flatSorted)
	for idx = n, 1, -1 do Rat_flatSorted[idx] = nil end

	local now = GetTime()
	for playerName, abilities in pairs(RatTbl) do
		for ability, data in pairs(abilities) do
			if data["cd"] and data["duration"] and data["duration"] > now then
				table.insert(Rat_flatSorted, {
					name = playerName,
					ability = ability,
					duration = data["duration"],
					cd = data["cd"],
					spellId = data["spellId"],
				})
			end
		end
	end
	-- Sort descending by duration (same as original sortDB)
	table.sort(Rat_flatSorted, function(a, b) return a.duration > b.duration end)
end

-- update function

function Rat:Update(force)
	local now = GetTime()
	if uptimer == nil or (now - uptimer > 0.5) then
		uptimer = now

	-- Static UI checks only on force updates (roster change, settings, etc.)
	if force then
		if Rat_Settings["showhide"] == 1 then
			Rat.Mainframe:Show()
		else
			Rat.Mainframe:Hide()
		end
		if Rat_Settings["Minimap"] == nil then
			Rat.Minimap:Hide()
		elseif Rat_Settings["Minimap"] == 1 then
			Rat.Minimap:Show()
		end
		if IsRaidOfficer("player") then
			Rat.Options.version:Show()
		else
			Rat.Options.version:Hide()
		end
		-- Rebuild path cache on force
		Rat_RebuildPathCache()
		Rat_dirty = true
	end

	-- Only rebuild data when dirty
	if Rat_dirty then
		Rat_dirty = false
		if not Rat_cachedFontPath then Rat_RebuildPathCache() end
		Rat_BuildFlatSorted()
	end

	-- Timer text updates at ~1s intervals
	local timerTick = math.floor(now)
	local timerChanged = (timerTick ~= Rat_lastTimerTick)
	if timerChanged then Rat_lastTimerTick = timerTick end

	local i = 1
	if Rat_Debug then
		local dbgCount = 0
		for n,_ in pairs(RatTbl) do
			for a,_ in pairs(RatTbl[n]) do
				if RatTbl[n][a]["cd"] then
					dbgCount = dbgCount + 1
					DEFAULT_CHAT_FRAME:AddMessage("|cFFFF00FF[Rat Debug]|r RatTbl: " .. n .. "/" .. a .. " cd=" .. tostring(RatTbl[n][a]["cd"]) .. " dur=" .. tostring(RatTbl[n][a]["duration"]) .. " remaining=" .. tostring(RatTbl[n][a]["duration"] and (RatTbl[n][a]["duration"] - now)) .. " showClass=" .. tostring(Rat_Settings[Rat:GetClass(n)]) .. " showAbility=" .. tostring(Rat_Settings[a]) .. " showhide=" .. tostring(Rat_Settings["showhide"]))
				end
			end
		end
		if dbgCount == 0 then DEFAULT_CHAT_FRAME:AddMessage("|cFFFF00FF[Rat Debug]|r RatTbl is EMPTY (no active CDs)") end
	end

	local mfWidth = Rat.Mainframe:GetWidth()
	local barMaxWidth = mfWidth - 89

	for _, entry in ipairs(Rat_flatSorted) do
		local eName = entry.name
		local ability = entry.ability
		local data = RatTbl[eName] and RatTbl[eName][ability]
		if data and data["duration"] and data["cd"] then
			local tname = eName .. "." .. ability
			local texture = cdtbl[ability]
			if not texture and HAS_NAMPOWER and data["spellId"] then
				local iconId = GetSpellRecField(data["spellId"], "spellIconID")
				if iconId then
					texture = GetSpellIconTexture(iconId)
					if texture then cdtbl[ability] = texture end
				end
			end
			local remaining = data["duration"] - now
			local bardecay = remaining / data["cd"]
			if bardecay > 1 then bardecay = 1 end
			local barWidth = bardecay * barMaxWidth

			RatFrames[tname] = RatFrames[tname] or Rat:CreateFrame(tname)
			local frame = RatFrames[tname]

			if force then
				Rat.Mainframe.Background.Top.Title:SetFont(Rat_cachedFontPath, Rat_cachedTitleFontSize)
			end
			frame:SetWidth(mfWidth - 4)
			frame:SetHeight(22)
			frame:ClearAllPoints()

			if Rat_Settings["Invert"] == nil then
				frame:SetPoint("TOPLEFT", 2, (-22 * i) + 2)
			else
				frame:SetPoint("TOPLEFT", 2, (22 * i))
			end
			frame.unit:SetTexture(Rat:GetClassColors(eName))
			frame.unit:SetGradientAlpha("Vertical", 1, 1, 1, 0, 1, 1, 1, 1)
			frame.unitname:SetText(eName)
			frame.unitname:SetFont(Rat_cachedFontPath, Rat_cachedFontSize)
			frame.icon:SetTexture(texture)
			frame.bar:SetWidth(barWidth)
			frame.bar:SetTexture(Rat_cachedBarTexPath, true)
			frame.bar:SetVertexColor(Rat_Settings["abilitybarcolor"]["r"], Rat_Settings["abilitybarcolor"]["g"], Rat_Settings["abilitybarcolor"]["b"], 1)
			frame.timer:SetTextColor(Rat_Settings["abilitytextcolor"]["r"], Rat_Settings["abilitytextcolor"]["g"], Rat_Settings["abilitytextcolor"]["b"])
			frame.time:SetTextColor(Rat_Settings["abilitytextcolor"]["r"], Rat_Settings["abilitytextcolor"]["g"], Rat_Settings["abilitytextcolor"]["b"])

			-- Notify when ready
			local playerClass = Rat:GetClass(eName)
			if Rat_Settings["Notify"] == 1 and playerClass and Rat_Settings[playerClass] == 1 and Rat_Settings[ability] == 1 and math.floor(remaining) == 0 then
				if Rat_Settings[tname] == nil or (now - Rat_Settings[tname]) > 2 or (now - Rat_Settings[tname]) < 0 then
					UIErrorsFrame:AddMessage(Rat_GetClassColors(eName) .. " |cffFFFF00" .. ability .. " - READY!")
					Rat_Settings[tname] = now
				end
			end

			-- Timer text
			if timerChanged or force then
				local cdtime = rtime(remaining)
				if cdtime and cdtime ~= 0 then
					frame.timer:SetText(ability)
					frame.time:SetText(cdtime)
					frame.timer:SetFont(Rat_cachedFontPath, Rat_cachedFontSize)
					frame.time:SetFont(Rat_cachedFontPath, Rat_cachedFontSize)
				end
			end

			if barWidth > 0 then
				frame.barglow:SetPoint("RIGHT", -(mfWidth - 88) + barWidth, 0)
				frame.barglow:Show()
				if playerClass and Rat_Settings[playerClass] == 1 then
					if Rat_Settings[ability] == 1 then
						frame:Show()
						i = i + 1
					else
						frame:Hide()
					end
				else
					frame:Hide()
				end
			else
				frame.barglow:Hide()
				frame:Hide()
			end
		end
	end

	if i == 0 then
		Rat.Mainframe:SetHeight(22 + (22 * 1))
		Rat.Mainframe.Background.Tab1:SetHeight(Rat.Mainframe:GetHeight() - 16)
	end

	-- Ready list update
	if Rat_Settings["ReadyList"] ~= 1 then
		if Rat.ReadyFrame:IsVisible() then Rat.ReadyFrame:Hide() end
	else
		Rat.ReadyFrame:Show()
		-- Use cached name list from RAT_NAME_TO_GUID
		local readyMembers = {}
		for memberName, _ in pairs(RAT_NAME_TO_GUID) do
			table.insert(readyMembers, memberName)
		end

		local usedRows = {}
		local rowIndex = 0

		for _, memberName in ipairs(readyMembers) do
			local class = Rat:GetClass(memberName)
			if class and Rat_Settings[class] == 1 then
				local spells = RAT_CLASS_SPELLS[class]
				if spells then
					local readyIcons = {}
					for _, spell in ipairs(spells) do
						if Rat_Settings[spell] == 1 then
							local isOnCooldown = false
							if RatTbl[memberName] and RatTbl[memberName][spell]
							   and RatTbl[memberName][spell]["duration"]
							   and RatTbl[memberName][spell]["duration"] - now > 0 then
								isOnCooldown = true
							end
							if not isOnCooldown then
								if RAT_NONBASELINE[spell] then
									if Rat_SeenSpells[memberName] and Rat_SeenSpells[memberName][spell] then
										table.insert(readyIcons, spell)
									end
								else
									table.insert(readyIcons, spell)
								end
							end
						end
					end
					-- Also check non-baseline spells not in class list
					for nbSpell, _ in pairs(RAT_NONBASELINE) do
						if Rat_SeenSpells[memberName] and Rat_SeenSpells[memberName][nbSpell] then
							local alreadyListed = false
							if spells then
								for _, s in ipairs(spells) do
									if s == nbSpell then alreadyListed = true end
								end
							end
							if not alreadyListed and Rat_Settings[nbSpell] == 1 then
								local isOnCooldown = false
								if RatTbl[memberName] and RatTbl[memberName][nbSpell]
								   and RatTbl[memberName][nbSpell]["duration"]
								   and RatTbl[memberName][nbSpell]["duration"] - now > 0 then
									isOnCooldown = true
								end
								if not isOnCooldown then
									table.insert(readyIcons, nbSpell)
								end
							end
						end
					end

					if table.getn(readyIcons) > 0 then
						if not RatReadyFrames[memberName] then
							RatReadyFrames[memberName] = Rat:CreateReadyRow(memberName)
						end
						local row = RatReadyFrames[memberName]
						row:ClearAllPoints()
						row:SetPoint("TOPLEFT", 2, (-22 * rowIndex))
						row:SetWidth(Rat.ReadyFrame:GetWidth() - 4)

						row.unitbg:SetTexture(Rat:GetClassColors(memberName))
						row.unitbg:SetGradientAlpha("Vertical", 1, 1, 1, 0, 1, 1, 1, 1)
						row.unitname:SetText(memberName)

						for iconIdx, iconSpell in ipairs(readyIcons) do
							if not row.icons[iconIdx] then
								row.icons[iconIdx] = row:CreateTexture(nil, "OVERLAY")
								row.icons[iconIdx]:SetWidth(20)
								row.icons[iconIdx]:SetHeight(20)
							end
							local tex = row.icons[iconIdx]
							tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
							tex:ClearAllPoints()
							tex:SetPoint("TOPLEFT", 62 + (21 * (iconIdx - 1)), -1)
							tex:SetTexture(cdtbl[iconSpell])
							tex:Show()
						end
						for hideIdx = table.getn(readyIcons) + 1, table.getn(row.icons) do
							if row.icons[hideIdx] then row.icons[hideIdx]:Hide() end
						end

						row:Show()
						usedRows[memberName] = true
						rowIndex = rowIndex + 1
					end
				end
			end
		end

		for rname, rframe in pairs(RatReadyFrames) do
			if not usedRows[rname] then
				rframe:Hide()
			end
		end

		if rowIndex > 0 then
			Rat.ReadyFrame:SetHeight(21 + (22 * rowIndex))
			Rat.ReadyFrame.Background.Content:SetHeight(22 * rowIndex)
		else
			Rat.ReadyFrame:SetHeight(21)
			Rat.ReadyFrame.Background.Content:SetHeight(1)
		end
	end
	end
end


-- slash commands

function Rat.slash(arg1,arg2,arg3)
    -- normalize args: Vanilla passes a single string
    local a1, a2, a3 = arg1, arg2, arg3
    if (not a2) and a1 and a1 ~= "" then
        local s = a1
        local sp = string.find(s, " ")
        if sp then
            a1 = string.sub(s, 1, sp - 1)
            s = string.sub(s, sp + 1)
            sp = string.find(s, " ")
            if sp then
                a2 = string.sub(s, 1, sp - 1)
                a3 = string.sub(s, sp + 1)
            else
                a2 = s
            end
        end
    end

    -- default help
    if a1 == nil or a1 == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r type |cFFFFFF00 /Rat show|r to show frame",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r type |cFFFFFF00 /Rat hide|r to hide frame",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r type |cFFFFFF00 /Rat options|r to show options menu",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r type |cFFFFFF00 /rat topbar hide|r to hide only the top bar",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r type |cFFFFFF00 /rat clear|r to clear saved cooldowns",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r type |cFFFFFF00 /rat ready|r to toggle ready spells list",1,1,1)
        return
    end

    if a1 == "show" then
        Rat_Settings["showhide"] = 1
        if Rat.Mainframe then Rat.Mainframe:Show() end

    elseif a1 == "hide" then
        Rat_Settings["showhide"] = 0
        if Rat.Mainframe then Rat.Mainframe:Hide() end

    elseif a1 == "options" then
        if Rat.Options then Rat.Options:Show() end

    elseif a1 == "topbar" then
        local sub = (a2 and string.lower(a2)) or "toggle"
        if sub == "hide" then
            if Rat.SetTopBarVisible then Rat:SetTopBarVisible(false) end
            DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r Top bar hidden.")
        elseif sub == "show" then
            if Rat.SetTopBarVisible then Rat:SetTopBarVisible(true) end
            DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r Top bar shown.")
        else
            if Rat.SetTopBarVisible then Rat:SetTopBarVisible(Rat_Settings.topbar_hidden ~= 1) end
            DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r Top bar toggled.")
        end

    elseif a1 == "clear" then
        if RatTbl then
            for n,_ in pairs(RatTbl) do
                if n ~= UnitName("player") then
                    for ability,_ in pairs(RatTbl[n]) do
                        local rframe = n.."."..ability
                        if RatFrames and RatFrames[rframe] then RatFrames[rframe]:Hide() end
                    end
                    RatTbl[n] = nil
                end
            end
        end
        if Rat_Settings and Rat_Settings.persist then
            for n,_ in pairs(Rat_Settings.persist) do
                if n ~= UnitName("player") then Rat_Settings.persist[n] = nil end
            end
        end
        if Rat.Update then Rat:Update(true) end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r Cleared saved cooldowns for other players.")

    elseif a1 == "debug" then
        Rat_Debug = not Rat_Debug
        if Rat_Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r Debug |cFF00FF00ON|r - cast a spell to see tracking info")
            -- dump current state
            local guidCount = 0
            for _ in pairs(RAT_GUID_TO_NAME) do guidCount = guidCount + 1 end
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[Rat Debug]|r GUIDs indexed: " .. guidCount)
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[Rat Debug]|r Player: " .. tostring(Rat_unit))
            local exists, guid = UnitExists("player")
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[Rat Debug]|r Player GUID: " .. tostring(guid) .. " in table: " .. tostring(RAT_GUID_TO_NAME[guid] or "NO"))
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[Rat Debug]|r HAS_NAMPOWER: " .. tostring(HAS_NAMPOWER))
            -- dump custom spells
            local customs = Rat_Settings and Rat_Settings["custom_spells"] or {}
            for i, entry in ipairs(customs) do
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[Rat Debug]|r Custom[" .. i .. "]: " .. tostring(entry.name) .. " cd=" .. tostring(entry.cd) .. " inL=" .. tostring(L[entry.name] ~= nil) .. " inCD=" .. tostring(RAT_COOLDOWN[entry.name] ~= nil) .. " enabled=" .. tostring(Rat_Settings[entry.name]))
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r Debug |cFFFF0000OFF|r")
        end

    elseif a1 == "ready" then
        if Rat_Settings["ReadyList"] == 1 then
            Rat_Settings["ReadyList"] = 0
            if Rat.ReadyFrame then Rat.ReadyFrame:Hide() end
            DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r Ready list |cFFFF0000OFF|r")
        else
            Rat_Settings["ReadyList"] = 1
            if Rat.ReadyFrame then Rat.ReadyFrame:Show() end
            DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r Ready list |cFF00FF00ON|r")
        end
        if Rat.Update then Rat:Update(true) end

    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A Rat:|r unknown command",1,0.3,0.3);
    end
end

SlashCmdList['RAT_SLASH'] = function(msg)
    local a1, a2, a3
    if msg and msg ~= "" then
        local s = msg
        local sp = string.find(s, " ")
        if sp then
            a1 = string.sub(s, 1, sp - 1)
            s = string.sub(s, sp + 1)
            sp = string.find(s, " ")
            if sp then
                a2 = string.sub(s, 1, sp - 1)
                a3 = string.sub(s, sp + 1)
            else
                a2 = s
            end
        else
            a1 = s
        end
    end
    Rat.slash(a1, a2, a3)
end
SLASH_RAT_SLASH1 = '/rat'
SLASH_RAT_SLASH2 = '/RAT'

-- call events

Rat:SetScript("OnEvent", Rat.OnEvent)
Rat:SetScript("OnUpdate", Rat.Update)

function Rat:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("RAT: "..msg)
end

-- function to format time into 00:00

function rtime(left)
	local min = math.floor(left / 60)
	local sec = math.floor(math.mod(left, 60))

	if (this.min == min and this.sec == sec) then
		return nil
	end

	this.min = min
	this.sec = sec

	return string.format("%02d:%02s", min, sec)
end

