-- AddCSLuaFile("cl_init.lua")
-- AddCSLuaFile("shared.lua")
-- include("shared.lua")

-- function ENT:Initialize()
--     print("hello")
--     self:SetCollisionBounds(vector_origin, vector_origin)
--     self:SetTransmitWithParent(true)
--     return
-- end

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    -- no physics
    self:SetSolid(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)

    -- ensures clients receive the entity and parent relationship
    self:SetTransmitWithParent(true)

    -- local ePart = self

    -- timer.Simple(10, function()
    --     ePart:Remove()
    -- end)
end

function ENT:SetFollowBone(boneName)
    self.ModularPartFollowBone = boneName
    self:SetNetworkedString("ModularPartFollowBone", boneName)
end