-- Aperçu au survol : le personnage du joueur (modèle, bodygroups et vêtements attachés) joue l'emote
-- dans une fenêtre transparente à droite du menu. Modèles créés à l'ouverture du menu, supprimés à sa fermeture.
local PREVIEW_W = 220
local PREVIEW_H = 300
local PREVIEW_GAP = 16
local PREVIEW_MARGIN = 20
local PREVIEW_FOV = 26
local PREVIEW_FRAMING = 1.12
local PREVIEW_LOOPS = 2
local FADE_SPEED = 8
local MOVE_SMOOTHING = 14
local PREVIEW_RADIUS = 28
local COLOR_PREVIEW_BG = Color(24, 35, 100, 200)
local vPreview
local vAnchorMenu
local vTargetRow
local tTarget
local nTargetFrame = 0
local nHoverStart = 0

local function CopyBodygroups(eSource, eTarget)
	eTarget:SetSkin(eSource:GetSkin())
	for i = 0, eSource:GetNumBodyGroups() - 1 do
		eTarget:SetBodygroup(i, eSource:GetBodygroup(i))
	end
end

-- Copie générique des entités mergées sur le joueur : indépendante du système de tenues
local function CreateParts(eBase, pPlayer)
	local tParts = {}

	for _, eChild in ipairs(pPlayer:GetChildren()) do
		local sModel = eChild:GetModel()
		if not sModel or eChild:IsWeapon() or not eChild:IsEffectActive(EF_BONEMERGE) then continue end

		local ePart = ClientsideModel(sModel, RENDERGROUP_OTHER)
		if not IsValid(ePart) then continue end

		CopyBodygroups(eChild, ePart)
		ePart:SetParent(eBase)
		ePart:AddEffects(EF_BONEMERGE)
		ePart:SetNoDraw(true)
		table.insert(tParts, ePart)
	end

	return tParts
end

-- Boucle de démonstration : Start, Loop x PREVIEW_LOOPS, End, puis recommence
local function GetPreviewPhase(eModel, tEmote, nElapsed)
	local nStop = 0
	if not tEmote.Loop then
		nStop = ZiliaEmotes.GetDuration(eModel, tEmote.Start)
	elseif tEmote.End then
		nStop = ZiliaEmotes.GetDuration(eModel, tEmote.Start)
			+ ZiliaEmotes.GetDuration(eModel, tEmote.Loop) * PREVIEW_LOOPS
	end

	local nPeriod = nStop + ZiliaEmotes.GetDuration(eModel, tEmote.End)
	if nStop > 0 and nPeriod > 0 then nElapsed = nElapsed % nPeriod end

	return ZiliaEmotes.GetPhase(eModel, tEmote, 0, nStop, nElapsed)
end

local function FrameModel(vModelPanel, eBase)
	local _, vMaxs = eBase:GetModelBounds()
	local nHalfHeight = vMaxs.z / 2
	local nDistance = nHalfHeight / math.tan(math.rad(PREVIEW_FOV / 2)) * PREVIEW_FRAMING

	vModelPanel:SetFOV(PREVIEW_FOV)
	vModelPanel:SetLookAt(Vector(0, 0, nHalfHeight))
	vModelPanel:SetCamPos(Vector(nDistance, 0, nHalfHeight))
end

local function GetTargetY(nPanelH)
	local _, nRowY = vTargetRow:LocalToScreen(0, 0)
	local nY = nRowY + vTargetRow:GetTall() / 2 - nPanelH / 2

	return math.Clamp(nY, ZiliaEmotes.S(PREVIEW_MARGIN), ScrH() - nPanelH - ZiliaEmotes.S(PREVIEW_MARGIN))
end

