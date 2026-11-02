-- Menu d'emotes (P ou zilia_emotes). Ne s'ouvre pas en mode Pokémon.
-- UI basée sur la maquette Figma « Pokémon » (modale « Add attack », action chips, pastilles de type).
local MENU_KEY = KEY_P
local CATEGORY_FAVORITES = "favorites"
local TOGGLE_DEBOUNCE = 0.25

local MENU_W = 420
local MENU_H = 620
local MENU_MARGIN = 30
local MENU_RADIUS = 28
local OPEN_TIME = 0.25
local CLOSE_TIME = 0.18
local OPEN_EASE = 0.3
local INDICATOR_SPEED = 14
local HOVER_SPEED = 12
local ROW_ANIM_TIME = 0.22
local ROW_ANIM_STAGGER = 0.025
local ROW_ANIM_MAX_STAGGER = 12
local ROW_ANIM_OFFSET = 14
local CAPTURE_ERROR_TIME = 2
local CAPTURE_PULSE_SPEED = 6
local KEY_LABEL_MAX = 4
local BLUR_AMOUNT = 4

-- Tokens Figma
local COLOR_WHITE = Color(255, 255, 255)
local COLOR_WHITE_70 = Color(255, 255, 255, 179)
local COLOR_WHITE_60 = Color(255, 255, 255, 153)
local COLOR_WHITE_20 = Color(255, 255, 255, 51)
local COLOR_WHITE_10 = Color(255, 255, 255, 26)
local COLOR_WHITE_5 = Color(255, 255, 255, 13)
local COLOR_NAVY = Color(10, 16, 47)              -- transparent-black/100
local COLOR_NAVY_40 = Color(10, 16, 47, 102)
local COLOR_NAVY_60 = Color(10, 16, 47, 153)
local COLOR_YELLOW = Color(253, 221, 0)           -- yellow/100
local COLOR_YELLOW_50 = Color(254, 240, 140)      -- yellow/50
local COLOR_RED = Color(220, 42, 42)              -- red/90
local COLOR_RED_HOVER = Color(236, 64, 64)
local COLOR_PANEL = Color(24, 35, 100, 200)       -- dégradé du panneau Stats, densifié pour le jeu
local COLOR_PANEL_LIGHT = Color(33, 49, 132, 70)
local COLOR_CHIP = Color(143, 153, 161, 51)       -- pastille de type Pokémon
local COLOR_CHIP_BORDER = Color(143, 153, 161, 120)
local COLOR_CHIP_TEXT = Color(196, 202, 210)
local COLOR_STAR_EMPTY = Color(143, 153, 161)
local COLOR_ERROR = Color(255, 110, 100)

local S = ZiliaEmotes.S

-- Sons d'interface (sound/zilia_emotes/*.wav, joués uniquement pour le joueur local, non spatialisés)
local SFX_HOVER = "zilia_emotes/hover.wav"
local SFX_TAB = "zilia_emotes/tab.wav"
local SFX_TOGGLE = "zilia_emotes/toggle.wav"
local SFX_ENTER = "zilia_emotes/enter.wav"
local SFX_HOVER_COOLDOWN = 0.04
local nLastHoverSound = 0

local function PlaySFX(sPath, nPitch, nVolume)
	local pPlayer = LocalPlayer()
	if not IsValid(pPlayer) then return end

	pPlayer:EmitSound(sPath, 0, nPitch or 100, nVolume or 1, CHAN_STATIC)
end

local function PlayHoverSFX()
	if RealTime() - nLastHoverSound < SFX_HOVER_COOLDOWN then return end
	nLastHoverSound = RealTime()

	PlaySFX(SFX_HOVER, math.random(96, 104), 0.6)
end

local TABS = {{ID = CATEGORY_FAVORITES, Name = "Favoris"}}
for _, tCategory in ipairs(ZiliaEmotes.Categories) do
	table.insert(TABS, tCategory)
end

local vEmoteMenu
local vClosingMenu
local sSelectedCategory = CATEGORY_FAVORITES
local sCaptureID
local nCaptureErrorUntil = 0
local nLastToggle = 0
local tKeyLabels = {}

