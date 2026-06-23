local IDENTIFIER = "jinton_5"

M_Fight.tConfig.tSkills[IDENTIFIER] = {
    sAnim = "",
    fMove = function(self, nLevel, fEnd)

        local oFirst = MOVE(self)
        oFirst:SetDelay(0)
        oFirst:SetSound(false)
        oFirst.OnStart = function(self)

            local iChakra = E_Value(IDENTIFIER, "chakra_level_"..nLevel, 450)
            local iVelocityUp = E_Value(IDENTIFIER, "velocity_up_"..nLevel, 1000)
            local iFlightMaxTime = E_Value(IDENTIFIER, "flight_max_time_"..nLevel, 10)
            local iLaserTime = E_Value(IDENTIFIER, "laser_time_"..nLevel, 5)
            local tLaserDmg5 = {[1] = 50, [2] = 70, [3] = 100}
            local iLaserDamage = tLaserDmg5[nLevel] or 300
            local iLaserHull = E_Value(IDENTIFIER, "laser_hull_"..nLevel, 30)
            local iLaserDistance = E_Value(IDENTIFIER, "laser_distance_"..nLevel, 2000)
            local iLaserTick = E_Value(IDENTIFIER, "laser_tick_"..nLevel, 1)
            local iFlightSpeed = E_Value(IDENTIFIER, "flight_speed_"..nLevel, 100)
            local iLaserSize = E_Value(IDENTIFIER, "laser_size_"..nLevel, 0.2)

            local iLaserPlayerSpeed = E_Value(IDENTIFIER, "laser_player_speed_"..nLevel, 5)

            local pOwner = self:GetOwner()

            local sHookId = "Solve.Naruto:Jinton:Jiton5:"..pOwner:EntIndex()

            local iSilence = nil
            pOwner:SetCustomCooldown("Éclair blanc", Color(255, 255, 255), iFlightMaxTime)
            ParticleEffectAttach("solve_jinton_aura", PATTACH_ABSORIGIN_FOLLOW, pOwner, 0)

            hook.Add("Solve.Naruto:PreventStun", "Solve.Naruto.Skills.Jinton:PreventStun:" .. pOwner:SteamID64(), function(pPlayer)
                if pPlayer ~= pOwner then return end
                return true
            end)

            hook.Add("StartCommand", sHookId, function(pPlayer, tCmd)

                local iSpeed = pPlayer:GetNetworkVar("Jiton5:Flight:Speed")
                if not iSpeed then return end
                local iMoveX, iMoveY = 0, 0
                tCmd:ClearMovement()

                if pPlayer:KeyDown(IN_FORWARD) then
                    iMoveX = 1
                end

                if pPlayer:KeyDown(IN_BACK) then
                    iMoveX = -1
                end

                if pPlayer:KeyDown(IN_MOVELEFT) then
                    iMoveY = -1
                end

                if pPlayer:KeyDown(IN_MOVERIGHT) then
                    iMoveY = 1
                end

                local angEye = pPlayer:EyeAngles()
                local vecNew = angEye:Forward()*iSpeed*iMoveX + angEye:Right()*iSpeed*iMoveY

                if pPlayer:KeyDown(IN_JUMP) then
                    vecNew = vecNew + Vector(0, 0, iSpeed)
                end

                if pPlayer:KeyDown(IN_DUCK) then
                    vecNew = vecNew + Vector(0, 0, -iSpeed)
                end

                if not pPlayer:KeyDown(IN_SPEED) then
                    vecNew = vecNew * 0.8
                end

                if pPlayer:KeyDown(IN_WALK) then
                    vecNew = vecNew * 0.5
                end

                pPlayer.vecJiton5Velocity = LerpVector(FrameTime()*5, pPlayer.vecJiton5Velocity or vecNew, vecNew)
                pPlayer:SetVelocity(pPlayer.vecJiton5Velocity - (pPlayer:GetVelocity()*0.2))
            end)


            local function fnCleanup()
                hook.Remove("PlayerButtonDown", sHookId)
                hook.Remove("Solve.Naruto:PreventStun", "Solve.Naruto.Skills.Jinton:PreventStun:" .. pOwner:SteamID64())
                hook.Remove("StartCommand", sHookId)
                pOwner:RemoveTimer("Jiton5:Flight")
                pOwner:RemoveTimer("Jiton5:Flight:Laser:Think")
                pOwner:SetNetworkVar("Jiton5:Flight:Speed", false)
                pOwner:SetNetworkVar("Jiton5:Flight:InLaser", false)
                pOwner:SetGravity(1)
                pOwner:RemoveCustomCooldown("Rayo Blanco")

                pOwner:StopJParticle()
                if pOwner.StopExecParticle then pOwner:StopExecParticle("solve_jinton_aura") end

                net.Start("Solve.Naruto:Jinton:Jiton5:Stop")
                    net.WritePlayer(pOwner)
                net.SendPVS(pOwner:GetPos())

                if IsValid(iSilence) then iSilence:Destroy() end
                if IsValid(pOwner.eLaser) then
                    SafeRemoveEntity(pOwner.eLaser)
                    pOwner.eLaser = nil
                end
                pOwner:StopSound("solve_naruto_base/jutsu/jinton/6fgCFjo.wav")
            end

            hook.Add("PlayerButtonDown", sHookId, function(pPlayer, iButton)
                if not IsFirstTimePredicted() then return end
                if pPlayer != pOwner then return end
                if not pPlayer:PressedCustomBind("jinton_5", "laser", iButton) then return end

                if not pOwner:GetNetworkVar("Jiton5:Flight:InLaser", false) then

                    local iCurrentLaserTime = iLaserTime
                    if iCurrentLaserTime <= 0 then return end

                    local vecEye = pOwner:EyePos() + Vector(0, 0, 30)

                    pOwner.eLaser = ents.Create("solve_naruto_jinton_laser")
                    pOwner.eLaser:SetPos(vecEye + pOwner:GetAimVector()*100)
                    pOwner.eLaser:SetAngles(pOwner:EyeAngles())
                    pOwner.eLaser:SetParent(pOwner)
                    pOwner.eLaser:Spawn()
                    pOwner.eLaser:Activate()
                    pOwner.eLaser:SetOwnerPlayer(pOwner)
                    pOwner.eLaser:SetDistance(iLaserSize)
                    pOwner.eLaser:SetLaserDistance(iLaserDistance)
                    pOwner.eLaser:SetLaserHull(iLaserHull)
                    pOwner.eLaser:SetDamage(iLaserDamage)

                    self:Timer(0.0, function()

                        pOwner:ExecSound("solve_naruto_base/jutsu/jinton/laser_start_rayon.wav")

                        pOwner:EmitSound("solve_naruto_base/jutsu/jinton/RKjuCJ5.wav")
                        self:Timer(0.5, function()
                            pOwner:EmitSound("solve_naruto_base/jutsu/jinton/6fgCFjo.wav")
                        end)

                        net.Start("Solve.Naruto:Jinton:Jiton5:Start")
                            net.WritePlayer(pOwner)
                            net.WriteUInt(iCurrentLaserTime, 16)
                            net.WriteUInt(iLaserDistance, 16)
                        net.SendPVS(vecEye)

                        iSilence = EF_SILENCE_CAN_USE_SECONDARY(pOwner)
                        pOwner:SetNetworkVar("Jiton5:Flight:InLaser", true)
                        pOwner:SetNetworkVar("Jiton5:Flight:Speed", iLaserPlayerSpeed)
                        pOwner:CreateTimer("Jiton5:Flight:Laser:Think", iLaserTick, 0, function()
                            if not IsValid(pOwner) then return end

                            iCurrentLaserTime = iCurrentLaserTime - iLaserTick

                            if iCurrentLaserTime <= 0 then
                                if IsValid(iSilence) then iSilence:Destroy() end
                                pOwner:RemoveTimer("Jiton5:Flight:Laser:Think")
                                pOwner:SetNetworkVar("Jiton5:Flight:InLaser", false)
                                pOwner:SetNetworkVar("Jiton5:Flight:Speed", iFlightSpeed)
                                pOwner:StopSound("solve_naruto_base/jutsu/jinton/6fgCFjo.wav")
                                if IsValid(pOwner.eLaser) then
                                    SafeRemoveEntity(pOwner.eLaser)
                                    pOwner.eLaser = nil
                                end

                                net.Start("Solve.Naruto:Jinton:Jiton5:Stop")
                                    net.WritePlayer(pOwner)
                                net.SendPVS(pOwner:GetPos())
                                return
                            end

                        end)
                    end)
                else

                    if IsValid(pOwner.eLaser) then
                        pOwner:SetGravity(0.0001)
                        if IsValid(iSilence) then iSilence:Destroy() end
                        pOwner:RemoveTimer("Jiton5:Flight:Laser:Think")
                        pOwner:SetNetworkVar("Jiton5:Flight:InLaser", false)
                        pOwner:SetNetworkVar("Jiton5:Flight:Speed", iFlightSpeed)
                        pOwner:StopSound("solve_naruto_base/jutsu/jinton/6fgCFjo.wav")
                        SafeRemoveEntity(pOwner.eLaser)
                        pOwner.eLaser = nil
                        net.Start("Solve.Naruto:Jinton:Jiton5:Stop")
                            net.WritePlayer(pOwner)
                        net.SendPVS(pOwner:GetPos())
                    end
                end
            end)

            if not pOwner:AddChakra(-iChakra) then return end
            pOwner:ExecSound("geams/solve_fast_mudra.wav")

            self:Timer(pOwner:RestartAnimationGesture("nrp_ninjutsu_defend_dragonflamebombs_start")/3, function()
                pOwner:ExecSound("eljaunito/solve/miscellaneous/jutsu1.wav")

                pOwner:EmitSound("solve_naruto_base/jutsu/jinton/easdmyE.wav")
                pOwner:SetVelocity(Vector(0, 0, iVelocityUp))
                self:Timer(1, function()

                    pOwner:SetNetworkVar("Jiton5:Flight:Active", true)
                    pOwner:SetNetworkVar("Jiton5:Flight:Speed", iFlightSpeed)
                    pOwner:SetGravity(0.0001)
                    pOwner:CreateTimer("Jiton5:Flight", iFlightMaxTime, 1, function()

                        fnCleanup()
                    end)

                end)

                fEnd()
            end)

        end

        return oFirst

    end
}

