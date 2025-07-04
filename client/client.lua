local Framework = nil
local FrameworkObject = nil
local Inventory = nil
local PlayerData = {}
local placingContainer = false
local previewObject = nil
local containers = {}

CreateThread(function()
    if Config.Framework == 'auto' then
        if GetResourceState('es_extended') == 'started' then
            Config.Framework = 'esx'
        elseif GetResourceState('qbx_core') == 'started' then
            Config.Framework = 'qbx'
        elseif GetResourceState('qb-core') == 'started' then
            Config.Framework = 'qb'
        end
    end

    if Config.Inventory == 'auto' then
        if GetResourceState('ox_inventory') == 'started' then
            Config.Inventory = 'ox'
        elseif GetResourceState('qb-inventory') == 'started' then
            Config.Inventory = 'qb'
        elseif GetResourceState('esx_inventoryhud') == 'started' then
            Config.Inventory = 'esx'
        end
    end

    Framework = Config.Framework
    Inventory = Config.Inventory

    InitializeFramework()
end)

function GetProgressFunction()
    if Inventory == 'ox' or Framework == 'qbx' then
        return lib and lib.progressBar or nil
    elseif Framework == 'qb' then
        return function(data, onFinishCb)
            QBCore.Functions.Progressbar(
                data.name or "progress",
                data.label or "Processing...",
                data.duration or 3000,
                data.useWhileDead or false,
                data.canCancel or true,
                data.disableControls or {},
                data.animation or {},
                data.prop or {},
                data.propTwo or {},
                onFinishCb,
                data.onCancel or function() end
            )
        end
    elseif Framework == 'esx' then
        return function(data, onFinishCb)
            exports["esx_progressbar"]:Progressbar(
                data.label or "Processing...",
                data.duration or 3000,
                {
                    FreezePlayer = data.freezePlayer or false,
                    animation = data.animation or {},
                    onFinish = onFinishCb,
                    onCancel = data.onCancel or function() end
                }
            )
        end
    end
    return nil
end

function DoProgressBar(options)
    local progressFunc = GetProgressFunction()
    if not progressFunc then
        Wait(options.duration or 1000)
        return true
    end

    if Inventory == 'ox' or Framework == 'qbx' then
        return progressFunc(options)
    elseif Framework == 'qb' then
        local p = promise.new()
        local anim = options.anim or {}
        local qbAnimation = nil
        if anim.dict and anim.clip then
            qbAnimation = {
                animDict = anim.dict,
                anim = anim.clip,
                flags = anim.flags or 49
            }
        end

        local qbOptions = {
            name = options.name or 'progressbar_action',
            label = options.label or 'Processing...',
            duration = options.duration or 1500,
            useWhileDead = options.useWhileDead or false,
            canCancel = options.canCancel ~= false,
            disableControls = options.disable or {},
            animation = qbAnimation,
            prop = options.prop,
            propTwo = options.propTwo,
        }

        QBCore.Functions.Progressbar(
            qbOptions.name,
            qbOptions.label,
            qbOptions.duration,
            qbOptions.useWhileDead,
            qbOptions.canCancel,
            qbOptions.disableControls,
            qbOptions.animation,
            qbOptions.prop,
            qbOptions.propTwo,
            function() p:resolve(true) end,
            function() p:resolve(false) end
        )
        return Citizen.Await(p)
    elseif Framework == 'esx' then
        local p = promise.new()
        options.onFinish = function()
            p:resolve(true)
        end
        options.onCancel = function()
            p:resolve(false)
        end
        progressFunc(options, options.onFinish)
        return Citizen.Await(p)
    end
    return true
end

