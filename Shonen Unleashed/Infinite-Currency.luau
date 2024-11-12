--[[
    @author Jorsan
    @date 11/10/2024
    @description In order for the infinite cash/tokens script to work you must complete an achievement e.g. the tutorial for cash.
--]]

_G.IsEnabled = true
_G.CURRENCY_TYPE = "Cash" -- Change to "Tokens" if you want to farm tokens instead

if not _G.IsEnabled then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local Client = Players.LocalPlayer

local DataFolder = Client:WaitForChild("Data")
local AchievementsFolder = DataFolder:WaitForChild("Achievements")

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local ClaimRemote = RemotesFolder:WaitForChild("Claim")

local function NotifyClient(Title, Text, Duration)
    StarterGui:SetCore("SendNotification", {
        Title = Title,
        Text = Text,
        Duration = Duration
    })
end

local function GetMaxAchievement(Currency)
    if Currency ~= "Tokens" and Currency ~= "Cash" then
        return
    end

    local CompletedAchievements = {}
    
    -- Collect all completed achievements for the specified currency
    for _, AchievementTypeFolder in ipairs(AchievementsFolder:GetChildren()) do
        for _, QuestFolder in ipairs(AchievementTypeFolder:GetChildren()) do
            if QuestFolder.Finished.Value and QuestFolder.Reward_Type.Value:lower() == Currency:lower() then
                table.insert(CompletedAchievements, {
                    AchievementType = AchievementTypeFolder.Name,
                    QuestName = QuestFolder.Name,
                    Currency = QuestFolder.Reward_Type.Value,
                    Amount = QuestFolder.Amount.Value
                })
            end
        end
    end
    
    -- Find achievement with maximum amount
    local MaxAchievement = nil
    local MaxAmount = -math.huge
    
    for _, Achievement in ipairs(CompletedAchievements) do
        if Achievement.Amount > MaxAmount then
            MaxAmount = Achievement.Amount
            MaxAchievement = Achievement
        end
    end
    
    return MaxAchievement
end

local AchievementData = GetMaxAchievement(_G.CURRENCY_TYPE)

if not AchievementData then
    for _, Message in {
        "You must complete at least one achievement for the currency you're trying to farm for the script to work!", 
        "Complete the tutorial for example then execute the script to get infinite cash!"
    } do
        NotifyClient(
            "Error", 
            Message, 
            9
        )
    end

    return
end

NotifyClient("Success", "Farm Started!", 6)

-- Start farm
while _G.IsEnabled do
    ClaimRemote:FireServer(AchievementData.AchievementType, AchievementData.QuestName)
    task.wait(0.01)
end
