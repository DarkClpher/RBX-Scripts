--!nonstrict

--[[
	@author Jorsan
]]

-- Libraries
local Maid = loadstring(game:HttpGet('https://raw.githubusercontent.com/Quenty/NevermoreEngine/refs/heads/main/src/maid/src/Shared/Maid.lua'))()
local Signal = loadstring(game:HttpGet('https://raw.githubusercontent.com/stravant/goodsignal/refs/heads/master/src/init.lua'))()

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- @class RedLightGreenLight
local RedLightGreenLight = {}
RedLightGreenLight.__index = RedLightGreenLight

function RedLightGreenLight.new(UIManager)
    local self = setmetatable({}, RedLightGreenLight)

    self._UIManager = UIManager
    self._Maid = Maid.new()

    self._Maid:GiveTask(function()
        self._IsGreenLight = nil
        self._LastRootPartCFrame = nil
    end)

    return self
end

function RedLightGreenLight:Start()
    local Client = Players.LocalPlayer
    local TrafficLightImage = Client.PlayerGui:WaitForChild("ImpactFrames"):WaitForChild("TrafficLightEmpty")

    self._IsGreenLight = TrafficLightImage.Image == ReplicatedStorage.Effects.Images.TrafficLights.GreenLight.Image

    local RootPart = Client.Character and Client.Character:FindFirstChild("HumanoidRootPart")
    self._LastRootPartCFrame = RootPart and RootPart.CFrame
    
    self._Maid:GiveTask(ReplicatedStorage.Remotes.Effects.OnClientEvent:Connect(function(EffectsData)
        if EffectsData.EffectName ~= "TrafficLight" then return end

        self._IsGreenLight = EffectsData.GreenLight == true

        local RootPart = Client.Character and Client.Character:FindFirstChild("HumanoidRootPart")
        self._LastRootPartCFrame = RootPart and RootPart.CFrame
    end))

    local OriginalNamecall
    OriginalNamecall = hookfunction(getrawmetatable(game).__namecall, newcclosure(function(Instance, ...)
        local Args = {...}

        if getnamecallmethod() == "FireServer" and Instance.ClassName == "RemoteEvent" and Instance.Name == "rootCFrame" then
            if self._UIManager:GetToggleValue("RedLightGodMode") and self._IsGreenLight == false and self._LastRootPartCFrame then
                -- Send cached CFrame data when it's red light
                Args[1] = self._LastRootPartCFrame
                return OriginalNamecall(Instance, unpack(Args))
            end
        end

        return OriginalNamecall(Instance, ...)
    end))

    self._Maid:GiveTask(function()
        hookfunction(getrawmetatable(game).__namecall, OriginalNamecall)
    end)

    warn("RLGL feature started!")
end

function RedLightGreenLight:Destroy()
    warn("RLGL feature destroyed!")
    self._Maid:Destroy()
end

-- @class Dalgona
local Dalgona = {}
Dalgona.__index = Dalgona

function Dalgona.new(UIManager)
    local self = setmetatable({}, Dalgona)

    self._UIManager = UIManager
    self._Maid = Maid.new()

    return self
end

function Dalgona:Start()
    local DalgonaClientModule = game.ReplicatedStorage.Modules.Games.DalgonaClient

    local function CompleteDalgona()
        --[[
            Search for the callback of RunService.RenderStepped
             containing an upvalue used to keep track of the amount of successful clicks
             for the Dalgona challenge.

            Setting this upvalue (amount of successful clicks) to a large number
             will allow it to pass the Dalgona challenge checks.
        ]]

        if not self._UIManager:GetToggleValue("DalgonaAuto") then return end

        for _, Value in ipairs(getreg()) do
            if typeof(Value) == "function" and islclosure(Value) then
                if getfenv(Value).script == DalgonaClientModule then
                    if getinfo(Value).nups == 54 then
                        setupvalue(Value, 15, 9e9)
                        break
                    end
                end
            end
        end
    end
    
    local OriginalDalgonaFunction
    OriginalDalgonaFunction = hookfunction(require(DalgonaClientModule), function(...)
        task.delay(3, CompleteDalgona)        
        return OriginalDalgonaFunction(...)
    end)

    self._Maid:GiveTask(function()
        hookfunction(require(DalgonaClientModule), OriginalDalgonaFunction)
        self._UIManager.Toggles.DalgonaAuto:OnChanged(function() end)
    end)
    
    self._UIManager.Toggles.DalgonaAuto:OnChanged(CompleteDalgona)
    
    warn("Dalgona feature started!")
