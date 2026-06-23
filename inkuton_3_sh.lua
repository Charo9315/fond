local IDENTIFIER = "inkuton_3"

if SERVER then
    util.AddNetworkString("inkuton_singe_particle")
end

M_Fight.tConfig.tSkills[IDENTIFIER] = {
    sAnim = "",
    fCheck = function(ply, nLevel)
        return true
    end,
    fMove = function(self, nLevel, fEnd)
        local oFirst = MOVE(self)
        oFirst:SetDelay(0)
        oFirst:SetSound(false)
        oFirst.OnStart = function(self)
            local iChakra = E_Value(IDENTIFIER, "chakra_level_"..nLevel, 50)
            local ply = self:GetOwner()
            ply:addBuff("inkuton")

            local iDuration = E_Value(IDENTIFIER, "duration_level_"..nLevel, 10)
            local iSpeed = E_Value(IDENTIFIER, "speed_level_"..nLevel, 250)
            local iWallhackDuration = E_Value(IDENTIFIER, "wallhack_duration_level_"..nLevel, 10)
            local iCastTime = E_Value(IDENTIFIER, "cast_time_level_"..nLevel, 0.1)
            if not ply:AddChakra(-iChakra) then return end

            local scrollDelay = ply:RestartAnimationGesture("m_sai_attack_doubleslashinghorizontally") * 0.7

            local scroll = ents.Create("solve_naruto_inkuton_scroll_anim")
            scroll:SetOwner(ply)
            scroll:SetPos(ply:GetPos())
            scroll:SetConfig(2)
            scroll:Spawn()
            SafeRemoveEntityDelayed(scroll, scrollDelay)

            ply:ExecSound("geams/solve_jutsu/inkuton/solve_inkuton_geams_start_all.wav")
            ply:JParticle("solve_inkuton_start_hand", nil, nil, 1, true, ply:LookupBone("ValveBiped.Bip01_R_Hand"))

            self:Timer(ply:RestartAnimationGesture("m_sai_attack_doubleslashinghorizontally")*iCastTime, function()
                ply:ExecSound("eljaunito/solve/miscellaneous/jutsu1.wav")
                ply:ExecSound("geams/solve_jutsu/inkuton/solve_inkuton_geams_03_monkey.wav")

                local pos = ply:GetPos() + ply:GetForward() * 20
                local angles = (ply:GetAimVector() * Vector(1, 1, 0)):Angle()

                local vecEye = ply:EyePos()
                local vecAim = ply:GetAimVector()
                local pTarget = nil
                local fBestDist = math.huge
                for _, v in ipairs(ents.FindInSphere(vecEye, 2000)) do
                    if not IsValid(v) or not v:IsPlayer() then continue end
                    if v == ply then continue end
                    if not v:Alive() then continue end
                    if v.AdminMode and v:AdminMode() then continue end
                    local vecToTarget = (v:GetPos() - vecEye):GetNormalized()
                    if vecAim:Dot(vecToTarget) > 0.5 then
                        local fDist = v:GetPos():DistToSqr(vecEye)
                        if fDist < fBestDist then
                            fBestDist = fDist
                            pTarget = v
                        end
                    end
                end

                local tMonkeys = {}

                for i = 1, 3 do
                    timer.Simple((i-1) * 0.05, function()
                        local ent = ents.Create("solve_naruto_inkuton_monkey")
                        ent:SetPos(pos)
                        ent:SetOwner(ply)
                        ent:SetAngles(angles)
                        ent:Spawn()
                        ent:SetDuration(iDuration)
                        ent.Speed = iSpeed
                        ent.WallhackDuration = iWallhackDuration
                        ent._monkeyIndex = i

                        if IsValid(pTarget) then
                            ent:SetTarget(pTarget)
                        end

                        ent:SetAttachConfig(i)
                        tMonkeys[i] = ent

                        ent.OnHitTarget = function(monkey, target)
                            if not IsValid(target) then return end

                            if target._inkutonClinging then return end
                            target._inkutonClinging = true

                            target:addBuff("slow", { slow = 0.9, duration = 4 })

                            if SERVER then
                                net.Start("inkuton_singe_particle")
                                net.WriteEntity(target)
                                net.WriteFloat(4)
                                net.Broadcast()
                            end

                            local iTickDamage = 10
                            for tickIdx = 1, 3 do
                                timer.Simple(tickIdx, function()
                                    if not IsValid(target) then return end
                                    if not IsValid(ply) then return end
                                    local dmg = DamageInfo()
                                    dmg:SetAttacker(ply)
                                    dmg:SetInflictor(IsValid(tMonkeys[tickIdx]) and tMonkeys[tickIdx] or ply)
                                    dmg:SetDamage(iTickDamage)
                                    dmg:SetDamageType(DMG_GENERIC)
                                    target:TakeDamageInfo(dmg)
                                    target:EmitSound("geams/solve_jutsu/inkuton/solve_inkuton_geams_03_monkey.wav")
                                end)
                            end

                            timer.Simple(4, function()
                                if IsValid(target) then
                                    target._inkutonClinging = nil
                                    target:removeBuff("slow")
                                end
                                for _, mk in pairs(tMonkeys) do
                                    if IsValid(mk) then
                                        SafeRemoveEntity(mk)
                                    end
                                end
                            end)
                        end

                        SafeRemoveEntityDelayed(ent, 5)
                    end)
                end

                fEnd()
            end)
        end

        return oFirst
    end
}
