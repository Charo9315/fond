local IDENTIFIER = "inkuton_5"

M_Fight.tConfig.tSkills[IDENTIFIER] = {
    fCheck = function(ply, nLevel)

        return true
    end,
    sAnim = "",
    fMove = function(self, nLevel, fEnd)

        local oFirst = MOVE(self)
        oFirst:SetDelay(0)
        oFirst:SetSound(false)
        oFirst.OnStart = function(self)

            local iChakra = E_Value(IDENTIFIER, "chakra_level_"..nLevel, 50)

            local ply = self:GetOwner()
            if not ply:AddChakra(-iChakra) then return end
            ply:addBuff("inkuton")

            local iTime = 10

            local tWarriorDamage = {[1] = 250, [2] = 350, [3] = 450}
            local tStunDuration = {[1] = 1.5, [2] = 2, [3] = 3}
            local iDamage = tWarriorDamage[nLevel] or 250
            local iSpeed = E_Value(IDENTIFIER, "speed_level_"..nLevel, 750)
            local iStunDuration = E_Value(IDENTIFIER, "stun_duration_level_"..nLevel, tStunDuration[nLevel])

            local iWallhackDuration = E_Value(IDENTIFIER, "wallhack_duration_level_"..nLevel, 10)

            ply:ExecSound("geams/solve_jutsu/inkuton/solve_inkuton_geams_start_all.wav")

            ply:JParticle("solve_inkuton_start_hand", nil, nil, 1, true, ply:LookupBone("ValveBiped.Bip01_R_Hand"))

            local scrollDelay = ply:RestartAnimationGesture("m_ni_sht_attack_tnt_scroll_cmb_01") * 0.7

            local scroll = ents.Create("solve_naruto_inkuton_scroll_anim")
            scroll:SetOwner(ply)
            scroll:SetPos(ply:GetPos())
            scroll:SetConfig(1)
            scroll:Spawn()
            SafeRemoveEntityDelayed(scroll, scrollDelay)

            self:Timer(ply:RestartAnimationGesture("m_ni_sht_attack_tnt_scroll_cmb_01")*0.33, function()
                ply:ExecSound("eljaunito/solve/miscellaneous/jutsu1.wav")

                local trAim = util.TraceLine({
                    start = ply:EyePos(),
                    endpos = ply:EyePos() + ply:GetAimVector() * 2000,
                    filter = ply,
                    mask = MASK_SHOT
                })
                local vecTarget = trAim.HitPos

                local rightMonk = ents.Create("solve_naruto_inkuton_monks")
                rightMonk:SetPos(ply:GetPos() - ply:GetForward() * 50)
                rightMonk:SetAngles((ply:GetAimVector()*Vector(1,1,0)):Angle())
                rightMonk:SetOwner(ply)
                rightMonk:SetCursorPos(vecTarget)
                rightMonk.Damage = iDamage
                rightMonk.Speed = iSpeed
                rightMonk.WallhackDuration = iWallhackDuration
                rightMonk.StunDuration = iStunDuration
                rightMonk:Spawn()
                rightMonk:Activate()
                SafeRemoveEntityDelayed(rightMonk, iTime)
                ply.rightMonk = rightMonk

                fEnd()

            end)

        end

        return oFirst

    end
}

fAddSkills("inkuton", {
    sID = IDENTIFIER,
    sName = "Guerriers d'encre",
    sDesc = "L'utilisateur invoque deux guerriers géants qui foncent sur la cible désignée, lui infligeant des dégâts considérables et l'immobilisant brièvement. L'ennemi ciblé reste marqué et visible pour l'utilisateur pendant un certain temps après l'attaque, quelle que soit sa position.",
    tLevels = {
        [1] = {
            nCoolDown = E_Value(IDENTIFIER, "cooldown_level_1",50),
            nPoint = 2,
            tInfos = {
                {sName = "Chakra", nValue = E_Value(IDENTIFIER, "chakra_level_1", 50)},
                {sName = "Damage", nValue = 250},
                {sName = "Speed", nValue = E_Value(IDENTIFIER, "speed_level_1", 750)},
                {sName = "Reach", nValue = E_Value(IDENTIFIER, "range_level_1", 1000)},
                {sName = "Trail width", nValue = E_Value(IDENTIFIER, "width_level_1", 100)},
                {sName = "Wallhack duration", nValue = E_Value(IDENTIFIER, "wallhack_duration_level_1", 10)},
                {sName = "Stupefaction duration", nValue = E_Value(IDENTIFIER, "stun_duration_level_1", 1.5)},
            },
        },
        [2] = {
            nCoolDown = E_Value(IDENTIFIER, "cooldown_level_2", 40),
            nPoint = 2,
            tInfos = {
                {sName = "Chakra", nValue = E_Value(IDENTIFIER, "chakra_level_2", 50)},
                {sName = "Damage", nValue = 350},
                {sName = "Speed", nValue = E_Value(IDENTIFIER, "speed_level_2", 750)},
                {sName = "Reach", nValue = E_Value(IDENTIFIER, "range_level_2", 1000)},
                {sName = "Trail width", nValue = E_Value(IDENTIFIER, "width_level_2", 100)},
                {sName = "Wallhack duration", nValue = E_Value(IDENTIFIER, "wallhack_duration_level_2", 10)},
                {sName = "Stupefaction duration", nValue = E_Value(IDENTIFIER, "stun_duration_level_2", 2)},
            },
        },
        [3] = {
            nCoolDown = E_Value(IDENTIFIER, "cooldown_level_3", 30),
            nPoint = 3,
            tInfos = {
                {sName = "Chakra", nValue = E_Value(IDENTIFIER, "chakra_level_3", 50)},
                {sName = "Damage", nValue = 450},
                {sName = "Speed", nValue = E_Value(IDENTIFIER, "speed_level_3", 750)},
                {sName = "Reach", nValue = E_Value(IDENTIFIER, "range_level_3", 1000)},
                {sName = "Trail width", nValue = E_Value(IDENTIFIER, "width_level_3", 100)},
                {sName = "Wallhack duration", nValue = E_Value(IDENTIFIER, "wallhack_duration_level_3", 10)},
                {sName = "Stupefaction duration", nValue = E_Value(IDENTIFIER, "stun_duration_level_3", 3)},
            },
        },
    },

    sType = "Attack",
    tParents = {"inkuton_3"},
	cGradient = Color(78, 79, 131, 50),
    mImage = Material("materials/jutsus/icons/kg/inkuton/4.png", "smooth"),
    nX = -1, nY = 1,
    sMinimumRank = "tokubetsu_jonin"
})
