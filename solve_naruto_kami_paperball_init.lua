AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:DrawShadow(false)
    self:SetNoDraw(true)

    self:StartMotion()

    self.HitBoxRadius = self.Hitbox or 16
    self.ImpactDamage = self.ImpactDamage or 25
end



function ENT:OnImpact(col)
    local pOwner = self:GetOwner()
    local vHitPos = col.HitPos or self:GetPos()
    local pHitEnt = col.HitEntity

    if IsValid(pOwner) then
        pOwner:ExecParticle("kami_01_solve_geams_impact", vHitPos, Angle(0, 0, 0), NULL, false)
        pOwner:ExecSound("geams/solve_jutsu/kami/01_geams_solve_impact.wav")
    end

    if IsValid(pHitEnt) and pHitEnt ~= pOwner then
        local bCanHit = hook.Run("Solve.Naruto.Skills:CanHitEntity", pOwner, pHitEnt)
        if bCanHit ~= false then
            if (pHitEnt:IsPlayer() or pHitEnt:IsNextBot()) and pHitEnt:Alive() then
                local dmginfo = DamageInfo()
                dmginfo:SetDamage(self.ImpactDamage or 25)
                dmginfo:SetDamageType(DMG_GENERIC)
                dmginfo:SetAttacker(IsValid(pOwner) and pOwner or self)
                dmginfo:SetInflictor(self)
                pHitEnt:TakeDamageInfo(dmginfo)

                local fBuffDuration = self.BuffDuration or 10
                local fDebuffPercent = 1.1

                if IsValid(pOwner) then
                    pOwner:SetNWEntity("Kami1:LinkedTarget", pHitEnt)
                    pOwner:SetNWFloat("Kami1:LinkedEnd", CurTime() + fBuffDuration)
                end

                pHitEnt._Kami1DebuffMul = fDebuffPercent
                pHitEnt._Kami1DebuffEnd = CurTime() + fBuffDuration

                hook.Add("EntityTakeDamage", "Kami1:GlobalDebuff", function(eTarget, oDmgInfo)
                    if not IsValid(eTarget) then return end
                    if not eTarget:IsPlayer() then return end
                    if not eTarget._Kami1DebuffMul then return end
                    if eTarget._Kami1DebuffMul <= 1 then return end
                    if CurTime() > (eTarget._Kami1DebuffEnd or 0) then
                        eTarget._Kami1DebuffMul = nil
                        eTarget._Kami1DebuffEnd = nil
                        return
                    end
                    oDmgInfo:ScaleDamage(eTarget._Kami1DebuffMul)
                end)

                timer.Simple(fBuffDuration, function()
                    if IsValid(pHitEnt) then
                        pHitEnt._Kami1DebuffMul = nil
                        pHitEnt._Kami1DebuffEnd = nil
                    end
                    if IsValid(pOwner) then
                        pOwner:SetNWEntity("Kami1:LinkedTarget", NULL)
                        pOwner:SetNWFloat("Kami1:LinkedEnd", 0)
                    end
                end)
            end
        end
    end
end