end

function Dalgona:Destroy()
    warn("Dalgona feature destroyed!")
    self._Maid:Destroy()
end

-- @class TugOfWar
local TugOfWar = {}
TugOfWar.__index = TugOfWar

function TugOfWar.new(UIManager)
    local self = setmetatable({}, TugOfWar)

    self._UIManager = UIManager
    self._Maid = Maid.new()

    return self
end

function TugOfWar:Start()
    local TemporaryReachedBindableRemote = ReplicatedStorage.Remotes.TemporaryReachedBindable
    
    local PULL_RATE = 0.025
    local VALID_PULL_DATA = {
        ["QTEGood"] = true
    }

    self._Maid:GiveTask(task.spawn(function()
        while task.wait(PULL_RATE) do
            if self._UIManager:GetToggleValue("TugOfWarAuto") then
                TemporaryReachedBindableRemote:FireServer(VALID_PULL_DATA)
            end
        end
    end))

    warn("TugOfWar feature started!")
end

function TugOfWar:Destroy()
    warn("TugOfWar feature destroyed!")
    self._Maid:Destroy()
end

-- @class GlassBridge
local GlassBridge = {}
GlassBridge.__index = GlassBridge

function GlassBridge.new(UIManager)
    local self = setmetatable({}, GlassBridge)

    self._UIManager = UIManager
    self._Maid = Maid.new()

    return self
end

function GlassBridge:Start()
    local GlassHolder = workspace.GlassBridge.GlassHolder

    local function SetupGlassPart(GlassPart)
        local CanEnableGlassBridgeESP = self._UIManager:GetToggleValue("GlassBridgeESP")
        if not CanEnableGlassBridgeESP then
            GlassPart.Color = Color3.fromRGB(106, 106, 106)
            GlassPart.Transparency = 0.45
            GlassPart.Material = Enum.Material.SmoothPlastic
        else
            -- Game owner is quite funny :skull:
            local Color = GlassPart:GetAttribute("exploitingisevil") and Color3.fromRGB(248, 87, 87) or Color3.fromRGB(28, 235, 87)
            GlassPart.Color = Color
            GlassPart.Transparency = 0
            GlassPart.Material = Enum.Material.Neon
        end
    end
    
    self._UIManager.Toggles.GlassBridgeESP:OnChanged(function()
        for _, PanelPair in ipairs(GlassHolder:GetChildren()) do
            for _, Panel in ipairs(PanelPair:GetChildren()) do
                local GlassPart = Panel:FindFirstChild("glasspart")
                if GlassPart then
                    task.defer(SetupGlassPart, GlassPart)
                end
            end
        end
    end)

    self._Maid:GiveTask(GlassHolder.DescendantAdded:Connect(function(Descendant)
        if Descendant.Name == "glasspart" and Descendant:IsA("BasePart") then
            task.defer(SetupGlassPart, Descendant)
        end
    end))

    self._Maid:GiveTask(function()
        self._UIManager.Toggles.GlassBridgeESP:OnChanged(function() end)
    end)

    warn("GlassBridge feature started!")
end

function GlassBridge:Destroy()
    warn("GlassBridge feature destroyed!")
    self._Maid:Destroy()
end

-- @class UIManager
local UIManager = {}
UIManager.__index = UIManager

function UIManager.new()
    local self = setmetatable({}, UIManager)
    
    self._Maid = Maid.new()
    self._Library = nil
    self._Window = nil
    self._Tabs = {}
    
    self.IsDestroyed = false

    -- Load and initialize the UI
    self:_LoadLibrary()
    
    self.Toggles = getgenv().Toggles
    self.Options = getgenv().Options

    self:_CreateWindow()
    self:_SetupTabs()
    
    self._Maid:GiveTask(function()
        self.IsDestroyed = true
        self._Library:Unload()
        
        -- Clear references
        self._Library = nil
        self._Window = nil
        self._Tabs = nil
        self.Toggles = nil
        self.Options = nil

        -- Terminate the script
        shared._InkGameScriptState.Cleanup()
    end)
    
    return self
end

function UIManager:_LoadLibrary()
    local Repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
    self._Library = loadstring(game:HttpGet(Repo .. 'Library.lua'))()
    
    if not self._Library then
        error("Failed to load LinoriaLib")
    end
