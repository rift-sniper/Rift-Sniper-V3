local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local UNRECOGNIZED_RIFTS_FILE = "RiftSniperV3\\unrecognized_rifts.json"
if not isfile(UNRECOGNIZED_RIFTS_FILE) then
    writefile(UNRECOGNIZED_RIFTS_FILE, HttpService:JSONEncode({}))
end

-- CONFIGURATION SECTION

-- Webhook URLs and role IDs for Discord notifications
local WEBHOOKS = {
-- Rare
    ["silly-egg"] = {
        url = "https://discord.com/api/webhooks/1365036728817287228/PXxkoxb1PbRv8Xui7vKVYPaKeJYjyNHQBO5gtJX6LJLvzNFeyWAnh3JC8D8VnXC_YE1P",
        roleId = "1366440504132243556"
    },
-- World 1
    ["void-egg"] = {
        url = "https://discord.com/api/webhooks/1366440914993680434/ziVdwzwlHEuIwoTBa1TKrDJSLjnlsCyYs6cInLutFSs4VjtZjKNUHT0pGWw_9Ec6yL69",
        roleId = "1363447141879648337"
    },
    ["nightmare-egg"] = {
        url = "https://discord.com/api/webhooks/1366441217222643822/DfOMDEjkYzY9SlJRFiUc8MhTx2zKrCidJAi0rpRH45GdVKbL2f-DaPzotFEtWRQK37sN",
        roleId = "1363447141879648338"
    },
    ["rainbow-egg"] = {
        url = "https://discord.com/api/webhooks/1366441055574298645/ucMAyTVyYhtAhowdsrveLtgTtRtOrbvX06-2Y3kQsUU3oYyBkeOTN6ty8g92Iy1UjjTi",
        roleId = "1363447141879648339"
    },
-- World 2
    ["mining-egg"] = {
        url = "https://discord.com/api/webhooks/1369859901559541780/OKTv-jMGQwoWbjbIl2mxRfnsJYnd2_2czTAATISRvGY9smkDrMGUBxZNutXds4TlD3WI",
        roleId = "1369860269215580230"
    },
    ["cyber-egg"] = {
        url = "https://discord.com/api/webhooks/1369859753337163827/3WXD1wPa1Z6087DQvxp4g1yvZbHeyu7Gz4yFFDk6Vv1t0FVipsQjrN6Fa40cb8Gk36mP",
        roleId = "1369860389701156935"
    },
    ["dice-rift"] = {
        url = "https://discord.com/api/webhooks/1369859611284209797/SrskxgoXVLa8Kyam2Ng9U8uACTfaLnI20kj7fmB7Xv_BWkmr5p_02BwJR0KDgeypyxOz",
        roleId = "1369374020620910633"
    },
-- Misc
    ["royal-chest"] = {
        url = "https://discord.com/api/webhooks/1366630052200185937/4mpU_ouuylr6wUk6joK5eG3sbnFK9Gp8iUhYsTPtkAy2lkpxUJq7tFRCspABf57qxGgX",
        roleId = "1363447141879648342"
    },
    ["bubble-rift"] = {
        url = "https://discord.com/api/webhooks/1366630240704663632/_tkmuzze5SVXt3XpRcgkMHMNyViftUANSBDweckBPdnZ55jBssZ_zfIu3XK3dfwdw5tg",
        roleId = "1364784553784508529"
    }
}

-- Display names for rifts in Discord embeds
local RIFT_DISPLAY_NAMES = {
-- Rare
    ["silly-egg"] = "Silly Egg",
-- World 1
    ["void-egg"] = "Void Egg",
    ["nightmare-egg"] = "Nightmare Egg",
    ["rainbow-egg"] = "Rainbow Egg",
-- World 2
    ["mining-egg"] = "Mining Egg",
    ["cyber-egg"] = "Cyber Egg",
    ["dice-rift"] = "Dice Rift"
-- Misc
    ["royal-chest"] = "Royal Chest",
    ["bubble-rift"] = "Bubble Rift",
}

-- Rift filtering parameters
local RIFT_CONFIGS = {
    RARE_RIFTS = {
        enabled = true,
        rifts = { "silly-egg" },
        minLuck = 0,
        minTime = 1,
        maxPlayers = 0
    },
    WORLD_1_RIFTS = {
        enabled = true,
        rifts = { "void-egg", "nightmare-egg", "rainbow-egg" },
        minLuck = 0,
        minTime = 0,
        maxPlayers = 0
    },
    WORLD_2_RIFTS = {
        enabled = true,
        rifts = {"mining-egg", "cyber-egg", "dice-rift"},
        minLuck = 25,
        minTime = 7,
        maxPlayers = 10
    },
    MISC_RIFTS = {
        enabled = true,
        rifts = {"royal-chest", "bubble-rift"},
        minTime = 8,
        maxPlayers = 8
    }
}