---------------------------------------------------------------------------
-- Helpers de rendu (partagés avec l'aperçu via ZiliaEmotes.UI)
---------------------------------------------------------------------------
local UI = {}
ZiliaEmotes.UI = UI

local MAT_BLUR = Material("pp/blurscreen")
local MAT_GRADIENT_DOWN = Material("gui/gradient_down")

local function CopyColor(cColor, nAlphaMul)
	return Color(cColor.r, cColor.g, cColor.b, cColor.a * (nAlphaMul or 1))
end

local function LerpColor(nFrac, cFrom, cTo)
	return Color(Lerp(nFrac, cFrom.r, cTo.r), Lerp(nFrac, cFrom.g, cTo.g), Lerp(nFrac, cFrom.b, cTo.b),
		Lerp(nFrac, cFrom.a, cTo.a))
end

local function Approach(nCurrent, bTarget, nSpeed)
	return math.Approach(nCurrent or 0, bTarget and 1 or 0, FrameTime() * (nSpeed or HOVER_SPEED))
end

local function EaseOut(nFrac)
	return 1 - (1 - nFrac) ^ 3
end

-- Polygone convexe d'un rectangle arrondi (masque stencil du flou)
local tRoundedPolys = {}
local function GetRoundedPoly(nW, nH, nRadius)
	local sKey = nW .. ":" .. nH .. ":" .. nRadius
	local tPoly = tRoundedPolys[sKey]
	if tPoly then return tPoly end

	tPoly = {}
	local nSteps = 10
	local tCorners = {
		{nW - nRadius, nRadius, -90}, {nW - nRadius, nH - nRadius, 0},
		{nRadius, nH - nRadius, 90}, {nRadius, nRadius, 180},
	}
	for _, tCorner in ipairs(tCorners) do
		for i = 0, nSteps do
			local nAngle = math.rad(tCorner[3] + 90 * i / nSteps)
			table.insert(tPoly, {x = tCorner[1] + math.cos(nAngle) * nRadius, y = tCorner[2] + math.sin(nAngle) * nRadius})
		end
	end

	tRoundedPolys[sKey] = tPoly

	return tPoly
end

-- Flou de l'arrière-plan, limité à la forme arrondie du panneau
function UI.DrawBlur(vPanel, nW, nH, nRadius, nAmount)
	local nX, nY = vPanel:LocalToScreen(0, 0)

	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(255)
	render.SetStencilTestMask(255)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)

	render.OverrideColorWriteEnable(true, false)
	draw.NoTexture()
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawPoly(GetRoundedPoly(nW, nH, nRadius))
	render.OverrideColorWriteEnable(false, false)

	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.SetStencilPassOperation(STENCIL_KEEP)

	surface.SetMaterial(MAT_BLUR)
	surface.SetDrawColor(255, 255, 255, 255)
	for i = 1, 3 do
		MAT_BLUR:SetFloat("$blur", i / 3 * (nAmount or BLUR_AMOUNT))
		MAT_BLUR:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(-nX, -nY, ScrW(), ScrH())
	end

	render.SetStencilEnable(false)
end

-- Contour fin d'un rectangle arrondi, sans remplissage (compatible fonds translucides)
function UI.DrawRoundedOutline(nX, nY, nW, nH, nRadius, cColor)
	surface.SetDrawColor(cColor)
	surface.DrawRect(nX + nRadius, nY, nW - nRadius * 2, 1)
	surface.DrawRect(nX + nRadius, nY + nH - 1, nW - nRadius * 2, 1)
	surface.DrawRect(nX, nY + nRadius, 1, nH - nRadius * 2)
	surface.DrawRect(nX + nW - 1, nY + nRadius, 1, nH - nRadius * 2)

	local nSteps = math.max(6, math.floor(nRadius / 2))
	local tCorners = {
		{nX + nW - nRadius - 0.5, nY + nRadius, -90}, {nX + nW - nRadius - 0.5, nY + nH - nRadius - 0.5, 0},
		{nX + nRadius, nY + nH - nRadius - 0.5, 90}, {nX + nRadius, nY + nRadius, 180},
	}
	for _, tCorner in ipairs(tCorners) do
		local nLastX, nLastY
		for i = 0, nSteps do
			local nAngle = math.rad(tCorner[3] + 90 * i / nSteps)
			local nPX = tCorner[1] + math.cos(nAngle) * (nRadius - 0.5)
			local nPY = tCorner[2] + math.sin(nAngle) * (nRadius - 0.5)
			if nLastX then surface.DrawLine(nLastX, nLastY, nPX, nPY) end
			nLastX, nLastY = nPX, nPY
		end
	end
end

-- Panneau Figma : fond bleu translucide + flou + liseré blanc/20 en retrait de 4px
function UI.DrawGlassPanel(vPanel, nW, nH, nRadius)
	UI.DrawBlur(vPanel, nW, nH, nRadius)
	draw.RoundedBox(nRadius, 0, 0, nW, nH, COLOR_PANEL)

	-- Léger éclaircissement vers le haut pour la profondeur
	draw.RoundedBoxEx(nRadius, 0, 0, nW, nRadius * 2, COLOR_PANEL_LIGHT, true, true, false, false)
	surface.SetMaterial(MAT_GRADIENT_DOWN)
	surface.SetDrawColor(COLOR_PANEL_LIGHT)
	surface.DrawTexturedRect(0, nRadius * 2, nW, nH * 0.45)

	local nInset = S(4)
	UI.DrawRoundedOutline(nInset, nInset, nW - nInset * 2, nH - nInset * 2, nRadius - nInset, COLOR_WHITE_20)
