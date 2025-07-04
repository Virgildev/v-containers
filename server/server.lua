local Framework = nil
local FrameworkObject = nil
local Inventory = nil
local containers = {}
local containerCount = 0
local playerActionCooldowns = {}

CreateThread(function()
    if Config.Framework == 'auto' then
        if GetResourceState('es_extended') == 'started' then
            Config.Framework = 'esx'
        elseif GetResourceState('qbx_core') == 'started' then
            Config.Framework = 'qbx'
        elseif GetResourceState('qb-core') == 'started' then
            Config.Framework = 'qb'
        else
            print("[v-containers] ERROR: No supported framework found!")
            return
        end
    end

    if Config.Inventory == 'auto' then
        if GetResourceState('ox_inventory') == 'started' then
            Config.Inventory = 'ox'
        elseif GetResourceState('qb-inventory') == 'started' then
            Config.Inventory = 'qb'
        else
            print("[v-containers] WARNING: No supported inventory found, defaulting to ox")
            Config.Inventory = 'ox'
        end
    end

    Framework = Config.Framework
    Inventory = Config.Inventory

    print(("[v-containers] Initialized with Framework: %s, Inventory: %s"):format(Framework, Inventory))

    InitializeFramework()

    local maxWait = 50
    local waited = 0
    while not FrameworkObject and waited < maxWait do
        Wait(100)
        waited = waited + 1
    end

    if not FrameworkObject then
        print("[v-containers] ERROR: Framework object not initialized!")
        return
    end

    LoadContainers()
    StartLifetimeCheck()

    Wait(1000)
    createItems()
end)

function LogAction(title, message, color, authorInfo)
    if not SV_Config.Webhook or SV_Config.Webhook == '' then return end

    local embed = {
        {
            ["title"] = title,
            ["description"] = message,
            ["color"] = color or 15158332,
            ["author"] = authorInfo,
            ["footer"] = {
                ["text"] = "v-containers | Server Time: " .. os.date('%Y-%m-%d %H:%M:%S')
            }
        }
    }

    PerformHttpRequest(SV_Config.Webhook, function() end, 'POST', json.encode({ embeds = embed }), { ['Content-Type'] = 'application/json' })
end

function GetPlayerAuthorInfo(xPlayer, source)
    local identifier = GetPlayerIdentifier(xPlayer) or "N/A"
    local playerName = GetPlayerName(source) or "N/A"
    return {
        name = string.format("%s (%s)", playerName, identifier),
        icon_url = ""
    }
end

function IsPlayerOnCooldown(source)
    local currentTime = os.time()
    if playerActionCooldowns[source] and (currentTime - playerActionCooldowns[source]) < SV_Config.ActionCooldown then
        if SV_Config.LogSettings.securityWarning then
            local xPlayer = GetPlayer(source)
            if not xPlayer then return true end
            LogAction("Security Warning: Event Spam",
                string.format("Player triggered an event too quickly.", GetPlayerIdentifier(xPlayer)),
                16776960,
                GetPlayerAuthorInfo(xPlayer, source))
        end
        return true
    end
    playerActionCooldowns[source] = currentTime
    return false
end

function IsDistanceCheckValid(playerCoords, targetCoords)
    if #(playerCoords - targetCoords) > SV_Config.MaxInteractionDistance then
        return false
    end
    return true
end

function createItems()
    for containerType, containerData in pairs(Config.Containers) do
        if Framework == 'esx' then
            if ESX and ESX.RegisterUsableItem then
                ESX.RegisterUsableItem(containerType, function(source)
                    TriggerClientEvent('v-containers:client:useContainer', source, {name = containerType})
                end)
            end
        elseif Framework == 'qb' then
            if QBCore and QBCore.Functions and QBCore.Functions.CreateUseableItem then
                QBCore.Functions.CreateUseableItem(containerType, function(source, item)
                    TriggerClientEvent('v-containers:client:useContainer', source, item)
                end)
            end
        elseif Framework == 'qbx' then
        else
            print(('[v-containers] Unsupported framework: %s — usable item "%s" not registered.'):format(Framework, containerType))
        end
    end
