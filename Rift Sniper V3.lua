-- Rift Sniper by Suna
-- Discord: ____

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Function to manually pretty-print an array as JSON
local function prettyPrintArray(arr)
    if #arr == 0 then
        return "[]"
    end

    local lines = { "[" }
    for i, value in ipairs(arr) do
        -- Convert the value to a JSON-compatible string
        local formattedValue
        if type(value) == "string" then
            formattedValue = '"' .. value .. '"'
        else
            formattedValue = tostring(value)
        end

        -- Add the value with indentation
        if i == #arr then
            -- Last element, no trailing comma
            table.insert(lines, "    " .. formattedValue)
        else
            -- Add a comma for non-last elements
            table.insert(lines, "    " .. formattedValue .. ",")
        end
    end
    table.insert(lines, "]")
    return table.concat(lines, "\n")
end

-- Persistent storage for server IDs
local AllIDs = {}
local foundAnything = ""
local actualHour = os.date("!*t").hour
local lastBlacklistReset = tick()
local File = pcall(function()
    AllIDs = HttpService:JSONDecode(readfile("Rift Sniper/noDuplicateServers.json"))
end)

-- Create Rift Sniper folder and initialize files
local function initializeFiles()
    local folderPath = "Rift Sniper"
    local noDuplicateServersPath = folderPath .. "/noDuplicateServers.json"
    local newRiftsPath = folderPath .. "/newRifts.json"

    -- Create the folder if it doesn't exist
    if not isfolder(folderPath) then
        makefolder(folderPath)
    end

    -- Initialize noDuplicateServers.json if it doesn't exist
    if not isfile(noDuplicateServersPath) then
        local initialData = { actualHour }
        pcall(function()
            writefile(noDuplicateServersPath, prettyPrintArray(initialData))
        end)
    end

    -- Initialize newRifts.json if it doesn't exist
    if not isfile(newRiftsPath) then
        local initialData = {}
        pcall(function()
            writefile(newRiftsPath, prettyPrintArray(initialData))
        end)
    end
end

-- Call the initialization function
initializeFiles()

-- Gobal parameters
local PlaceID = game.PlaceId -- The placeID you want to serverhop
local PRE_RIFT_DELAY = 10 -- Delay in seconds before searching for rifts
local PRE_HOP_DELAY = 10 -- Delay in seconds before server hopping
local MAX_HOP_ATTEMPTS = 10 -- Max attempts to find a valid server
local LOAD_TIMEOUT = 10 -- Seconds to wait for Rifts to load
local API_CALL_DELAY = 1 -- Delay before each HttpGet to avoid rate limits
local RETRY_DELAY = 5 -- Delay between teleport retries
local RATE_LIMIT_WAIT = 30 -- Wait after max attempts to reset rate limits
local BLACKLIST_RESET_INTERVAL = 600 -- Reset blacklist every 10 minutes (in seconds)

-- Rift & filtering parameters
local RARE_RIFTS = {
    enabled = true, -- Toggle to enable/disable this list
    rifts = {
        "silly-egg"
    },
    minLuck = 5, -- Minimum luck multiplier
    minTime = 2, -- Minimum time in minutes
    maxPlayers = 12 -- Maximum players in the server (excluding local player)
}

local EGG_RIFTS = {
    enabled = true, -- Toggle to enable/disable this list
    rifts = {
        "void-egg",
        "nightmare-egg",
        "rainbow-egg"
    },
    minLuck = 25, -- Minimum luck multiplier
    minTime = 7, -- Minimum time in minutes
    maxPlayers = 10 -- Maximum players in the server (excluding local player)
}

local MISC_RIFTS = {
    enabled = true, -- Toggle to enable/disable this list
    rifts = {
        "royal-chest",
        "bubble-rift"
    },
    minTime = 5, -- Minimum time in minutes
    maxPlayers = 8 -- Maximum players in the server (excluding local player)
}

-- Master ignore list (rifts to always ignore)
local MASTER_IGNORE_LIST = {
    "gift-rift",
    "golden-chest",
    "spikey-egg",
    "magma-egg",
    "crystal-egg",
    "lunar-egg",
    "hell-egg"
}