-- Rifts to ignore
local MASTER_IGNORE_LIST = {
-- World 1
    "spikey-egg",
    "magma-egg",
    "crystal-egg",
    "lunar-egg",
    "hell-egg"
-- Misc
    "gift-rift",
    "golden-chest",
}

-- Timeout for waiting for Workspace.Rendered.Rifts to load (in seconds)
local LOAD_TIMEOUT = 5

-- Delay before checking rifts (in seconds)
local PRE_RIFT_DELAY = 5

-- LOGIC

-- Function to parse luck value
local function parseLuck(luckText)
    local number = luckText:match("x(%d+)")
    if number then
        return tonumber(number)
    end
    return 0
end

-- Function to parse timer text into minutes
local function parseTimer(timerText)
    local minutes = 0
    local seconds = 0

    local minutesMatch = timerText:match("(%d+)%s*minute[s]?")
    if minutesMatch then
        minutes = tonumber(minutesMatch)
    end

    local secondsMatch = timerText:match("(%d+)%s*second[s]?")
    if secondsMatch then
        seconds = tonumber(secondsMatch)
    end

    local totalMinutes = minutes + (seconds / 60)
    return totalMinutes
end

-- Function to convert timer text to Discord timestamp
local function getDiscordTimestamp(timerText)
    local totalSeconds = parseTimer(timerText) * 60
    local expiryTime = os.time() + totalSeconds
    return "<t:" .. expiryTime .. ":R>"
end

-- Function to send Discord webhook
local function sendWebhook(riftName, playerCount, timerText, jobId, luckValue)
    local webhookData = WEBHOOKS[riftName]
    if not webhookData then
        warn("No webhook configured for rift: " .. riftName)
        return
    end

    local protocolLink = "https://rift-sniper.github.io/?placeID=" .. game.PlaceId .. "&gameInstanceId=" .. jobId
    local discordTimestamp = getDiscordTimestamp(timerText)

    local displayName = RIFT_DISPLAY_NAMES[riftName] or riftName

    local description = ":busts_in_silhouette: Players: `" .. tostring(playerCount) .. "`\n" .. ":watch: Expires: " .. discordTimestamp .. "\n"

    if luckValue and luckValue ~= "" then
        local parsedLuck = parseLuck(luckValue)
        if parsedLuck and parsedLuck > 0 then
            description = description .. ":four_leaf_clover: Luck: `x" .. tostring(parsedLuck) .. "`\n"
        end
    end

    local embed = {
        title = "Rift: " .. displayName,
        description = description,
        fields = {
            { name = "Join Link:", value = protocolLink, inline = false }
        },
        footer = { text = "Built by Suna" },
        color = 0xC6D4FF
    }

    local payload = {
        content = "<@&" .. webhookData.roleId .. ">",
        embeds = { embed }
    }

    local success, errorMessage = pcall(function()
        request({Url = webhookData.url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(payload)})
    end)
    if success then
        print("Successfully sent webhook for rift: " .. riftName .. " at " .. os.date("%H:%M:%S"))
    else
        warn("Failed to send webhook for rift " .. riftName .. ": " .. tostring(errorMessage) .. " at " .. os.date("%H:%M:%S"))
    end
end

-- Function to wait for Rifts to load
local function waitForRifts()
    local startTime = tick()
    local rendered, rifts

    while not rendered and tick() - startTime < LOAD_TIMEOUT do
        rendered = Workspace:FindFirstChild("Rendered")
        if not rendered then
            task.wait(0.1)
        end
    end

    if not rendered then
        error("Timeout: Rendered not found in Workspace after " .. LOAD_TIMEOUT .. " seconds at " .. os.date("%H:%M:%S"))
        return false
    end

    startTime = tick()
    while not rifts and tick() - startTime < LOAD_TIMEOUT do
        rifts = rendered:FindFirstChild("Rifts")
        if not rifts then
            task.wait(0.1)
        end
    end

    if not rifts then
        error("Timeout: Rifts not found in Rendered after " .. LOAD_TIMEOUT .. " seconds at " .. os.date("%H:%M:%S"))
        return false
    end

    print("Rifts loaded successfully!")
    return true
end