end

-- Pastille avec liseré sur fond translucide : liseré dessous, intérieur assombri par-dessus
local function DrawChip(nX, nY, nW, nH, cBorder, cFill)
	local nRadius = math.floor(nH / 2)
	local nBorder = math.max(1, math.Round(S(1)))

	draw.RoundedBox(nRadius, nX, nY, nW, nH, cBorder)
	draw.RoundedBox(nRadius - nBorder, nX + nBorder, nY + nBorder, nW - nBorder * 2, nH - nBorder * 2, cFill)
end

---------------------------------------------------------------------------

local function GetKeyLabel(nKey)
	local sLabel = tKeyLabels[nKey]
	if sLabel then return sLabel end

	sLabel = string.upper(input.GetKeyName(nKey) or "?"):sub(1, KEY_LABEL_MAX)
	tKeyLabels[nKey] = sLabel

	return sLabel
end

local function StopCapture()
	sCaptureID = nil
	if IsValid(vEmoteMenu) then vEmoteMenu:SetKeyboardInputEnabled(false) end
end

local function StartCapture(sID)
	sCaptureID = sID
	nCaptureErrorUntil = 0
	vEmoteMenu:SetKeyboardInputEnabled(true)
	vEmoteMenu:RequestFocus()
end

local function CloseMenu(bSilent)
	if not IsValid(vEmoteMenu) then return end
	if not bSilent then PlaySFX(SFX_ENTER, 88) end

	StopCapture()
	ZiliaEmotes.DestroyPreview()

	local vMenu = vEmoteMenu
	vEmoteMenu = nil
	vClosingMenu = vMenu
	vMenu:Stop()
	vMenu:SetMouseInputEnabled(false)
	vMenu:SetKeyboardInputEnabled(false)
	vMenu:MoveTo(-vMenu:GetWide(), vMenu:GetY(), CLOSE_TIME)
	vMenu:AlphaTo(0, CLOSE_TIME, 0, function() vMenu:Remove() end)
end

local function GetCategoryEmotes(sCategory)
	local tEmotes = {}

	for _, tEmote in ipairs(ZiliaEmotes.List) do
		local bInCategory = tEmote.Category == sCategory
		if sCategory == CATEGORY_FAVORITES then bInCategory = ZiliaEmotes.IsFavorite(tEmote.ID) end
		if bInCategory then table.insert(tEmotes, tEmote) end
	end

	return tEmotes
end

local STAR_INNER_RATIO = 0.45
local STAR_OUTER = {}
local STAR_INNER = {}
for i = 1, 5 do
	local nOuterAngle = math.rad(-90 + (i - 1) * 72)
	local nInnerAngle = nOuterAngle + math.rad(36)

	STAR_OUTER[i] = {math.cos(nOuterAngle), math.sin(nOuterAngle)}
	STAR_INNER[i] = {math.cos(nInnerAngle) * STAR_INNER_RATIO, math.sin(nInnerAngle) * STAR_INNER_RATIO}
end

local tPentagonPoly = {{}, {}, {}, {}, {}}
local tTrianglePoly = {{}, {}, {}}

local function SetVertex(tVertex, tPoint, nX, nY, nRadius)
	tVertex.x = nX + tPoint[1] * nRadius
	tVertex.y = nY + tPoint[2] * nRadius
end

-- Sommets dans le sens horaire (axe Y vers le bas), sinon DrawPoly n'affiche rien
local function DrawFilledStar(nX, nY, nRadius, cColor)
	draw.NoTexture()
	surface.SetDrawColor(cColor)

	for i = 1, 5 do
		SetVertex(tPentagonPoly[i], STAR_INNER[i], nX, nY, nRadius)
	end
	surface.DrawPoly(tPentagonPoly)

	for i = 1, 5 do
		SetVertex(tTrianglePoly[1], STAR_INNER[(i - 2) % 5 + 1], nX, nY, nRadius)
		SetVertex(tTrianglePoly[2], STAR_OUTER[i], nX, nY, nRadius)
		SetVertex(tTrianglePoly[3], STAR_INNER[i], nX, nY, nRadius)
		surface.DrawPoly(tTrianglePoly)
	end
end

local function DrawThickLine(nX1, nY1, nX2, nY2, nThickness)
	local nLength = math.sqrt((nX2 - nX1) ^ 2 + (nY2 - nY1) ^ 2)
	local nAngle = math.deg(math.atan2(nY1 - nY2, nX2 - nX1))

	surface.DrawTexturedRectRotated((nX1 + nX2) / 2, (nY1 + nY2) / 2, nLength + nThickness * 0.6, nThickness, nAngle)
