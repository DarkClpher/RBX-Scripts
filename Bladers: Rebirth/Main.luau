--[[
    @author Jorsan
    @date 11/12/2024
--]]

--!nonstrict

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))()
local Maid = loadstring(game:HttpGet("https://raw.githubusercontent.com/Quenty/NevermoreEngine/refs/heads/main/src/maid/src/Shared/Maid.lua"))()
local Signal = loadstring(game:HttpGet("https://raw.githubusercontent.com/Sleitnick/RbxUtil/refs/heads/main/modules/signal/init.luau"))()

-- Game Modules
local NetworkModule = require(ReplicatedStorage.Modules.Network)

-- Constants
local GENERAL_POLL_DELAY = 0.1

-- Controllers
local AutofarmController = {}
local UIController = {}

-- Variables
local Client = Players.LocalPlayer

local BeybladesFolder = workspace.Beyblades
local TrainingFolder = workspace.Training

-- Controller Definitions
do
    local CharacterMaid = Maid.new()
    local CurrentRockTarget: nil | Model = nil

    function AutofarmController:_GetClientBeyblade() : Model
        return BeybladesFolder:FindFirstChild(Client.Name)
    end
    
    function AutofarmController:_LaunchBeyblade()
        local ClientBeyblade: Model = self:_GetClientBeyblade()
        if not ClientBeyblade then
            repeat
                NetworkModule:fire("Launch")
                task.wait(GENERAL_POLL_DELAY)
            until self:_GetClientBeyblade()
        end
    end

    function AutofarmController:_OnBeybladeRemoved(Beyblade: Model)
        if Beyblade.Name == Client.Name and UIController:IsBeybladeAutofarmToggled() then
            task.wait(GENERAL_POLL_DELAY) -- Small delay before relaunching
            self:_LaunchBeyblade()
            print("Re-Launched Beyblade!")
        end
    end

    function AutofarmController:_UnlaunchBeyblade()
        local Character = Client.Character
        if Character and Character:GetAttribute("Launching") == true then
            Character:GetAttributeChangedSignal("Launching"):Wait()
        end
        local ClientBeyblade: Model = self:_GetClientBeyblade()
        if ClientBeyblade then
            repeat
                NetworkModule:fire("Launch")
                task.wait(GENERAL_POLL_DELAY)
            until not self:_GetClientBeyblade()
        end
    end

    function AutofarmController:_ScanForRockTarget()
        local TargetRockName: string = UIController:GetSelectedRockName()
        for _, Rock: Model in TrainingFolder:GetChildren() do
            if Rock.PrimaryPart and Rock.PrimaryPart.Position.Y > 1000 then continue end
            if Rock.Name ~= TargetRockName then continue end
            CurrentRockTarget = Rock
            break
        end
    end

    function AutofarmController:_OnRockAdded(Rock: Model)
        task.wait() -- Wait for PrimaryPart to be added
        local TargetRockName: string = UIController:GetSelectedRockName()
        if Rock.Name ~= TargetRockName then return end

        if Rock.PrimaryPart and Rock.PrimaryPart.Position.Y < 1000 then
            if not CurrentRockTarget then
                CurrentRockTarget = Rock
            end
        end
    end
    
    function AutofarmController:_OnRockRemoved(Rock: Model)
        if Rock == CurrentRockTarget then
            CurrentRockTarget = nil
            -- Find new target
            self:_ScanForRockTarget()
        end
    end

    function AutofarmController:Init()
    end
    
    function AutofarmController:Start()
        local function OnCharacterAdded(Character)
            CharacterMaid:DoCleaning()

            Character:WaitForChild("HumanoidRootPart")
            Character:WaitForChild("Humanoid")

            -- Initial scan for valid target
            self:_ScanForRockTarget()

            -- Handle target tracking
            CharacterMaid:GiveTask(TrainingFolder.ChildAdded:Connect(function(Rock: Model)
                self:_OnRockAdded(Rock)
            end))

            CharacterMaid:GiveTask(TrainingFolder.ChildRemoved:Connect(function(Rock: Model)
                self:_OnRockRemoved(Rock)
            end))

            -- Handle beyblade tracking
            CharacterMaid:GiveTask(BeybladesFolder.ChildRemoved:Connect(function(Beyblade: Model)
                self:_OnBeybladeRemoved(Beyblade)
            end))

            -- Beyblade Attack Handler
            local LastAttack: number = 0
            CharacterMaid:GiveTask(RunService.Heartbeat:Connect(function()
                if not UIController:IsBeybladeAutofarmToggled() then return end

                local ClientBeyblade: Model = self:_GetClientBeyblade()
                if not ClientBeyblade then return end

                if not CurrentRockTarget then return end
                if os.clock() - LastAttack < GENERAL_POLL_DELAY then return end

                -- Attack Target
                LastAttack = os.clock()

                if UIController:GetHighestPriorityFarm() == "RockFarm" then
                    NetworkModule:fire("Attack", CurrentRockTarget, 0.9, Vector3.new())
                end
            end))

            -- Beyblade Teleportation Handler
            CharacterMaid:GiveTask(RunService.Heartbeat:Connect(function()
                if not UIController:IsBeybladeAutofarmToggled() then return end
                
                local ClientBeyblade: Model = self:_GetClientBeyblade()

                if not ClientBeyblade then return end
                if not CurrentRockTarget then return end

                -- Teleport to target
                if UIController:GetHighestPriorityFarm() == "RockFarm" then
                    ClientBeyblade.PrimaryPart.CFrame = CurrentRockTarget.PrimaryPart.CFrame * CFrame.new(0, -10, 0)
                end
            end))

            CharacterMaid:GiveTask(UIController.OnBeybladeAutofarmToggled:Connect(function(IsEnabled: boolean)
                if IsEnabled then
                    self:_LaunchBeyblade()
                else
                    self:_UnlaunchBeyblade()
                end
            end))

            CharacterMaid:GiveTask(UIController.OnRockTargetTypeChanged:Connect(function()
                -- Scan for a new target after changing the type of rock we want to target
                self:_ScanForRockTarget()
            end))

            -- Cleanup
            CharacterMaid:GiveTask(function()
                CurrentRockTarget = nil
                LastAttack = nil
            end)
        end

        Client.CharacterAdded:Connect(OnCharacterAdded)
        if Client.Character then
            task.spawn(OnCharacterAdded, Client.Character)
        end
    end