if SERVER then

    util.AddNetworkString("Solve.Naruto:Jinton:Jiton5:Start")
    util.AddNetworkString("Solve.Naruto:Jinton:Jiton5:Stop")
else

    Solve.Naruto.Skills.Jiton5HitParticles = Solve.Naruto.Skills.Jiton5HitParticles or {}

    net.Receive("Solve.Naruto:Jinton:Jiton5:Start", function()

        local pPlayer = net.ReadPlayer()
        if not IsValid(pPlayer) then return end

        local iTime = net.ReadUInt(16)
        local iDistance = net.ReadUInt(16)

        Solve.Naruto.Skills.Jiton5HitParticles[pPlayer] = {
            iEndTime = CurTime() + iTime,
            iDistance = iDistance,
        }

    end)

    net.Receive("Solve.Naruto:Jinton:Jiton5:Stop", function()
        local pPlayer = net.ReadPlayer()
        if not IsValid(pPlayer) then return end

        if Solve.Naruto.Skills.Jiton5HitParticles[pPlayer] and IsValid(Solve.Naruto.Skills.Jiton5HitParticles[pPlayer].eParticle) then
            Solve.Naruto.Skills.Jiton5HitParticles[pPlayer].eParticle:Remove()
        end

        Solve.Naruto.Skills.Jiton5HitParticles[pPlayer] = nil
    end)

    hook.Add("PostDrawTranslucentRenderables", "Solve.Naruto:Jinton:Jiton5", function()
        for pPlayer, tData in pairs(Solve.Naruto.Skills.Jiton5HitParticles) do
            if not IsValid(pPlayer) then
                Solve.Naruto.Skills.Jiton5HitParticles[pPlayer] = nil
                continue
            end

            if CurTime() > tData.iEndTime then
                if IsValid(tData.eParticle) then
                    tData.eParticle:Remove()
                end
                Solve.Naruto.Skills.Jiton5HitParticles[pPlayer] = nil
                continue
            end

            local vecEye = pPlayer:EyePos()
            local tTrace = util.TraceLine({
                start = vecEye,
                endpos = vecEye + pPlayer:GetAimVector()*tData.iDistance,
                mask = MASK_NPCWORLDSTATIC
            })

            if tTrace.Hit then
                if not IsValid(tData.eParticle) then
                    tData.eParticle = ClientsideModel("models/hunter/blocks/cube025x025x025.mdl")
                    tData.eParticle:SetRenderMode(RENDERMODE_TRANSCOLOR)
                    tData.eParticle:SetColor(Color(0, 0, 0, 0))

                    ParticleEffectAttach("impact_world_geams", PATTACH_ABSORIGIN_FOLLOW, tData.eParticle, 0)
                end

                tData.eParticle:SetPos(tTrace.HitPos)
                tData.eParticle:SetAngles(Angle(0, 0, 0))

            else
                if IsValid(tData.eParticle) then
                    tData.eParticle:Remove()
                end
            end
        end
    end)
end
