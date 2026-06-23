AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:DrawShadow(false)

    self:SetDistance(0.2)
    self:SetDamage(100)
    self:SetLaserDistance(10000)
    self:SetLaserHull(50)

    self.flNextDamage = 0
    self.tHitEntities = {}
end

function ENT:Think()
    local pOwner = self:GetOwnerPlayer()
    local iCurTime = CurTime()

    if not IsValid(pOwner) then
        self:Remove()
        return
    end

    if iCurTime >= self.flNextDamage then
        self.flNextDamage = iCurTime + 1

        local flDamage = self:GetDamage()
        if flDamage <= 0 then
            self:NextThink(CurTime())
            return true
        end

        local flLaserDistance = self:GetLaserDistance()
        local flLaserHull = self:GetLaserHull()

        local vecStartPos = pOwner:EyePos()
        local vecAim = pOwner:GetAimVector()
        local vecEndPos = vecStartPos + vecAim * flLaserDistance

        local tHullSize = Vector(flLaserHull, flLaserHull, flLaserHull)

        local tTrace = util.TraceHull({
            start = vecStartPos,
            endpos = vecEndPos,
            filter = pOwner,
            mins = -tHullSize,
            maxs = tHullSize,
            mask = MASK_SHOT_HULL
        })

        if tTrace.Hit and IsValid(tTrace.Entity) then
            local eEntity = tTrace.Entity

            if eEntity:IsPlayer() or eEntity:IsNPC() then
                if not eEntity:AdminMode() then
                    local oDamageInfo = DamageInfo()
                    oDamageInfo:SetDamage(flDamage)
                    oDamageInfo:SetAttacker(pOwner)
                    oDamageInfo:SetInflictor(self)
                    oDamageInfo:SetDamageType(DMG_DISSOLVE)
                    eEntity:TakeDamageInfo(oDamageInfo)

                    eEntity:JParticle("hit_jinton", Vector(0, 0, 50), nil, 0.3, true)
                end
            end
        end

        self.tHitEntities = {}
    end

    self:NextThink(CurTime())
    return true
end

function ENT:OnRemove()
end