function InitializeFramework()
    if Framework == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
        FrameworkObject = ESX

        RegisterNetEvent('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
            TriggerServerEvent('v-containers:server:playerLoaded')
        end)

        RegisterNetEvent('esx:setJob', function(job)
            PlayerData.job = job
        end)

    elseif Framework == 'qb' then
        QBCore = exports['qb-core']:GetCoreObject()
        FrameworkObject = QBCore

        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = FrameworkObject.Functions.GetPlayerData()
            TriggerServerEvent('v-containers:server:playerLoaded')
        end)

        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
            PlayerData.job = job
        end)

        RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
            PlayerData = {}
        end)

    elseif Framework == 'qbx' then
        local QBX = exports['qb-core']:GetCoreObject()
        FrameworkObject = QBX

        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = QBX.PlayerData
            TriggerServerEvent('v-containers:server:playerLoaded')
        end)

        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
            PlayerData.job = job
        end)

        RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
            PlayerData = {}
        end)
    end
end

function ShowNotification(msg)
    if Framework == 'esx' then
        FrameworkObject.ShowNotification(msg)
    elseif Framework == 'qb' then
        FrameworkObject.Functions.Notify(msg)
    elseif Framework == 'qbx' then
        exports.qbx_core:Notify(msg)
    end
end

function ShowTextUI(text)
    if Inventory == 'ox' or Framework == 'qbx' then
        lib.showTextUI(text)
    elseif Framework == 'qb' then
        exports['qb-core']:DrawText(text)
    elseif Framework == 'esx' then
        exports['esx_textui']:TextUI(text, 'info')
    end
end

function HideTextUI()
    if Inventory == 'ox' or Framework == 'qbx' then
        lib.hideTextUI()
    elseif Framework == 'qb' then
        exports['qb-core']:HideText()
    elseif Framework == 'esx' then
        exports['esx_textui']:HideUI()
    end
end

RegisterNetEvent('v-containers:client:useContainer', function(item)
    if placingContainer then return end

    local containerType = item.name or item
    local containerData = Config.Containers[containerType]
    if not containerData then
        return
    end

    StartPlacingContainer(containerType, containerData)
end)

function StartPlacingContainer(containerType, containerData)
    placingContainer = true
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local progressSuccess = DoProgressBar({
        duration = 2000,
        label = 'Preparing container...',
        useWhileDead = false,
        canCancel = false,
        disable = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped',
        }
    })

    if not progressSuccess then
        placingContainer = false
        return
    end

    RequestModel(containerData.model)
    while not HasModelLoaded(containerData.model) do
        Wait(1)
    end

    local minDim, maxDim = GetModelDimensions(containerData.model)
    local modelHeightOffset = math.abs(minDim.z)
    local initialZ = playerCoords.z + modelHeightOffset + 0.05

    previewObject = CreateObject(containerData.model, playerCoords.x, playerCoords.y, initialZ, false, false, false)
    SetEntityAlpha(previewObject, 150, false)
    SetEntityCollision(previewObject, false, false)
    FreezeEntityPosition(previewObject, true)

    ShowTextUI("[E] Place | [Scroll] Rotate | [Q/Z] Height | [X] Cancel")

    local placing = true
    local rotationZ = 0.0
    local heightOffset = 0.0
    local rotationSpeed = 2.0
    local heightSpeed = 0.05

    CreateThread(function()
        while placing do
            local coords = GetEntityCoords(playerPed)
            local forward = GetEntityForwardVector(playerPed)
            local placeCoords = coords + forward * 2.0

            if IsControlPressed(0, 14) then
                rotationZ = rotationZ + rotationSpeed
                if rotationZ >= 360.0 then rotationZ = 0.0 end
            elseif IsControlPressed(0, 15) then
                rotationZ = rotationZ - rotationSpeed
                if rotationZ < 0.0 then rotationZ = 360.0 end
            end

            if IsControlPressed(0, 246) then
                rotationZ = rotationZ + rotationSpeed
                if rotationZ >= 360.0 then rotationZ = 0.0 end
            end

            if IsControlPressed(0, 44) then
                heightOffset = math.min(heightOffset + heightSpeed, 3.0)
            elseif IsControlPressed(0, 20) then
                heightOffset = math.max(heightOffset - heightSpeed, -2.0)
            end

            local rayOriginZ = placeCoords.z + 5.0
            local rayEndZ = placeCoords.z - 2.0
            local foundGround, groundZ = GetGroundZFor_3dCoord(placeCoords.x, placeCoords.y, rayOriginZ, false)

            if foundGround then
                placeCoords = vector3(placeCoords.x, placeCoords.y, groundZ + heightOffset + modelHeightOffset)
            else
                placeCoords = vector3(placeCoords.x, placeCoords.y, placeCoords.z + heightOffset)
            end

            SetEntityCoords(previewObject, placeCoords.x, placeCoords.y, placeCoords.z, false, false, false, true)
            SetEntityRotation(previewObject, 0.0, 0.0, rotationZ, 2, false)

            if IsControlJustPressed(0, 38) then
                if IsLocationValid(placeCoords, containerData.size) then
                    local placeSuccess = DoProgressBar({
                        duration = 3000,
                        label = 'Placing container...',
                        useWhileDead = false,
                        canCancel = true,
                        disable = {
                            disableMovement = true,
                            disableCarMovement = true,
                            disableMouse = false,
                            disableCombat = true,
                        },
                        anim = {
                            dict = 'mini@repair',
                            clip = 'fixing_a_ped',
                        }
                    })

                    if placeSuccess then
                        TriggerServerEvent('v-containers:server:placeContainer', containerType, placeCoords, rotationZ)
                        placing = false
                        placingContainer = false
                        DeleteObject(previewObject)
                        HideTextUI()
                    end
                else
                    ShowNotification(Config.Notifications.invalid_location)
                end
            elseif IsControlJustPressed(0, 73) then
                placing = false
                placingContainer = false
                DeleteObject(previewObject)
                HideTextUI()
            end

            Wait(0)
        end
    end)
