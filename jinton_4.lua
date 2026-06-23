local IDENTIFIER = "jinton_4"

M_Fight.tConfig.tSkills[IDENTIFIER] = {
    sAnim = "",
    fMove = function(self, nLevel, fEnd)

        local oFirst = MOVE(self)
        oFirst:SetDelay(0)
        oFirst:SetSound(false)
        oFirst.OnStart = function(self)

            local iChakra = E_Value(IDENTIFIER, "chakra_level_"..nLevel, 50)
            local iProjectionVelocity = E_Value(IDENTIFIER, "projection_velocity_"..nLevel, 1000)
            local tDmgHit = {[1] = 50, [2] = 70, [3] = 100}
            local iDamageHit = tDmgHit[nLevel] or 250
            local iTickHit = E_Value(IDENTIFIER, "tick_hit_"..nLevel, 0.01)
            local tTickDmg = {[1] = 5, [2] = 10, [3] = 15}
            local iTickHitDamage = tTickDmg[nLevel] or 3
            local iTickHitCount = E_Value(IDENTIFIER, "tick_hit_count_"..nLevel, 100)
            local sCollisionModel = E_Value(IDENTIFIER, "collision_model_"..nLevel, "models/hunter/blocks/cube1x150x1.mdl")

            local pOwner = self:GetOwner()
            if not pOwner:AddChakra(-iChakra) then return end

            pOwner:ExecSound("geams/solve_fast_mudra.wav")

            self:Timer(pOwner:RestartAnimationGesture("nrp_ninjutsu_defend_dragonflamebombs_start")/3, function()
                pOwner:ExecSound("eljaunito/solve/miscellaneous/jutsu1.wav")
                self:Timer(0.25, function()
                    pOwner:ExecAnim("m_attack_aerial_ssp_nrt_kunai_cmb_06")
                end)
                self:Timer(0.2, function()

                    local eCube = ents.Create("solve_naruto_jinton_cube")
                    timer.Simple(0.01, function()
                        if IsValid(eCube) then
                            eCube:SetModel(sCollisionModel)
                        end
                    end)
                    eCube:SetPos(pOwner:EyePos() + pOwner:GetAimVector()*50 + pOwner:GetUp()*30)
                    eCube:SetAngles(pOwner:GetAngles())
                    eCube:SetParent(pOwner)
                    eCube:Spawn()
                    eCube:Activate()
                    eCube.do_not_explode = true
                    eCube.pOwner = pOwner
                    eCube.OnHitWorld = function(eCube)
                        SafeRemoveEntity(eCube)
                    end
                    eCube.OnHit = function(eCube, pVictim)

                        if pVictim == pOwner then return end
                        if pVictim:AdminMode() then return end

                        pOwner:ExecSound("solve_naruto_base/jutsu/jinton/cube_cage_on_hit.wav")

                        local oDamageInfo = DamageInfo()
                            oDamageInfo:SetDamage(iDamageHit)
                            oDamageInfo:SetAttacker(pOwner)
                            oDamageInfo:SetInflictor(eCube)
                        pVictim:TakeDamageInfo(oDamageInfo)

                        eCube:SetOverideModel("models/solve/billy/cubeonoki2.mdl")
                        eCube:SetPos(pVictim:GetPos() + Vector(0, 0, 50))
                        eCube:SetParent(pVictim)
                        pVictim:GodEnable()
                        local jintonStun = EF_STUN(pVictim, iTickHitCount*iTickHit, true, true)
                        eCube:GetPhysicsObject():EnableMotion(false)
                        eCube:SetMultiplicator(2.25)
                        eCube.OnHitWorld = function() end
                        eCube.OnHit = function() end

                        pVictim:JParticle("solve_geams_01_cube", Vector(0, 0, 40), nil, iTickHitCount*iTickHit, true)
                        self:Timer(0.5, function()
                            pVictim:JParticle("blood_geams_copy", Vector(0, 0, 40), nil, iTickHitCount*iTickHit - 0.5, true)
                        end)
                        pOwner:CreateTimer("jinton_tick_hit", iTickHit, iTickHitCount, function()
                            if not IsValid(pVictim) then return end
                            if not IsValid(eCube) then return end

                            local iMaxHealth = pVictim:GetMaxHealth()
                            local iNewHealth = math.Clamp(pVictim:Health() - iTickHitDamage, 0, iMaxHealth)
                            pVictim:SetHealth(iNewHealth)
                            Solve.Naruto:HitMarker(pOwner, iTickHitDamage, 2, pVictim)
                            if pVictim:Health() <= 0 then
                                if IsValid(pVictim) then
                                    if IsValid(jintonStun) then
                                        jintonStun:Destroy()
                                    end
                                    pVictim:StopJParticle("blood_geams_copy")
                                    pVictim:GodDisable()
                                end
                                pVictim:TakeDamage(1, pOwner, nil)
                                if IsValid(eCube) then
                                    eCube:SetMultiplicator(0)
                                    SafeRemoveEntity(eCube)
                                end
                                pOwner:RemoveTimer("jinton_tick_hit")
                                timer.Remove("jinton_reset" .. pOwner:SteamID64())
                                return
                            end
                            EmitSound("geams/solve_jutsu/hyoton/solve_hyoton_mirror_hit.wav", pVictim:GetPos(), nil, CHAN_STATIC)
                        end)

                        timer.Create("jinton_reset".. pOwner:SteamID64(), iTickHit*iTickHitCount, 1, function()
                            pOwner:RemoveTimer("jinton_tick_hit")
                            if IsValid(pVictim) then
                                if IsValid(jintonStun) then
                                    jintonStun:Destroy()
                                end
                                pVictim:GodDisable()
                                pVictim:StopJParticle("blood_geams_copy")
                                pVictim:StopAnimationGesture(GESTURE_SLOT_VCD)
                            end
                            if IsValid(eCube) then
                                eCube:SetMultiplicator(0)
                                SafeRemoveEntity(eCube)
                            end
                        end)

                    end

                    eCube:JParticle("start_jinton_time", nil, nil, 2, true)

                    if not IsValid(eCube) then return end

                    pOwner:EmitSound("solve_naruto_base/jutsu/jinton/RKjuCJ5.wav")
                    pOwner:ExecSound("solve_naruto_base/jutsu/jinton/cage_cube_start.wav")

                    local vecEye = pOwner:EyePos()
                    local tTraceHit = util.TraceLine({
                        start = vecEye,
                        endpos = vecEye + pOwner:GetAimVector()*1000,
                        filter = {pOwner, "naruto_hitbox"},
                    })

                    local vecDirection = pOwner:GetAimVector()

                    if tTraceHit.Hit and tTraceHit.HitPos:Distance(vecEye) < 2000 then
                        vecDirection = (tTraceHit.HitPos - vecEye):GetNormalized()
                    end

                    eCube:SetParent(NULL)
                    eCube:SetMoveType(MOVETYPE_NOCLIP)
                    eCube:SetSolid(SOLID_NONE)

                    local vecNewPos = vecEye + vecDirection*10 + pOwner:GetUp()
                    if math.abs(vecNewPos.x) > 16000 or math.abs(vecNewPos.y) > 16000 or math.abs(vecNewPos.z) > 16000 then
                        vecNewPos = pOwner:GetPos() + pOwner:GetForward()*200 + Vector(0, 0, 100)
                    end
                    if not IsValid(eCube) then return end
                    eCube:SetPos(vecNewPos)
                    if not IsValid(eCube) then return end
                    eCube:SetAngles(vecDirection:Angle())

                    timer.Create("jinton4_cube_move_"..eCube:EntIndex(), 0, 0, function()
                        if not IsValid(eCube) then
                            timer.Remove("jinton4_cube_move_"..eCube:EntIndex())
                            return
                        end
                        local vecCurPos = eCube:GetPos() + vecDirection * iProjectionVelocity * FrameTime()
                        eCube:SetPos(vecCurPos)

                        for _, eEnt in ipairs(ents.FindInSphere(vecCurPos, 64)) do
                            if IsValid(eEnt) and eEnt:IsPlayer() and eEnt ~= pOwner then
                                if eEnt.AdminMode and eEnt:AdminMode() then continue end
                                timer.Remove("jinton4_cube_move_"..eCube:EntIndex())
                                if eCube.OnHit then
                                    eCube:OnHit(eEnt)
                                end
                                return
                            end
                        end
                    end)

                    timer.Simple(5, function()
                        timer.Remove("jinton4_cube_move_"..(IsValid(eCube) and eCube:EntIndex() or 0))
                        if IsValid(eCube) then
                            SafeRemoveEntity(eCube)
                        end
                    end)

                    fEnd()

                end)

            end)

        end

        return oFirst

    end
}
