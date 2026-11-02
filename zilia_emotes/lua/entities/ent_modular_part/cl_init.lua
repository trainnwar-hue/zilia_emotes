-- include("shared.lua")

-- function ENT:Initialize()
--     self:AddEffects(EF_BONEMERGE)
--     self:AddEffects(EF_BONEMERGE_FASTCULL)
--     self:SetupBones()
--     self:InvalidateBoneCache()

--     self.LastBoneUpdate = 0
--     self.BoneInfo = {} -- maps our bones to parent bones
--     self.BoneInfo[0] = "ValveBiped.Bip01_Spine4"
--     self.BoneMatrices = {}

--     self:AddCallback("BuildBonePositions", self.BuildBonePositions)
-- end

-- function ENT:BuildBonePositions(boneCount)
--     if not IsValid(self) then return end
--     local parent = self:GetParent()
--     if not IsValid(parent) then return end

--     -- Make sure we have bones ready
--     if self:GetBoneCount() <= 0 then return end
--     if parent:GetBoneCount() <= 0 then return end

--     -- Only update once per frame
--     local ct = CurTime()
--     if self.LastBoneUpdate == ct then return end
--     self.LastBoneUpdate = ct

--     -- Validate bones
--     for i = 0, self:GetBoneCount() - 1 do
--         -- Skip if invalid or procedural
--         local boneName = self:GetBoneName(i)
--         if not boneName or boneName == "__INVALIDBONE__" then continue end
--         if self:BoneHasFlag(i, BONE_ALWAYS_PROCEDURAL) then continue end

--         local followName = self.BoneInfo[i]
--         if not followName then continue end

--         local parentBone = parent:LookupBone(followName)
--         if not parentBone then continue end

--         local matr = parent:GetBoneMatrix(parentBone)
--         if not matr then continue end

--         -- Clone matrix so we don't overwrite parent data
--         local newMat = Matrix(matr)
--     end
-- end

include("shared.lua")

function ENT:Initialize()
    self:SetupBonemerge()
end

// Define the method that replaces GetFollowBone()
function ENT:GetFollowBone()
    return self:GetNetworkedString("ModularPartFollowBone", "")
end


function ENT:SetupBonemerge()
    local parent = self:GetParent()
    local followBone = self:GetFollowBone() 

    if not IsValid(parent) or followBone == "" then
    
        timer.Simple(0.1, function()
            if IsValid(self) then
                self:SetupBonemerge()
            end
        end)
        
        return
    end

    self:AddEffects(EF_BONEMERGE)
    self:AddEffects(EF_BONEMERGE_FASTCULL)

    self:SetupBones() 
end

function ENT:Draw()
    self:DrawModel()
end