end

function IsLocationValid(coords, size)
    local minDistance = 2.0

    for _, container in pairs(containers) do
        if container.coords and #(coords - container.coords) < minDistance then
            return false
        end
    end

    local ray = StartExpensiveSynchronousShapeTestLosProbe(coords.x, coords.y, coords.z + 5.0, coords.x, coords.y, coords.z - 2.0, 1, 0, 4)
    local _, hit, _, _, _ = GetShapeTestResult(ray)

    return hit
end

RegisterNetEvent('v-containers:client:containerPlaced', function(containerData)
    containers[containerData.id] = containerData
    SpawnContainer(containerData)
end)

RegisterNetEvent('v-containers:client:syncContainers', function(containerData)
    for containerId, container in pairs(containers) do
        if container.object and DoesEntityExist(container.object) then
            if Framework == 'qb' then
                exports['qb-target']:RemoveTargetEntity(container.object, 'Open Container')
                exports['qb-target']:RemoveTargetEntity(container.object, 'Enter PIN')
                exports['qb-target']:RemoveTargetEntity(container.object, 'Hack Container')
                exports['qb-target']:RemoveTargetEntity(container.object, 'Pick Up Container')
                exports['qb-target']:RemoveTargetEntity(container.object, 'Destroy Container')
                exports['qb-target']:RemoveTargetEntity(container.object, 'Add Keypad')
                exports['qb-target']:RemoveTargetEntity(container.object, 'Add Trap')
                exports['qb-target']:RemoveTargetEntity(container.object, 'Repair Container')
                exports['qb-target']:RemoveTargetEntity(container.object, 'Check Lifetime')
            else
                exports.ox_target:removeLocalEntity(container.object)
            end
            DeleteObject(container.object)
        end
    end

    containers = {}

    Wait(100)

    containers = containerData
    for _, container in pairs(containers) do
        SpawnContainer(container)
    end
end)

