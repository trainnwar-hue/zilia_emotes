-- ENT.Base = "base_gmodentity"
-- ENT.PrintName = "Modular Body Part"
-- ENT.Spawnable = false
-- ENT.RenderGroup = RENDERGROUP_BOTH

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.RenderGroup = RENDERGROUP_OPAQUE

ENT.Type = "anim"
ENT.Base = "base_anim"

// Define a Networked String for the bone name
net.Receive("ModularPart_BoneData", function()
    local ent = net.ReadEntity()
    if IsValid(ent) and ent:IsClientside() then
        ent.ModularPartFollowBone = net.ReadString()
    end
end)