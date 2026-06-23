local tStats = {
    [1] = {
        ["iDamage"] = 200,
        ["iChakra"] = 700,
        ["iRadiusZone"] = 700,
        ["iStun"] = 1.5,
    },
    [2] = {
        ["iDamage"] = 400,
        ["iChakra"] = 600,
        ["iRadiusZone"] = 700,
        ["iStun"] = 2,
    },
    [3] = {
        ["iDamage"] = 600,
        ["iChakra"] = 500,
        ["iRadiusZone"] = 700,
        ["iStun"] = 2.5,

    },
}
M_Fight.tConfig.tSkills["raiton_skills_11"] = {
    sAnim = "",
    fMove = function(self, nLevel, fEnd)

        local oFirst = MOVE(self)
        oFirst:SetDelay(0)
        oFirst:SetSound(false)
        oFirst.OnStart = function(self)

            local iChakra = E_Value("raiton_divine", "chakra_level_"..nLevel, tStats[nLevel].iChakra)
            local iDamage = E_Value("raiton_divine", "dmg_level_"..nLevel, tStats[nLevel].iDamage)
            local iRadiusZone = E_Value("raiton_divine", "radius_zone_level_"..nLevel, tStats[nLevel].iRadiusZone)
            local iStun = E_Value("raiton_divine", "stun_level_"..nLevel, tStats[nLevel].iStun)
            local iMultiplierDamage = E_Value("raiton_divine", "multiplier_damage_level_"..nLevel, 1)
            local iStunMultiplier = E_Value("raiton_divine", "stun_multiplier_level_"..nLevel, 1)
            
            local iRange = E_Value("raiton_divine", "range_level_"..nLevel, 5000)
            local iRadiusMultiplier = E_Value("raiton_divine", "radius_multiplier_level_"..nLevel, 1)

            local pOwner = self:GetOwner()
            local iSilenceAndRoot = nil
            if not pOwner:AddChakra(-iChakra) then return end
            if pOwner:OnGround() then
                iSilenceAndRoot = EF_SILENCE_AND_ROOT(pOwner)
            else
                local groundCheckHookName = "raiton_kirin:GroundCheck:" .. pOwner:EntIndex()
                hook.Add("Think", groundCheckHookName, function()
                    if not IsValid(pOwner) or not pOwner:Alive() then
                        if IsValid(iSilenceAndRoot) then iSilenceAndRoot:Destroy() end
                        hook.Remove("Think", groundCheckHookName)
                        return
                    end

                    if pOwner:OnGround() then
                        if not iSilenceAndRoot then
                            iSilenceAndRoot = EF_SILENCE_AND_ROOT(pOwner)
                        end
                        hook.Remove("Think", groundCheckHookName)
                    end
                end)
            end

            local iLeftHand = pOwner:LookupBone("ValveBiped.Bip01_L_Hand")
            if not iLeftHand then return end
            pOwner:JParticle("solve_raiton_punch_hand_big", nil, nil, 0, true, iLeftHand)

            ParticleEffectAttach("solve_raiton_chakramode_start_add21", PATTACH_ABSORIGIN_FOLLOW, pOwner, 0)
            ParticleEffectAttach("solve_raiton_chakramode_start_add22", PATTACH_ABSORIGIN_FOLLOW, pOwner, 0)

            pOwner:ExecSound("geams/solve_fast_mudra.wav")
            pOwner:RestartAnimationGesture("nrp_ninjutsu_trow_kirin", nil, GESTURE_SLOT_VCD, 3)

            net.Start("Solve.Naruto.ScreenDarken.Start")
            net.Send(pOwner)
            pOwner:EmitSound("ambient/atmosphere/thunder"..math.random(1,4)..".wav", 110, 90)

            -- Auto-fire after a short delay (single press, no hold needed)
            timer.Simple(0.5, function()
                if not IsValid(pOwner) or not pOwner:Alive() then
                    hook.Remove("Think", "raiton_kirin:GroundCheck:" .. pOwner:EntIndex())
                    if IsValid(iSilenceAndRoot) then iSilenceAndRoot:Destroy() end
                    return
                end

                net.Start("Solve.Naruto.ScreenDarken.Stop")
                net.Send(pOwner)
                pOwner:EmitSound("natures/raiton/assaut_hit.wav", 75, 100, 0.5)

                hook.Remove("Think", "raiton_kirin:GroundCheck:" .. pOwner:EntIndex())
                if IsValid(iSilenceAndRoot) then iSilenceAndRoot:Destroy() end

                local vecEye = pOwner:EyePos()

                local tTrace = util.TraceLine({
                    start = vecEye,
                    endpos = vecEye + pOwner:GetAimVector()*iRange,
                    filter = {pOwner, "naruto_hitbox", "player"},
                })

                pOwner:StopJParticle("solve_raiton_punch_hand_big")

                local iLeftHand = pOwner:LookupBone("ValveBiped.Bip01_L_Hand")
                if not iLeftHand then return end
                pOwner:JParticle("solve_raiton_kirin_trail", nil, nil, 0.5, true, iLeftHand)

                local vecSpawnPoint = tTrace.HitPos + Vector(0, 0, 10)

                -- Use prop_dynamic instead of prop_physics to avoid issues
                -- when prop_physics is blocked on the server
                local eParticleBox = ents.Create("prop_dynamic")
                if not IsValid(eParticleBox) then
                    -- Fallback: use a simple entity if prop_dynamic also fails
                    eParticleBox = ents.Create("info_target")
                end
                if IsValid(eParticleBox) then
                    eParticleBox:SetModel("models/hunter/blocks/cube1x1x1.mdl")
                    eParticleBox:SetPos(vecSpawnPoint)
                    eParticleBox:Spawn()
                    eParticleBox:Activate()
                    if eParticleBox.DropToFloor then
                        eParticleBox:DropToFloor()
                    end
                    eParticleBox:SetMoveType(MOVETYPE_NONE)
                    eParticleBox:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
                    eParticleBox:SetRenderMode(RENDERMODE_TRANSCOLOR)
                    eParticleBox:SetColor(Color(0, 0, 0, 0))
                end

                local tTraceUp = util.TraceLine({
                    start = vecSpawnPoint,
                    endpos = vecSpawnPoint + Vector(0, 0, 900),
                    mask = MASK_NPCWORLDSTATIC,
                })

                local eDragon = ents.Create("solve_naruto_hyoton_dragon")
                if IsValid(eDragon) then
                    eDragon:SetModel("models/solve/billy/kirinsolve.mdl")
                    eDragon:SetPos(tTraceUp.HitPos)
                    eDragon:Spawn()
                    eDragon:Activate()
                    eDragon:DropToFloor()
                    eDragon:SetMoveType(MOVETYPE_NONE)
                    if IsValid(eParticleBox) then
                        eDragon:SetParent(eParticleBox)
                    end
                    eDragon:SetModelScale(4, 0.00001)

                    ParticleEffectAttach("solve_raiton_kirin_trail_animal", PATTACH_ABSORIGIN_FOLLOW, eDragon, 0)
                end

                if IsValid(eParticleBox) then
                    eParticleBox:EmitSound("geams/solve_jutsu/solve_kirin_geams.wav")
                end
                ParticleEffect("solve_kirin_cloud", tTraceUp.HitPos, Angle(0, 0, 0), eParticleBox)


                self:Timer(0, function()
                    if not IsValid(eDragon) then return end

                    eDragon:ResetSequence(eDragon:LookupSequence("sk_wep_eff_kirin_01_anim"))

                    self:Timer(1.8, function()
                        if not IsValid(eParticleBox) then return end

                        eParticleBox:EmitSound("eljaunito/solve/jutsu/raiton/raiton1.wav")
                        ParticleEffectAttach("solve_raiton_kirin_bigimpact_floor", 4, eParticleBox, 4)

                        util.ScreenShake(vecSpawnPoint, 30, 30, 4, 3500, true)

                        for _, eEntity in ipairs(ents.FindInSphere(vecSpawnPoint, iRadiusZone * iRadiusMultiplier)) do
                            if eEntity == pOwner then continue end
                            if not eEntity:IsPlayer() then continue end
                            if eEntity:AdminMode() then continue end

                            eEntity:TakeDamage(iDamage * iMultiplierDamage, pOwner, self.eWeapon)
                            eEntity:ExecSound("eljaunito/solve/jutsu/raiton/raiton1.wav")
                            eEntity:RestartAnimationGesture("nrp_beaten_burn_type01", true, GESTURE_SLOT_VCD)
                            EF_STUN(eEntity, iStun * iStunMultiplier)

                            net.Start("Solve.Naruto.Skills.ImpactFX")
                            net.WriteEntity(pOwner)
                            net.WriteEntity(eEntity)
                            net.Send(eEntity)
                        end

                        self:Timer(0.25, function()
                            SafeRemoveEntity(eDragon)
                        end)

                        self:Timer(5, function()
                            SafeRemoveEntity(eParticleBox)
                        end)
                    end)
                end)

                fEnd()
            end)

        end

        return oFirst
    end,
}