RegisterNetEvent('v-containers:client:removeContainer', function(containerId)
    if containers[containerId] then
        if containers[containerId].object and DoesEntityExist(containers[containerId].object) then
            if Framework == 'qb' then
                exports['qb-target']:RemoveTargetEntity(containers[containerId].object, 'Open Container')
                exports['qb-target']:RemoveTargetEntity(containers[containerId].object, 'Enter PIN')
                exports['qb-target']:RemoveTargetEntity(containers[containerId].object, 'Hack Container')
                exports['qb-target']:RemoveTargetEntity(containers[containerId].object, 'Pick Up Container')
                exports['qb-target']:RemoveTargetEntity(containers[containerId].object, 'Destroy Container')
                exports['qb-target']:RemoveTargetEntity(containers[containerId].object, 'Add Keypad')
                exports['qb-target']:RemoveTargetEntity(containers[containerId].object, 'Add Trap')
                exports['qb-target']:RemoveTargetEntity(containers[containerId].object, 'Repair Container')
                exports['qb-target']:RemoveTargetEntity(containers[containerId].object, 'Check Lifetime')
            else
                exports.ox_target:removeLocalEntity(containers[containerId].object)
            end
            DeleteObject(containers[containerId].object)
        end

        containers[containerId] = nil
    end
end)

function SpawnContainer(containerData)
    if containers[containerData.id] and containers[containerData.id].object then
        local existingObj = containers[containerData.id].object
        if DoesEntityExist(existingObj) then
            if Framework == 'qb' then
                exports['qb-target']:RemoveTargetEntity(existingObj, 'Open Container')
                exports['qb-target']:RemoveTargetEntity(existingObj, 'Enter PIN')
                exports['qb-target']:RemoveTargetEntity(existingObj, 'Hack Container')
                exports['qb-target']:RemoveTargetEntity(existingObj, 'Pick Up Container')
                exports['qb-target']:RemoveTargetEntity(existingObj, 'Destroy Container')
                exports['qb-target']:RemoveTargetEntity(existingObj, 'Add Keypad')
                exports['qb-target']:RemoveTargetEntity(existingObj, 'Add Trap')
                exports['qb-target']:RemoveTargetEntity(existingObj, 'Repair Container')
                exports['qb-target']:RemoveTargetEntity(existingObj, 'Check Lifetime')
            else
                exports.ox_target:removeLocalEntity(existingObj)
            end
            DeleteObject(existingObj)
        end
    end

    RequestModel(containerData.model)
    while not HasModelLoaded(containerData.model) do
        Wait(1)
    end

    local obj = CreateObject(containerData.model, containerData.coords.x, containerData.coords.y, containerData.coords.z, true, false, true)

    ActivatePhysics(obj)
    PlaceObjectOnGroundProperly(obj)

    if containerData.rotation then
        SetEntityHeading(obj, containerData.rotation + 0.0)
    end

    FreezeEntityPosition(obj, true)

    containers[containerData.id].object = obj

    local options = {}

    table.insert(options, {
        name = 'open_container',
        label = containerData.locked and 'Enter PIN' or 'Open Container',
        icon = containerData.locked and 'fas fa-lock' or 'fas fa-box-open',
        onSelect = function()
            HandleContainerInteraction(containerData.id, 'open')
        end
    })

    if containerData.locked then
        table.insert(options, {
            name = 'hack_container',
            label = 'Hack Container',
            icon = 'fas fa-user-secret',
            onSelect = function()
                HandleContainerInteraction(containerData.id, 'hack')
            end
        })
    end

    if containerData.pickupable then
        table.insert(options, {
            name = 'pickup_container',
            label = 'Pick Up Container',
            icon = 'fas fa-hand-paper',
            onSelect = function()
                HandleContainerInteraction(containerData.id, 'pickup')
            end
        })
    end

    table.insert(options, {
        name = 'destroy_container',
        label = 'Destroy Container',
        icon = 'fas fa-trash',
        onSelect = function()
            HandleContainerInteraction(containerData.id, 'destroy')
        end
    })

    if containerData.lockable and not containerData.locked then
        table.insert(options, {
            name = 'add_keypad',
            label = 'Add Keypad',
            icon = 'fas fa-lock',
            onSelect = function()
                HandleContainerInteraction(containerData.id, 'addKeypad')
            end
        })
    end

    if containerData.trapable and not containerData.isTrapped then
        table.insert(options, {
            name = 'add_trap',
            label = 'Add Trap',
            icon = 'fas fa-bomb',
            onSelect = function()
                HandleContainerInteraction(containerData.id, 'addTrap')
            end
        })
    end

    table.insert(options, {
        name = 'repair_container',
        label = 'Repair Container',
        icon = 'fas fa-wrench',
        onSelect = function()
            HandleContainerInteraction(containerData.id, 'repair')
        end
    })

    table.insert(options, {
        name = 'check_lifetime',
        label = 'Check Lifetime',
        icon = 'fas fa-clock',
        onSelect = function()
            HandleContainerInteraction(containerData.id, 'checkLifetime')
        end
    })

    if Framework == 'qb' then
        local qb_target_options = {}
        for _, opt in pairs(options) do
            table.insert(qb_target_options, {
                event = "v-containers:client:targetInteraction",
                icon = opt.icon,
                label = opt.label,
                id = containerData.id,
                action_type = opt.name,
                action = function()
                    opt.onSelect()
                end
            })
        end
        exports['qb-target']:AddTargetEntity(obj, {
            options = qb_target_options,
            distance = 2.0
        })
    else
        exports.ox_target:addLocalEntity(obj, options)
    end
