["katana"] = {
    ["sName"] = "Katanas",
    ["bEditable"] = true,
    ["tModelPanelOffset"] = {

        ["vecOffset"] = Vector(10, 30, 25),
        ["angOffset"] = Angle(0, 0, 40),
        ["iFOV"] = 30,

    },
    ["fnSet"] = function(pPlayer, tItem, sItemId)
        if not SERVER then return end
        local eSword = pPlayer:GetWeapon("naruto_katana_swep")
        if not IsValid(eSword) then
            pPlayer:Give("naruto_katana_swep")
            eSword = pPlayer:GetWeapon("naruto_katana_swep")
        end
        if IsValid(eSword) then
            eSword:SetSwordItem(sItemId)
            if tItem and tItem.bIsDoubleKatana then
                eSword:SetDoubleKatana(true)
            else
                eSword:SetDoubleKatana(false)
            end
        end
    end,
    ["fnUnSet"] = function(pPlayer, tItem, sItemId)
        if not SERVER then return end
        local eSword = pPlayer:GetWeapon("naruto_katana_swep")
        if IsValid(eSword) then
            eSword:SetActive(false)
            eSword:SetSwordItem("")
            eSword:SetDoubleKatana(false)
        end
        pPlayer:StripWeapon("naruto_katana_swep")
    end,
},
