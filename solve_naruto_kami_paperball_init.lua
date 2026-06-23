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
                local fDebuffPercent = self.DebuffPercent or 1.4

                local sHookName = "Kami1:Debuff:" .. pHitEnt:SteamID64()

                if IsValid(pOwner) then
                    pOwner:SetNWEntity("Kami1:LinkedTarget", pHitEnt)
                    pOwner:SetNWFloat("Kami1:LinkedEnd", CurTime() + fBuffDuration)
                end

                hook.Add("EntityTakeDamage", sHookName, function(eTarget, oDmgInfo)
                    if not IsValid(pHitEnt) then
                        hook.Remove("EntityTakeDamage", sHookName)
                        return
                    end
                    if eTarget ~= pHitEnt then return end
                    local flDmg = oDmgInfo:GetDamage()
                    oDmgInfo:SetDamage(flDmg * fDebuffPercent)
                end)

                timer.Simple(fBuffDuration, function()
                    hook.Remove("EntityTakeDamage", sHookName)
                    if IsValid(pOwner) then
                        pOwner:SetNWEntity("Kami1:LinkedTarget", NULL)
                        pOwner:SetNWFloat("Kami1:LinkedEnd", 0)
                    end
                end)
            end
        end
    end
end