end

function InitializeFramework()
    if Framework == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
        FrameworkObject = ESX
    elseif Framework == 'qb' then
        QBCore = exports['qb-core']:GetCoreObject()
        FrameworkObject = QBCore
    elseif Framework == 'qbx' then
        FrameworkObject = exports.qbx_core
    end
end

function GetPlayer(source)
    if Framework == 'esx' then
        return FrameworkObject.GetPlayerFromId(source)
    elseif Framework == 'qb' then
        return FrameworkObject.Functions.GetPlayer(source)
    elseif Framework == 'qbx' then
        return exports.qbx_core:GetPlayer(source)
    end
end

function GetPlayerIdentifier(xPlayer)
    if not xPlayer then return nil end
    if Framework == 'esx' then
        return xPlayer.identifier
    elseif Framework == 'qb' or Framework == 'qbx' then
        return xPlayer.PlayerData.citizenid
    end
end

function RemoveItem(xPlayer, item, amount)
    if Framework == 'esx' then
        xPlayer.removeInventoryItem(item, amount)
    elseif Framework == 'qb' then
        xPlayer.Functions.RemoveItem(item, amount)
    elseif Framework == 'qbx' then
        exports.ox_inventory:RemoveItem(xPlayer.PlayerData.source, item, amount)
    end
end

function AddItem(xPlayer, item, amount)
    if Framework == 'esx' then
        xPlayer.addInventoryItem(item, amount)
    elseif Framework == 'qb' then
        xPlayer.Functions.AddItem(item, amount)
    elseif Framework == 'qbx' then
        exports.ox_inventory:AddItem(xPlayer.PlayerData.source, item, amount)
    end
end

function GetItemCount(xPlayer, item)
    if Framework == 'esx' then
        local xItem = xPlayer.getInventoryItem(item)
        return xItem and xItem.count or 0
    elseif Framework == 'qb' then
        local plyInv = xPlayer.Functions.GetInventory()
        local count = 0
        for _, invItem in pairs(plyInv) do
            if invItem.name == item then
                count = invItem.amount
                break
            end
        end
        return count
    elseif Framework == 'qbx' then
        return exports.ox_inventory:GetItemCount(xPlayer.PlayerData.source, item)
    end
end

function ShowNotification(source, msg)
    if Framework == 'esx' then
        TriggerClientEvent('esx:showNotification', source, msg)
    elseif Framework == 'qb' then
        TriggerClientEvent('QBCore:Notify', source, msg)
    elseif Framework == 'qbx' then
        exports.qbx_core:Notify(source, msg, 'primary')
    end
end

function LoadContainers()
    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:execute([[
            CREATE TABLE IF NOT EXISTS v_containers (
                id VARCHAR(50) PRIMARY KEY,
                type VARCHAR(50),
                coords TEXT,
                rotation FLOAT,
                owner VARCHAR(50),
                locked BOOLEAN DEFAULT FALSE,
                pin VARCHAR(4),
                expires_at BIGINT,
                isTrapped BOOLEAN DEFAULT FALSE,
                created_at BIGINT DEFAULT CURRENT_TIMESTAMP
            )
        ]])

        local result = exports.oxmysql:executeSync('SELECT * FROM v_containers', {})

        for _, row in pairs(result) do
            local coords = json.decode(row.coords)
            local containerConfig = Config.Containers[row.type]
            if not containerConfig then
                print(("[v-containers] WARNING: Found a container in DB with invalid type '%s'. Skipping."):format(row.type))
                goto continue
            end

            containers[row.id] = {
                id = row.id,
                type = row.type,
                coords = vector3(coords.x, coords.y, coords.z),
                rotation = row.rotation,
                owner = row.owner,
                locked = row.locked == 1,
                pin = row.pin,
                expiresAt = tonumber(row.expires_at),
                createdAt = tonumber(row.created_at),
                hasAccess = false,
                isTrapped = row.isTrapped == 1,
                pickupable = containerConfig.pickupable,
                lockable = containerConfig.lockable,
                trapable = containerConfig.trapable,
                weight = containerConfig.weight,
                slots = containerConfig.slots,
                model = containerConfig.model
            }

            if Inventory == 'ox' then
                exports.ox_inventory:RegisterStash(row.id, containerConfig.label, containerConfig.slots, containerConfig.weight)
            elseif Inventory == 'qb' then
                exports['qb-inventory']:CreateInventory(row.id, {
                    label = containerConfig.label,
                    maxweight = containerConfig.weight,
                    slots = containerConfig.slots
                })
            end
            ::continue::
        end

        containerCount = #result
        print(("[v-containers] Loaded %d containers from the database."):format(containerCount))

        CreateThread(function()
            Wait(2000)
            for _, playerId in pairs(GetPlayers()) do
                TriggerClientEvent('v-containers:client:syncContainers', playerId, containers)
            end
        end)
    end
