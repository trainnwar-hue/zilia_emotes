local INDEX_BITS = 10
local NW_INDEX = "ZiliaEmote"
local NW_START = "ZiliaEmoteStart"
local NW_STOP = "ZiliaEmoteStop"
-- IN_BULLRUSH n'est pas utilisé par le jeu : il signale au serveur un saut retiré côté client
local CANCEL_SIGNAL = IN_BULLRUSH
local CANCEL_BUTTONS = bit.bor(IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT, IN_JUMP, IN_DUCK, CANCEL_SIGNAL)

ZiliaEmotes.INDEX_BITS = INDEX_BITS
ZiliaEmotes.NW_INDEX = NW_INDEX
ZiliaEmotes.NW_START = NW_START
ZiliaEmotes.NW_STOP = NW_STOP
ZiliaEmotes.SEQUENCE_KEYS = {"Start", "Loop", "End"}

local function IsValidEmote(tEmote, tByID)
	if not isstring(tEmote.ID) or tByID[tEmote.ID] then return false end
	if not isstring(tEmote.Category) or not isstring(tEmote.Name) then return false end

	return tEmote.Start ~= nil or tEmote.Loop ~= nil or tEmote.End ~= nil
end

local tByID = {}
local tValidList = {}

for _, tEmote in ipairs(ZiliaEmotes.List) do
	if IsValidEmote(tEmote, tByID) then
		table.insert(tValidList, tEmote)
		tEmote.Index = #tValidList
		tByID[tEmote.ID] = tEmote
	else
		ErrorNoHalt("[Emotes] Emote invalide ou ID en double : ", tostring(tEmote.ID), "\n")
	end
end

if #tValidList >= bit.lshift(1, INDEX_BITS) then
	ErrorNoHalt("[Emotes] Trop d'emotes pour INDEX_BITS = ", INDEX_BITS, "\n")
end

ZiliaEmotes.List = tValidList
ZiliaEmotes.ByID = tByID

-- LookupSequence/SequenceDuration sont lus à chaque frame : cache par modèle (seules les séquences trouvées)
local tSequenceCache = {}

function ZiliaEmotes.GetSequence(eEntity, sName)
	local sModel = eEntity:GetModel()
	local tModelCache = tSequenceCache[sModel]
	if not tModelCache then
		tModelCache = {}
		tSequenceCache[sModel] = tModelCache
	end

	local tInfo = tModelCache[sName]
	if tInfo then return tInfo[1], tInfo[2] end

	local nSequence = eEntity:LookupSequence(sName)
	if nSequence < 0 then return -1, 0 end

	tInfo = {nSequence, eEntity:SequenceDuration(nSequence)}
	tModelCache[sName] = tInfo

	return tInfo[1], tInfo[2]
end

function ZiliaEmotes.GetDuration(eEntity, sName)
	if not sName then return 0 end

	local _, nDuration = ZiliaEmotes.GetSequence(eEntity, sName)

	return nDuration
end

function ZiliaEmotes.GetLookPitch(tEmote)
	return tEmote.LookPitch or ZiliaEmotes.LookPitch
end

-- Lecture des NW vars ; sv_emotes.lua remplace cette fonction côté serveur par une lecture de champs Lua
function ZiliaEmotes.GetState(pPlayer)
	return pPlayer:GetNWInt(NW_INDEX), pPlayer:GetNWFloat(NW_START), pPlayer:GetNWFloat(NW_STOP)
end

function ZiliaEmotes.GetActive(pPlayer)
	local nIndex, nStart, nStop = ZiliaEmotes.GetState(pPlayer)
	if nIndex == 0 then return end

	return tValidList[nIndex], nStart, nStop
end

local function PlayOnce(eEntity, sName, nElapsed)
	if not sName then return end

	local nSequence, nDuration = ZiliaEmotes.GetSequence(eEntity, sName)
	if nElapsed >= nDuration then return end

	return nSequence, nElapsed / nDuration
end

