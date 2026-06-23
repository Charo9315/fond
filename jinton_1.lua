local IDENTIFIER = "jinton_1"

M_Fight.tConfig.tSkills[IDENTIFIER] = {
    sAnim = "",
    fMove = function(self, nLevel, fEnd)

        local oFirst = MOVE(self)
        oFirst:SetDelay(0)
        oFirst:SetSound(false)
        oFirst.OnStart = function(self)

            local iChakra = E_Value(IDENTIFIER, "chakra_level_"..nLevel, 50)
            local iPropulseVelocity = E_Value(IDENTIFIER, "propulse_velocity_"..nLevel, 1000)
            local iWaitBeforeExplosion = E_Value(IDENTIFIER, "wait_before_explosion_"..nLevel, 1)
            local iExplosionRadius = E_Value(IDENTIFIER, "explosion_radius_"..nLevel, 300)
            local tExplosionDmg = {[1] = 200, [2] = 270, [3] = 350}
            local iExplosionDamage = tExplosionDmg[nLevel] or 200
            local tHitDmg = {[1] = 150, [2] = 200, [3] = 250}
            local iDamage = tHitDmg[nLevel] or 150
            local sCollisionModel = E_Value(IDENTIFIER, "collision_model", "models/hunter/blocks/cube075x075x075.mdl")
            local iStun = E_Value(IDENTIFIER, "stun_"..nLevel, 2)

            local pOwner = self:GetOwner()
            if not pOwner:AddChakra(-iChakra) then return end

            pOwner:ExecSound("geams/solve_fast_mudra.wav")
            local hitEntities = {}

            self:Timer(pOwner:RestartAnimationGesture("nrp_ninjutsu_defend_dragonflamebombs_start")/3, function()
                pOwner:ExecSound("eljaunito/solve/miscellaneous/jutsu1.wav")
                pOwner:Dash(500, Vector(0, 0, 1))
                self:Timer(0.5, function()
                    pOwner:ExecAnim("m_attack_aerial_hand_punch")

                    local eCube = ents.Create("solve_naruto_jinton_cube")
                    eCube:SetModel(sCollisionModel)
                    eCube:SetPos(pOwner:EyePos() + pOwner:GetAimVector()*50)
                    eCube:SetAngles(pOwner:GetAngles())
                    eCube:SetOwner(pOwner)
                    eCube:Spawn()
                    eCube:Activate()
                    eCube:SetParent(pOwner)
                    eCube.iRadius = iExplosionRadius
                    eCube.iDamage = iExplosionDamage
                    eCube.pOwner = pOwner
                    eCube.iWaitBeforeExplode = iWaitBeforeExplosion
                    eCube.iStun = iStun

                    eCube.OnHit = function(eCube, eEntity)

                        if not IsValid(eEntity) then return end
                        if eEntity == pOwner then return end

                        if hitEntities[eEntity:EntIndex()] then return end
                        hitEntities[eEntity:EntIndex()] = true

                        local oDamageInfo = DamageInfo()
                        oDamageInfo:SetDamage(iDamage)
                        oDamageInfo:SetAttacker(pOwner)
                        oDamageInfo:SetInflictor(eCube)
                        eEntity:TakeDamageInfo(oDamageInfo)

                        EF_STUN(eEntity, iStun)

                        eEntity:JParticle("hit_jinton", Vector(0, 0, 50), nil, 2, true)

                    end

                    eCube.OnExplode = function(eCube)
                        EmitSound("solve_naruto_base/jutsu/jinton/3FWQ0KN.wav", eCube:GetPos())

                        for _, eEntity in ipairs(ents.FindInSphere(eCube:GetPos(), iExplosionRadius)) do
                            if not IsValid(eEntity) then continue end
                            if not eEntity:IsPlayer() then continue end
                            if eEntity == pOwner then continue end
                            if hitEntities[eEntity:EntIndex()] then continue end
                            hitEntities[eEntity:EntIndex()] = true

                            local oDamageInfo = DamageInfo()
                            oDamageInfo:SetDamage(iExplosionDamage)
                            oDamageInfo:SetAttacker(pOwner)
                            oDamageInfo:SetInflictor(eCube)
                            eEntity:TakeDamageInfo(oDamageInfo)

                            EF_STUN(eEntity, iStun)
                        end
                    end

                    eCube:JParticle("start_jinton_time", nil, nil, 2, true)

                    self:Timer(0.3, function()

                        pOwner:EmitSound("solve_naruto_base/jutsu/jinton/damage_cube_start.wav")
                        pOwner:EmitSound("solve_naruto_base/jutsu/jinton/RKjuCJ5.wav")

                        local vecEye = pOwner:EyePos()
                        local tTraceHit = util.TraceLine({
                            start = vecEye,
                            endpos = vecEye + pOwner:GetAimVector()*100000,
                            filter = {pOwner, "naruto_hitbox"},
                        })

                        local vecDirection = (tTraceHit.HitPos - vecEye):GetNormalized()

                        eCube:SetParent(NULL)
                        eCube:SetMoveType(MOVETYPE_NOCLIP)
                        eCube:SetSolid(SOLID_NONE)
                        eCube:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
                        eCube:SetPos(vecEye + vecDirection*100)
                        eCube:SetAngles(vecDirection:Angle())

                        timer.Simple(0.1, function()
                            if IsValid(eCube) then
                                eCube:SetMultiplicator(1)
                            end
                        end)

                        timer.Create("jinton_cube_move_"..eCube:EntIndex(), 0, 0, function()
                            if not IsValid(eCube) then
                                timer.Remove("jinton_cube_move_"..eCube:EntIndex())
                                return
                            end
                            local vecNewPos = eCube:GetPos() + vecDirection * iPropulseVelocity * FrameTime()
                            eCube:SetPos(vecNewPos)

                            for _, eEnt in ipairs(ents.FindInSphere(eCube:GetPos(), 64)) do
                                if IsValid(eEnt) and eEnt:IsPlayer() and eEnt ~= pOwner then
                                    if eEnt.AdminMode and eEnt:AdminMode() then continue end
                                    if eCube.OnHit then
                                        eCube:OnHit(eEnt)
                                    end
                                end
                            end
                        end)

                        self:Timer(5, function()
                            timer.Remove("jinton_cube_move_"..eCube:EntIndex())
                            if IsValid(eCube) then
                                eCube:Explode()
                                eCube:Remove()
                            end
                        end)

                    end)

                    fEnd()

                end)

            end)

        end

        return oFirst

    end
}