end

function UIManager:_CreateWindow()
    self._Window = self._Library:CreateWindow({
        Title = "Ink Game Cheats | Script Author: Jorsan | UI Library: Linoria",
        Center = true,
        AutoShow = true,
        TabPadding = 8,
        MenuFadeTime = 0.2,
        Size = UDim2.new(0, 500, 0, 400)
    })
end

function UIManager:_SetupTabs()
    -- Create tabs
    self._Tabs = {
        Main = self._Window:AddTab("Main"),
        Player = self._Window:AddTab("Player"),
        Settings = self._Window:AddTab("Settings")
    }
    
    -- Setup tabs
    self:_SetupMainCheatsTab()
    self:_SetupPlayerTab()
    self:_SetupSettingsTab()
end

function UIManager:_SetupMainCheatsTab()
    local GameCheats = self._Tabs.Main:AddLeftGroupbox("Game Features")
    
    -- Red Light Green Light God Mode
    GameCheats:AddToggle("RedLightGodMode", {
        Text = "Red Light God Mode",
        Default = false,
        Tooltip = "Prevents you from being eliminated during Red Light Green Light"
    })
    
    -- Glass Bridge ESP
    GameCheats:AddToggle("GlassBridgeESP", {
        Text = "Glass Bridge ESP",
        Default = false,
        Tooltip = "Shows which glass panels are safe to step on"
    })
    
    -- Tug of War Auto Pull
    GameCheats:AddToggle("TugOfWarAuto", {
        Text = "Tug of War Auto Pull",
        Default = false,
        Tooltip = "Automatically pulls during Tug of War game"
    })
    
    -- Dalgona Auto Complete
    GameCheats:AddToggle("DalgonaAuto", {
        Text = "Dalgona Auto Complete",
        Default = false,
        Tooltip = "Automatically completes the Dalgona cookie challenge"
    })
    
    -- Add divider and status
    GameCheats:AddDivider()
    GameCheats:AddLabel("Status: Ready")
end

function UIManager:_SetupPlayerTab()
    local PlayerSettings = self._Tabs.Player:AddLeftGroupbox("Player Modifications")

    -- NoClip Toggle
    PlayerSettings:AddToggle("EnableWalkSpeed", {
        Text = "Enable WalkSpeed",
        Default = false
    })

    -- WalkSpeed Changer
    PlayerSettings:AddSlider("WalkSpeed", {
        Text = "Walk Speed",
        Default = 16,
        Min = 1,
        Max = 100,
        Rounding = 0,
        Compact = false,
        Suffix = " studs/s"
    })

    -- Add divider
    PlayerSettings:AddDivider()

    -- NoClip Toggle
    PlayerSettings:AddToggle("Noclip", {
        Text = "Noclip",
        Default = false,
        Tooltip = "Walk through walls"
    })

    -- Setup character cheats
    local Client = Players.LocalPlayer
    local CharacterMaid = Maid.new()

    self._Maid:GiveTask(CharacterMaid)

    local function OnCharacterAdded(Character)
        CharacterMaid:DoCleaning()
        local Humanoid = Character:WaitForChild("Humanoid")
        
        local CachedBaseParts = {}
        for _, Object in ipairs(Character:GetDescendants()) do
            if Object:IsA("BasePart") then
                table.insert(CachedBaseParts, Object)
            end
        end

        CharacterMaid:GiveTask(Character.DescendantAdded:Connect(function(Descendant)
            if Descendant:IsA("BasePart") then
                table.insert(CachedBaseParts, Descendant)
            end
        end))
        
        local function ChangeWalkSpeed()
            if not self:GetToggleValue("EnableWalkSpeed") then return end
            local NewWalkSpeed = self:GetOptionValue("WalkSpeed")
            if not NewWalkSpeed then return end
        
            Humanoid.WalkSpeed = NewWalkSpeed
        end
        
        CharacterMaid:GiveTask(Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(ChangeWalkSpeed))

        local NoclippedBaseParts = {}
        CharacterMaid:GiveTask(RunService.Stepped:Connect(function()
            if not self:GetToggleValue("Noclip") then
                for BasePart, _ in NoclippedBaseParts do
                    NoclippedBaseParts[BasePart] = nil
                    BasePart.CanCollide = true
                end
                return
            end

            for _, BasePart in ipairs(CachedBaseParts) do
                if BasePart.CanCollide then
                    NoclippedBaseParts[BasePart] = true
                    BasePart.CanCollide = false
                end
            end
        end))
        
        CharacterMaid:GiveTask(function()
            for BasePart, _ in NoclippedBaseParts do
                NoclippedBaseParts[BasePart] = nil
                BasePart.CanCollide = true
            end
        end)

        self.Toggles.EnableWalkSpeed:OnChanged(ChangeWalkSpeed)
        self.Options.WalkSpeed:OnChanged(ChangeWalkSpeed)
    end

    self._Maid:GiveTask(function()
        self.Toggles.EnableWalkSpeed:OnChanged(function() end)
        self.Options.WalkSpeed:OnChanged(function() end)
    end)
    
    self._Maid:GiveTask(Client.CharacterAdded:Connect(OnCharacterAdded))
    
    if Client.Character then
        task.spawn(OnCharacterAdded, Client.Character)
    end