-- Display names for rifts in embeds
local RIFT_DISPLAY_NAMES = {
    ["silly-egg"] = "Silly Egg",
    ["void-egg"] = "Void Egg",
    ["nightmare-egg"] = "Nightmare Egg",
    ["rainbow-egg"] = "Rainbow Egg",
    ["royal-chest"] = "Royal Chest",
    ["bubble-rift"] = "Bubble Rift"
}

-- Webhook and role configuration
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

-- DO NOT CANGE ANYTHING PAST THIS POINT UNLESS YOU KNOW WHAT YO ARE DOING

-- Fuction to parse luck value
local function parseLuck(luckText)
    local number = luckText:match("x(%d+)")
    if number then
        return tonumber(number)
    end
    return 0 -- Default to 0 if parsing fails
end

-- Function to parse timer text into minutes
local function parseTimer(timerText)
    local minutes = 0
    local seconds = 0

    -- Extract minutes (format: "[number] minutes")
    local minutesMatch = timerText:match("(%d+)%s*minute[s]?")
    if minutesMatch then
        minutes = tonumber(minutesMatch)
    end

    -- Extract seconds (format: "[number] seconds")
    local secondsMatch = timerText:match("(%d+)%s*second[s]?")
    if secondsMatch then
        seconds = tonumber(secondsMatch)
    end

    -- Convert to total minutes
    local totalMinutes = minutes + (seconds / 60)
    return totalMinutes
end

-- Function to convert timer text to Discord timestamp
local function getDiscordTimestamp(timerText)
    local totalSeconds = parseTimer(timerText) * 60
    local expiryTime = os.time() + totalSeconds
    return "<t:" .. expiryTime .. ":R>" -- Discord relative timestamp
end