end

function SaveContainer(containerData)
    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:execute('INSERT INTO v_containers (id, type, coords, rotation, owner, locked, pin, expires_at, isTrapped, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
            containerData.id,
            containerData.type,
            json.encode({x = containerData.coords.x, y = containerData.coords.y, z = containerData.coords.z}),
            containerData.rotation or 0.0,
            containerData.owner,
            containerData.locked,
            containerData.pin,
            containerData.expiresAt,
            containerData.isTrapped,
            containerData.createdAt
        })
    end
end

function UpdateContainer(containerId, updates)
    if not containers[containerId] then return end

    local setClause = {}
    local values = {}

    for key, value in pairs(updates) do
        if key == 'coords' then
            table.insert(setClause, 'coords = ?')
            table.insert(values, json.encode({x = value.x, y = value.y, z = value.z}))
        elseif key == 'locked' or key == 'pin' or key == 'expiresAt' or key == 'rotation' or key == 'isTrapped' then
            local dbKey = key == 'expiresAt' and 'expires_at' or key
            table.insert(setClause, dbKey .. ' = ?')
            table.insert(values, value)
        end
        containers[containerId][key] = value
    end

    if #setClause > 0 and GetResourceState('oxmysql') == 'started' then
        table.insert(values, containerId)
        local query = 'UPDATE v_containers SET ' .. table.concat(setClause, ', ') .. ' WHERE id = ?'
        exports.oxmysql:execute(query, values)
    end
end

function DeleteContainer(containerId)
    if not containers[containerId] then return end
    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:execute('DELETE FROM v_containers WHERE id = ?', {containerId})
    end
    if Inventory == 'qb' then
        exports['qb-inventory']:RemoveInventory(containerId)
    elseif Inventory == 'ox' then

    end
    containers[containerId] = nil
end

function GenerateContainerId()
    containerCount = containerCount + 1
    return 'container_' .. tostring(containerCount) .. '_' .. string.gsub(tostring(os.time()), '0', '') .. math.random(1000, 9999)
end

