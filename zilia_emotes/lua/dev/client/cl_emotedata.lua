-- Données client des emotes : échelle UI, favoris et raccourcis (data/ziliadata/emotes.json), demandes au serveur
local SAVE_FOLDER = "ziliadata"
local SAVE_FILE = SAVE_FOLDER .. "/emotes.json"
local REQUEST_DEBOUNCE = 0.3

-- Touches liées à ces commandes refusées pour les raccourcis, quelle que soit la disposition du clavier
local RESERVED_COMMANDS = {"+forward", "+back", "+moveleft", "+moveright", "+jump", "+duck"}
local CAPTURE_KEYS = {[KEY_NONE] = true, [KEY_ESCAPE] = true, [KEY_BACKSPACE] = true}

local tFavorites = {}
local tBinds = {}
local tKeyToEmote = {}
local nLastRequest = 0
local nScale = 1

function ZiliaEmotes.UpdateScale()
	nScale = math.min(ScrW() / 1920, ScrH() / 1080)
end

function ZiliaEmotes.S(n)
	return math.Round(n * nScale)
end

ZiliaEmotes.UpdateScale()

local function RebuildKeyLookup()
	tKeyToEmote = {}
	for sID, nKey in pairs(tBinds) do
		tKeyToEmote[nKey] = sID
	end
end

local function Save()
	timer.Create("Roa:AdminSys:EmoteSave", 1, 1, function()
		file.CreateDir(SAVE_FOLDER)
		file.Write(SAVE_FILE, util.TableToJSON({Favorites = tFavorites, Binds = tBinds}))
	end)
end

local function Load()
	local sJSON = file.Read(SAVE_FILE, "DATA")
	local tData = sJSON and util.JSONToTable(sJSON)
	if not istable(tData) then return end

	if istable(tData.Favorites) then tFavorites = tData.Favorites end
	if istable(tData.Binds) then tBinds = tData.Binds end
	RebuildKeyLookup()
end

function ZiliaEmotes.IsPokemon()
	return LocalPlayer():GetNWBool("IsPoke")
end

function ZiliaEmotes.IsFavorite(sID)
	return tFavorites[sID] == true
end

function ZiliaEmotes.ToggleFavorite(sID)
	tFavorites[sID] = not tFavorites[sID] or nil
	Save()
end

function ZiliaEmotes.GetBind(sID)
	return tBinds[sID]
end

-- Une touche ne correspond qu'à une emote : l'assigner la retire de la précédente
function ZiliaEmotes.SetBind(sID, nKey)
	local sPrevious = nKey and tKeyToEmote[nKey]
	if sPrevious then tBinds[sPrevious] = nil end

	tBinds[sID] = nKey
	RebuildKeyLookup()
	Save()
end

local function IsReservedKey(nKey)
	local sBinding = input.LookupKeyBinding(nKey)
	if not sBinding then return false end

	for _, sCommand in ipairs(RESERVED_COMMANDS) do
		if string.find(sBinding, sCommand, 1, true) then return true end
	end

	return false
end

function ZiliaEmotes.IsBindKeyAllowed(nKey)
	if CAPTURE_KEYS[nKey] or ZiliaEmotes.BlockedBindKeys[nKey] then return false end

	return IsReservedKey(nKey) == false
end

function ZiliaEmotes.IsPlaying(tEmote)
	return ZiliaEmotes.GetActive(LocalPlayer()) == tEmote
end

-- Renvoie true si une demande de lancement a été envoyée
function ZiliaEmotes.ToggleEmote(tEmote)
	local nNow = RealTime()
	if nNow - nLastRequest < REQUEST_DEBOUNCE then return false end
	nLastRequest = nNow

	if ZiliaEmotes.IsPlaying(tEmote) then
		net.Start("Roa:AdminSys:StopEmote")
		net.SendToServer()

		return false
	end

	net.Start("Roa:AdminSys:RequestEmote")
	net.WriteUInt(tEmote.Index, ZiliaEmotes.INDEX_BITS)
	net.SendToServer()

	return true
end

hook.Add("PlayerButtonDown", "Roa:AdminSys:EmoteBinds", function(_, nKey)
	local sID = tKeyToEmote[nKey]
	if not sID or not IsFirstTimePredicted() then return end
	if ZiliaEmotes.IsPokemon() or IsValid(vgui.GetKeyboardFocus()) then return end
	if IsInCharacterCreation and IsInCharacterCreation() then return end

	local tEmote = ZiliaEmotes.ByID[sID]
	if tEmote then ZiliaEmotes.ToggleEmote(tEmote) end
end)

Load()