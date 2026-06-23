if CLIENT then return end

local PLAYER = FindMetaTable("Player")

Solve.Naruto.Inventory = Solve.Naruto.Inventory or {}
Solve.Naruto.Inventory.Config = Solve.Naruto.Inventory.Config or {}

local function CreateInventoryTables()
    Solve.MySQL:Query([[
        CREATE TABLE IF NOT EXISTS solve_naruto_inventory (
            id INT AUTO_INCREMENT PRIMARY KEY,
            iCharacterId INT NOT NULL,
            sItemId VARCHAR(128) NOT NULL,
            sKind VARCHAR(64) NOT NULL DEFAULT 'objects',
            iCount INT NOT NULL DEFAULT 1,
            iSlot INT DEFAULT NULL,
            sAccessoryId VARCHAR(128) DEFAULT NULL,
            sCustomData TEXT DEFAULT NULL,
            createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_inventory_char (iCharacterId),
            INDEX idx_inventory_item (sItemId)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], function()
        print("[Lucid.Naruto] Inventory MySQL tables initialized")
    end)
end

hook.Add("Solve.MySQL:Connected", "Solve.Inventory:InitTables", CreateInventoryTables)
if Solve.MySQL.bReady then
    CreateInventoryTables()
end

local function SQLStr(str)
    if str == nil then return "NULL" end
    return Solve.MySQL:Escape(tostring(str))
end

local function GetCharacterId(pPlayer)
    if pPlayer.GetCharacterGlobalId then
        local iGlobalId = pPlayer:GetCharacterGlobalId()
        if iGlobalId and iGlobalId > 0 then
            return iGlobalId
        end
    end
    
    local iSlot = pPlayer:GetNWInt("CharacterId", 1)
    local sSteamId = pPlayer:SteamID64() or "0"
    return tonumber(sSteamId:sub(-8)) * 10 + iSlot
end

local function CopyInventoryLogContext(tContext)
    if type(tContext) ~= "table" then return nil end

    local tCopy = {}
    for k, v in pairs(tContext) do
        tCopy[k] = v
    end

    return tCopy
end

function Solve.Naruto.Inventory:PushLogContext(tContext)
    self.tLogContextStack = self.tLogContextStack or {}
    table.insert(self.tLogContextStack, tContext or {})
end

function Solve.Naruto.Inventory:PopLogContext()
    if not self.tLogContextStack or #self.tLogContextStack == 0 then return nil end
    return table.remove(self.tLogContextStack)
end

function Solve.Naruto.Inventory:GetLogContext()
    if not self.tLogContextStack or #self.tLogContextStack == 0 then return nil end
    return self.tLogContextStack[#self.tLogContextStack]
end

function Solve.Naruto.Inventory:WithLogContext(tContext, fn)
    self:PushLogContext(tContext)

    local tResults = {xpcall(fn, debug.traceback)}

    self:PopLogContext()

    if not tResults[1] then
        error(tResults[2])
    end

    return unpack(tResults, 2)
end

local function NetWriteOptionalString(str)
    if str and str ~= "" and str ~= "NULL" then
        net.WriteBool(true)
        net.WriteString(str)
    else
        net.WriteBool(false)
    end
end

function Solve.Naruto.Inventory:LoadPlayerInventory(pPlayer)
    if not IsValid(pPlayer) then return end
    
    local iCharId = GetCharacterId(pPlayer)
    if not iCharId then return end
    
    pPlayer.SolveNarutoInv = pPlayer.SolveNarutoInv or {}
    pPlayer.SolveNarutoInv.tItems = {}
    pPlayer.SolveNarutoInv.tAccessories = {}
    pPlayer.SolveNarutoInv.iCharId = iCharId
    
    pPlayer.SolveNaruto = pPlayer.SolveNaruto or {}
    pPlayer.SolveNaruto.tAccessories = {}
    
    local tData = nil
    
    Solve.MySQL:Query("SELECT * FROM solve_naruto_inventory WHERE iCharacterId = " .. iCharId, function(tResult)
        if not IsValid(pPlayer) then return end
        
        if tResult then
            for _, tRow in ipairs(tResult) do
                local sItemId = tRow.sItemId
                
                pPlayer.SolveNarutoInv.tItems[sItemId] = {
                    iCount = tonumber(tRow.iCount) or 1,
                    iSlot = tonumber(tRow.iSlot),
                    sAccessoryId = tRow.sAccessoryId,
                    sKind = tRow.sKind or "objects",
                    iDbId = tonumber(tRow.id),
                }
                
                if tRow.sAccessoryId and tRow.sAccessoryId ~= "" then
                    pPlayer.SolveNarutoInv.tAccessories[tRow.sAccessoryId] = sItemId
                    pPlayer.SolveNaruto.tAccessories[tRow.sAccessoryId] = sItemId
                end
            end
        end
        
        print("[Lucid.Naruto] Loaded inventory for: " .. pPlayer:Nick() .. " (" .. table.Count(pPlayer.SolveNarutoInv.tItems) .. " items)")
        
        Solve.Naruto.Inventory:SyncInventoryToClient(pPlayer)
        
        local tCategories = Solve.Naruto.Inventory.Config["itemsCategories"]
        if tCategories then
            for sSlotId, sItemId in pairs(pPlayer.SolveNarutoInv.tAccessories) do
                local tItemConfig = Solve.Naruto.Inventory:GetItemData(sItemId)
                if tItemConfig then
                    local tCategory = tCategories[tItemConfig.sCategory]
                    if tCategory and tCategory.fnSet then
                        local bOk, sErr = pcall(tCategory.fnSet, pPlayer, tItemConfig, sItemId)
                        if not bOk then
                            print("[Inventory] WARNING: fnSet on load error for " .. sItemId .. ": " .. tostring(sErr))
                        else
                            print("[Inventory] Re-applied fnSet for equipped item: " .. sItemId .. " (slot: " .. sSlotId .. ")")
                        end
                    end
                end
            end
        end
        
        hook.Run("Solve.Naruto.Inventory:Loaded", pPlayer)
    end)
end

function Solve.Naruto.Inventory:SyncInventoryToClient(pPlayer)
    if not IsValid(pPlayer) then 
        print("[Inventory Sync] Player invalid")
        return 
    end
    if not pPlayer.SolveNarutoInv or not pPlayer.SolveNarutoInv.tItems then 
        print("[Inventory Sync] No inventory data for " .. pPlayer:Nick())
        return 
    end
    
    local tItems = pPlayer.SolveNarutoInv.tItems
    local iTotal = table.Count(tItems)
    
    print("[Inventory Sync] Syncing " .. iTotal .. " items to " .. pPlayer:Nick())
    
    net.Start("Solve.Naruto.Inventory:ClientSide")
        net.WriteUInt(1, 3)
        net.WriteUInt(iTotal, 32)
        
        for sItemId, tItem in pairs(tItems) do
            print("[Inventory Sync] Sending item: " .. sItemId .. " x" .. (tItem.iCount or 1) .. " accessory: " .. tostring(tItem.sAccessoryId))
            net.WriteString(sItemId)
            net.WriteUInt(tItem.iCount or 1, 32)
            net.WriteString(tItem.sAccessoryId or "")
            NetWriteOptionalString(nil)
            NetWriteOptionalString(nil)
        end
    net.Send(pPlayer)
    
    print("[Inventory Sync] Sent to " .. pPlayer:Nick())
end

function Solve.Naruto.Inventory:AddItem(pPlayer, sItemId, iCount, fnCallback, bSilent)
    if not IsValid(pPlayer) then 
        if fnCallback then fnCallback(0) end
        return false 
    end
    
    iCount = iCount or 1
    
    local tItemConfig = self:GetItemData(sItemId)
    local sKind = tItemConfig and tItemConfig.sType or "objects"
    
    pPlayer.SolveNarutoInv = pPlayer.SolveNarutoInv or {}
    pPlayer.SolveNarutoInv.tItems = pPlayer.SolveNarutoInv.tItems or {}
    
    local iCharId = pPlayer.SolveNarutoInv.iCharId or GetCharacterId(pPlayer)
    pPlayer.SolveNarutoInv.iCharId = iCharId
    
    local tExisting = pPlayer.SolveNarutoInv.tItems[sItemId]
    local iOldCount = tExisting and (tExisting.iCount or 0) or 0
    
    if tExisting then
        tExisting.iCount = tExisting.iCount + iCount
        
        if tExisting.iDbId then
            Solve.MySQL:Execute("UPDATE solve_naruto_inventory SET iCount = " .. tExisting.iCount .. " WHERE id = " .. tExisting.iDbId)
        end
    else
        Solve.MySQL:Query(string.format(
            "INSERT INTO solve_naruto_inventory (iCharacterId, sItemId, sKind, iCount) VALUES (%d, %s, %s, %d)",
            iCharId,
            SQLStr(sItemId),
            SQLStr(sKind),
            iCount
        ), function(_, iLastInsert)
            if not IsValid(pPlayer) then return end
            if pPlayer.SolveNarutoInv and pPlayer.SolveNarutoInv.tItems and pPlayer.SolveNarutoInv.tItems[sItemId] then
                pPlayer.SolveNarutoInv.tItems[sItemId].iDbId = tonumber(iLastInsert)
            end
        end)
        
        pPlayer.SolveNarutoInv.tItems[sItemId] = {
            iCount = iCount,
            iSlot = nil,
            sAccessoryId = nil,
            sKind = sKind,
            iDbId = nil,
        }
    end
    
    local sItemName = tItemConfig and tItemConfig.sName or sItemId
    if not bSilent then
        pPlayer:ChatPrint(L("inventory.item_added", {count = iCount, name = sItemName}))
    end
    
    self:SyncInventoryToClient(pPlayer)

    hook.Run("Lucid.Inventory.ItemAdded", pPlayer, {
        itemId = sItemId,
        itemName = sItemName,
        itemCategory = tItemConfig and tItemConfig.sCategory or nil,
        kind = sKind,
        amount = iCount,
        oldCount = iOldCount,
        newCount = pPlayer:GetItemCount(sItemId),
        context = CopyInventoryLogContext(self:GetLogContext()),
    })
    
    if fnCallback then fnCallback(iCount) end
    
    return true
end

function PLAYER:GiveItem(sItemId, iCount, sKind, tCustomData)
    return Solve.Naruto.Inventory:AddItem(self, sItemId, iCount)
end

function Solve.Naruto.Inventory:RemoveItem(pPlayer, sItemId, iCount)
    if not IsValid(pPlayer) then return false end
    if not pPlayer.SolveNarutoInv or not pPlayer.SolveNarutoInv.tItems then return false end
    
    iCount = iCount or 1
    
    local tItem = pPlayer.SolveNarutoInv.tItems[sItemId]
    if not tItem then return false end
    if tItem.iCount < iCount then return false end

    local tItemConfig = self:GetItemData(sItemId)
    local iOldCount = tItem.iCount or 0
    local bWasEquipped = tItem.sAccessoryId ~= nil and tItem.sAccessoryId ~= ""
    local sOldSlotId = tItem.sAccessoryId
    local sKind = tItem.sKind or (tItemConfig and tItemConfig.sType) or "objects"
    
    if tItem.sAccessoryId and tItem.iCount <= iCount then
        pPlayer:UnequipItem(sItemId)
    end
    
    tItem.iCount = tItem.iCount - iCount
    
    if tItem.iCount <= 0 then
        if tItem.iDbId then
            Solve.MySQL:Execute("DELETE FROM solve_naruto_inventory WHERE id = " .. tItem.iDbId)
        end
        
        if tItem.sAccessoryId then
            pPlayer.SolveNarutoInv.tAccessories[tItem.sAccessoryId] = nil
        end
        
        pPlayer.SolveNarutoInv.tItems[sItemId] = nil
    else
        if tItem.iDbId then
            Solve.MySQL:Execute("UPDATE solve_naruto_inventory SET iCount = " .. tItem.iCount .. " WHERE id = " .. tItem.iDbId)
        end
    end

    hook.Run("Lucid.Inventory.ItemRemoved", pPlayer, {
        itemId = sItemId,
        itemName = tItemConfig and (tItemConfig.sName or tItemConfig.sLittleName) or sItemId,
        itemCategory = tItemConfig and tItemConfig.sCategory or nil,
        kind = sKind,
        amount = iCount,
        oldCount = iOldCount,
        newCount = math.max(iOldCount - iCount, 0),
        wasEquipped = bWasEquipped,
        slotId = sOldSlotId,
        deleted = iOldCount <= iCount,
        context = CopyInventoryLogContext(self:GetLogContext()),
    })
    
    return true
end

function PLAYER:RemoveItem(sItemId, iCount, sKind)
    return Solve.Naruto.Inventory:RemoveItem(self, sItemId, iCount)
end

function PLAYER:HasItem(sItemId, iCount, sKind)
    if not self.SolveNarutoInv or not self.SolveNarutoInv.tItems then return false end
    
    local tItem = self.SolveNarutoInv.tItems[sItemId]
    if not tItem then return false end
    
    return tItem.iCount >= (iCount or 1)
end

function PLAYER:GetItemCount(sItemId, sKind)
    if not self.SolveNarutoInv or not self.SolveNarutoInv.tItems then return 0 end
    
    local tItem = self.SolveNarutoInv.tItems[sItemId]
    return tItem and tItem.iCount or 0
end

function PLAYER:EquipItem(sItemId, sSlotId, sKind)
    if not self.SolveNarutoInv or not self.SolveNarutoInv.tItems then 
        print("[Inventory] EquipItem failed: No inventory")
        return false 
    end
    
    local tItem = self.SolveNarutoInv.tItems[sItemId]
    if not tItem then
        print("[Inventory] EquipItem failed: Item not found: " .. sItemId)
        return false
    end

    print("[Inventory] EquipItem: " .. sItemId .. " -> slot: " .. tostring(sSlotId))
    
    local sOldItem = self.SolveNarutoInv.tAccessories[sSlotId]
    if sOldItem then
        self:UnequipItem(sOldItem)
    end
    
    tItem.sAccessoryId = sSlotId
    self.SolveNarutoInv.tAccessories[sSlotId] = sItemId
    
    self.SolveNaruto = self.SolveNaruto or {}
    self.SolveNaruto.tAccessories = self.SolveNaruto.tAccessories or {}
    self.SolveNaruto.tAccessories[sSlotId] = sItemId
    
    if tItem.iDbId then
        Solve.MySQL:Execute("UPDATE solve_naruto_inventory SET sAccessoryId = " .. SQLStr(sSlotId) .. " WHERE id = " .. tItem.iDbId)
        print("[Inventory] Saved to DB: id=" .. tItem.iDbId .. " accessory=" .. sSlotId)
    end
    
    local tItemConfig = Solve.Naruto.Inventory:GetItemData(sItemId)
    local tCategory = tItemConfig and Solve.Naruto.Inventory.Config["itemsCategories"] and Solve.Naruto.Inventory.Config["itemsCategories"][tItemConfig.sCategory]
    if tCategory and tCategory.fnSet then
        local bOk, sErr = pcall(tCategory.fnSet, self, tItemConfig, sItemId)
        if not bOk then
            print("[Inventory] WARNING: fnSet error for " .. sItemId .. ": " .. tostring(sErr))
        end
    end

    hook.Run("Lucid.Inventory.ItemEquipped", self, {
        itemId = sItemId,
        itemName = tItemConfig and (tItemConfig.sName or tItemConfig.sLittleName) or sItemId,
        itemCategory = tItemConfig and tItemConfig.sCategory or nil,
        slotId = sSlotId,
        replacedItemId = sOldItem,
        context = CopyInventoryLogContext(Solve.Naruto.Inventory:GetLogContext()),
    })
    
    return true
end

function PLAYER:UnequipItem(sItemId, sKind)
    if not self.SolveNarutoInv or not self.SolveNarutoInv.tItems then return false end
    
    local tItem = self.SolveNarutoInv.tItems[sItemId]
    if not tItem or not tItem.sAccessoryId then return false end
    
    local sSlotId = tItem.sAccessoryId
    
    local tItemConfig = Solve.Naruto.Inventory:GetItemData(sItemId)
    local tCategory = tItemConfig and Solve.Naruto.Inventory.Config["itemsCategories"] and Solve.Naruto.Inventory.Config["itemsCategories"][tItemConfig.sCategory]
    if tCategory and tCategory.fnUnSet then
        local bOk, sErr = pcall(tCategory.fnUnSet, self, tItemConfig, sItemId)
        if not bOk then
            print("[Inventory] WARNING: fnUnSet error for " .. sItemId .. ": " .. tostring(sErr))
        end
    end
    
    tItem.sAccessoryId = nil
    self.SolveNarutoInv.tAccessories[sSlotId] = nil
    
    if self.SolveNaruto and self.SolveNaruto.tAccessories then
        self.SolveNaruto.tAccessories[sSlotId] = nil
    end
    
    if tItem.iDbId then
        Solve.MySQL:Execute("UPDATE solve_naruto_inventory SET sAccessoryId = NULL WHERE id = " .. tItem.iDbId)
    end

    hook.Run("Lucid.Inventory.ItemUnequipped", self, {
        itemId = sItemId,
        itemName = tItemConfig and (tItemConfig.sName or tItemConfig.sLittleName) or sItemId,
        itemCategory = tItemConfig and tItemConfig.sCategory or nil,
        slotId = sSlotId,
        context = CopyInventoryLogContext(Solve.Naruto.Inventory:GetLogContext()),
    })
    
    return true
end

function PLAYER:UseItem(sItemId, sKind)
    if not self:HasItem(sItemId, 1) then
        self:ChatPrint(L("inventory.no_item"))
        return false
    end
    
    local tItemConfig = Solve.Naruto.Inventory:GetItemData(sItemId)
    if not tItemConfig then return false end
    
    local tCategory = Solve.Naruto.Inventory.Config["itemsCategories"] and Solve.Naruto.Inventory.Config["itemsCategories"][tItemConfig.sCategory]
    if not tCategory or not tCategory.fnUse then
        self:ChatPrint(L("inventory.cannot_use"))
        return false
    end
    
    local iConsumed = tCategory.fnUse(self, tItemConfig)

    hook.Run("Lucid.Inventory.ItemUsed", self, {
        itemId = sItemId,
        itemName = tItemConfig.sName or tItemConfig.sLittleName or sItemId,
        itemCategory = tItemConfig.sCategory,
        consumed = math.max(tonumber(iConsumed) or 0, 0),
        useType = "primary",
        context = CopyInventoryLogContext(Solve.Naruto.Inventory:GetLogContext()),
    })
    
    if iConsumed and iConsumed > 0 then
        Solve.Naruto.Inventory:WithLogContext({
            reason = "use_consume",
            itemId = sItemId,
        }, function()
            self:RemoveItem(sItemId, iConsumed)
        end)
    end
    
    return true
end

function PLAYER:SetItemSlot(sItemId, iSlot, sKind)
    if not self.SolveNarutoInv or not self.SolveNarutoInv.tItems then return false end
    
    local tItem = self.SolveNarutoInv.tItems[sItemId]
    if not tItem then return false end
    
    tItem.iSlot = iSlot
    
    if tItem.iDbId then
        local sSlotValue = iSlot and tostring(iSlot) or "NULL"
        Solve.MySQL:Execute("UPDATE solve_naruto_inventory SET iSlot = " .. sSlotValue .. " WHERE id = " .. tItem.iDbId)
    end

    local tItemConfig = Solve.Naruto.Inventory:GetItemData(sItemId)

    hook.Run("Lucid.Inventory.ItemSlotChanged", self, {
        itemId = sItemId,
        itemName = tItemConfig and (tItemConfig.sName or tItemConfig.sLittleName) or sItemId,
        itemCategory = tItemConfig and tItemConfig.sCategory or nil,
        slot = iSlot,
        kind = sKind or tItem.sKind,
        context = CopyInventoryLogContext(Solve.Naruto.Inventory:GetLogContext()),
    })
    
    return true
end

function PLAYER:GetInventoryWeight(sKind)
    if not self.SolveNarutoInv or not self.SolveNarutoInv.tItems then return 0 end
    
    local iWeight = 0
    
    for sItemId, tItem in pairs(self.SolveNarutoInv.tItems) do
        local tItemConfig = Solve.Naruto.Inventory:GetItemData(sItemId)
        local iItemWeight = tItemConfig and tItemConfig.iWeight or 1
        iWeight = iWeight + (iItemWeight * tItem.iCount)
    end
    
    return iWeight
end

function PLAYER:GetMaxInventoryWeight()
    local iBase = Solve.Naruto.Inventory.Config["weight"] or 80
    return iBase
end

local tLastSync = {}

net.Receive("Solve.Naruto.Inventory:OpenInventory", function(len, pPlayer)
    if not IsValid(pPlayer) then return end
    
    local sSteamId = pPlayer:SteamID64()
    local iNow = CurTime()
    
    if tLastSync[sSteamId] and (iNow - tLastSync[sSteamId]) < 1 then
        return
    end
    tLastSync[sSteamId] = iNow
    
    if not pPlayer.SolveNarutoInv then
        Solve.Naruto.Inventory:LoadPlayerInventory(pPlayer)
    end
    
    Solve.Naruto.Inventory:SyncInventoryToClient(pPlayer)
end)

net.Receive("Solve.Naruto.Inventory:UseItem", function(len, pPlayer)
    if not IsValid(pPlayer) then return end
    
    local sItemId = net.ReadString()
    local sKind = net.ReadString()
    
    pPlayer:UseItem(sItemId, sKind)
end)

net.Receive("Solve.Naruto.Inventory:EquipItem", function(len, pPlayer)
    if not IsValid(pPlayer) then return end
    
    local sItemId = net.ReadString()
    local sSlotId = net.ReadString()
    local sKind = net.ReadString()
    
    local bSuccess = pPlayer:EquipItem(sItemId, sSlotId, sKind)
    
    if bSuccess then
        local sSteamId = pPlayer:SteamID64()
        tLastSync[sSteamId] = CurTime()
        Solve.Naruto.Inventory:SyncInventoryToClient(pPlayer)
    end
end)

net.Receive("Solve.Naruto.Inventory:UnequipItem", function(len, pPlayer)
    if not IsValid(pPlayer) then return end
    
    local sItemId = net.ReadString()
    local sKind = net.ReadString()
    
    local bSuccess = pPlayer:UnequipItem(sItemId, sKind)
    
    if bSuccess then
        local sSteamId = pPlayer:SteamID64()
        tLastSync[sSteamId] = CurTime()
        Solve.Naruto.Inventory:SyncInventoryToClient(pPlayer)
    end
end)

net.Receive("Solve.Naruto.Inventory:DropItem", function(len, pPlayer)
    if not IsValid(pPlayer) then return end
    
    local sItemId = net.ReadString()
    local iCount = net.ReadUInt(16)
    local sKind = net.ReadString()
    
    if pPlayer:HasItem(sItemId, iCount) then
        Solve.Naruto.Inventory:WithLogContext({
            reason = "drop",
            source = "drop_item_net",
            kind = sKind,
        }, function()
            pPlayer:RemoveItem(sItemId, iCount)
        end)
        pPlayer:ChatPrint(L("inventory.item_dropped"))
    end
end)

net.Receive("Solve.Naruto.Inventory:SetSlot", function(len, pPlayer)
    if not IsValid(pPlayer) then return end
    
    local sItemId = net.ReadString()
    local iSlot = net.ReadInt(16)
    local sKind = net.ReadString()
    
    Solve.Naruto.Inventory:WithLogContext({
        reason = "set_slot",
        source = "set_slot_net",
        kind = sKind,
    }, function()
        pPlayer:SetItemSlot(sItemId, iSlot > 0 and iSlot or nil, sKind)
    end)
end)

hook.Add("Solve.Naruto.CharacterCreator:CharacterSelected", "Solve.Naruto.Inventory:Load", function(pPlayer, tChar)
    timer.Simple(1, function()
        if IsValid(pPlayer) then
            Solve.Naruto.Inventory:LoadPlayerInventory(pPlayer)
        end
    end)
end)

hook.Add("PlayerInitialSpawn", "Solve.Naruto.Inventory:InitLoad", function(pPlayer)
    timer.Simple(3, function()
        if IsValid(pPlayer) then
            Solve.Naruto.Inventory:LoadPlayerInventory(pPlayer)
        end
    end)
end)

net.Receive("Solve.Naruto.Inventory:ServerSide", function(len, pPlayer)
    if not IsValid(pPlayer) then return end
    
    local iNetId = net.ReadUInt(3)
    
    print("[Inventory ServerSide] NetId: " .. iNetId .. " from " .. pPlayer:Nick())
    
    if iNetId == 1 then
        local sItemId = net.ReadString()
        local iCount = net.ReadUInt(32)
        
        if iCount <= 0 then return end
        if pPlayer:HasItem(sItemId, iCount) then
            Solve.Naruto.Inventory:WithLogContext({
                reason = "drop",
                source = "serverside_drop",
            }, function()
                pPlayer:RemoveItem(sItemId, iCount)
            end)
            pPlayer:ChatPrint(L("inventory.item_dropped"))
            Solve.Naruto.Inventory:SyncInventoryToClient(pPlayer)
            
            local eItem = ents.Create("solve_naruto_inventory_item")
            if IsValid(eItem) then
                local vecPos = pPlayer:GetPos() + pPlayer:GetForward() * 50 + Vector(0, 0, 20)
                eItem:SetPos(vecPos)
                eItem:SetAngles(Angle(0, 0, 0))
                eItem:Spawn()
                eItem:Activate()
                eItem:Setup(sItemId, iCount)
                
                local iRemoveTime = Solve.Naruto.Inventory.Config["removeDroppedItem"] or 600
                timer.Simple(iRemoveTime, function()
                    if IsValid(eItem) then eItem:Remove() end
                end)
            end
        end
        
    elseif iNetId == 2 then
        local sItemId = net.ReadString()
        local bUnequip = net.ReadBool()
        
        local bHasSwap = false
        local sSwapItemId = nil
        
        if net.BytesLeft() >= 1 then
            bHasSwap = net.ReadBool()
            if bHasSwap and net.BytesLeft() >= 1 then
                sSwapItemId = net.ReadString()
            end
        end
        
        local tItemConfig = Solve.Naruto.Inventory:GetItemData(sItemId)
        if not tItemConfig then 
            print("[Inventory] Item config not found: " .. sItemId)
            return 
        end
        
        local sSlotId = tItemConfig.sPlayerAccessory
        if not sSlotId then 
            print("[Inventory] No sPlayerAccessory for: " .. sItemId)
            return 
        end
        
        if bUnequip then
            print("[Inventory] Unequipping: " .. sItemId)
            pPlayer:UnequipItem(sItemId)
        else
            print("[Inventory] Equipping: " .. sItemId .. " to slot: " .. sSlotId)
            
            if sSwapItemId then
                pPlayer:UnequipItem(sSwapItemId)
            end
            
            pPlayer:EquipItem(sItemId, sSlotId)
        end
        
        Solve.Naruto.Inventory:SyncInventoryToClient(pPlayer)
        
    elseif iNetId == 5 then
        local sItemId = net.ReadString()
        Solve.Naruto.Inventory:WithLogContext({
            reason = "use",
            source = "serverside_use",
        }, function()
            pPlayer:UseItem(sItemId)
        end)
        
    elseif iNetId == 7 then
        local sItemId = net.ReadString()
        local tItemConfig = Solve.Naruto.Inventory:GetItemData(sItemId)
        if tItemConfig then
            local tCategory = Solve.Naruto.Inventory.Config["itemsCategories"] and Solve.Naruto.Inventory.Config["itemsCategories"][tItemConfig.sCategory]
            if tCategory and tCategory.fnUse2 then
                tCategory.fnUse2(pPlayer, sItemId)
                hook.Run("Lucid.Inventory.ItemUsed", pPlayer, {
                    itemId = sItemId,
                    itemName = tItemConfig.sName or tItemConfig.sLittleName or sItemId,
                    itemCategory = tItemConfig.sCategory,
                    consumed = 0,
                    useType = "secondary",
                    context = CopyInventoryLogContext(Solve.Naruto.Inventory:GetLogContext()),
                })
            end
        end

    elseif iNetId == 3 then
        local sItemId = net.ReadString()
        local iCount = net.ReadUInt(32)

        if iCount <= 0 then return end
        if pPlayer:HasItem(sItemId, iCount) then
            Solve.Naruto.Inventory:WithLogContext({
                reason = "destroy",
                source = "serverside_destroy",
            }, function()
                pPlayer:RemoveItem(sItemId, iCount)
            end)
            pPlayer:ChatPrint(L("inventory.item_destroyed"))
            Solve.Naruto.Inventory:SyncInventoryToClient(pPlayer)
        end

    elseif iNetId == 6 then
        local sItemId = net.ReadString()
        local iCount = net.ReadUInt(32)
        local pTarget = net.ReadEntity()

        if iCount <= 0 then return end
        if not IsValid(pTarget) or not pTarget:IsPlayer() then return end
        if pTarget == pPlayer then return end
        if pPlayer:GetPos():DistToSqr(pTarget:GetPos()) > 500 * 500 then
            pPlayer:ChatPrint("El jugador está demasiado lejos.")
            return
        end
        if pPlayer:HasItem(sItemId, iCount) then
            Solve.Naruto.Inventory:WithLogContext({
                reason = "player_transfer_sent",
                source = "player_transfer",
                targetPlayer = pTarget,
            }, function()
                pPlayer:RemoveItem(sItemId, iCount)
            end)
            Solve.Naruto.Inventory:WithLogContext({
                reason = "player_transfer_received",
                source = "player_transfer",
                actor = pPlayer,
                fromPlayer = pPlayer,
            }, function()
                Solve.Naruto.Inventory:AddItem(pTarget, sItemId, iCount)
            end)
            Solve.Naruto.Inventory:SyncInventoryToClient(pPlayer)
            Solve.Naruto.Inventory:SyncInventoryToClient(pTarget)

            local tItemData = Solve.Naruto.Inventory:GetItemData(sItemId)
            local sName = tItemData and tItemData.sLittleName or sItemId
            pPlayer:ChatPrint("Has dado x" .. iCount .. " " .. sName .. " a " .. pTarget:Nick() .. ".")
            pTarget:ChatPrint(pPlayer:Nick() .. " te ha dado x" .. iCount .. " " .. sName .. ".")
        end

    elseif iNetId == 4 then
        local eEntity = net.ReadEntity()
        if not IsValid(eEntity) then return end
        if eEntity:GetClass() ~= "solve_naruto_inventory_item" then return end

        if pPlayer:GetPos():DistToSqr(eEntity:GetPos()) > 200 * 200 then return end

        local sItemId = eEntity:GetItemId()
        local iCount = eEntity:GetCount()

        if sItemId == "" then return end

        Solve.Naruto.Inventory:WithLogContext({
            reason = "pickup_ground",
            source = "pickup_entity_net",
            entityClass = eEntity:GetClass(),
        }, function()
            Solve.Naruto.Inventory:AddItem(pPlayer, sItemId, iCount)
        end)
        eEntity:Remove()
    end
end)

print("[Lucid.Naruto] Inventory Server (MySQL) loaded!")

local tInvWebhookQueue = {}
local bInvWebhookProcessing = false
local flInvWebhookLastCall = 0

function Solve.Naruto.Inventory:LookUpInventory(pTarget, pAdmin)
    if not IsValid(pTarget) or not IsValid(pAdmin) then return end
    if pAdmin:GetUserGroup() ~= "superadmin" then return end

    if not pTarget.SolveNarutoInv or not pTarget.SolveNarutoInv.tItems then
        pAdmin:ChatPrint("[Inventaire] El jugador no tiene Inventaire cargado.")
        return
    end

    local tByKind = {}
    for sItemId, tItem in pairs(pTarget.SolveNarutoInv.tItems) do
        local sKind = tItem.sKind or "objects"
        tByKind[sKind] = tByKind[sKind] or {}
        tByKind[sKind][sItemId] = tItem
    end

    local iKindCount = table.Count(tByKind)
    local iItemTotal = 0

    for _, tKindItems in pairs(tByKind) do
        iItemTotal = iItemTotal + table.Count(tKindItems)
    end

    hook.Run("Lucid.Inventory.InventoryViewed", pAdmin, {
        targetPlayer = pTarget,
        totalKinds = iKindCount,
        totalItems = iItemTotal,
        context = {
            reason = "admin_lookup",
        },
    })

    net.Start("Solve.Naruto.Inventory:LookUpInventory")
        net.WritePlayer(pTarget)
        net.WriteUInt(iKindCount, 3)

        for sKind, tItems in pairs(tByKind) do
            net.WriteString(sKind)
            net.WriteUInt(table.Count(tItems), 16)

            for sItemId, tItem in pairs(tItems) do
                net.WriteString(sItemId)
                net.WriteUInt(tItem.iCount or 1, 16)
                net.WriteBool(tItem.sAccessoryId ~= nil and tItem.sAccessoryId ~= "")
                if tItem.sAccessoryId and tItem.sAccessoryId ~= "" then
                    net.WriteString(tItem.sAccessoryId)
                end
            end
        end
    net.Send(pAdmin)

    SendInventoryWebhook({
        title = "Inventaire Revisado",
        color = 3447003,
        fields = {
            { name = "Admin", value = pAdmin:Nick() .. " (`" .. pAdmin:SteamID() .. "`)", inline = true },
            { name = "Jugador", value = pTarget:Nick() .. " (`" .. pTarget:SteamID() .. "`)", inline = true },
            { name = "Items totales", value = tostring(iItemTotal), inline = true },
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
end

net.Receive("Solve.Naruto.Inventory:AdminRemoveItem", function(_, pAdmin)
    if not IsValid(pAdmin) or not pAdmin:IsPlayer() then return end
    if pAdmin:GetUserGroup() ~= "superadmin" then return end

    local pTarget = net.ReadEntity()
    local sItemId = net.ReadString()
    local iCount = net.ReadUInt(16)

    if not IsValid(pTarget) or not pTarget:IsPlayer() then
        pAdmin:ChatPrint("[Inventaire] Jugador no válido.")
        return
    end

    if not sItemId or sItemId == "" then return end
    iCount = math.max(1, iCount or 1)

    if not pTarget.SolveNarutoInv or not pTarget.SolveNarutoInv.tItems then
        pAdmin:ChatPrint("[Inventaire] El jugador no tiene Inventaire cargado.")
        return
    end

    local tItem = pTarget.SolveNarutoInv.tItems[sItemId]
    if not tItem then
        pAdmin:ChatPrint("[Inventaire] El jugador no tiene ese item.")
        return
    end

    if tItem.sAccessoryId and tItem.sAccessoryId ~= "" then
        pTarget:UnequipItem(sItemId)
    end

    local bSuccess = Solve.Naruto.Inventory:WithLogContext({
        reason = "admin_remove",
        source = "admin_remove_net",
        actor = pAdmin,
        command = "Solve.Naruto.Inventory:AdminRemoveItem",
    }, function()
        return Solve.Naruto.Inventory:RemoveItem(pTarget, sItemId, iCount)
    end)
    if bSuccess then
        Solve.Naruto.Inventory:SyncInventoryToClient(pTarget)

        local tItemConfig = Solve.Naruto.Inventory:GetItemData(sItemId)
        local sItemName = tItemConfig and tItemConfig.sLittleName or sItemId

        pAdmin:ChatPrint("[Inventaire] Eliminado x" .. iCount .. " " .. sItemName .. " de " .. pTarget:Nick())
        pTarget:ChatPrint("[Inventaire] Un admin ha eliminado x" .. iCount .. " " .. sItemName .. " de tu Inventaire.")

        print("[Inventory Admin] " .. pAdmin:Nick() .. " removed x" .. iCount .. " " .. sItemId .. " from " .. pTarget:Nick() .. " (" .. pTarget:SteamID64() .. ")")

        SendInventoryWebhook({
            title = "Item Eliminado del Inventaire",
            color = 15158332,
            fields = {
                { name = "Admin", value = pAdmin:Nick() .. " (`" .. pAdmin:SteamID() .. "`)", inline = true },
                { name = "Jugador", value = pTarget:Nick() .. " (`" .. pTarget:SteamID() .. "`)", inline = true },
                { name = "Item", value = sItemName .. " (`" .. sItemId .. "`)", inline = false },
                { name = "Cantidad", value = "x" .. iCount, inline = true },
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        })

        timer.Simple(0.5, function()
            if IsValid(pTarget) and IsValid(pAdmin) then
                Solve.Naruto.Inventory:LookUpInventory(pTarget, pAdmin)
            end
        end)
    else
        pAdmin:ChatPrint("[Inventaire] No se pudo eliminar el item (cantidad insuficiente?).")
    end
end)

net.Receive("Solve.Naruto.Inventory:AskPlayerMaskMode", function(_, pPlayer)
    if not IsValid(pPlayer) or not pPlayer:IsPlayer() then return end

    local bMasked = net.ReadBool()
    pPlayer:SetNetworkVar("bMasked", bMasked)
end)

net.Receive("Solve.Naruto.Inventory:ItemBrowser", function(_, pPlayer)
    if not IsValid(pPlayer) or not pPlayer:IsPlayer() then return end
    if not pPlayer:IsAdmin() then return end

    local iNetId = net.ReadUInt(3)

    if iNetId == 1 then
        local pTarget = net.ReadEntity()
        local sReason = net.ReadString()
        local iItemCount = net.ReadUInt(32)

        if not IsValid(pTarget) or not pTarget:IsPlayer() then return end
        if iItemCount > 50 then return end

        for i = 1, iItemCount do
            local sItemId = net.ReadString()
            local iCount = net.ReadUInt(32)

            if sItemId and sItemId ~= "" and iCount > 0 and iCount <= 9999 then
                Solve.Naruto.Inventory:WithLogContext({
                    reason = "admin_grant",
                    source = "item_browser",
                    actor = pPlayer,
                    reasonText = sReason,
                }, function()
                    Solve.Naruto.Inventory:AddItem(pTarget, sItemId, iCount)
                end)
            end
        end

        print("[Inventory ItemBrowser] " .. pPlayer:Nick() .. " gave items to " .. pTarget:Nick() .. " | Reason: " .. sReason)
    end
end)

hook.Add("Solve.Naruto.Inventory:Loaded", "Solve.Naruto.Inventory:ApplyEquipmentBoosts", function(pPlayer)
    if not IsValid(pPlayer) then return end
    if not Solve.Naruto.Inventory.ApplyItemBoosts then return end

    timer.Simple(0.5, function()
        if not IsValid(pPlayer) then return end
        Solve.Naruto.Inventory:ReapplyAllEquipmentBoosts(pPlayer)
        print("[Inventory] Applied equipment boosts for: " .. pPlayer:Nick())
    end)
end)