-- Function to check for rifts
local function checkRifts()
    local rendered = Workspace:FindFirstChild("Rendered")
    local rifts = rendered and rendered:FindFirstChild("Rifts")
    if not rifts then
        return
    end

    -- Load or initialize unrecognized rifts data
    local unrecognizedRifts = {}
    if isfile(UNRECOGNIZED_RIFTS_FILE) then
        local content = readfile(UNRECOGNIZED_RIFTS_FILE)
        if content and content ~= "" then
            unrecognizedRifts = HttpService:JSONDecode(content) or {}
        end
    end

    for _, rift in pairs(rifts:GetChildren()) do
        local riftName = rift.Name
        local playerCount = #Players:GetPlayers() - 1

        if table.find(MASTER_IGNORE_LIST, riftName) then
            continue
        end

        local display = rift:FindFirstChild("Display")
        if not display then
            warn("Display not found for rift: " .. riftName .. " at " .. os.date("%H:%M:%S"))
            continue
        end

        local surfaceGui = display:FindFirstChild("SurfaceGui")
        if not surfaceGui then
            warn("SurfaceGui not found for rift: " .. riftName .. " at " .. os.date("%H:%M:%S"))
            continue
        end

        local icon = surfaceGui:FindFirstChild("Icon")
        local luckText = icon and icon:FindFirstChild("Luck")
        local luckValue = luckText and luckText.Text or nil

        local timerText = surfaceGui:FindFirstChild("Timer")
        local timerValue = timerText and timerText.Text or nil

        if not timerValue then
            warn("Timer value not found for rift: " .. riftName .. " at " .. os.date("%H:%M:%S"))
            continue
        end

        local timerMinutes = parseTimer(timerValue)

        local isInRareRifts = table.find(RIFT_CONFIGS.RARE_RIFTS.rifts, riftName)
        local isInWorld1Rifts = table.find(RIFT_CONFIGS.WORLD_1_RIFTS.rifts, riftName)
        local isInWorld2Rifts = table.find(RIFT_CONFIGS.WORLD_2_RIFTS.rifts, riftName)
        local isInMiscRifts = table.find(RIFT_CONFIGS.MISC_RIFTS.rifts, riftName)

        if RIFT_CONFIGS.RARE_RIFTS.enabled and isInRareRifts then
            if playerCount > RIFT_CONFIGS.RARE_RIFTS.maxPlayers then
                continue
            end
            
            local parsedLuck = parseLuck(luckValue)
            if parsedLuck >= RIFT_CONFIGS.RARE_RIFTS.minLuck and timerMinutes >= RIFT_CONFIGS.RARE_RIFTS.minTime then
                sendWebhook(riftName, playerCount, timerValue, game.JobId, luckValue)
            end
            continue
        end

        if RIFT_CONFIGS.WORLD_1_RIFTS.enabled and isInWorld1Rifts then
            if playerCount > RIFT_CONFIGS.WORLD_1_RIFTS.maxPlayers then
                continue
            end
            
            local parsedLuck = parseLuck(luckValue)
            if parsedLuck >= RIFT_CONFIGS.WORLD_1_RIFTS.minLuck and timerMinutes >= RIFT_CONFIGS.WORLD_1_RIFTS.minTime then
                sendWebhook(riftName, playerCount, timerValue, game.JobId, luckValue)
            end
            continue
        end

        if RIFT_CONFIGS.WORLD_2_RIFTS.enabled and isInWorld2Rifts then
            if playerCount > RIFT_CONFIGS.WORLD_2_RIFTS.maxPlayers then
                continue
            end
            
            local parsedLuck = parseLuck(luckValue or "")
            if (RIFT_CONFIGS.WORLD_2_RIFTS.minLuck == 0 or parsedLuck >= RIFT_CONFIGS.WORLD_2_RIFTS.minLuck) and timerMinutes >= RIFT_CONFIGS.WORLD_2_RIFTS.minTime then
                sendWebhook(riftName, playerCount, timerValue, game.JobId, luckValue)
            end
            continue
        end

        if RIFT_CONFIGS.MISC_RIFTS.enabled and isInMiscRifts then
            if playerCount > RIFT_CONFIGS.MISC_RIFTS.maxPlayers then
                continue
            end
            
            if timerMinutes >= RIFT_CONFIGS.MISC_RIFTS.minTime then
                sendWebhook(riftName, playerCount, timerValue, game.JobId, luckValue)
            end
            continue
        end

        if isInRareRifts or isInWorld1Rifts or isInWorld2Rifts or isInMiscRifts then
            continue
        end

        -- Log unrecognized rift to console and file
        warn("Rift " .. riftName .. " not in any configured list at " .. os.date("%H:%M:%S"))
        if not table.find(unrecognizedRifts, riftName) then
            table.insert(unrecognizedRifts, riftName)
            writefile(UNRECOGNIZED_RIFTS_FILE, HttpService:JSONEncode(unrecognizedRifts))
        end
    end
end

-- Main execution
local success, err = pcall(function()
    task.wait(PRE_RIFT_DELAY)
    if waitForRifts() then
        checkRifts()
    end
end)

if not success then
    warn("Script execution failed: " .. tostring(err))
end