end

function HandleContainerInteraction(containerId, action)
    local container = containers[containerId]
    if not container then return end

    if action == 'open' then
        if container.isTrapped then
            TriggerServerEvent('v-containers:server:triggerTrap', containerId)
        elseif container.locked then
            OpenPinPad(containerId)
        else
            TriggerServerEvent('v-containers:server:openContainer', containerId)
        end
    elseif action == 'hack' then
        if Config.useHackItem and Config.hackItem then
            local hasItem = false
            if Inventory == 'ox' then
                hasItem = exports.ox_inventory:GetItemCount(Config.hackItem) > 0
            elseif Framework == 'qb' then
                hasItem = QBCore.Functions.HasItem(Config.hackItem)
            elseif Framework == 'esx' then
                hasItem = ESX.GetPlayerData().inventory[Config.hackItem] and ESX.GetPlayerData().inventory[Config.hackItem].count > 0
            end

            if not hasItem then
                ShowNotification("You are missing a item to hack the container")
                return
            end
        end
        TriggerServerEvent('v-containers:server:hackContainer', containerId)
    elseif action == 'pickup' then
        local success = DoProgressBar({
            duration = 5000,
            label = 'Picking up container...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            },
            anim = {
                dict = 'anim@heists@narcotics@trash',
                clip = 'pickup'
            }
        })
        if success then
            TriggerServerEvent('v-containers:server:pickupContainer', containerId)
        end
    elseif action == 'destroy' then
        local playerPed = PlayerPedId()
        local hasRequiredWeapon = false
        local hasRequiredItem = false

        if Config.useDestroyWeapon and Config.destroyWeapon then
            local _, currentWeapon = GetCurrentPedWeapon(playerPed, true)

            if currentWeapon ~= GetHashKey("weapon_unarmed") then
                if currentWeapon == GetHashKey(Config.destroyWeapon) then
                    hasRequiredWeapon = true
                else
                    hasRequiredWeapon = false
                end
            else
                hasRequiredWeapon = false
            end
        else
            hasRequiredWeapon = true
        end

        if Config.useDestoryItem and Config.destroyItem then
            if Inventory == 'ox' then
                hasRequiredItem = exports.ox_inventory:GetItemCount(Config.destroyItem, nil, false) > 0
            elseif Framework == 'qb' then
                hasRequiredItem = QBCore.Functions.HasItem(Config.destroyItem)
            elseif Framework == 'esx' then
                local inventory = ESX.GetPlayerData().inventory
                for _, item in pairs(inventory) do
                    if item.name == Config.destroyItem and item.count > 0 then
                        hasRequiredItem = true
                        break
                    end
                end
            end
        else
            hasRequiredItem = true
        end

        local meetsRequirements = false
        if Config.useDestroyWeapon and Config.useDestoryItem then
            meetsRequirements = hasRequiredWeapon and hasRequiredItem
        elseif Config.useDestroyWeapon then
            meetsRequirements = hasRequiredWeapon
        elseif Config.useDestoryItem then
            meetsRequirements = hasRequiredItem
        else
            meetsRequirements = true
        end

        if not meetsRequirements then
            local requiredText = ""
            if Config.useDestroyWeapon and Config.useDestoryItem then
                requiredText = string.format("You are missing a few things for this...")
            elseif Config.useDestroyWeapon then
                requiredText = string.format("Hmm have you tried hitting it?")
            elseif Config.useDestoryItem then
                requiredText = string.format("You may be missing something?")
            else
                requiredText = "You do not meet the requirements to destroy the container."
            end
            ShowNotification(requiredText)
            return
        end

        local animDict = 'amb@prop_human_bum_bin@idle_a'
        local animClip = 'idle_a'
        if hasRequiredWeapon and Config.destroyWeapon and string.find(Config.destroyWeapon, 'weapon_') then
            animDict = 'melee@large_wpn@streamed_core'
            animClip = 'ground_attack_on_spot'
        end

        local success = DoProgressBar({
            duration = 10000,
            label = 'Destroying container...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            },
            anim = {
                dict = animDict,
                clip = animClip
            }
        })

        if success then
            TriggerServerEvent('v-containers:server:destroyContainer', containerId)
        end
    elseif action == 'addKeypad' then
        local containerConfig = Config.Containers[container.type]
        if not containerConfig.keypadItem then
            ShowNotification(Config.Notifications.no_keypad_item_defined)
            return
        end

        local hasKeypadItem = false
        if Inventory == 'ox' then
            hasKeypadItem = exports.ox_inventory:GetItemCount(containerConfig.keypadItem) > 0
        elseif Framework == 'qb' then
            hasKeypadItem = QBCore.Functions.HasItem(containerConfig.keypadItem)
        elseif Framework == 'esx' then
            hasKeypadItem = ESX.GetPlayerData().inventory[containerConfig.keypadItem] and ESX.GetPlayerData().inventory[containerConfig.keypadItem].count > 0
        end

        if not hasKeypadItem then
            ShowNotification(Config.Notifications.keypad_required)
            return
        end
        AddKeypadToContainer(containerId)
    elseif action == 'addTrap' then
        local containerConfig = Config.Containers[container.type]
        if not containerConfig.trapable then
            ShowNotification(Config.Notifications.not_trapable)
            return
        end
        if container.isTrapped then
            ShowNotification(Config.Notifications.container_already_trapped)
            return
        end
        if not containerConfig.trapItem then
            ShowNotification(Config.Notifications.no_trap_item)
            return
        end

        local hasTrapItem = false
        if Inventory == 'ox' then
            hasTrapItem = exports.ox_inventory:GetItemCount(containerConfig.trapItem) > 0
        elseif Framework == 'qb' then
            hasTrapItem = QBCore.Functions.HasItem(containerConfig.trapItem)
        elseif Framework == 'esx' then
            hasTrapItem = ESX.GetPlayerData().inventory[containerConfig.trapItem] and ESX.GetPlayerData().inventory[containerConfig.trapItem].count > 0
        end

        if not hasTrapItem then
            ShowNotification(Config.Notifications.no_trap_item)
            return
        end
        InstallTrap(containerId)
    elseif action == 'repair' then
        local containerConfig = Config.Containers[container.type]
        local repairKit = containerConfig.repairItem
        if not repairKit then
            ShowNotification(Config.Notifications.no_repair_item_defined)
            return
        end

        local hasRepairKit = false
        if Inventory == 'ox' then
            hasRepairKit = exports.ox_inventory:GetItemCount(repairKit) > 0
        elseif Framework == 'qb' then
            hasRepairKit = QBCore.Functions.HasItem(repairKit)
        elseif Framework == 'esx' then
            hasRepairKit = ESX.GetPlayerData().inventory[repairKit] and ESX.GetPlayerData().inventory[repairKit].count > 0
        end

        if not hasRepairKit then
            ShowNotification(Config.Notifications.repair_failed)
            return
        end

        local success = DoProgressBar({
            duration = 8000,
            label = 'Repairing container...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            },
            anim = {
                dict = 'mini@repair',
                clip = 'fixing_a_ped'
            }
        })
        if success then
            TriggerServerEvent('v-containers:server:repairContainer', containerId)
        end
    elseif action == 'checkLifetime' then
        TriggerServerEvent('v-containers:server:checkLifetime', containerId)
    end
