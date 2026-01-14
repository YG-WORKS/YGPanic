-- server.lua
local authorizedPlayers = {}
local activeDepartments = {}
local activeCounts = {}

-- Discord Bot Configuration
local DISCORD_BOT_TOKEN = ""  -- Replace with your bot token
local CHANNEL_ID = ""  -- Replace with your channel ID
local messageId = nil  -- Stores the message ID to edit

local function updateAgencyEmbed()
    local fields = {}
    
    for _, deptKey in ipairs(Config.DepartmentOrder) do
        if Config.Departments[deptKey] then
            local count = activeCounts[deptKey] or 0
            local deptData = Config.Departments[deptKey]
            local deptName = deptData.name or deptKey
            
            table.insert(fields, {
                name = deptName,
                value = string.format("**%02d** Units Active", count),
                inline = true
            })
        end
    end
    
    if #fields == 0 then
        print('[YGPANIC] WARNING: Config.DepartmentOrder keys do not match Config.Departments.')
        table.insert(fields, {
            name = "Error",
            value = "No departments configured",
            inline = false
        })
    end
    
    local embed = {
        embeds = {{
            title = "🚨 Active Unit Status",
            description = "Current on-duty units across all departments",
            color = 3447003,
            fields = fields,
            footer = {
                text = "Active Unit Status"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    if messageId then
        PerformHttpRequest(
            string.format("https://discord.com/api/v10/channels/%s/messages/%s", CHANNEL_ID, messageId),
            function(err, text, headers)
                if err ~= 200 and err ~= 204 then
                    print(('[YGPANIC] Discord edit error: %s - %s'):format(err, text))
                    messageId = nil
                end
            end,
            "PATCH",
            json.encode(embed),
            {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "Bot " .. DISCORD_BOT_TOKEN
            }
        )
    else
        PerformHttpRequest(
            string.format("https://discord.com/api/v10/channels/%s/messages", CHANNEL_ID),
            function(err, text, headers)
                if err == 200 then
                    local response = json.decode(text)
                    if response and response.id then
                        messageId = response.id
                    end
                else
                    print(('[YGPANIC] Discord post error: %s - %s'):format(err, text))
                end
            end,
            "POST",
            json.encode(embed),
            {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "Bot " .. DISCORD_BOT_TOKEN
            }
        )
    end
end

local function recalculateUnitCounts()
    activeCounts = {}
    for deptKey, _ in pairs(Config.Departments) do
        activeCounts[deptKey] = 0
    end
    
    for playerId, dept in pairs(activeDepartments) do
        print(('  - Player %s: %s'):format(playerId, dept))
        if activeCounts[dept] ~= nil then
            activeCounts[dept] = activeCounts[dept] + 1
        else
            print(('  - WARNING: Department "%s" not found in Config.Departments'):format(dept))
        end
    end
    
    updateAgencyEmbed()
end

RegisterNetEvent('custompanic:verifyPassword')
AddEventHandler('custompanic:verifyPassword', function(password, department)
    local src = source
    
    if password == Config.Password then
        authorizedPlayers[src] = true
        
        if Config.Departments[department] then
            activeDepartments[src] = department
        else
            activeDepartments[src] = "unknown"
        end
        
        TriggerClientEvent('custompanic:authSuccess', src, activeDepartments[src])
        
        print(('[YGPANIC] %s authorized as %s.'):format(
            GetPlayerName(src),
            activeDepartments[src]
        ))
        
        recalculateUnitCounts()
    else
        TriggerClientEvent('custompanic:authFailed', src)
        print(('[YGPANIC] %s entered an invalid password.'):format(GetPlayerName(src)))
    end
end)

RegisterNetEvent('custompanic:trigger')
AddEventHandler('custompanic:trigger', function(coords, name)
    local src = source
    
    if not authorizedPlayers[src] then
        print(('[YGPANIC] Unauthorized panic attempt by %s.'):format(name))
        return
    end
    
    local dept = activeDepartments[src]
    if not dept then return end
    
    print(('[YGPANIC] %s (%s) triggered panic at %s'):format(
        name,
        dept,
        json.encode(coords)
    ))
    
    for playerId, authorized in pairs(authorizedPlayers) do
        if authorized and activeDepartments[playerId] == dept then
            TriggerClientEvent('custompanic:alert', playerId, coords, name, dept)
        end
    end
end)

RegisterNetEvent('custompanic:setDepartment')
AddEventHandler('custompanic:setDepartment', function(department)
    local src = source
    
    if department then
        activeDepartments[src] = department
        print(('[YGPANIC] %s set to department: %s'):format(GetPlayerName(src), department))
        
        recalculateUnitCounts()
    end
end)

RegisterNetEvent('custompanic:logout')
AddEventHandler('custompanic:logout', function()
    local src = source
    local playerName = GetPlayerName(src)
    
    activeDepartments[src] = nil
    authorizedPlayers[src] = nil
    
    print(('[YGPANIC] %s logged out'):format(playerName))
    
    recalculateUnitCounts()
end)

RegisterNetEvent('custompanic:requestUnitCounts')
AddEventHandler('custompanic:requestUnitCounts', function()
    local src = source
    local counts = {}
    
    for deptKey, deptData in pairs(Config.Departments) do
        counts[deptKey] = 0
    end
    
    for playerId, dept in pairs(activeDepartments) do
        if counts[dept] ~= nil then
            counts[dept] = counts[dept] + 1
        end
    end
    
    TriggerClientEvent('custompanic:receiveUnitCounts', src, counts)
end)

AddEventHandler('playerDropped', function()
    local src = source
    authorizedPlayers[src] = nil
    activeDepartments[src] = nil
    print(('[YGPANIC] %s disconnected and removed from active units'):format(GetPlayerName(src)))
    
    recalculateUnitCounts()
end)

CreateThread(function()
    Wait(5000)
    
    PerformHttpRequest(
        string.format("https://discord.com/api/v10/channels/%s/messages?limit=100", CHANNEL_ID),
        function(err, text, headers)
            if err == 200 then
                local messages = json.decode(text)
                if messages then
                    for _, msg in ipairs(messages) do
                        if msg.embeds and #msg.embeds > 0 then
                            for _, embed in ipairs(msg.embeds) do
                                if embed.footer and embed.footer.text == "Active Unit Status" then
                                    PerformHttpRequest(
                                        string.format("https://discord.com/api/v10/channels/%s/messages/%s", CHANNEL_ID, msg.id),
                                        function(delErr, delText, delHeaders)
                                            if delErr == 204 then
                                            end
                                        end,
                                        "DELETE",
                                        "",
                                        {
                                            ["Authorization"] = "Bot " .. DISCORD_BOT_TOKEN
                                        }
                                    )
                                    Wait(1000)
                                    break
                                end
                            end
                        end
                    end
                end
            end
            
            Wait(2000)
            recalculateUnitCounts()
        end,
        "GET",
        "",
        {
            ["Authorization"] = "Bot " .. DISCORD_BOT_TOKEN
        }
    )
end)

CreateThread(function()
    while true do
        Wait(60000)
        recalculateUnitCounts()
    end
end)