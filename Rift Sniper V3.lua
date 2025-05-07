local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

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
    local WEBHOOKS = {
        ["silly-egg"] = {
            url = "https://discord.com/api/webhooks/1365036728817287228/PXxkoxb1PbRv8Xui7vKVYPaKeJYjyNHQBO5gtJX6LJLvzNFeyWAnh3JC8D8VnXC_YE1P",
            roleId = "1366440504132243556"
        },
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
        ["royal-chest"] = {
            url = "https://discord.com/api/webhooks/1366630052200185937/4mpU_ouuylr6wUk6joK5eG3sbnFK9Gp8iUhYsTPtkAy2lkpxUJq7tFRCspABf57qxGgX",
            roleId = "1363447141879648342"
        },
        ["bubble-rift"] = {
            url = "https://discord.com/api/webhooks/1366630240704663632/_tkmuzze5SVXt3XpRcgkMHMNyViftUANSBDweckBPdnZ55jBssZ_zfIu3XK3dfwdw5tg",
            roleId = "1364784553784508529"
        }
    }

    local webhookData = WEBHOOKS[riftName]
    if not webhookData then
        warn("No webhook configured for rift: " .. riftName)
        return
    end

    local protocolLink = "https://rift-sniper.github.io/?placeID=" .. game.PlaceId .. "&gameInstanceId=" .. jobId
    local discordTimestamp = getDiscordTimestamp(timerText)

    local RIFT_DISPLAY_NAMES = {
        ["silly-egg"] = "Silly Egg",
        ["void-egg"] = "Void Egg",
        ["nightmare-egg"] = "Nightmare Egg",
        ["rainbow-egg"] = "Rainbow Egg",
        ["royal-chest"] = "Royal Chest",
        ["bubble-rift"] = "Bubble Rift"
    }

    local displayName = RIFT_DISPLAY_NAMES[riftName] or riftName

    local description = ":busts_in_silhouette: Players: `" .. tostring(playerCount) .. "`\n" ..
                       ":watch: Expires: " .. discordTimestamp .. "\n"

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
            { name = "Roblox Protocol Join Link (faster):", value = protocolLink, inline = false }
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

-- Function to wait for Workspace.Rendered.Rifts to load
local function waitForRifts()
    local LOAD_TIMEOUT = 10
    local startTime = tick()
    local rendered, rifts

    while not rendered and tick() - startTime < LOAD_TIMEOUT do
        rendered = Workspace:FindFirstChild("Rendered")
        if not rendered then
            task.wait(0.1)
        end
    end

    if not rendered then
        print("Timeout: Rendered not found in Workspace after " .. LOAD_TIMEOUT .. " seconds at " .. os.date("%H:%M:%S"))
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
        print("Timeout: Rifts not found in Rendered after " .. LOAD_TIMEOUT .. " seconds at " .. os.date("%H:%M:%S"))
        return false
    end

    print("Workspace.Rendered.Rifts loaded successfully at " .. os.date("%H:%M:%S"))
    return true
end

-- Rift & filtering parameters
local RARE_RIFTS = {
    enabled = true,
    rifts = { "silly-egg" },
    minLuck = 5,
    minTime = 2,
    maxPlayers = 12
}

local EGG_RIFTS = {
    enabled = true,
    rifts = { "void-egg", "nightmare-egg", "rainbow-egg" },
    minLuck = 25,
    minTime = 7,
    maxPlayers = 10
}

local MISC_RIFTS = {
    enabled = true,
    rifts = { "royal-chest", "bubble-rift" },
    minTime = 5,
    maxPlayers = 8
}

local MASTER_IGNORE_LIST = {
    "gift-rift", "golden-chest", "spikey-egg", "magma-egg",
    "crystal-egg", "lunar-egg", "hell-egg"
}

-- Function to check for rifts in Workspace.Rendered.Rifts
local function checkRifts()
    local rendered = Workspace:FindFirstChild("Rendered")
    local rifts = rendered and rendered:FindFirstChild("Rifts")
    if not rifts then
        return
    end

    for _, rift in pairs(rifts:GetChildren()) do
        local riftName = rift.Name
        local playerCount = #Players:GetPlayers() - 1

        if table.find(MASTER_IGNORE_LIST, riftName) then
            continue
        end

        local display = rift:FindFirstChild("Display")
        if not display then
            print("Display not found for rift: " .. riftName .. " at " .. os.date("%H:%M:%S"))
            continue
        end

        local surfaceGui = display:FindFirstChild("SurfaceGui")
        if not surfaceGui then
            print("SurfaceGui not found for rift: " .. riftName .. " at " .. os.date("%H:%M:%S"))
            continue
        end

        local icon = surfaceGui:FindFirstChild("Icon")
        local luckText = icon and icon:FindFirstChild("Luck")
        local luckValue = luckText and luckText.Text or nil

        local timerText = surfaceGui:FindFirstChild("Timer")
        local timerValue = timerText and timerText.Text or nil

        if not timerValue then
            print("Timer value not found for rift: " .. riftName .. " at " .. os.date("%H:%M:%S"))
            continue
        end

        local timerMinutes = parseTimer(timerValue)

        local isInRareRifts = table.find(RARE_RIFTS.rifts, riftName)
        local isInEggRifts = table.find(EGG_RIFTS.rifts, riftName)
        local isInMiscRifts = table.find(MISC_RIFTS.rifts, riftName)

        if RARE_RIFTS.enabled and isInRareRifts then
            if playerCount > RARE_RIFTS.maxPlayers then
                continue
            end
            if not luckValue then
                print("Luck value not found for rift: " .. riftName .. " at " .. os.date("%H:%M:%S"))
                continue
            end
            local parsedLuck = parseLuck(luckValue)
            if parsedLuck >= RARE_RIFTS.minLuck and timerMinutes >= RARE_RIFTS.minTime then
                sendWebhook(riftName, playerCount, timerValue, game.JobId, luckValue)
            end
            continue
        end

        if EGG_RIFTS.enabled and isInEggRifts then
            if playerCount > EGG_RIFTS.maxPlayers then
                continue
            end
            if not luckValue then
                print("Luck value not found for rift: " .. riftName .. " at " .. os.date("%H:%M:%S"))
                continue
            end
            local parsedLuck = parseLuck(luckValue)
            if parsedLuck >= EGG_RIFTS.minLuck and timerMinutes >= EGG_RIFTS.minTime then
                sendWebhook(riftName, playerCount, timerValue, game.JobId, luckValue)
            end
            continue
        end

        if MISC_RIFTS.enabled and isInMiscRifts then
            if playerCount > MISC_RIFTS.maxPlayers then
                continue
            end
            if timerMinutes >= MISC_RIFTS.minTime then
                sendWebhook(riftName, playerCount, timerValue, game.JobId, luckValue)
            end
            continue
        end

        if isInRareRifts or isInEggRifts or isInMiscRifts then
            continue
        end

        print("Rift " .. riftName .. " not in any configured list at " .. os.date("%H:%M:%S"))
    end
end

-- Main execution
task.wait(10) -- Delay to allow server to settle
if waitForRifts() then
    checkRifts()
end
