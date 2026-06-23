AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SharedInitialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:SetMoveType(MOVETYPE_NOCLIP)
    self:SetSolid(SOLID_NONE)
    self:SetNoDraw(true)
    self:DrawShadow(false)

    self:SetIsAttached(false)
    self:SetIsJumping(false)
    self:SetIsOnGround(true)
    self:SetStamp(CurTime())
    self:SetDuration(self.Duration or 10)

    self.Speed = self.Speed or 75
    self.Damage = self.Damage or 10
end

function ENT:Setup(pPlayer, eTarget)
    if not IsValid(pPlayer) then return end

    self:SetOwner(pPlayer)
    self:SetPos(pPlayer:GetPos() + pPlayer:GetForward() * 50)
    self:SetAngles(pPlayer:GetAngles())

    if IsValid(eTarget) then
        self:SetTarget(eTarget)
    end
end

function ENT:Think()
    local pOwner = self:GetOwner()
    local eTarget = self:GetTarget()

    if self:GetIsAttached() then
        if IsValid(eTarget) then
            self:SetPos(eTarget:GetPos())
        end
        self:NextThink(CurTime())
        return true
    end

    local vecPos = self:GetPos()
    local vecDir
    local flSpeed = self.Speed or 75

    if IsValid(eTarget) then
        local vecTargetPos = eTarget:GetPos() + Vector(0, 0, 40)
        vecDir = (vecTargetPos - vecPos):GetNormalized()
        local flDist = vecPos:Distance(vecTargetPos)

        if flDist < 50 then
            self:SetIsAttached(true)
            self:SetNWString("MonkeyAnim", "customman_attack_ssp_brushscroll_ride_loop_monkey.001")

            if not eTarget._inkutonClinging then
                eTarget._inkutonClinging = true

                local oldRunSpeed = eTarget:GetRunSpeed()
                local oldWalkSpeed = eTarget:GetWalkSpeed()
                eTarget:SetRunSpeed(20)
                eTarget:SetWalkSpeed(20)

                local iSilenceRoot = EF_SILENCE_AND_ROOT(eTarget)

                timer.Create("inkuton_speed_"..eTarget:EntIndex(), 0.1, 40, function()
                    if not IsValid(eTarget) then
                        timer.Remove("inkuton_speed_"..eTarget:EntIndex())
                        return
                    end
                    eTarget:SetRunSpeed(20)
                    eTarget:SetWalkSpeed(20)
                end)

                if SERVER then
                    net.Start("inkuton_singe_particle")
                    net.WriteEntity(eTarget)
                    net.WriteFloat(4)
                    net.Broadcast()
                end

                for tickIdx = 1, 3 do
                    timer.Simple(tickIdx, function()
                        if not IsValid(eTarget) then return end
                        if not IsValid(pOwner) then return end
                        local dmg = DamageInfo()
                        dmg:SetAttacker(pOwner)
                        dmg:SetInflictor(IsValid(self) and self or pOwner)
                        dmg:SetDamage(10)
                        dmg:SetDamageType(DMG_GENERIC)
                        eTarget:TakeDamageInfo(dmg)
                        eTarget:EmitSound("geams/solve_jutsu/inkuton/solve_inkuton_geams_03_monkey.wav")
                    end)
                end

                timer.Simple(4, function()
                    timer.Remove("inkuton_speed_"..eTarget:EntIndex())
                    if IsValid(iSilenceRoot) then
                        iSilenceRoot:Destroy()
                    end
                    if IsValid(eTarget) then
                        eTarget._inkutonClinging = nil
                        eTarget:SetRunSpeed(oldRunSpeed)
                        eTarget:SetWalkSpeed(oldWalkSpeed)
                    end
                end)
            end

            if pOwner.ExecParticle then
                pOwner:ExecParticle("solve_inkuton_dog_impact_big", eTarget:GetPos(), Angle(0, 0, 0), nil)
            end
            self:EmitSound("geams/solve_jutsu/inkuton/solve_inkuton_geams_01_impact.wav")

            return
        end
    else
        vecDir = self:GetAngles():Forward()
    end

    if vecDir then
        local flActualSpeed = math.max(flSpeed, 500)
        local vecNewPos = vecPos + vecDir * flActualSpeed * FrameTime()
        self:SetPos(vecNewPos)
        self:SetAngles(vecDir:Angle())
    end

    self:NextThink(CurTime())
    return true
end

function ENT:OnRemove()
    if self.info then
        self.info:SetParent(nil)
        SafeRemoveEntityDelayed(self.info, 1)
    end
    self:EmitSound("npc/antlion_grub/squashed.wav")
end
