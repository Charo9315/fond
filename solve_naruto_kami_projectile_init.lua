AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:SetMoveType(MOVETYPE_NOCLIP)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
    self:SetNoDraw(true)
    self:DrawShadow(false)

    self.eLeftWheel = ents.Create("prop_dynamic")
    if IsValid(self.eLeftWheel) then
        self.eLeftWheel:SetModel("models/geams_naruto/customkami/roue_kami_geams.mdl")
        self.eLeftWheel:SetPos(self:GetPos())
        self.eLeftWheel:SetParent(self)
        self.eLeftWheel:SetLocalPos(Vector(0, -30, -30))
        self.eLeftWheel:SetLocalAngles(Angle(0, 90, 0))
        self.eLeftWheel:Spawn()
        self.eLeftWheel:DrawShadow(false)
    end

    self.eRightWheel = ents.Create("prop_dynamic")
    if IsValid(self.eRightWheel) then
        self.eRightWheel:SetModel("models/geams_naruto/customkami/roue_kami_geams.mdl")
        self.eRightWheel:SetPos(self:GetPos())
        self.eRightWheel:SetParent(self)
        self.eRightWheel:SetLocalPos(Vector(0, 30, -30))
        self.eRightWheel:SetLocalAngles(Angle(0, 90, 0))
        self.eRightWheel:Spawn()
        self.eRightWheel:DrawShadow(false)
    end

    self.Speed = 800
    self.fDamageOut = 25
    self.fDamageReturn = 25
    self.StartTime = CurTime()
    self.bReturning = false
    self._tHits = {}
    self._tHitsReturn = {}
end

function ENT:Setup(pPlayer, vecDir, flSpeed, flDamage)
    if not IsValid(pPlayer) then return end

    self:SetOwner(pPlayer)
    self:SetPos(pPlayer:GetPos() + Vector(0, 0, 50) + pPlayer:GetForward() * 50)

    if vecDir then
        self.Direction = vecDir
        self:SetAngles(vecDir:Angle())
    else
        self.Direction = pPlayer:GetAimVector()
        self:SetAngles(pPlayer:EyeAngles())
    end

    if flSpeed then
        self.Speed = flSpeed
    end

    if flDamage then
        self.Damage = flDamage
    end
end

function ENT:StartReturning()
    self.bReturning = true
    self:SetNWBool("bReturning", true)
end

function ENT:Think()
    local pOwner = self:GetOwner()
    local iCurTime = CurTime()

    local fLifetime = self.fLifetime or 5
    if iCurTime > self.StartTime + fLifetime then
        self:StartReturning()
    end

    local vecDir
    local fCurSpeed
    if self.bReturning and IsValid(pOwner) then
        vecDir = (pOwner:GetPos() + Vector(0, 0, 50) - self:GetPos()):GetNormalized()
        fCurSpeed = self.fReturnSpeed or self.Speed or 800

        if self:GetPos():Distance(pOwner:GetPos() + Vector(0, 0, 50)) < 100 then
            self:Remove()
            return
        end
    else
        vecDir = self.vecDirection or self.Direction or self:GetAngles():Forward()
        fCurSpeed = self.fSpeed or self.Speed or 800
    end

    local vecNewPos = self:GetPos() + vecDir * fCurSpeed * FrameTime()

    for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 60)) do
        if IsValid(ent) and ent ~= self and ent ~= pOwner and (ent:IsPlayer() or ent:IsNPC()) then
            if ent.AdminMode and ent:AdminMode() then continue end
            if self.bReturning then
                if not self._tHitsReturn[ent] then
                    self._tHitsReturn[ent] = true
                    self:OnHit(ent)
                end
            else
                if not self._tHits[ent] then
                    self._tHits[ent] = true
                    self:OnHit(ent)
                end
            end
        end
    end

    local tr = util.TraceLine({
        start = self:GetPos(),
        endpos = vecNewPos,
        filter = {self, pOwner}
    })

    if tr.Hit and not self.bReturning then
        if IsValid(tr.Entity) and (tr.Entity:IsPlayer() or tr.Entity:IsNPC()) then
            if not self._tHits[tr.Entity] then
                self._tHits[tr.Entity] = true
                self:OnHit(tr.Entity)
            end
        end
        self:StartReturning()
    else
        self:SetPos(vecNewPos)
        self:SetAngles(vecDir:Angle())
    end

    self:NextThink(CurTime())
    return true
end

function ENT:OnHit(eTarget)
    if not IsValid(eTarget) then return end

    local pOwner = self:GetOwner()
    local iDmg = self.bReturning and (self.fDamageReturn or 25) or (self.fDamageOut or 25)

    local dmginfo = DamageInfo()
    dmginfo:SetDamage(iDmg)
    dmginfo:SetAttacker(IsValid(pOwner) and pOwner or self)
    dmginfo:SetInflictor(self)
    dmginfo:SetDamageType(DMG_SLASH)
    eTarget:TakeDamageInfo(dmginfo)

    if self.iSlowForce and self.iSlowTime then
        local oldRun = eTarget:GetRunSpeed()
        local oldWalk = eTarget:GetWalkSpeed()
        local newSpeed = oldRun * self.iSlowForce
        eTarget:SetRunSpeed(newSpeed)
        eTarget:SetWalkSpeed(newSpeed)
        timer.Simple(self.iSlowTime, function()
            if IsValid(eTarget) then
                eTarget:SetRunSpeed(oldRun)
                eTarget:SetWalkSpeed(oldWalk)
            end
        end)
    end
end

function ENT:OnRemove()
    SafeRemoveEntity(self.eLeftWheel)
    SafeRemoveEntity(self.eRightWheel)

    local pOwner = self:GetOwner()
    if IsValid(pOwner) then
        pOwner.eKamiProjectile = nil
        hook.Remove("PlayerButtonDown", "Solve.Naruto.Skills.Kami3:Recall" .. pOwner:EntIndex())
    end
end
