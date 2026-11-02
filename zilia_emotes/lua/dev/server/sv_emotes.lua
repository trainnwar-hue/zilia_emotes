util.AddNetworkString("Roa:AdminSys:RequestEmote")
util.AddNetworkString("Roa:AdminSys:StopEmote")

local REQUEST_COOLDOWN = 0.3

local NW_INDEX = ZiliaEmotes.NW_INDEX
local NW_START = ZiliaEmotes.NW_START
local NW_STOP = ZiliaEmotes.NW_STOP

-- Les hooks appelés à chaque commande lisent un champ Lua plutôt que les NW vars,
-- qui ne servent qu'à informer les clients
function ZiliaEmotes.GetState(pPlayer)
	local tState = pPlayer.tZiliaEmoteState
	if not tState then return 0, 0, 0 end

	return tState.Index, tState.Start, tState.Stop
end

local function SetState(pPlayer, nIndex, nStart, nStop)
	pPlayer.tZiliaEmoteState = nIndex ~= 0 and {Index = nIndex, Start = nStart, Stop = nStop} or nil
	pPlayer:SetNWFloat(NW_START, nStart)
	pPlayer:SetNWFloat(NW_STOP, nStop)
	pPlayer:SetNWInt(NW_INDEX, nIndex)
end

-- MOVETYPE_WALK exclut aussi noclip, échelles et Canalisation (MOVETYPE_NONE)
local function IsUnavailable(pPlayer)
	return pPlayer:Alive() == false
		or pPlayer:InVehicle()
		or pPlayer:GetMoveType() ~= MOVETYPE_WALK
		or pPlayer:GetNWBool("IsPoke")
		or pPlayer.InCombat == true
end

local function HasAllSequences(pPlayer, tEmote)
	for _, sKey in ipairs(ZiliaEmotes.SEQUENCE_KEYS) do
		local sSequence = tEmote[sKey]
		if sSequence and ZiliaEmotes.GetSequence(pPlayer, sSequence) < 0 then return false end
	end

	return true
end

local function ClearEmote(pPlayer)
	if not pPlayer.tZiliaEmoteState then return end

	SetState(pPlayer, 0, 0, 0)
end

local function StartEmote(pPlayer, tEmote)
	local nNow = CurTime()
	local nStop = 0
	if not tEmote.Loop then
		nStop = nNow + ZiliaEmotes.GetDuration(pPlayer, tEmote.Start)
	end

	SetState(pPlayer, tEmote.Index, nNow, nStop)
end

local function StopEmote(pPlayer, bInstant)
	local tEmote, nStart, nStop = ZiliaEmotes.GetActive(pPlayer)
	if not tEmote then return end

	if bInstant or not tEmote.End then
		ClearEmote(pPlayer)

		return
	end

	local nNow = CurTime()
	if nStop > 0 and nStop <= nNow then return end

	SetState(pPlayer, tEmote.Index, nStart, nNow)
end

function ZiliaEmotes.OnEmoteCommand(pPlayer, tEmote, nStop, bCancel)
	if IsUnavailable(pPlayer) then
		ClearEmote(pPlayer)

		return
	end

	local nNow = CurTime()
	if nStop > 0 and nNow >= nStop + ZiliaEmotes.GetDuration(pPlayer, tEmote.End) then
		ClearEmote(pPlayer)

		return
	end

	if nStop > 0 and nNow >= nStop then return end
	if bCancel then StopEmote(pPlayer, false) end
end

local function IsRateLimited(pPlayer)
	local nNow = CurTime()
	if (pPlayer.nZiliaEmoteNextRequest or 0) > nNow then return true end

	pPlayer.nZiliaEmoteNextRequest = nNow + REQUEST_COOLDOWN

	return false
end

net.Receive("Roa:AdminSys:RequestEmote", function(_, pPlayer)
	if IsRateLimited(pPlayer) then return end

	local tEmote = ZiliaEmotes.List[net.ReadUInt(ZiliaEmotes.INDEX_BITS)]
	if not tEmote then return end

	if IsUnavailable(pPlayer) or pPlayer:IsOnGround() == false then
		pPlayer:ChatPrint("Vous ne pouvez pas faire d'emote maintenant.")

		return
	end

	if not HasAllSequences(pPlayer, tEmote) then
		pPlayer:ChatPrint("Cette emote n'est pas disponible avec votre modèle.")

		return
	end

	StartEmote(pPlayer, tEmote)
end)

net.Receive("Roa:AdminSys:StopEmote", function(_, pPlayer)
	if IsRateLimited(pPlayer) then return end

	StopEmote(pPlayer, false)
end)

-- Même événement que le lancer de Pokéball : l'emote est retirée dans le même tick, sans phase End
hook.Add("PlayerButtonDown", "Roa:AdminSys:EmoteThrowCancel", function(pPlayer, nButton)
	if nButton ~= ZiliaEmotes.ThrowKey then return end

	StopEmote(pPlayer, true)
end)

hook.Add("PlayerSpawn", "Roa:AdminSys:EmoteReset", ClearEmote)
hook.Add("PlayerDeath", "Roa:AdminSys:EmoteReset", ClearEmote)