RegisterServerEvent('v-containers:server:placeContainer', function(containerType, coords, rotation)
    local source = source
    if IsPlayerOnCooldown(source) then return end

    local xPlayer = GetPlayer(source)
    if not xPlayer then return end

    if not coords or type(coords) ~= 'vector3' then return end
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    if not IsDistanceCheckValid(playerCoords, coords) then
        if SV_Config.LogSettings.securityWarning then
            LogAction("Security Warning: Invalid Placement Coords",
                string.format("Player tried to place a container too far away.\nPlayer Coords: `%s`\nTarget Coords: `%s`", tostring(playerCoords), tostring(coords)),
                16776960,
                GetPlayerAuthorInfo(xPlayer, source))
        end
        return
    end

    local containerConfig = Config.Containers[containerType]
    if not containerConfig then return end

    if GetItemCount(xPlayer, containerType) < 1 then
        ShowNotification(source, Config.Notifications.no_container_item)
        return
    end

    local containerId = GenerateContainerId()
    local identifier = GetPlayerIdentifier(xPlayer)
    local expiresAt = os.time() + (containerConfig.lifetime * 3600)

    local containerData = {
        id = containerId,
        type = containerType,
        coords = coords,
        rotation = rotation or 0.0,
        owner = identifier,
        locked = false,
        pin = nil,
        expiresAt = expiresAt,
        createdAt = os.time(),
        hasAccess = false,
        isTrapped = false,
        pickupable = containerConfig.placeable and containerConfig.pickupable,
        lockable = containerConfig.lockable,
        trapable = containerConfig.trapable,
        weight = containerConfig.weight,
        slots = containerConfig.slots,
        model = containerConfig.model
    }

    containers[containerId] = containerData
    RemoveItem(xPlayer, containerType, 1)

    if Inventory == 'ox' then
        exports.ox_inventory:RegisterStash(containerId, containerConfig.label, containerConfig.slots, containerConfig.weight)
    elseif Inventory == 'qb' then
        exports['qb-inventory']:CreateInventory(containerId, {label = containerConfig.label, maxweight = containerConfig.weight, slots = containerConfig.slots})
    end

    SaveContainer(containerData)
    TriggerClientEvent('v-containers:client:containerPlaced', -1, containerData)
    ShowNotification(source, Config.Notifications.container_placed)

    if SV_Config.LogSettings.placeContainer then
        LogAction("Container Placed",
            string.format("Container **%s** (`%s`) placed at `%s`.", containerType, containerId, tostring(coords)),
            3066993,
            GetPlayerAuthorInfo(xPlayer, source))
    end
end)

RegisterServerEvent('v-containers:server:pickupContainer', function(containerId)
    local source = source
    if IsPlayerOnCooldown(source) then return end

    local xPlayer = GetPlayer(source)
    if not xPlayer then return end

    local container = containers[containerId]
    if not container then
        ShowNotification(source, Config.Notifications.container_not_found)
        return
    end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    if not IsDistanceCheckValid(playerCoords, container.coords) then return end

    if not container.pickupable then
        ShowNotification(source, Config.Notifications.not_pickupable)
        return
    end

    local identifier = GetPlayerIdentifier(xPlayer)
    if Config.onlyOwnerCanPickup and container.owner ~= identifier then
        ShowNotification(source, Config.Notifications.not_owner)
        return
    end

    AddItem(xPlayer, container.type, 1)
    DeleteContainer(containerId)
    TriggerClientEvent('v-containers:client:removeContainer', -1, containerId)
    ShowNotification(source, Config.Notifications.container_pickup)

    if SV_Config.LogSettings.pickupContainer then
        LogAction("Container Picked Up",
            string.format("Container **%s** (`%s`) picked up from `%s`.", container.type, containerId, tostring(container.coords)),
            3447003,
            GetPlayerAuthorInfo(xPlayer, source))
    end
end)

RegisterServerEvent('v-containers:server:destroyContainer', function(containerId)
    local source = source
    if IsPlayerOnCooldown(source) then return end
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end

    local container = containers[containerId]
    if not container then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    if not IsDistanceCheckValid(playerCoords, container.coords) then return end

    local identifier = GetPlayerIdentifier(xPlayer)
    if Config.onlyOwnerCanDestroy and container.owner ~= identifier then
        ShowNotification(source, Config.Notifications.not_owner)
        return
    end

    local canDestroy = not (Config.useDestroyWeapon or Config.useDestoryItem)
    if Config.useDestroyWeapon and GetItemCount(xPlayer, Config.destroyWeapon) > 0 then canDestroy = true end
    if Config.useDestoryItem and GetItemCount(xPlayer, Config.destroyItem) > 0 then
        if canDestroy and not Config.useDestroyWeapon then
            RemoveItem(xPlayer, Config.destroyItem, 1)
        elseif not canDestroy then
             RemoveItem(xPlayer, Config.destroyItem, 1)
        end
        canDestroy = true
    end

    if not canDestroy then
        ShowNotification(source, "Destruction requirements not met.")
        return
    end

    local containerType, containerCoords = container.type, container.coords
    DeleteContainer(containerId)
    TriggerClientEvent('v-containers:client:removeContainer', -1, containerId)
    ShowNotification(source, Config.Notifications.container_destroyed)

    if SV_Config.LogSettings.destroyContainer then
        LogAction("Container Destroyed",
            string.format("Container **%s** (`%s`) destroyed at `%s`.", containerType, containerId, tostring(containerCoords)),
            15158332,
            GetPlayerAuthorInfo(xPlayer, source))
    end
end)

