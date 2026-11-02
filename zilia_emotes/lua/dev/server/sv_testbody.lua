-- Test en solo uniquement : version minimale de InitializeBody (sv_characreator.lua). À supprimer à l'intégration.
-- Nécessite lua/entities/ent_modular_part/ copié depuis le projet.
local BASE_MODEL = "models/washton/zilia/femme_base.mdl"
local PART_MODEL_PATH = "models/washton/zilia/"
local PART_DELAY = 0.01

-- {modèle, os, bodygroup, sous-modèle}, comme BuildOutfitPart (os repris de CLOTHES_OUTFIT_BONES)
local TEST_PARTS = {
	{"femme_cheveux_1.mdl", "ValveBiped.Bip01_Head1", 0, 1},
	{"femme_top_1.mdl", "ValveBiped.Bip01_Spine4", 0, 0},
	{"femme_bottom_1.mdl", "ValveBiped.Bip01_Pelvis", 0, 0},
	{"femme_botte_1.mdl", "ValveBiped.Bip01_L_Foot", 0, 0},
}

local function RemoveTestParts(pPlayer)
	for _, eChild in ipairs(pPlayer:GetChildren()) do
		if eChild.bZiliaTestPart then eChild:Remove() end
	end
end

local function CreatePart(pPlayer, tPart)
	local sModel = PART_MODEL_PATH .. tPart[1]
	local sBone = tPart[2]
	if not file.Exists(sModel, "GAME") then
		pPlayer:ChatPrint("Modèle introuvable : " .. sModel)

		return
	end

	local ePart = ents.Create("ent_modular_part")
	if not IsValid(ePart) then return end

	ePart:SetModel(sModel)
	ePart:SetPos(pPlayer:GetPos())
	ePart:SetAngles(pPlayer:GetAngles())
	ePart:Spawn()
	ePart:SetBodygroup(tPart[3], tPart[4])
	ePart:SetParent(pPlayer)
	ePart:SetLocalPos(vector_origin)
	ePart:SetLocalAngles(angle_zero)
	ePart:AddEffects(EF_BONEMERGE)
	ePart:AddEffects(EF_BONEMERGE_FASTCULL)
	ePart:FollowBone(pPlayer, pPlayer:LookupBone(sBone) or 0)
	ePart:SetFollowBone(sBone)
	ePart.bZiliaTestPart = true
end

concommand.Add("zilia_testbody", function(pPlayer)
	if not IsValid(pPlayer) or pPlayer:IsSuperAdmin() == false then return end

	RemoveTestParts(pPlayer)
	pPlayer:SetModel(BASE_MODEL)

	-- Comme InitializeBody : le squelette du nouveau modèle n'est pas prêt dans le même tick que SetModel
	for i, tPart in ipairs(TEST_PARTS) do
		timer.Simple(PART_DELAY * i, function()
			if IsValid(pPlayer) then CreatePart(pPlayer, tPart) end
		end)
	end
end)