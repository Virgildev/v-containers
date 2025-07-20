Config = {}

Config.Framework = 'auto' -- qb, qbox or esx (recommended: auto)

Config.Inventory = 'auto' -- qb, ox, esx or codem (recommended: auto)

Config.onlyOwnerCanPickup = true -- If true, only the owner of the container can pick it up (recommended: true)
Config.onlyOwnerCanDestroy = false -- If true, only the owner of the container can destroy (recommended: false)
Config.onlyOwnerCanRepair = true -- If true, only the owner of the container can repair it (recommended: true)
Config.onlyOwnerCanAddKeypad = true -- If true, only the owner of the container (recommended: true)
Config.onlyOwnerCanCheckLifetime = true -- If true, only the owner of the container can check its lifetime (recommended: true)
Config.onlyOwnerCanSetTrap = true -- If true, only the owner of the container can check its lifetime (recommended: false)
Config.onlyOwnerCanInstallTrap = true -- If true, only the owner of the container can install traps (recommended: true)

Config.useDestroyWeapon = true -- If true, players must destroy containers with a weapon
Config.destroyWeapon = 'weapon_crowbar' -- Item or weapon required to destroy a container

-- if both item & weapon are true both are required.

Config.useDestoryItem = false -- If true, players must destroy containers with an item
Config.destroyItem = 'lockpick' -- Item required to destroy a container

Config.useHackItem = true -- If true, players can destroy containers with an item
Config.hackItem = 'lockpick' -- Item required to destroy a container

Config.InstallTrapFailChance = 30 -- Percentage chance for trap installation to fail (0-100)

Config.MaxPinAttempts = 3 -- Maximum number of failed PIN attempts before temporary lock
Config.TemporaryLockTime = 300 -- Temporary lock duration in seconds (5 minutes)

Config.Containers = {
    ['small_crate'] = { -- item name
        label = 'Small Storage Crate', -- label
        weight = 50000, -- weight of container storage
        slots = 20, --slots inside
        size = vector3(1.0, 1.0, 1.0), -- target stuff bigger prop make larger
        model = 'prop_mil_crate_02', -- prop model
        placeable = true, -- leave as true 
        pickupable = true, -- cant be picked up
        lockable = true, -- can be locked
        trapable = true, -- can be trapped
        trapItem = 'explosive_trap', -- trap item name 
        lifetime = 72, -- lifetime before it gets destroyed (hours)
        repairItem = 'repair_kit', -- item to make lifetime longer
        keypadItem = 'keypad' --keypad item
    },
    ['medium_crate'] = {
        label = 'Medium Storage Crate',
        weight = 100000,
        slots = 40,
        size = vector3(1.5, 1.5, 1.5),
        model = 'prop_mil_crate_01',
        placeable = true,
        pickupable = true,
        lockable = true,
        trapable = true,
        trapItem = 'explosive_trap',
        lifetime = 72,
        repairItem = 'repair_kit',
        keypadItem = 'keypad'
    },
    ['weapon_crate'] = {
        label = 'Weapon Storage Crate',
        weight = 75000,
        slots = 30,
        size = vector3(1.2, 1.2, 1.2),
        model = 'prop_weapon_crate_01',
        placeable = true,
        pickupable = true,
        lockable = true,
        trapable = true,
        trapItem = 'explosive_trap',
        lifetime = 96,
        repairItem = 'repair_kit',
        keypadItem = 'advanced_keypad'
    },
    ['medical_crate'] = {
        label = 'Medical Supply Crate',
        weight = 60000,
        slots = 25,
        size = vector3(1.1, 1.1, 1.1),
        model = 'prop_med_bag_01b',
        placeable = true,
        pickupable = true,
        lockable = true,
        trapable = false,
        lifetime = 48,
        repairItem = 'repair_kit',
        keypadItem = 'keypad'
    },
    ['secure_safe'] = {
        label = 'Secure Safe',
        weight = 150000,
        slots = 50,
        size = vector3(1.0, 1.0, 1.5),
        model = 'prop_ld_int_safe_01',
        placeable = true,
        pickupable = false,
        lockable = true,
        trapable = false,
        lifetime = 168,
        repairItem = 'advanced_repair_kit',
        keypadItem = 'advanced_keypad'
    },
    ['drug_stash'] = {
        label = 'Drug Stash Box',
        weight = 40000,
        slots = 15,
        size = vector3(0.8, 0.8, 0.8),
        model = 'prop_cs_cardbox_01',
        placeable = true,
        pickupable = true,
        lockable = true,
        trapable = true,
        trapItem = 'explosive_trap',
        lifetime = 24,
        repairItem = 'repair_kit',
        keypadItem = 'keypad'
    },
    ['money_case'] = {
        label = 'Money Case',
        weight = 80000,
        slots = 35,
        size = vector3(1.3, 1.0, 0.5),
        model = 'prop_security_case_01',
        placeable = true,
        pickupable = true,
        lockable = true,
        trapable = true,
        trapItem = 'explosive_trap',
        lifetime = 120,
        repairItem = 'repair_kit',
        keypadItem = 'advanced_keypad'
    },
    ['evidence_box'] = {
        label = 'Evidence Storage Box',
        weight = 90000,
        slots = 45,
        size = vector3(1.4, 1.4, 1.0),
        model = 'prop_box_ammo03a',
        placeable = true,
        pickupable = true,
        lockable = true,
        trapable = false,
        lifetime = 192,
        repairItem = 'advanced_repair_kit',
        keypadItem = 'police_keypad'
    },
}

