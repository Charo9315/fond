AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self.PhysicsModel)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NOCLIP)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    self:SetNoDraw(true)
    self:DrawShadow(false)
    
    self:SetStamp(CurTime())
    self:SetSide(1)
    
    self:SetMaxHealth(self.PuppetHealth)
    self:SetHealth(self.PuppetHealth)
    
    self.HitPlayers = {}
    self.bAttached = false
    self.iTicksDone = 0
    self.flNextTick = 0
end

function ENT:Setup(pPlayer, iSide)
    if not IsValid(pPlayer) then return end
    
    self:SetOwner(pPlayer)
    
    if iSide then
        self:SetSide(iSide)
    end
    
    local tConfig = self.Config[self:GetSide()] or self.Config[1]
    local flOffset = tConfig.sideOffset or 0
    
    self:SetPos(pPlayer:GetPos() + pPlayer:GetRight() * flOffset + pPlayer:GetForward() * 50)
    self:SetAngles(pPlayer:GetAngles())
end

function ENT:Think()
    local pOwner = self:GetOwner()
    if not IsValid(pOwner) then
        self:Remove()
        return
    end

    if self.bAttached then
        if IsValid(self.eHitTarget) and self.iTicksDone < 3 and CurTime() >= self.flNextTick then
            self.iTicksDone = self.iTicksDone + 1
            self.flNextTick = CurTime() + 1

            local dmg = DamageInfo()
            dmg:SetDamage(10)
            dmg:SetAttacker(pOwner)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_GENERIC)
            self.eHitTarget:TakeDamageInfo(dmg)
            self.eHitTarget:EmitSound("geams/solve_jutsu/inkuton/solve_inkuton_geams_03_monkey.wav")
        end

        self:NextThink(CurTime())
        return true
    end
    
    if not self.Direction then
        self.Direction = self:GetAngles():Forward()
    end
    
    local vecPos = self:GetPos()
    local flSpeed = self.Speed or 250
    
    local vecNewPos = vecPos + self.Direction * flSpeed * FrameTime()
    self:SetPos(vecNewPos)
    
    for _, eEnt in ipairs(ents.FindInSphere(vecNewPos, self.Radius or 128)) do
        if IsValid(eEnt) and eEnt:IsPlayer() and eEnt ~= pOwner and not self.HitPlayers[eEnt] then
            if eEnt:AdminMode() then continue end
            
            self.HitPlayers[eEnt] = true
            self.bAttached = true
            self.eHitTarget = eEnt
            self.flNextTick = CurTime() + 1
            self.iTicksDone = 0

            self:SetIsAttached(true)
            self:SetTarget(eEnt)
            self:SetHasAttacked(true)

            self:SetSolid(SOLID_NONE)
            self:SetMoveType(MOVETYPE_NONE)

            local boneName = "ValveBiped.Bip01_Spine2"
            if self._monkeyIndex == 2 then
                boneName = "ValveBiped.Bip01_L_UpperArm"
            elseif self._monkeyIndex == 3 then
                boneName = "ValveBiped.Bip01_R_UpperArm"
            end
            local boneId = eEnt:LookupBone(boneName) or 0
            self:FollowBone(eEnt, boneId)
            self:SetLocalPos(Vector(0, 0, 0))
            self:SetLocalAngles(Angle(0, 0, 0))

            if not eEnt._inkutonClinging then
                eEnt._inkutonClinging = true

                local iSilenceRoot = EF_SILENCE_AND_ROOT(eEnt)

                if SERVER then
                    net.Start("inkuton_singe_particle")
                    net.WriteEntity(eEnt)
                    net.WriteFloat(4)
                    net.Broadcast()
                end

                timer.Simple(4, function()
                    if IsValid(iSilenceRoot) then
                        iSilenceRoot:Destroy()
                    end
                    if IsValid(eEnt) then
                        eEnt._inkutonClinging = nil
                    end
                end)
            end

            if pOwner.ExecParticle then
                pOwner:ExecParticle("solve_inkuton_dog_impact_big", eEnt:GetPos(), Angle(0, 0, 0), nil)
            end
            self:EmitSound("geams/solve_jutsu/inkuton/solve_inkuton_geams_01_impact.wav")

            return true
        end
    end
    
    self:NextThink(CurTime())
    return true
end

function ENT:OnTakeDamage(dmginfo)
    self:SetHealth(self:Health() - dmginfo:GetDamage())
    
    if self:Health() <= 0 then
        self:Remove()
    end
end

function ENT:OnRemove()
end
