-- Caméra des emotes : orbite autour du joueur, zoom à la molette, flou directionnel pendant la rotation.
-- La souris pilote une caméra séparée et les angles envoyés au serveur restent figés (regard levé) :
-- corps, tête et vêtements ne bougent pas, pour tout le monde.
local CAMERA_DISTANCE = 90
local CAMERA_MIN_DISTANCE = 50
local CAMERA_MAX_DISTANCE = 130
local CAMERA_ZOOM_STEP = 10
local CAMERA_ZOOM_SMOOTHING = 10
local CAMERA_PIVOT_HEIGHT = 56
local CAMERA_RAISE = 10
local CAMERA_HULL = Vector(4, 4, 4)
local CAMERA_ANGLE_SMOOTHING = 12
local CAMERA_BLEND_SPEED = 5
local CAMERA_DRAW_BODY_BLEND = 0.3
local CAMERA_PITCH_LIMIT = 89

local BLUR_SAMPLES = 6
local BLUR_EXPOSURE = 1 / 60
local BLUR_STRENGTH = 0.01
local BLUR_MIN_PIXELS = 1.5
local BLUR_MAX_PIXELS = 40
local BLUR_SMOOTHING = 10
local BLUR_OPACITY = 0.8

local MAT_BLUR = CreateMaterial("Roa_AdminSys_EmoteBlur", "UnlitGeneric", {
	["$basetexture"] = "_rt_FullFrameFB",
	["$translucent"] = 1,
	["$vertexalpha"] = 1,
	["$vertexcolor"] = 1,
	["$ignorez"] = 1,
})

local cvSensitivity = GetConVar("sensitivity")
local cvMouseYaw = GetConVar("m_yaw")
local cvMousePitch = GetConVar("m_pitch")

local tCameraTrace = {mins = -CAMERA_HULL, maxs = CAMERA_HULL, mask = MASK_SOLID_BRUSHONLY}
local aCameraAngles = Angle()
local aViewAngles = Angle()
local aOrbitAngles = Angle()
local aLockedView = Angle()
local aInitialView = Angle()
local nCameraBlend = 0
local nTargetDistance = CAMERA_DISTANCE
local nDistance = CAMERA_DISTANCE
local nBlurX, nBlurY = 0, 0
local nViewFov = 75
local nReleasedStart
local bCameraActive = false
local bOrbiting = false

local function IsThrowKeyDown()
	return input.IsKeyDown(ZiliaEmotes.ThrowKey) and not IsValid(vgui.GetKeyboardFocus())
end

local function StartOrbit(aEyeAngles)
	bOrbiting = true
	aInitialView:Set(aEyeAngles)
	aOrbitAngles:Set(aEyeAngles)
end

local function StopOrbit(cmd)
	bOrbiting = false
	cmd:SetViewAngles(aInitialView)
	LocalPlayer():SetEyeAngles(aInitialView)
end

-- CreateMove tourne à chaque commande, même menu ouvert (curseur visible), contrairement à InputMouseApply :
-- le verrouillage et la restauration de la vue ne dépendent donc pas de la souris
hook.Add("CreateMove", "Roa:AdminSys:EmoteCamera", function(cmd)
	local tEmote, nStart = ZiliaEmotes.GetActive(LocalPlayer())
	-- Vue d'origine rendue dès la commande qui contient R, avant que le serveur ne traite le lancer
	if tEmote and IsThrowKeyDown() then nReleasedStart = nStart end

	if not tEmote or nStart == nReleasedStart then
		if bOrbiting then StopOrbit(cmd) end

		return
	end

	if not bOrbiting then StartOrbit(cmd:GetViewAngles()) end

	aLockedView:SetUnpacked(ZiliaEmotes.GetLookPitch(tEmote), aInitialView.y, 0)
	cmd:SetViewAngles(aLockedView)
end)

hook.Add("InputMouseApply", "Roa:AdminSys:EmoteCamera", function(cmd, nMouseX, nMouseY)
	if not bOrbiting then return end

	local nSensitivity = cvSensitivity:GetFloat()
	local nPitch = aOrbitAngles.p + nMouseY * cvMousePitch:GetFloat() * nSensitivity
	aOrbitAngles.p = math.Clamp(nPitch, -CAMERA_PITCH_LIMIT, CAMERA_PITCH_LIMIT)
	aOrbitAngles.y = math.NormalizeAngle(aOrbitAngles.y - nMouseX * cvMouseYaw:GetFloat() * nSensitivity)
	cmd:SetViewAngles(aLockedView)

	return true
end)

-- La molette zoome au lieu de changer d'arme pendant l'emote
hook.Add("PlayerBindPress", "Roa:AdminSys:EmoteCamera", function(_, sBind, bPressed)
	if not bOrbiting or not bPressed then return end

	local nDirection = 0
	if string.find(sBind, "invprev", 1, true) then
		nDirection = -1
	elseif string.find(sBind, "invnext", 1, true) then
		nDirection = 1
	end
	if nDirection == 0 then return end

	nTargetDistance = math.Clamp(nTargetDistance + nDirection * CAMERA_ZOOM_STEP, CAMERA_MIN_DISTANCE,
		CAMERA_MAX_DISTANCE)

	return true
end)