end

RegisterNetEvent('v-containers:client:startHackAttempt', function(containerId)
    AttemptHack(containerId)
end)

function OpenPinPad(containerId)
    local dialog
    if Inventory == 'ox' or Framework == 'qbx' then
        dialog = lib.inputDialog('Enter PIN', {
            {type = 'number', label = 'PIN Code', description = 'Enter the 4-digit PIN', required = true, min = 1000, max = 9999}
        })
    elseif Framework == 'qb' then
        dialog = exports['qb-input']:ShowInput({
            header = "Container PIN",
            submitText = "Enter",
            inputs = {
                {
                    text = "PIN Code",
                    name = "pin",
                    type = "number",
                    isRequired = true
                }
            }
        })
    elseif Framework == 'esx' then
        ESX.UI.ShowInput({
            title = "Enter PIN",
            hint = "4-digit PIN",
            type = 'number',
            maxlength = 4
        }, function(input)
            if input and tonumber(input) then
                TriggerServerEvent('v-containers:server:checkPin', containerId, tostring(input))
            else
                ShowNotification("Invalid PIN format.")
            end
        end)
        return
    end

    if dialog then
        local pin = dialog[1] or dialog.pin
        if pin then
            TriggerServerEvent('v-containers:server:checkPin', containerId, tostring(pin))
        end
    end
