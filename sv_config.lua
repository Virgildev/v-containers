SV_Config = {}

SV_Config.Webhook = '' -- ur webhook here for logging

SV_Config.LogSettings = {
    placeContainer = true,
    pickupContainer = true,
    destroyContainer = true,
    hackAttempt = true,
    hackSuccess = true,
    addKeypad = true,
    triggerTrap = true,
    failedPinAttempt = true,
    securityWarning = true -- Logs potential exploits like event spam or distance cheating
}

SV_Config.ActionCooldown = 2.0 -- Cooldown in seconds for some actions to prevent spam
SV_Config.MaxInteractionDistance = 7.0 -- Max distance in meters a player can be from a container to interact with it