-- Séquence et cycle déduits uniquement du temps : identiques sur le serveur, chez les clients et dans l'aperçu
function ZiliaEmotes.GetPhase(eEntity, tEmote, nStart, nStop, nNow)
	if nStop > 0 and nNow >= nStop then
		return PlayOnce(eEntity, tEmote.End, nNow - nStop)
	end

	local nElapsed = nNow - nStart
	if tEmote.Start then
		local nSequence, nDuration = ZiliaEmotes.GetSequence(eEntity, tEmote.Start)
		if nElapsed < nDuration then return nSequence, nElapsed / nDuration end
		if not tEmote.Loop then return nSequence, 1 end

		nElapsed = nElapsed - nDuration
	end

	if not tEmote.Loop then return end

	local nSequence, nDuration = ZiliaEmotes.GetSequence(eEntity, tEmote.Loop)
	if nDuration <= 0 then return nSequence, 0 end

	return nSequence, (nElapsed % nDuration) / nDuration
end

hook.Add("CalcMainActivity", "Roa:AdminSys:Emotes", function(pPlayer)
	local tEmote, nStart, nStop = ZiliaEmotes.GetActive(pPlayer)
	if not tEmote then return end

	local nSequence, nCycle = ZiliaEmotes.GetPhase(pPlayer, tEmote, nStart, nStop, CurTime())
	if not nSequence or nSequence < 0 then return end

	pPlayer:SetCycle(nCycle)

	return ACT_INVALID, nSequence
end)

local function HasCancelInput(cmd)
	return bit.band(cmd:GetButtons(), CANCEL_BUTTONS) ~= 0
		or cmd:GetForwardMove() ~= 0
		or cmd:GetSideMove() ~= 0
end

-- Saut retiré tant que la touche est enfoncée (sinon le relâcher puis le garder ferait sauter au tick suivant).
-- Côté client, StartCommand modifie la commande envoyée : le signal est ajouté à chaque commande, car le
-- client en reconstruit une par image et seule la dernière avant l'envoi part au serveur.
local function FilterJump(pPlayer, cmd, bEmoting)
	local bBlocked = pPlayer.bZiliaEmoteJumpBlock
	if not bEmoting and not bBlocked then return end

	if not cmd:KeyDown(IN_JUMP) then
		if bBlocked then pPlayer.bZiliaEmoteJumpBlock = nil end

		return
	end

	cmd:RemoveKey(IN_JUMP)
	pPlayer.bZiliaEmoteJumpBlock = true
	if bEmoting then cmd:AddKey(CANCEL_SIGNAL) end
end

-- Exécuté dans les deux realms pour que la prédiction du client reste cohérente avec le serveur.
-- ZiliaEmotes.OnEmoteCommand n'existe que côté serveur (annulation, fin de l'emote).
hook.Add("StartCommand", "Roa:AdminSys:EmoteInput", function(pPlayer, cmd)
	local tEmote, _, nStop = ZiliaEmotes.GetActive(pPlayer)
	FilterJump(pPlayer, cmd, tEmote ~= nil)
	if not tEmote then return end

	if ZiliaEmotes.OnEmoteCommand then
		ZiliaEmotes.OnEmoteCommand(pPlayer, tEmote, nStop, HasCancelInput(cmd))
		tEmote, _, nStop = ZiliaEmotes.GetActive(pPlayer)
	end

	if tEmote and nStop > 0 and CurTime() >= nStop then
		cmd:ClearMovement()
		cmd:ClearButtons()
	end
end)

local function DetourGrabEarAnimation()
	local tGamemode = GAMEMODE
	if not tGamemode or tGamemode.fZiliaGrabEarOriginal or not tGamemode.GrabEarAnimation then return end

	local fOriginal = tGamemode.GrabEarAnimation
	tGamemode.fZiliaGrabEarOriginal = fOriginal

	function tGamemode:GrabEarAnimation(pPlayer, ...)
		if not ZiliaEmotes.GetActive(pPlayer) then return fOriginal(self, pPlayer, ...) end
		if (pPlayer.ChatGestureWeight or 0) <= 0 then return end

		pPlayer.ChatGestureWeight = 0
		pPlayer:AnimResetGestureSlot(GESTURE_SLOT_VCD)
	end
end

hook.Add("PostGamemodeLoaded", "Roa:AdminSys:EmoteChatGesture", DetourGrabEarAnimation)
DetourGrabEarAnimation()