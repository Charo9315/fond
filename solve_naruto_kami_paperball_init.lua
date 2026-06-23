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

hook.Add("EntityTakeDamage", "Kami1:GlobalDebuff", function(eTarget, oDmgInfo)
    if not IsValid(eTarget) then return end
    if not eTarget:IsPlayer() then return end
    local flDebuff = eTarget:GetNWFloat("Kami1:DamageDebuff", 0)
    if flDebuff <= 0 then return end
    local flEnd = eTarget:GetNWFloat("Kami1:DebuffEnd", 0)
    if CurTime() > flEnd then return end
    oDmgInfo:SetDamage(oDmgInfo:GetDamage() * flDebuff)
end)

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
                local fDebuffPercent = self.DebuffPercent or 1.4

                if IsValid(pOwner) then
                    pOwner:SetNWEntity("Kami1:LinkedTarget", pHitEnt)
                    pOwner:SetNWFloat("Kami1:LinkedEnd", CurTime() + fBuffDuration)
                end

                pHitEnt:SetNWFloat("Kami1:DamageDebuff", fDebuffPercent)
                pHitEnt:SetNWFloat("Kami1:DebuffEnd", CurTime() + fBuffDuration)

                timer.Simple(fBuffDuration, function()
                    if IsValid(pHitEnt) then
                        pHitEnt:SetNWFloat("Kami1:DamageDebuff", 0)
                        pHitEnt:SetNWFloat("Kami1:DebuffEnd", 0)
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