end

do 
    local CONFIG_FOLDER_NAME: string = "Bladers-Rebirth-Config-2"

    UIController.OnBeybladeAutofarmToggled = Signal.new()
    UIController.OnRockTargetTypeChanged = Signal.new()    
   
    -- Centralized state management
    UIController.State = {
        IsAutofarmEnabled = false,
        SelectedRock = "Rock", -- Default value
        ActiveFarms = {
            RockFarm = {
                Enabled = false,
                Priority = 50
            }
        }
    }

    -- State getters
    function UIController:IsBeybladeAutofarmToggled(): boolean
        return self.State.IsAutofarmEnabled
    end

    function UIController:GetSelectedRockName(): string
        return self.State.SelectedRock
    end

    function UIController:GetHighestPriorityFarm(): nil | string
        local HighestPriority: number = -1
        local SelectedFarm: nil | string = nil
        
        for FarmType: string, FarmData in pairs(self.State.ActiveFarms) do
            if FarmData.Enabled and FarmData.Priority > HighestPriority then
                HighestPriority = FarmData.Priority
                SelectedFarm = FarmType
            end
        end
        
        return SelectedFarm
    end

    -- State setters
    function UIController:SetAutofarmEnabled(IsEnabled: boolean)
        self.State.IsAutofarmEnabled = IsEnabled
        self.OnBeybladeAutofarmToggled:Fire(IsEnabled)
    end

    function UIController:SetSelectedRock(RockName: string)
        self.State.SelectedRock = RockName
        self.OnRockTargetTypeChanged:Fire()
    end

    function UIController:SetFarmState(FarmType: string, IsEnabled: boolean, Priority: number?)
        if IsEnabled ~= nil then
            self.State.ActiveFarms[FarmType].Enabled = IsEnabled
        end

        if Priority then
            self.State.ActiveFarms[FarmType].Priority = Priority
        end
    end

    function UIController:Start()
    end
    
    function UIController:Init()
        local Window = Rayfield:CreateWindow({
            Name = "Blader's Rebirth",
            LoadingTitle = "Loading User Interface",
            LoadingSubtitle = "Script Credits: Jorsan",
    
            ConfigurationSaving = {
                Enabled = true,
                FolderName = CONFIG_FOLDER_NAME
            },
            
            KeySystem = false
        })

        UIController:_CreateFarmTab(Window)
        Rayfield:LoadConfiguration()
    end
    
    function UIController:_CreateFarmTab(Window)
        local Tab = Window:CreateTab("Farming", 4483362458)
        
        -- Main Autofarm Toggle Section
        Tab:CreateSection("Main Controls")
        
        Tab:CreateToggle({
            Name = "Enable Beyblade Autofarm",
            CurrentValue = self.State.IsAutofarmEnabled,
            Flag = "MainAutofarmToggle",
            Callback = function(State)
                self:SetAutofarmEnabled(State)
            end,
        })
        
        -- Rock Farm Section
        Tab:CreateSection("Auto Rock Farm")

        local RockList = {
            "Rock", "Large Rock", "Cobblestone", "Metal", "Large Metal Rock", 
            "Blood Rock", "Bluesteel Rock", "Large Bluesteel Rock",
            "Sandstone", "Sandcastle", "Cactus", "Glacier", "Ice Crystal", 
            "Water Rock", "Giant Water Rock", "Ghost Tear", "Darkstone", 
            "Molten Rock", "Large Darkstone", "Portable Crystal", "Boulder"
        }

        -- Add anything extra we missed out
        for _, Rock in TrainingFolder:GetChildren() do
            if not table.find(RockList, Rock.Name) then continue end
            table.insert(RockList, Rock.Name)        
        end
        
        Tab:CreateDropdown({
            Name = "Select Rock to Farm",
            Options = RockList,
            CurrentOption = {self.State.SelectedRock},
            Flag = "SelectedRockToFarm",
            Callback = function(Option)
                self:SetSelectedRock(Option[1])
            end
        })

        Tab:CreateToggle({
            Name = "Rock Autofarm",
            CurrentValue = self.State.ActiveFarms.RockFarm.Enabled,
            Flag = "RockAutofarmToggle",
            Callback = function(State)
                self:SetFarmState("RockFarm", State)
            end,
        })
        
        Tab:CreateSlider({
            Name = "Rock Farm Priority",
            Range = {0, 100},
            Increment = 1,
            Suffix = "Priority",
            CurrentValue = self.State.ActiveFarms.RockFarm.Priority,
            Flag = "RockFarmPriority",
            Callback = function(Value)
                self:SetFarmState("RockFarm", nil, Value)
            end,
        })
    end
end

-- Load Controllers
local function LoadControllers()
    -- Bypasses before we start anything:

    -- Reverse Remote name randomisations
    -- I will only be utilizing this for remote listeners
    for _, Upvalue in getupvalues(NetworkModule.fire) do
        if type(Upvalue) == "table" and Upvalue["Attack"] then            
            for RemoteName, RemoteObject in Upvalue do
                RemoteObject.Name = RemoteName
            end
            break
        end
    end

    UIController:Init()
    UIController:Start()

    AutofarmController:Init()
    AutofarmController:Start()
end

LoadControllers()