local function UpdateCameraAngles(aTarget, nFrameTime)
	local nFrac = math.min(nFrameTime * CAMERA_ANGLE_SMOOTHING, 1)
	local nYawStep = math.AngleDifference(aTarget.y, aCameraAngles.y) * nFrac
	local nPitchStep = math.AngleDifference(aTarget.p, aCameraAngles.p) * nFrac

	aCameraAngles.p = aCameraAngles.p + nPitchStep
	aCameraAngles.y = math.NormalizeAngle(aCameraAngles.y + nYawStep)

	return nYawStep, nPitchStep
end

-- Déplacement apparent de l'image (en pixels) sur une durée d'exposition fixe : flou indépendant du framerate
local function UpdateBlur(nYawStep, nPitchStep, nFrameTime)
	if nFrameTime <= 0 then return end

	local nScale = BLUR_EXPOSURE / nFrameTime * ScrW() / nViewFov * BLUR_STRENGTH
	local nFrac = math.min(nFrameTime * BLUR_SMOOTHING, 1)

	nBlurX = Lerp(nFrac, nBlurX, nYawStep * nScale)
	nBlurY = Lerp(nFrac, nBlurY, nPitchStep * nScale)
end

local function GetOrbitPosition(pPlayer)
	local vPivot = pPlayer:GetPos()
	vPivot.z = vPivot.z + CAMERA_PIVOT_HEIGHT

	tCameraTrace.start = vPivot
	local vEnd = vPivot - aCameraAngles:Forward() * nDistance
	vEnd.z = vEnd.z + CAMERA_RAISE
	tCameraTrace.endpos = vEnd
	tCameraTrace.filter = pPlayer

	return util.TraceHull(tCameraTrace).HitPos
end

-- Fondu entre la vue normale et l'orbite, à l'entrée comme à la sortie de l'emote
hook.Add("CalcView", "Roa:AdminSys:EmoteCamera", function(pPlayer, vOrigin, aAngles, nFov)
	if not bCameraActive then
		if not bOrbiting then return end

		bCameraActive = true
		aCameraAngles:Set(aOrbitAngles)
	end

	local nFrameTime = FrameTime()
	nCameraBlend = math.Approach(nCameraBlend, bOrbiting and 1 or 0, nFrameTime * CAMERA_BLEND_SPEED)
	if nCameraBlend <= 0 then
		bCameraActive = false
		nBlurX, nBlurY = 0, 0

		return
	end

	nViewFov = nFov

	local nYawStep, nPitchStep = UpdateCameraAngles(bOrbiting and aOrbitAngles or aAngles, nFrameTime)
	UpdateBlur(nYawStep, nPitchStep, nFrameTime)
	nDistance = Lerp(math.min(nFrameTime * CAMERA_ZOOM_SMOOTHING, 1), nDistance, nTargetDistance)

	-- Pendant l'orbite, aAngles contient la vue figée (regard levé) : le fondu part de la vue d'origine
	local aBase = bOrbiting and aInitialView or aAngles
	local nEase = nCameraBlend * nCameraBlend * (3 - 2 * nCameraBlend)
	aViewAngles.p = aBase.p + math.AngleDifference(aCameraAngles.p, aBase.p) * nEase
	aViewAngles.y = aBase.y + math.AngleDifference(aCameraAngles.y, aBase.y) * nEase

	return {
		origin = LerpVector(nEase, vOrigin, GetOrbitPosition(pPlayer)),
		angles = aViewAngles,
		fov = nFov,
		drawviewer = nEase > CAMERA_DRAW_BODY_BLEND,
	}
end)

-- Flou directionnel : l'image est redessinée de part et d'autre du centre dans le sens de la rotation.
-- L'alpha 1 / (i + 1) fait une moyenne uniforme des échantillons.
hook.Add("RenderScreenspaceEffects", "Roa:AdminSys:EmoteCamera", function()
	if not bCameraActive then return end

	local nRawLength = math.sqrt(nBlurX ^ 2 + nBlurY ^ 2)
	if nRawLength < BLUR_MIN_PIXELS then return end

	local nRatio = math.min(nRawLength, BLUR_MAX_PIXELS) / nRawLength
	local nDirX, nDirY = nBlurX * nRatio, nBlurY * nRatio
	local nW, nH = ScrW(), ScrH()

	render.UpdateScreenEffectTexture()
	render.SetMaterial(MAT_BLUR)

	for i = 1, BLUR_SAMPLES do
		local nOffset = (i - 0.5) / BLUR_SAMPLES - 0.5
		MAT_BLUR:SetFloat("$alpha", BLUR_OPACITY / (i + 1))
		render.DrawScreenQuadEx(nDirX * nOffset, nDirY * nOffset, nW, nH)
	end
end)

hook.Add("PreDrawViewModel", "Roa:AdminSys:EmoteCamera", function()
	if bCameraActive then return true end
end)