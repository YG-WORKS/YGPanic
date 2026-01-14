-- client.lua
local isAuthorized = false
local isOnCooldown = false
local departmentCounts = {}
local isUIVisible = true
local currentDepartment = nil

-- Configuration for Unit Counter UI
local UIConfig = {
    Position = {
        x = 0.885, -- X position (0.0 = left, 1.0 = right)
        y = 0.015   -- Y position (0.0 = top, 1.0 = bottom)
    },
    UpdateInterval = 5000, -- Update every 5 seconds
    ShowOffline = true -- Show departments with 0 units
}

-- Initialize department counts
CreateThread(function()
    for deptKey, deptData in pairs(Config.Departments) do
        departmentCounts[deptKey] = 0
    end
end)

-- Handle duress alert
RegisterNetEvent('custompanic:alert')
AddEventHandler('custompanic:alert', function(coords, name, department)
    -- Play duress sound
    SendNUIMessage({ action = 'playSound' })
    
    -- Add blip and waypoint
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.Blip.Sprite)
    SetBlipColour(blip, Config.Blip.Color)
    SetBlipScale(blip, Config.Blip.Scale)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Duress Alert: ' .. name)
    EndTextCommandSetBlipName(blip)
    SetNewWaypoint(coords.x, coords.y)
    
    -- Chat message
    TriggerEvent('chat:addMessage', {
        color = {255, 0, 0},
        args = {'^1[DURESS ALERT]', name .. ' (' .. department:upper() .. ') has triggered their duress alarm!'}
    })
    
    -- Remove blip after duration
    Citizen.CreateThread(function()
        Citizen.Wait(Config.Blip.Duration * 1000)
        RemoveBlip(blip)
    end)
end)

-- Duress command
RegisterCommand('duress', function()
    if not isAuthorized then
        TriggerEvent('chat:addMessage', { args = { '^1[DURESS]', 'You are not authorized. Use /duresslogin <password> first.' } })
        return
    end
    
    if isOnCooldown then
        TriggerEvent('chat:addMessage', { args = { '^1[DURESS]', 'You must wait before sending another duress alert!' } })
        return
    end
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local name = GetPlayerName(PlayerId())
    
    TriggerServerEvent('custompanic:trigger', coords, name)
    
    -- Start cooldown
    isOnCooldown = true
    Citizen.CreateThread(function()
        local timeLeft = Config.Cooldown
        while timeLeft > 0 do
            Citizen.Wait(1000)
            timeLeft = timeLeft - 1
        end
        isOnCooldown = false
        TriggerEvent('chat:addMessage', { args = { '^2[DURESS]', 'You may now use /duress again.' } })
    end)
end, false)

-- Login command
RegisterCommand('duresslogin', function(source, args)
    local department = args[1]
    local password = args[2]
    
    if not password or not department then
        TriggerEvent('chat:addMessage', {
            args = { '^1Usage', '/duresslogin <police|fire|ems> <password>' }
        })
        return
    end
    
    department = string.lower(department)
    
    if department ~= 'police' and department ~= 'fire' and department ~= 'ems' then
        TriggerEvent('chat:addMessage', {
            args = { '^1[YGPANIC]', 'Invalid department. Use police, fire, or ems.' }
        })
        return
    end
    
    TriggerServerEvent('custompanic:verifyPassword', password, department)
end, false)

-- Auth success / fail
RegisterNetEvent('custompanic:authSuccess')
AddEventHandler('custompanic:authSuccess', function(department)
    isAuthorized = true
    currentDepartment = department
    TriggerEvent('chat:addMessage', { args = { '^2[DURESS]', 'You are now authorized to use /duress.' } })
    
    -- Notify server of department assignment
    TriggerServerEvent('custompanic:setDepartment', department)
end)

RegisterNetEvent('custompanic:authFailed')
AddEventHandler('custompanic:authFailed', function()
    TriggerEvent('chat:addMessage', { args = { '^1[DURESS]', 'Invalid password.' } })
end)

-- Logout command
RegisterCommand('duresslogout', function()
    if isAuthorized then
        TriggerServerEvent('custompanic:logout')
        isAuthorized = false
        currentDepartment = nil
        TriggerEvent('chat:addMessage', { args = { '^3[DURESS]', 'You have been logged out.' } })
        
        -- Request updated counts immediately
        Wait(100)
        RequestUnitCounts()
    else
        TriggerEvent('chat:addMessage', { args = { '^1[DURESS]', 'You are not logged in.' } })
    end
end, false)

-- Toggle unit counter UI
RegisterCommand('toggleunits', function()
    isUIVisible = not isUIVisible
    SendNUIMessage({
        type = 'toggleUI',
        visible = isUIVisible
    })
    TriggerEvent('chat:addMessage', { 
        args = { '^3[YGPANIC]', 'Unit counter ' .. (isUIVisible and 'shown' or 'hidden') } 
    })
end, false)

-- Request unit counts from server
function RequestUnitCounts()
    TriggerServerEvent('custompanic:requestUnitCounts')
end

-- Receive unit counts from server
RegisterNetEvent('custompanic:receiveUnitCounts')
AddEventHandler('custompanic:receiveUnitCounts', function(counts)
    departmentCounts = counts
end)

-- Initialize UI and start update loop
CreateThread(function()
    Wait(1000)
    
    -- Build departments config for NUI
    local deptConfig = {}
    for deptKey, deptData in pairs(Config.Departments) do
        table.insert(deptConfig, {
            name = deptKey,
            displayName = deptData.name,
            color = deptData.color
        })
    end
    
    -- Send initial config to NUI
    SendNUIMessage({
        type = 'setConfig',
        config = {
            UIPosition = UIConfig.Position,
            Departments = deptConfig,
            ShowOffline = UIConfig.ShowOffline
        }
    })
    
    -- Update counts periodically
    while true do
        if isAuthorized then
            RequestUnitCounts()
        end
        Wait(UIConfig.UpdateInterval)
    end
end)

-- Update NUI when counts change
CreateThread(function()
    while true do
        Wait(500)
        SendNUIMessage({
            type = 'updateCounts',
            counts = departmentCounts
        })
    end
end)

-- Keybinds
RegisterKeyMapping('duress', 'Duress Button Keybind', 'keyboard', 'NONE')
RegisterKeyMapping('toggleunits', 'Toggle Unit Counter', 'keyboard', 'NONE')

-- Chat Suggestions
CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/duresslogin', 'Login to duress system', {
        { name = 'department', help = 'police | fire | ems' },
        { name = 'password', help = 'Your duress password' }
    })
    TriggerEvent('chat:addSuggestion', '/duress', 'Trigger duress alert')
    TriggerEvent('chat:addSuggestion', '/duresslogout', 'Logout from duress system')
    TriggerEvent('chat:addSuggestion', '/toggleunits', 'Show/hide unit counter')
end)