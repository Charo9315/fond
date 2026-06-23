-- hola
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
            
            local dmginfo = DamageInfo()
            dmginfo:SetDamage(self.Damage or 1000)
            dmginfo:SetAttacker(pOwner)
            dmginfo:SetInflictor(self)
            dmginfo:SetDamageType(DMG_SLASH)
            eEnt:TakeDamageInfo(dmginfo)
            
            -- Aplicar stun avec EF_STUN
            if self.StunDuration and self.StunDuration > 0 then
                EF_STUN(eEnt, self.StunDuration)
            end
            
            -- Aplicar wallhack
            if self.WallhackDuration and self.WallhackDuration > 0 then
                eEnt:SetNWFloat("Inkuton:Wallhack:" .. pOwner:SteamID64(), CurTime() + self.WallhackDuration)
                if eEnt.addBuff then
                    eEnt:addBuff("inkuton_draw", self.WallhackDuration)
                end
            end
            
            -- Efecto de impacto
            if pOwner.ExecParticle then
                pOwner:ExecParticle("solve_inkuton_dog_impact_big", eEnt:GetPos(), Angle(0, 0, 0), nil)
            end
            self:EmitSound("geams/solve_jutsu/inkuton/solve_inkuton_geams_01_impact.wav")
            
            self:SetHasAttacked(true)
            SafeRemoveEntityDelayed(self, 0.5)
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