RegisterServerEvent('v-containers:server:addKeypad', function(containerId, pin)
    local source = source
    if IsPlayerOnCooldown(source) then return end

    local xPlayer = GetPlayer(source)
    if not xPlayer then return end

    local container = containers[containerId]
    if not container then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    if not IsDistanceCheckValid(playerCoords, container.coords) then return end

    if not container.lockable or container.locked then
        ShowNotification(source, container.locked and Config.Notifications.already_locked or Config.Notifications.not_lockable)
        return
    end

    local identifier = GetPlayerIdentifier(xPlayer)
    if Config.onlyOwnerCanAddKeypad and container.owner ~= identifier then
        ShowNotification(source, Config.Notifications.not_owner)
        return
    end

    local containerConfig = Config.Containers[container.type]
    if GetItemCount(xPlayer, containerConfig.keypadItem) < 1 then
        ShowNotification(source, Config.Notifications.keypad_required)
        return
    end

    RemoveItem(xPlayer, containerConfig.keypadItem, 1)

    UpdateContainer(containerId, { locked = true, pin = pin, failedAttempts = 0 })
    containers[containerId].hasAccess = false

    TriggerClientEvent('v-containers:client:updateContainer', -1, containerId, { locked = true, hasAccess = false })
    ShowNotification(source, Config.Notifications.keypad_added)

    if SV_Config.LogSettings.addKeypad then
        LogAction("Keypad Added",
            string.format("A keypad was added to container **%s** (`%s`).", container.type, containerId),
            15844367,
            GetPlayerAuthorInfo(xPlayer, source))
    end
end)

RegisterServerEvent('v-containers:server:checkPin', function(containerId, pin)
    local source = source
    if IsPlayerOnCooldown(source) then return end

    local xPlayer = GetPlayer(source)
    if not xPlayer then return end

    local container = containers[containerId]
    if not container or not container.locked then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    if not IsDistanceCheckValid(playerCoords, container.coords) then return end

    if container.temporaryLock and os.time() < container.temporaryLock then
        ShowNotification(source, Config.Notifications.temporarily_locked)
        return
    end

    if container.pin == pin then
        containers[containerId].hasAccess = true
        containers[containerId].failedAttempts = 0
        TriggerClientEvent('v-containers:client:updateContainer', source, containerId, {hasAccess = true})

        if Inventory == 'ox' then
            exports.ox_inventory:forceOpenInventory(source, 'stash', containerId)
        elseif Inventory == 'qb' then
            exports['qb-inventory']:OpenInventory(source, containerId, "stash_"..containerId)
        end
        ShowNotification(source, Config.Notifications.access_granted)
    else
        containers[containerId].failedAttempts = (containers[containerId].failedAttempts or 0) + 1
        if containers[containerId].failedAttempts >= Config.MaxPinAttempts then
            containers[containerId].temporaryLock = os.time() + Config.TemporaryLockTime
            ShowNotification(source, Config.Notifications.too_many_attempts)
        else
            ShowNotification(source, Config.Notifications.wrong_pin)
        end

        if SV_Config.LogSettings.failedPinAttempt then
            LogAction("Failed PIN Attempt",
                string.format("A wrong PIN (`%s`) was entered for container **%s** (`%s`).\nAttempt %d/%d.",
                pin, container.type, containerId, containers[containerId].failedAttempts, Config.MaxPinAttempts),
                16737380,
                GetPlayerAuthorInfo(xPlayer, source))
        end
    end
end)