Config.RepairKits = {
    ['repair_kit'] = {
        label = 'Repair Kit',
        timeExtension = 24
    },
    ['advanced_repair_kit'] = {
        label = 'Advanced Repair Kit',
        timeExtension = 72
    }
}

Config.Keypads = {
    ['keypad'] = {
        label = 'Basic Keypad',
    },
    ['advanced_keypad'] = {
        label = 'Advanced Keypad',
    },
    ['police_keypad'] = {
        label = 'Police Keypad',
    }
}

Config.Minigames = { -- rec just changing it for your core not the custom
    qb = function()
        local success = exports['qb-lock']:StartLockPickCircle(3, 20, success)
        return success
    end,
    ox = function()
        local success = lib.skillCheck({'easy', 'easy', 'easy'}, {'w', 'a', 's', 'd'})
        return success
    end,
    esx = function()
        local success = exports['esx_lockpick']:StartLockPicking()
        return success
    end,
    custom = function()
        local success = exports['custom_export']:start()
        return success
    end
}

Config.ExplosionSettings = {
    explosionType = 2,
    damageScale = 1.0,
    isAudible = true,
    isInvisible = false,
    cameraShake = 1.0
}

Config.Notifications = {
    container_placed = 'Container placed successfully',
    container_pickup = 'Container picked up',
    container_destroyed = 'Container destroyed',
    container_not_found = 'Container not found',
    invalid_location = 'Cannot place container here',
    no_space = 'Not enough space to place container',
    no_container_item = 'You need a container item to place',
    not_pickupable = 'This container cannot be picked up',
    not_owner = 'You are not the owner of this container',
    keypad_added = 'Keypad added to container',
    keypad_required = 'You need a keypad to secure this container',
    already_locked = 'Container is already locked',
    not_lockable = 'This container cannot be locked',
    repair_success = 'Container repaired successfully',
    repair_failed = 'You need a repair kit',
    no_repair_item_defined = 'No repair item defined for this container',
    invalid_repair_kit = 'Invalid repair kit',
    hack_success = 'Successfully hacked the container',
    hack_successful = 'Successfully hacked the container',
    hack_failed = 'Failed to hack the container',
    hack_item_required = 'You need a %s to hack this container',
    wrong_pin = 'Incorrect PIN entered',
    access_granted = 'Access granted',
    too_many_attempts = 'Too many failed attempts, container temporarily locked',
    temporarily_locked = 'Container is temporarily locked',
    pin_set = 'PIN set successfully',
    container_expired = 'Container has expired and been removed',
    lifetime_expired = 'Container has expired',
    lifetime_check = 'Container has %s hours and %s minutes remaining',
    trap_triggered = 'BOOM! The container was trapped!',
    trap_installed = 'Trap installed successfully!',
    trap_install_failed = 'You failed to install the trap!',
    no_trap_item = 'You need a trap item to install a trap!',
    container_already_trapped = 'This container already has a trap installed.',
    not_trapable = 'This container cannot have a trap installed.',
    no_keypad_item_defined = 'No keypad item defined for this container'
}