local function SetupPreviewPanel(vModelPanel, tParts)
	local fPaintModel = vModelPanel.Paint
	function vModelPanel:Paint(nW, nH)
		local nRadius = ZiliaEmotes.S(PREVIEW_RADIUS)
		local UI = ZiliaEmotes.UI
		if UI then
			UI.DrawGlassPanel(self, nW, nH, nRadius)
		else
			draw.RoundedBox(nRadius, 0, 0, nW, nH, COLOR_PREVIEW_BG)
		end
		fPaintModel(self, nW, nH)
	end
	function vModelPanel:LayoutEntity(eEntity)
		if not tTarget then return end

		local nSequence, nCycle = GetPreviewPhase(eEntity, tTarget, RealTime() - nHoverStart)
		if not nSequence or nSequence < 0 then return end

		if eEntity:GetSequence() ~= nSequence then eEntity:ResetSequence(nSequence) end
		eEntity:SetCycle(nCycle)
	end

	function vModelPanel:PostDrawModel()
		for _, ePart in ipairs(tParts) do
			ePart:DrawModel()
		end
	end

	function vModelPanel:UpdatePosition(bSnap)
		if not IsValid(vAnchorMenu) or not IsValid(vTargetRow) then return end

		local nTargetY = GetTargetY(self:GetTall())
		self.nY = bSnap and nTargetY or Lerp(math.min(FrameTime() * MOVE_SMOOTHING, 1), self.nY, nTargetY)
		self:SetPos(vAnchorMenu:GetX() + vAnchorMenu:GetWide() + ZiliaEmotes.S(PREVIEW_GAP), self.nY)
	end

	-- Masqué (SetVisible) une fois le fondu terminé : aucun rendu tant que rien n'est survolé
	function vModelPanel:Think()
		local bHovered = IsValid(vTargetRow) and FrameNumber() - nTargetFrame <= 1
		self.nAlpha = math.Approach(self.nAlpha, bHovered and 1 or 0, FrameTime() * FADE_SPEED)
		self:SetAlpha(self.nAlpha * 255)

		if bHovered then
			self:UpdatePosition(false)
		elseif self.nAlpha <= 0 then
			self:SetVisible(false)
		end
	end

	local fRemoveEntity = vModelPanel.OnRemove
	function vModelPanel:OnRemove()
		for _, ePart in ipairs(tParts) do
			if IsValid(ePart) then ePart:Remove() end
		end

		fRemoveEntity(self)
	end
end

function ZiliaEmotes.DestroyPreview()
	if IsValid(vPreview) then vPreview:Remove() end

	vPreview = nil
	vTargetRow = nil
	tTarget = nil
end

function ZiliaEmotes.CreatePreview(vMenu)
	ZiliaEmotes.DestroyPreview()

	local pPlayer = LocalPlayer()
	local vModelPanel = vgui.Create("DModelPanel")
	vModelPanel:SetSize(ZiliaEmotes.S(PREVIEW_W), ZiliaEmotes.S(PREVIEW_H))
	vModelPanel:SetMouseInputEnabled(false)
	vModelPanel:SetKeyboardInputEnabled(false)
	vModelPanel:SetModel(pPlayer:GetModel())
	vModelPanel:SetAlpha(0)
	vModelPanel:SetVisible(false)
	vModelPanel.nAlpha = 0
	vModelPanel.nY = 0

	local eBase = vModelPanel:GetEntity()
	if not IsValid(eBase) then
		vModelPanel:Remove()

		return
	end

	CopyBodygroups(pPlayer, eBase)
	eBase:SetAngles(angle_zero)
	function eBase:GetPlayerColor() return pPlayer:GetPlayerColor() end

	FrameModel(vModelPanel, eBase)
	SetupPreviewPanel(vModelPanel, CreateParts(eBase, pPlayer))

	vPreview = vModelPanel
	vAnchorMenu = vMenu
end

-- Appelé chaque frame par la ligne survolée ; l'aperçu se masque dès qu'aucune ligne ne l'appelle plus
function ZiliaEmotes.SetPreviewTarget(tEmote, vRow)
	if not IsValid(vPreview) then return end

	nTargetFrame = FrameNumber()
	vTargetRow = vRow
	if tTarget ~= tEmote then
		tTarget = tEmote
		nHoverStart = RealTime()
	end

	if vPreview:IsVisible() then return end

	vPreview:SetVisible(true)
	vPreview:UpdatePosition(true)
end