RegisterServerEvent('v-containers:server:hackContainer', function(containerId)
    local source = source
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end

    local container = containers[containerId]
    if not container or not container.locked then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    if not IsDistanceCheckValid(playerCoords, container.coords) then return end
    if container.temporaryLock and os.time() < container.temporaryLock then
        ShowNotification(source, Config.Notifications.temporarily_locked)
        return
    end
    if Config.useHackItem and Config.hackItem and GetItemCount(xPlayer, Config.hackItem) < 1 then
        ShowNotification(source, string.format(Config.Notifications.hack_item_required, Config.hackItem))
        return
    end

    if SV_Config.LogSettings.hackAttempt then
        LogAction("Hacking Attempt Started",
            string.format("Player is attempting to hack container **%s** (`%s`).", container.type, containerId),
            3447003,
            GetPlayerAuthorInfo(xPlayer, source))
    end

    TriggerClientEvent('v-containers:client:startHackAttempt', source, containerId)
end)

RegisterServerEvent('v-containers:server:hackSuccess', function(containerId)
    local source = source
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end

    local container = containers[containerId]
    if not container then return end

    if container.temporaryLock and os.time() < container.temporaryLock then return end

    if Config.useHackItem and Config.hackItem then
        if GetItemCount(xPlayer, Config.hackItem) >= 1 then
            RemoveItem(xPlayer, Config.hackItem, 1)
        else
            ShowNotification(source, string.format(Config.Notifications.hack_item_required, Config.hackItem))
            return
        end
    end

    containers[containerId].hasAccess = true
    TriggerClientEvent('v-containers:client:updateContainer', source, containerId, {hasAccess = true})

    if Inventory == 'ox' then
        exports.ox_inventory:forceOpenInventory(source, 'stash', containerId)
    elseif Inventory == 'qb' then
        exports['qb-inventory']:OpenInventory(source, containerId, "stash_"..containerId)
    end
    ShowNotification(source, Config.Notifications.hack_successful)

    if SV_Config.LogSettings.hackSuccess then
        LogAction("Hack Successful",
            string.format("Container **%s** (`%s`) was successfully hacked.", container.type, containerId),
            3066993,
            GetPlayerAuthorInfo(xPlayer, source))
    end
end)

RegisterServerEvent('v-containers:server:triggerTrap', function(containerId)
    local source = source
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end

    local container = containers[containerId]
    if not container or not container.isTrapped then return end

    local containerType, containerCoords = container.type, container.coords

    if SV_Config.LogSettings.triggerTrap then
        LogAction("Container Trap Triggered",
            string.format("Trap on container **%s** (`%s`) was triggered at `%s`.", containerType, containerId, tostring(containerCoords)),
            10038562,
            GetPlayerAuthorInfo(xPlayer, source))
    end

    TriggerClientEvent('v-containers:client:triggerExplosion', -1, container.coords)
    DeleteContainer(containerId)
    TriggerClientEvent('v-containers:client:removeContainer', -1, containerId)
end)

function StartLifetimeCheck()
    CreateThread(function()
        while true do
            Wait(60000)
            local currentTime = os.time()
            local expiredContainers = {}

            for id, container in pairs(containers) do
                if container.expiresAt and currentTime >= container.expiresAt then
                    table.insert(expiredContainers, id)
                elseif container.temporaryLock and currentTime >= container.temporaryLock then
                    containers[id].temporaryLock = nil
                    containers[id].failedAttempts = 0
                end
            end

            for _, id in ipairs(expiredContainers) do
                if containers[id] then
                    print(("[v-containers] Container %s has expired and is being removed."):format(id))
                    DeleteContainer(id)
                    TriggerClientEvent('v-containers:client:removeContainer', -1, id)
                end
            end
        end
    end)
end