end

-- Étoile vide (contour seul) : reste propre quel que soit le fond de la ligne
local function DrawOutlinedStar(nX, nY, nRadius, nThickness, cColor)
	draw.NoTexture()
	surface.SetDrawColor(cColor)

	local nInset = nThickness / 2
	local nLastX, nLastY
	for i = 1, 6 do
		local nIndex = (i - 1) % 5 + 1
		local nOX = nX + STAR_OUTER[nIndex][1] * (nRadius - nInset)
		local nOY = nY + STAR_OUTER[nIndex][2] * (nRadius - nInset)
		if nLastX then DrawThickLine(nLastX, nLastY, nOX, nOY, nThickness) end
		if i == 6 then break end

		local nIX = nX + STAR_INNER[nIndex][1] * (nRadius - nInset)
		local nIY = nY + STAR_INNER[nIndex][2] * (nRadius - nInset)
		DrawThickLine(nOX, nOY, nIX, nIY, nThickness)
		nLastX, nLastY = nIX, nIY
	end
end

local function DrawCross(nX, nY, nSize, nThickness, cColor)
	draw.NoTexture()
	surface.SetDrawColor(cColor)
	surface.DrawTexturedRectRotated(nX, nY, nSize, nThickness, 45)
	surface.DrawTexturedRectRotated(nX, nY, nSize, nThickness, -45)
end

local function DrawKeyboardIcon(nX, nY, nW, nH, cColor)
	local nThickness = math.max(1, S(2))
	local nKey = math.max(2, math.Round(nH * 0.16))
	local nGap = (nW - nKey * 4) / 5

	surface.SetDrawColor(cColor)
	surface.DrawOutlinedRect(nX, nY, nW, nH, nThickness)
	for i = 0, 3 do
		surface.DrawRect(nX + nGap + i * (nKey + nGap), nY + nH * 0.25, nKey, nKey)
	end
	surface.DrawRect(nX + nW * 0.25, nY + nH * 0.62, nW * 0.5, nKey)
end

-- Police de la maquette : Manrope (nom interne de la famille), graisse = fichier choisi
local FONT_FAMILY = "Manrope"
local tFonts = {}

local function CreateFont(sName, nSize, nWeight)
	surface.CreateFont(sName, {font = FONT_FAMILY, size = nSize, weight = nWeight, extended = true, antialias = true})

	return sName
end

local function BuildFonts()
	local nScaleKey = S(1000)
	if tFonts.nScaleKey == nScaleKey then return end

	tFonts.nScaleKey = nScaleKey
	tFonts.Title = CreateFont("Roa:AdminSys:EmoteTitle", S(28), 800)   -- Heading/H4 ExtraBold
	tFonts.Tab = CreateFont("Roa:AdminSys:EmoteTab", S(15), 700)       -- Text/L Bold
	tFonts.Item = CreateFont("Roa:AdminSys:EmoteItem", S(17), 700)     -- Text/XL Bold
	tFonts.Status = CreateFont("Roa:AdminSys:EmoteStatus", S(15), 700)
	tFonts.Small = CreateFont("Roa:AdminSys:EmoteSmall", S(14), 600)
	tFonts.Key = CreateFont("Roa:AdminSys:EmoteKey", S(15), 700)
end

local function StyleScrollBar(vScroll)
	local vBar = vScroll:GetVBar()
	vBar:SetWide(math.max(2, math.Round(S(2))))
	vBar:SetHideButtons(true)
	vBar:DockMargin(S(10), 0, 0, 0)

	function vBar:Paint(nW, nH)
		draw.RoundedBox(math.floor(nW / 2), 0, 0, nW, nH, COLOR_WHITE_10)
	end

	function vBar.btnGrip:Paint(nW, nH)
		self.nHover = Approach(self.nHover, self:IsHovered() or self.Depressed)
		draw.RoundedBox(math.floor(nW / 2), 0, 0, nW, nH, LerpColor(self.nHover, COLOR_WHITE_70, COLOR_WHITE))
	end
end