end

function UIManager:_SetupSettingsTab()
    local MenuSettings = self._Tabs.Settings:AddLeftGroupbox("Menu Settings")
    
    MenuSettings:AddButton({
        Text = "Unload/Destroy Script",
        Func = function()
            self:Destroy()
        end,
        Tooltip = "Completely removes and destroys the script"
    })
end

function UIManager:GetToggleValue(ToggleName)
    if self.Toggles and self.Toggles[ToggleName] then
        return self.Toggles[ToggleName].Value
    end
    return false
end

function UIManager:GetOptionValue(OptionName)
    if self.Options and self.Options[OptionName] then
        return self.Options[OptionName].Value
    end
    
    return nil
end

function UIManager:Notify(Text, Duration)
    if not self._Library then return end
    self._Library:Notify(Text, Duration)
end

function UIManager:Destroy()
    if self.IsDestroyed then return end
    self._Maid:Destroy()
    
    warn("UIManager destroyed successfully!")
end

-- Validate game
assert(game.GameId == 7008097940, "Invalid Game!")

-- Setup Global State
if not shared._InkGameScriptState then
    shared._InkGameScriptState = {
        IsScriptExecuted = false,
        IsScriptReady = false,
        ScriptReady = Signal.new(),
        Cleanup = function() end
    }
end

local GlobalScriptState = shared._InkGameScriptState

-- Handle script re-execution
if GlobalScriptState.IsScriptExecuted then
    if not GlobalScriptState.IsScriptReady then
        GlobalScriptState.ScriptReady:Wait()
        if GlobalScriptState.IsScriptReady then return end
    end
    GlobalScriptState.Cleanup()
end

GlobalScriptState.IsScriptExecuted = true

-- Main
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local UI = UIManager.new()
local GameState = workspace.Values

local CurrentRunningFeature = nil
local GameChangedConnection = nil

local Features = {
    ["RedLightGreenLight"] = RedLightGreenLight,
    ["Dalgona"] = Dalgona,
    ["TugOfWar"] = TugOfWar,
    ["GlassBridge"] = GlassBridge
}

local function CleanupCurrentFeature()
    if CurrentRunningFeature then
        CurrentRunningFeature:Destroy()
        CurrentRunningFeature = nil
    end
end

local function CurrentGameChanged()
    warn("Current game: " .. GameState.CurrentGame.Value)
    
    CleanupCurrentFeature()
    
    local Feature = Features[GameState.CurrentGame.Value]
    if not Feature then return end

    CurrentRunningFeature = Feature.new(UI)
    CurrentRunningFeature:Start()
end

-- Setup connections
GameChangedConnection = GameState.CurrentGame:GetPropertyChangedSignal("Value"):Connect(CurrentGameChanged)
CurrentGameChanged()

-- Global cleanup function
GlobalScriptState.Cleanup = function()
    CleanupCurrentFeature()
    
    if GameChangedConnection then
        GameChangedConnection:Disconnect()
        GameChangedConnection = nil
    end
    
    if not UI.IsDestroyed then
        UI:Destroy()
    end
    
    GlobalScriptState.IsScriptReady = false
    GlobalScriptState.IsScriptExecuted = false
end

-- Mark as ready
GlobalScriptState.IsScriptReady = true
GlobalScriptState.ScriptReady:Fire()

UI:Notify("Script executed successfully!", 4)
UI:Notify("Script authored by: Jorsan, enjoy!", 4)