end

function AttemptHack(containerId)
    local container = containers[containerId]
    local containerConfig = Config.Containers[container.type]

    local success = DoProgressBar({
        duration = 15000,
        label = 'Hacking container...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        anim = {
            dict = 'mp_prison_break',
            clip = 'hack_loop'
        }
    })

    if not success then return end

    local minigameType = Framework
    if Inventory == 'ox' or Framework == 'qbx' then
        minigameType = 'ox'
    end

    local hackSuccess = false
    if Config.Minigames and Config.Minigames[minigameType] then
        hackSuccess = Config.Minigames[minigameType]()
    else
        hackSuccess = math.random(1, 100) <= 25
    end

    if hackSuccess then
        TriggerServerEvent('v-containers:server:hackSuccess', containerId)
    else
        ShowNotification(Config.Notifications.hack_failed)
    end
end

function AddKeypadToContainer(containerId)
    local container = containers[containerId]
    local containerConfig = Config.Containers[container.type]

    local dialog
    if Inventory == 'ox' or Framework == 'qbx' then
        dialog = lib.inputDialog('Set PIN', {
            {type = 'number', label = 'PIN Code', description = 'Set a 4-digit PIN', required = true, min = 1000, max = 9999}
        })
    elseif Framework == 'qb' then
        dialog = exports['qb-input']:ShowInput({
            header = "Set Container PIN",
            submitText = "Set PIN",
            inputs = {
                {
                    text = "PIN Code",
                    name = "pin",
                    type = "number",
                    isRequired = true
                }
            }
        })
    elseif Framework == 'esx' then
        ESX.UI.ShowInput({
            title = "Set PIN",
            hint = "4-digit PIN",
            type = 'number',
            maxlength = 4
        }, function(input)
            if input and tonumber(input) then
                local success = DoProgressBar({
                    duration = 6000,
                    label = 'Installing keypad...',
                    useWhileDead = false,
                    canCancel = true,
                    disable = {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true,
                    },
                    anim = {
                        dict = 'mini@repair',
                        clip = 'fixing_a_ped'
                    }
                })

                if success then
                    TriggerServerEvent('v-containers:server:addKeypad', containerId, tostring(input))
                end
            else
                ShowNotification("Invalid PIN format.")
            end
        end)
        return
    end

    if dialog then
        local pin = dialog[1] or dialog.pin
        if pin then
            local success = DoProgressBar({
                duration = 6000,
                label = 'Installing keypad...',
                useWhileDead = false,
                canCancel = true,
                disable = {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                },
                anim = {
                    dict = 'mini@repair',
                    clip = 'fixing_a_ped'
                }
            })

            if success then
                TriggerServerEvent('v-containers:server:addKeypad', containerId, tostring(pin))
            end
        end
    end
