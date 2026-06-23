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

            if self.WallhackDuration and self.WallhackDuration > 0 and IsValid(pOwner) then
                eTarget:SetNWFloat("Inkuton:Wallhack:" .. pOwner:SteamID64(), CurTime() + self.WallhackDuration)
                if eTarget.addBuff then
                    eTarget:addBuff("inkuton_draw", self.WallhackDuration)
                end
            end

            if self.OnHitTarget then
                self:OnHitTarget(eTarget)
            end

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