RegisterNetEvent('v-containers:server:playerLoaded', function()
    local source = source

    CreateThread(function()
        Wait(5000)
        for id, _ in pairs(containers) do
            containers[id].hasAccess = false
        end
        TriggerClientEvent('v-containers:client:syncContainers', source, containers)
        print(("[v-containers] Synced %d containers for player %s."):format(table.maxn(containers), source))
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CreateThread(function()
            Wait(5000)

            for _, playerId in pairs(GetPlayers()) do
                TriggerClientEvent('v-containers:client:syncContainers', playerId, containers)
            end
            print("[v-containers] Resource started, containers synced for all players.")
        end)
    end
end)

RegisterServerEvent('v-containers:server:openContainer', function(containerId)
    local source = source
    local container = containers[containerId]
    if not container then
        ShowNotification(source, Config.Notifications.container_not_found)
        return
    end

    if container.locked and not container.hasAccess then
        ShowNotification(source, "You don't have access to this container.")
        return
    end

    if Inventory == 'ox' then
        exports.ox_inventory:forceOpenInventory(source, 'stash', containerId)
    elseif Inventory == 'qb' then
        exports['qb-inventory']:OpenInventory(source, containerId, "stash_"..containerId)
    end
end)

RegisterServerEvent('v-containers:server:repairContainer', function(containerId)
    local source = source

    local xPlayer = GetPlayer(source)
    if not xPlayer then return end
    local container = containers[containerId]
    if not container then return end

    local identifier = GetPlayerIdentifier(xPlayer)
    if Config.onlyOwnerCanRepair and container.owner ~= identifier then
        ShowNotification(source, Config.Notifications.not_owner)
        return
    end
    local containerConfig = Config.Containers[container.type]
    local repairKit = containerConfig.repairItem
    if not repairKit then
        ShowNotification(source, Config.Notifications.no_repair_item_defined)
        return
    end
    if GetItemCount(xPlayer, repairKit) < 1 then
        ShowNotification(source, Config.Notifications.repair_failed)
        return
    end
    RemoveItem(xPlayer, repairKit, 1)
    local repairConfig = Config.RepairKits[repairKit]
    if not repairConfig then
        ShowNotification(source, Config.Notifications.invalid_repair_kit)
        return
    end
    local newExpiryTime = container.expiresAt + (repairConfig.timeExtension * 3600)
    UpdateContainer(containerId, { expiresAt = newExpiryTime })
    ShowNotification(source, Config.Notifications.repair_success)
end)

RegisterServerEvent('v-containers:server:checkLifetime', function(containerId)
    local source = source

    local xPlayer = GetPlayer(source)
    if not xPlayer then return end
    local container = containers[containerId]
    if not container then return end

    local identifier = GetPlayerIdentifier(xPlayer)
    if Config.onlyOwnerCanCheckLifetime and container.owner ~= identifier then
        ShowNotification(source, Config.Notifications.not_owner)
        return
    end
    local timeLeft = container.expiresAt - os.time()
    if timeLeft <= 0 then
        ShowNotification(source, Config.Notifications.lifetime_expired)
    else
        local hoursLeft = math.floor(timeLeft / 3600)
        local minutesLeft = math.floor((timeLeft % 3600) / 60)
        ShowNotification(source, string.format(Config.Notifications.lifetime_check, hoursLeft, minutesLeft))
    end
end)

RegisterServerEvent('v-containers:server:installTrap', function(containerId)
    local source = source

    local xPlayer = GetPlayer(source)
    if not xPlayer then return end
    local container = containers[containerId]
    if not container then return end

    local identifier = GetPlayerIdentifier(xPlayer)
    if Config.onlyOwnerCanInstallTrap and container.owner ~= identifier then
        ShowNotification(source, Config.Notifications.not_owner)
        return
    end
    local containerConfig = Config.Containers[container.type]
    if not containerConfig.trapable or container.isTrapped then
        ShowNotification(source, container.isTrapped and Config.Notifications.container_already_trapped or Config.Notifications.not_trapable)
        return
    end
    if not containerConfig.trapItem or GetItemCount(xPlayer, containerConfig.trapItem) < 1 then
        ShowNotification(source, Config.Notifications.no_trap_item)
        return
    end
    RemoveItem(xPlayer, containerConfig.trapItem, 1)
    if math.random(100) <= Config.InstallTrapFailChance then
        TriggerClientEvent('v-containers:client:playerExplode', source, GetEntityCoords(GetPlayerPed(source)))
        ShowNotification(source, Config.Notifications.trap_install_failed)
    else
        UpdateContainer(containerId, { isTrapped = true })
        TriggerClientEvent('v-containers:client:updateContainer', -1, containerId, { isTrapped = true })
        ShowNotification(source, Config.Notifications.trap_installed)
    end
end)