-- Function to send Discord webhook
local function sendWebhook(riftName, playerCount, timerText, jobId)
    local webhookData = WEBHOOKS[riftName]
    if not webhookData then
        warn("No webhook configured for rift: " .. riftName)
        return
    end

    local protocolLink = "https://rift-sniper.github.io/?placeID=" .. PlaceID .. "&gameInstanceId=" .. jobId
    local extensionLink = "https://www.roblox.com/home?placeId=" .. PlaceID .. "&gameId=" .. jobId
    local discordTimestamp = getDiscordTimestamp(timerText)

    -- Use display name if available, otherwise fall back to riftName
    local displayName = RIFT_DISPLAY_NAMES[riftName] or riftName

    local embed = {
        title = "Rift: " .. displayName,
        fields = {
            { name = "Players:", value = tostring(playerCount), inline = true },
            { name = "Expires:", value = discordTimestamp, inline = true },
            { name = "Roblox Protocol Join Link (faster):", value = protocolLink, inline = false },
            { name = "Roblox Extension-Based Join Link (slower):", value = extensionLink, inline = false }
        },
        footer = { text = "Built by Suna" },
        color = 0xC6D4FF
    }

    local payload = {
        content = "<@&" .. webhookData.roleId .. ">",
        embeds = { embed }
    }

    local success, errorMessage = pcall(function()
        return request({
            Url = webhookData.url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    if success then
        print("Successfully sent webhook for rift: " .. riftName)
    else
        warn("Failed to send webhook for rift " .. riftName .. ": " .. tostring(errorMessage))
    end
end

-- Function to wait for Workspace.Rendered.Rifts to load
local function waitForRifts()
    local startTime = tick()
    local rendered, rifts

    -- Wait for Rendered
    while not rendered and tick() - startTime < LOAD_TIMEOUT do
        rendered = Workspace:FindFirstChild("Rendered")
        if not rendered then
            wait(0.1)
        end
    end

    if not rendered then
        print("Timeout: Rendered not found in Workspace after " .. LOAD_TIMEOUT .. " seconds.")
        return false
    end

    -- Wait for Rifts
    startTime = tick()
    while not rifts and tick() - startTime < LOAD_TIMEOUT do
        rifts = rendered:FindFirstChild("Rifts")
        if not rifts then
            wait(0.1)
        end
    end

    if not rifts then
        print("Timeout: Rifts not found in Rendered after " .. LOAD_TIMEOUT .. " seconds.")
        return false
    end

    print("Workspace.Rendered.Rifts loaded successfully.")
    return true
end

-- Function to check for rifts in Workspace.Rendered.Rifts
local function checkRifts()
    local rendered = Workspace:FindFirstChild("Rendered")
    local rifts = rendered and rendered:FindFirstChild("Rifts")
    if not rifts then
        return
    end

    -- Check all rift instances under Rifts
    for _, rift in pairs(rifts:GetChildren()) do
        local riftName = rift.Name

        -- Calculate player count once (excluding local player)
        local playerCount = #Players:GetPlayers() - 1

        -- Check if rift is in the master ignore list
        if table.find(MASTER_IGNORE_LIST, riftName) then
            continue
        end

        -- Access the hierarchy
        local display = rift:FindFirstChild("Display")
        if not display then
            print("Display not found for rift: " .. riftName)
            continue
        end

        local surfaceGui = display:FindFirstChild("SurfaceGui")
        if not surfaceGui then
            print("SurfaceGui not found for rift: " .. riftName)
            continue
        end

        local icon = surfaceGui:FindFirstChild("Icon")
        local luckText = icon and icon:FindFirstChild("Luck")
        local luckValue = luckText and luckText.Text or nil

        local timerText = surfaceGui:FindFirstChild("Timer")
        local timerValue = timerText and timerText.Text or nil

        -- Skip if timer value is missing
        if not timerValue then
            print("Timer value not found for rift: " .. riftName)
            continue
        end

        -- Parse timer into minutes
        local timerMinutes = parseTimer(timerValue)

        -- Check if the rift belongs to any list
        local isInRareRifts = table.find(RARE_RIFTS.rifts, riftName)
        local isInEggRifts = table.find(EGG_RIFTS.rifts, riftName)
        local isInMiscRifts = table.find(MISC_RIFTS.rifts, riftName)

        -- Check Rare Rifts
        if RARE_RIFTS.enabled and isInRareRifts then
            if playerCount > RARE_RIFTS.maxPlayers then
                continue
            end
            if not luckValue then
                print("Luck value not found for rift: " .. riftName)
                continue
            end
            local parsedLuck = parseLuck(luckValue) -- Parse luck value for numerical comparison
            if parsedLuck >= RARE_RIFTS.minLuck and timerMinutes >= RARE_RIFTS.minTime then
                local jobId = game.JobId
                sendWebhook(riftName, playerCount, timerValue, jobId)
            end
            continue
        end

        -- Check Egg Rifts
        if EGG_RIFTS.enabled and isInEggRifts then
            if playerCount > EGG_RIFTS.maxPlayers then
                continue
            end
            if not luckValue then
                print("Luck value not found for rift: " .. riftName)
                continue
            end
            local parsedLuck = parseLuck(luckValue) -- Parse luck value for numerical comparison
            if parsedLuck >= EGG_RIFTS.minLuck and timerMinutes >= EGG_RIFTS.minTime then
                local jobId = game.JobId
                sendWebhook(riftName, playerCount, timerValue, jobId)
            end
            continue
        end

        -- Check Misc Rifts
        if MISC_RIFTS.enabled and isInMiscRifts then
            if playerCount > MISC_RIFTS.maxPlayers then
                continue
            end
            if timerMinutes >= MISC_RIFTS.minTime then
                local jobId = game.JobId
                sendWebhook(riftName, playerCount, timerValue, jobId)
            end
            continue
        end

        -- If the rift is in a list but the list is disabled, skip it without logging
        if isInRareRifts or isInEggRifts or isInMiscRifts then
            continue
        end

        -- If the rift isn't in any list, log it to console and file
        print("Rift " .. riftName .. " not in any configured list")
        -- Load existing new rifts
        local newRifts = {}
        local filePath = "Rift Sniper/newRifts.json"
        local fileExists, fileContent = pcall(function()
            return readfile(filePath)
        end)
        if fileExists then
            newRifts = HttpService:JSONDecode(fileContent)
        end
        -- Add the new rift if not already present
        if not table.find(newRifts, riftName) then
            table.insert(newRifts, riftName)
            -- Write back to the file
            pcall(function()
                writefile(filePath, prettyPrintArray(newRifts))
            end)
        end
    end
end

-- Function to fetch and teleport to a new server
local function TPReturner()
    -- Delay to avoid API rate limits
    wait(Api_CALL_DELAY)

    local Site
    if foundAnything == "" then
        Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'))
    else
        Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' .. foundAnything))
    end
    local ID = ""
    if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
        foundAnything = Site.nextPageCursor
    end
    local num = 0
    for i, v in pairs(Site.data) do
        local Possible = true
        ID = tostring(v.id)
        -- Skip private servers
        if v.privateServerId ~= nil or (v.privateServerOwnerId and v.privateServerOwnerId ~= 0) then
            print("Skipping private server with JobId " .. ID)
            Possible = false
        end
        if Possible and tonumber(v.maxPlayers) > tonumber(v.playing) then
            for _, Existing in pairs(AllIDs) do
                if num ~= 0 then
                    if ID == tostring(Existing) then
                        Possible = false
                    end
                else
                    if tonumber(actualHour) ~= tonumber(Existing) then
                        local delFile = pcall(function()
                            delfile("Rift Sniper/noDuplicateServers.json")
                            AllIDs = {}
                            table.insert(AllIDs, actualHour)
                        end)
                    end
                end
                num = num + 1
            end
            if Possible then
                print("Joining new server")
                print("-------------------")
                table.insert(AllIDs, ID)
                local success, errorMessage = pcall(function()
                    writefile("Rift Sniper/noDuplicateServers.json", prettyPrintArray(AllIDs))
                    TeleportService:TeleportToPlaceInstance(PlaceID, ID, Players.LocalPlayer)
                end)
                if success then
                    return true -- Indicate successful teleport attempt
                else
                    warn("Teleport failed with error: " .. tostring(errorMessage))
                    -- Remove the problematic server from AllIDs
                    table.remove(AllIDs, #AllIDs)
                    -- Write the updated AllIDs back to file
                    pcall(function()
                        writefile("Rift Sniper/noDuplicateServers.json", prettyPrintArray(AllIDs))
                    end)
                    if errorMessage:find("773") then
                        print("Error 773: Can't join private server with JobId " .. ID .. ", skipping...")
                    end
                    return false -- Try the next server
                end
            end
        end
    end
    print("No suitable server found in this batch.")
    return false -- No suitable server found
end

-- Main function to handle rift checking and server hopping
local function main()
    -- Record the start time in the server
    local serverStartTime = tick()

    -- Reset blacklist if interval has passed
    if tick() - lastBlacklistReset >= BLACKLIST_RESET_INTERVAL then
        print("Resetting blacklist after " .. BLACKLIST_RESET_INTERVAL .. " seconds...")
        local delFile = pcall(function()
        delfile("Rift Sniper/noDuplicateServers.json")
            AllIDs = {}
            table.insert(AllIDs, actualHour)
            writefile("Rift Sniper/noDuplicateServers.json", prettyPrintArray(AllIDs))
        end)
        lastBlacklistReset = tick()
    end

    -- Wait before searching for rifts
    print("Waiting " .. PRE_RIFT_DELAY .. " seconds before searching for rifts...")
    wait(PRE_RIFT_DELAY)

    -- Wait for server to load
    if not waitForRifts() then
        print("Skipping rift check due to load failure, attempting to hop...")
    else
        -- Check rifts and send webhooks
        checkRifts()
    end

-- Ensure minimum time in server before hopping
    local timeInServer = tick() - serverStartTime
    if timeInServer < (PRE_RIFT_DELAY + PRE_HOP_DELAY) then
        local waitTime = (PRE_RIFT_DELAY + PRE_HOP_DELAY) - timeInServer
        wait(waitTime)
    end

-- Attempt to hop to a new server
    local attempts = 0
    local success = false
    while attempts < MAX_HOP_ATTEMPTS and not success do
        local teleportSuccess, teleportResult = pcall(TPReturner)
        if teleportSuccess and teleportResult then
            success = true
        else
            if not teleportSuccess then
                warn("TPReturner failed with error: " .. tostring(teleportResult))
            else
                print("Teleport attempt " .. (attempts + 1) .. " failed, retrying...")
            end
            attempts = attempts + 1
            wait(RETRY_DELAY)
        end
    end
    if not success then
        warn("Max teleport attempts reached, waiting " .. RATE_LIMIT_WAIT .. " seconds to reset rate limits...")
        wait(RATE_LIMIT_WAIT)
        local finalSuccess, finalResult = pcall(TPReturner)
        if not finalSuccess then
            warn("Final teleport attempt failed with error: " .. tostring(finalResult))
        elseif not finalResult then
            print("Final teleport attempt failed.")
        end
    end
end

-- Start the script with error handling
local success, errorMessage = pcall(main)
if not success then
    warn("Script error: " .. tostring(errorMessage))
end