end

function InstallTrap(containerId)
    local success = DoProgressBar({
        duration = 8000,
        label = 'Installing trap...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        anim = {
            dict = 'amb@world_human_gardener_plant@male@base',
            clip = 'base'
        }
    })

    if success then
        TriggerServerEvent('v-containers:server:installTrap', containerId)
    end
end

RegisterNetEvent('v-containers:client:triggerExplosion', function(coords)
    AddExplosion(coords.x, coords.y, coords.z, Config.ExplosionSettings.explosionType, Config.ExplosionSettings.damageScale, Config.ExplosionSettings.isAudible, Config.ExplosionSettings.isInvisible, Config.ExplosionSettings.cameraShake)
    ShowNotification(Config.Notifications.trap_triggered)
end)

RegisterNetEvent('v-containers:client:playerExplode', function(coords)
    AddExplosion(coords.x, coords.y, coords.z, Config.ExplosionSettings.explosionType, Config.ExplosionSettings.damageScale, Config.ExplosionSettings.isAudible, Config.ExplosionSettings.isInvisible, Config.ExplosionSettings.cameraShake)
    ShowNotification(Config.Notifications.trap_install_failed)
end)

RegisterNetEvent('v-containers:client:updateContainer', function(containerId, updates)
    if containers[containerId] then
        for k, v in pairs(updates) do
            containers[containerId][k] = v
        end
        SpawnContainer(containers[containerId])
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, container in pairs(containers) do
            if container.object and DoesEntityExist(container.object) then
                if Framework == 'qb' then
                    exports['qb-target']:RemoveTargetEntity(container.object, 'Open Container')
                    exports['qb-target']:RemoveTargetEntity(container.object, 'Enter PIN')
                    exports['qb-target']:RemoveTargetEntity(container.object, 'Hack Container')
                    exports['qb-target']:RemoveTargetEntity(container.object, 'Pick Up Container')
                    exports['qb-target']:RemoveTargetEntity(container.object, 'Destroy Container')
                    exports['qb-target']:RemoveTargetEntity(container.object, 'Add Keypad')
                    exports['qb-target']:RemoveTargetEntity(container.object, 'Add Trap')
                    exports['qb-target']:RemoveTargetEntity(container.object, 'Repair Container')
                    exports['qb-target']:RemoveTargetEntity(container.object, 'Check Lifetime')
                else
                    exports.ox_target:removeLocalEntity(container.object)
                end
                DeleteObject(container.object)
            end
        end

        if previewObject and DoesEntityExist(previewObject) then
            DeleteObject(previewObject)
        end
    end
end
)