local function BuildHeader(vFrame)
	local vHeader = vgui.Create("DPanel", vFrame)
	vHeader:Dock(TOP)
	vHeader:SetTall(S(40))
	vHeader:DockMargin(S(8), 0, 0, S(16))

	function vHeader:Paint(nW, nH)
		draw.SimpleText("Emotes", tFonts.Title, 0, nH / 2, COLOR_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- Button-Red de la maquette : rond rouge, liseré blanc/20 intérieur, croix blanche
	local vClose = vgui.Create("DButton", vHeader)
	vClose:Dock(RIGHT)
	vClose:SetWide(S(32))
	vClose:DockMargin(0, S(4), 0, S(4))
	vClose:SetText("")
	vClose.DoClick = function() CloseMenu() end

	function vClose:Paint(nW, nH)
		self.nHover = Approach(self.nHover, self:IsHovered())

		local nSize = math.min(nW, nH)
		local nX, nY = (nW - nSize) / 2, (nH - nSize) / 2
		local cFill = LerpColor(self.nHover, COLOR_RED, COLOR_RED_HOVER)
		local nRing = S(2)
		local nBorder = math.max(1, math.Round(S(1)))

		draw.RoundedBox(math.floor(nSize / 2), nX, nY, nSize, nSize, cFill)
		local nInner = nSize - nRing * 2
		draw.RoundedBox(math.floor(nInner / 2), nX + nRing, nY + nRing, nInner, nInner, COLOR_WHITE_20)
		draw.RoundedBox(math.floor(nInner / 2) - nBorder, nX + nRing + nBorder, nY + nRing + nBorder,
			nInner - nBorder * 2, nInner - nBorder * 2, cFill)
		DrawCross(nW / 2, nH / 2, nSize * 0.4, math.max(2, S(2.4)), COLOR_WHITE)
	end
end

-- Action chips de la maquette : pastille jaune (sélection) qui glisse, les autres en navy/40
local function BuildTabs(vFrame)
	local vTabs = vgui.Create("DPanel", vFrame)
	vTabs:Dock(TOP)
	vTabs:SetTall(S(38))
	vTabs:DockMargin(0, 0, 0, S(16))
	vTabs.tButtons = {}

	for _, tTab in ipairs(TABS) do
		local vButton = vgui.Create("DButton", vTabs)
		vButton:SetText("")
		vTabs.tButtons[tTab.ID] = vButton

		function vButton:DoClick()
			if sSelectedCategory ~= tTab.ID then PlaySFX(SFX_TAB) end
			vFrame:SelectCategory(tTab.ID)
		end

		function vButton:Paint(nW, nH)
			local bActive = sSelectedCategory == tTab.ID
			self.nActive = Approach(self.nActive, bActive, INDICATOR_SPEED)
			self.nHover = Approach(self.nHover, self:IsHovered() and not bActive)

			local cColor = LerpColor(self.nActive, COLOR_WHITE, COLOR_NAVY)
			draw.SimpleText(tTab.Name, tFonts.Tab, nW / 2, nH / 2, cColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	function vTabs:PerformLayout(nW, nH)
		local nGap = S(6)
		local nTabW = (nW - nGap * (#TABS - 1)) / #TABS

		for i, tTab in ipairs(TABS) do
			local vButton = self.tButtons[tTab.ID]
			vButton:SetPos(math.Round((i - 1) * (nTabW + nGap)), 0)
			vButton:SetSize(math.Round(nTabW), nH)
		end
	end

	-- Les fonds sont peints par le conteneur pour que la pastille jaune passe sous le texte
	function vTabs:Paint(nW, nH)
		local nRadius = math.floor(nH / 2)
		for _, tTab in ipairs(TABS) do
			local vButton = self.tButtons[tTab.ID]
			draw.RoundedBox(nRadius, vButton:GetX(), 0, vButton:GetWide(), nH,
				LerpColor(vButton.nHover or 0, COLOR_NAVY_40, COLOR_NAVY_60))
		end

		local vTarget = self.tButtons[sSelectedCategory]
		local nTargetX, nTargetW = vTarget:GetX(), vTarget:GetWide()
		if not self.nIndicatorX then
			self.nIndicatorX, self.nIndicatorW = nTargetX, nTargetW
		end

		local nFrac = math.min(FrameTime() * INDICATOR_SPEED, 1)
		self.nIndicatorX = Lerp(nFrac, self.nIndicatorX, nTargetX)
		self.nIndicatorW = Lerp(nFrac, self.nIndicatorW, nTargetW)

		DrawChip(self.nIndicatorX, 0, self.nIndicatorW, nH, COLOR_YELLOW_50, COLOR_YELLOW)
	end
end

local function BuildFooter(vFrame)
	local vFooter = vgui.Create("DPanel", vFrame)
	vFooter:Dock(BOTTOM)
	vFooter:SetTall(S(32))
	vFooter:DockMargin(0, S(12), 0, 0)

	function vFooter:Paint(nW, nH)
		local nPad = S(8)
		surface.SetDrawColor(COLOR_WHITE_20)
		surface.DrawRect(nPad, 0, nW - nPad * 2, math.max(1, math.Round(S(1))))

		local nTextY = nH / 2 + S(4)
		local sText, cColor = "Bouger, sauter, Ctrl ou R : annuler", COLOR_WHITE_60
		if sCaptureID then
			sText, cColor = "Touche ? Échap : annuler, Retour : retirer", COLOR_YELLOW
			if RealTime() < nCaptureErrorUntil then sText, cColor = "Touche non autorisée", COLOR_ERROR end
		end

		draw.SimpleText(sText, tFonts.Small, nPad, nTextY, cColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		if sCaptureID then return end

		draw.SimpleText("P : fermer", tFonts.Small, nW - nPad, nTextY, COLOR_WHITE_60, TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
	end
end

local function GetEmptyMessage()
	if sSelectedCategory == CATEGORY_FAVORITES then
		return "Cliquez sur l'étoile d'une emote\npour l'ajouter à vos favoris."
	end

	return "Aucune emote dans cette catégorie."
end

local function BuildList(vFrame)
	local vListPanel = vgui.Create("DPanel", vFrame)
	vListPanel:Dock(FILL)

	function vListPanel:Paint(nW, nH)
		if not self.bEmpty then return end

		draw.DrawText(GetEmptyMessage(), tFonts.Small, nW / 2, nH / 2 - S(18), COLOR_WHITE_60, TEXT_ALIGN_CENTER)
	end

	local vScroll = vgui.Create("DScrollPanel", vListPanel)
	vScroll:Dock(FILL)
	StyleScrollBar(vScroll)

	return vListPanel, vScroll
end

local function CreateStarButton(vFrame, vRow, tEmote)
	local vStar = vgui.Create("DButton", vRow)
	vStar:Dock(RIGHT)
	vStar:SetWide(S(40))
	vStar:DockMargin(0, 0, S(4), 0)
	vStar:SetText("")

	function vStar:DoClick()
		ZiliaEmotes.ToggleFavorite(tEmote.ID)
		PlaySFX(SFX_TOGGLE, ZiliaEmotes.IsFavorite(tEmote.ID) and 112 or 90)
		if sSelectedCategory == CATEGORY_FAVORITES then vFrame:RefreshList(false) end
	end

	function vStar:Paint(nW, nH)
		self.nHover = Approach(self.nHover, self:IsHovered(), 14)
		self.nFavorite = Approach(self.nFavorite, ZiliaEmotes.IsFavorite(tEmote.ID), 12)

		local nPlaying = vRow.nPlaying or 0
		local nRadius = S(11) + S(1.5) * self.nHover
		local nX, nY = nW / 2, nH / 2 + S(1)
		local cFilled = LerpColor(nPlaying, COLOR_YELLOW, COLOR_NAVY)
		local cEmpty = LerpColor(nPlaying, LerpColor(self.nHover, COLOR_STAR_EMPTY, COLOR_WHITE),
			CopyColor(COLOR_NAVY, 0.55))

		surface.SetAlphaMultiplier(vRow:GetAppearFraction())
		if self.nFavorite < 1 then
			DrawOutlinedStar(nX, nY, nRadius, math.max(1.5, S(1.8)), CopyColor(cEmpty, 1 - self.nFavorite))
		end
		if self.nFavorite > 0 then
			DrawFilledStar(nX, nY, nRadius * Lerp(self.nFavorite, 0.6, 1), CopyColor(cFilled, self.nFavorite))
		end
		surface.SetAlphaMultiplier(1)
	end
end

-- Touche = pastille « type Pokémon » de la maquette : fond gris translucide, liseré et texte gris
local function PaintKeyButton(vButton, nW, nH, tEmote, nPlaying)
	local nKey = ZiliaEmotes.GetBind(tEmote.ID)
	local bCapture = sCaptureID == tEmote.ID
	vButton.nHover = Approach(vButton.nHover, vButton:IsHovered())

	local sLabel = bCapture and "…" or (nKey and GetKeyLabel(nKey))
	local nChipH = S(30)
	local nChipW = S(44)
	if sLabel then
		surface.SetFont(tFonts.Key)
		nChipW = math.max(nChipW, surface.GetTextSize(sLabel) + S(26))
	end

	local nX, nY = math.Round((nW - nChipW) / 2), math.Round((nH - nChipH) / 2)
	local cBorder = LerpColor(vButton.nHover, COLOR_CHIP_BORDER, COLOR_WHITE_60)
	local cFill = LerpColor(vButton.nHover, COLOR_NAVY_40, COLOR_NAVY_60)
	local cText = LerpColor(vButton.nHover, COLOR_CHIP_TEXT, COLOR_WHITE)

	-- Sur une ligne jaune (emote en cours), la pastille passe en navy translucide
	if nPlaying > 0 then
		cBorder = LerpColor(nPlaying, cBorder, CopyColor(COLOR_NAVY, 0.45))
		cFill = LerpColor(nPlaying, cFill, CopyColor(COLOR_NAVY, 0.12))
		cText = LerpColor(nPlaying, cText, COLOR_NAVY)
	end

	if bCapture then
		local nPulse = 0.5 + 0.5 * math.sin(RealTime() * CAPTURE_PULSE_SPEED)
		cBorder = CopyColor(nPlaying > 0.5 and COLOR_NAVY or COLOR_YELLOW, 0.45 + 0.55 * nPulse)
		cText = nPlaying > 0.5 and COLOR_NAVY or COLOR_YELLOW
	end

	DrawChip(nX, nY, nChipW, nChipH, cBorder, cFill)

	if sLabel then
		draw.SimpleText(sLabel, tFonts.Key, nW / 2, nH / 2, cText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		return
	end

	local nIconW, nIconH = S(18), S(12)
	DrawKeyboardIcon((nW - nIconW) / 2, (nH - nIconH) / 2, nIconW, nIconH, cText)
end

local function CreateKeyButton(vRow, tEmote)
	local vKey = vgui.Create("DButton", vRow)
	vKey:Dock(RIGHT)
	vKey:SetWide(S(64))
	vKey:SetText("")
	vKey:SetTooltip("Définir un raccourci")

	function vKey:DoClick()
		PlaySFX(SFX_TAB, sCaptureID == tEmote.ID and 90 or 105)
		if sCaptureID == tEmote.ID then StopCapture() else StartCapture(tEmote.ID) end
	end

	function vKey:Paint(nW, nH)
		surface.SetAlphaMultiplier(vRow:GetAppearFraction())
		PaintKeyButton(self, nW, nH, tEmote, vRow.nPlaying or 0)
		surface.SetAlphaMultiplier(1)
	end
end

-- Ligne = composant « attack » de la maquette : blanc/5, survol blanc/10, sélection jaune
local function CreateEmoteRow(vFrame, vScroll, tEmote, nOrder, bAnimate)
	local vRow = vScroll:Add("DButton")
	vRow:Dock(TOP)
	vRow:SetTall(S(48))
	vRow:DockMargin(0, 0, 0, S(10))
	vRow:SetText("")
	vRow.nAppear = bAnimate and RealTime() + math.min(nOrder - 1, ROW_ANIM_MAX_STAGGER) * ROW_ANIM_STAGGER or 0
	vRow.nPlaying = ZiliaEmotes.IsPlaying(tEmote) and 1 or 0

	function vRow:DoClick()
		StopCapture()
		PlaySFX(SFX_ENTER, 106)
		if ZiliaEmotes.ToggleEmote(tEmote) then CloseMenu(true) end
	end

	function vRow:GetAppearFraction()
		return EaseOut(math.Clamp((RealTime() - self.nAppear) / ROW_ANIM_TIME, 0, 1))
	end

	function vRow:IsRowHovered()
		return self:IsHovered() or self:IsChildHovered()
	end

	function vRow:Think()
		local bHovered = self:IsRowHovered()
		if bHovered and not self.bWasHovered then PlayHoverSFX() end
		self.bWasHovered = bHovered

		if bHovered then ZiliaEmotes.SetPreviewTarget(tEmote, self) end
	end

	function vRow:Paint(nW, nH)
		local nFrac = self:GetAppearFraction()
		local nOffset = math.Round((1 - nFrac) * S(ROW_ANIM_OFFSET))
		self.nHover = Approach(self.nHover, self:IsRowHovered())
		self.nPlaying = Approach(self.nPlaying, ZiliaEmotes.IsPlaying(tEmote), 8)

		local nRadius = math.floor(nH / 2)
		local nX, nRowW = nOffset, nW - nOffset

		surface.SetAlphaMultiplier(nFrac)
		draw.RoundedBox(nRadius, nX, 0, nRowW, nH, LerpColor(self.nHover, COLOR_WHITE_5, COLOR_WHITE_10))
		if self.nPlaying > 0 then
			draw.RoundedBox(nRadius, nX, 0, nRowW, nH, CopyColor(COLOR_YELLOW, self.nPlaying))
		end

		-- « Nom • En cours » : même construction que « Item name • Rare » dans la maquette
		local nTextX = nX + S(20)
		local cName = LerpColor(self.nPlaying, COLOR_WHITE, COLOR_NAVY)
		surface.SetFont(tFonts.Item)
		local nNameW = surface.GetTextSize(tEmote.Name)
		draw.SimpleText(tEmote.Name, tFonts.Item, nTextX, nH / 2, cName, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if self.nPlaying > 0 then
			local cStatus = CopyColor(COLOR_NAVY, 0.6 * self.nPlaying)
			local nDotX = nTextX + nNameW + S(10)
			draw.SimpleText("•", tFonts.Status, nDotX, nH / 2, cStatus, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText("En cours", tFonts.Status, nDotX + S(12) + S(4) * (1 - self.nPlaying), nH / 2, cStatus,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		surface.SetAlphaMultiplier(1)
	end

	CreateStarButton(vFrame, vRow, tEmote)
	CreateKeyButton(vRow, tEmote)
end

local function OnCaptureKey(nKey)
	if nKey == KEY_BACKSPACE then
		ZiliaEmotes.SetBind(sCaptureID, nil)
		PlaySFX(SFX_TOGGLE, 90)
		StopCapture()

		return
	end

	if ZiliaEmotes.IsBindKeyAllowed(nKey) == false then
		nCaptureErrorUntil = RealTime() + CAPTURE_ERROR_TIME
		PlaySFX(SFX_ENTER, 70, 0.8)

		return
	end

	ZiliaEmotes.SetBind(sCaptureID, nKey)
	PlaySFX(SFX_TOGGLE, 108)
	StopCapture()
end

local function OpenMenu()
	if IsValid(vEmoteMenu) or ZiliaEmotes.IsPokemon() then return end

	if IsValid(vClosingMenu) then vClosingMenu:Remove() end
	vClosingMenu = nil
	surface.SetAlphaMultiplier(1)

	BuildFonts()
	sSelectedCategory = CATEGORY_FAVORITES

	local nMenuW, nMenuH = S(MENU_W), S(MENU_H)
	local nMenuY = math.Round((ScrH() - nMenuH) / 2)

	local vFrame = vgui.Create("EditablePanel")
	vEmoteMenu = vFrame
	vFrame:SetSize(nMenuW, nMenuH)
	vFrame:SetPos(-nMenuW, nMenuY)
	vFrame:DockPadding(S(18), S(22), S(18), S(14))
	vFrame:MakePopup()
	-- Clavier laissé au jeu (P via PlayerButtonDown), repris seulement pendant l'assignation d'un raccourci
	vFrame:SetKeyboardInputEnabled(false)
	vFrame:SetAlpha(0)
	vFrame:MoveTo(S(MENU_MARGIN), nMenuY, OPEN_TIME, 0, OPEN_EASE)
	vFrame:AlphaTo(255, OPEN_TIME)

	function vFrame:Paint(nW, nH)
		UI.DrawGlassPanel(self, nW, nH, S(MENU_RADIUS))
	end

	function vFrame:Think()
		if self ~= vEmoteMenu then return end
		if ZiliaEmotes.IsPokemon() then
			CloseMenu(true)

			return
		end

		local bEscapeDown = input.IsKeyDown(KEY_ESCAPE)
		local bEscapePressed = bEscapeDown and not self.bEscapeWasDown
		self.bEscapeWasDown = bEscapeDown
		if not bEscapePressed then return end

		gui.HideGameUI()
		if sCaptureID then StopCapture() else CloseMenu() end
	end

	function vFrame:OnKeyCodePressed(nKey)
		if sCaptureID then OnCaptureKey(nKey) end
	end

	BuildHeader(vFrame)
	BuildTabs(vFrame)
	BuildFooter(vFrame)

	local vListPanel, vScroll = BuildList(vFrame)

	function vFrame:RefreshList(bAnimate)
		vScroll:Clear()

		local tEmotes = GetCategoryEmotes(sSelectedCategory)
		for i, tEmote in ipairs(tEmotes) do
			CreateEmoteRow(self, vScroll, tEmote, i, bAnimate)
		end

		vListPanel.bEmpty = #tEmotes == 0
	end

	function vFrame:SelectCategory(sCategory)
		if sSelectedCategory == sCategory then return end

		sSelectedCategory = sCategory
		self:RefreshList(false)
		vScroll:GetVBar():SetScroll(0)
	end

	vFrame:RefreshList(true)
	ZiliaEmotes.CreatePreview(vFrame)
	PlaySFX(SFX_ENTER, 100)
end

local function ToggleMenu()
	if RealTime() - nLastToggle < TOGGLE_DEBOUNCE then return end
	nLastToggle = RealTime()

	if IsValid(vEmoteMenu) then CloseMenu() else OpenMenu() end
end

hook.Add("PlayerButtonDown", "Roa:AdminSys:EmoteMenu", function(_, nKey)
	if nKey ~= MENU_KEY or not IsFirstTimePredicted() then return end
	if IsValid(vgui.GetKeyboardFocus()) then return end
	if IsInCharacterCreation and IsInCharacterCreation() then return end

	ToggleMenu()
end)

hook.Add("OnScreenSizeChanged", "Roa:AdminSys:EmoteMenu", function()
	ZiliaEmotes.UpdateScale()
	if not IsValid(vEmoteMenu) then return end

	ZiliaEmotes.DestroyPreview()
	vEmoteMenu:Remove()
	vEmoteMenu = nil
	OpenMenu()
end)

concommand.Add("zilia_emotes", ToggleMenu)