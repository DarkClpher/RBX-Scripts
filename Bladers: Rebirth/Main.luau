--[[
    @author Jorsan
    @date 11/12/2024
--]]

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
    local CurrentRockTarget = nil

    function AutofarmController:_GetClientBeyblade()
        return BeybladesFolder:FindFirstChild(Client.Name)
    end
    
    function AutofarmController:_LaunchBeyblade()
        local ClientBeyblade = BeybladesFolder:FindFirstChild(Client.Name)
        if not ClientBeyblade then
            repeat
                NetworkModule:fire("Launch")
                task.wait(GENERAL_POLL_DELAY)
            until BeybladesFolder:FindFirstChild(Client.Name)
        end
    end

    function AutofarmController:_OnBeybladeRemoved(Beyblade)
        if Beyblade.Name == Client.Name and UIController.States.IsBeybladeAutofarmToggled then
            task.wait(GENERAL_POLL_DELAY) -- Small delay before relaunching
            self:_LaunchBeyblade()
            print("Re-Launched Beyblade!")
        end
    end

    function AutofarmController:_UnlaunchBeyblade()
        if Client.Character and Client.Character:GetAttribute("Launching") == true then
            Client.Character:GetAttributeChangedSignal("Launching"):Wait()
        end
        local ClientBeyblade = BeybladesFolder:FindFirstChild(Client.Name)
        if ClientBeyblade then
            repeat
                NetworkModule:fire("Launch")
                task.wait(GENERAL_POLL_DELAY)
            until not BeybladesFolder:FindFirstChild(Client.Name)
        end
    end

    function AutofarmController:_OnRockAdded(Rock)
        task.wait() -- Wait for PrimaryPart to be added
        local TargetRockName = Rayfield.Flags.SelectedRockToFarm.CurrentOption[1]
        if Rock.Name ~= TargetRockName then return end

        if Rock.PrimaryPart and Rock.PrimaryPart.Position.Y < 1000 then
            if not CurrentRockTarget then
                CurrentRockTarget = Rock
            end
        end
    end
    
    function AutofarmController:_OnRockRemoved(Rock)
        if Rock == CurrentRockTarget then
            CurrentRockTarget = nil

            -- Find new target
            local TargetRockName = Rayfield.Flags.SelectedRockToFarm.CurrentOption[1]

            for _, NewRock in TrainingFolder:GetChildren() do
                if NewRock.Name ~= TargetRockName then continue end
                if NewRock.PrimaryPart and NewRock.PrimaryPart.Position.Y > 1000 then continue end
                CurrentRockTarget = NewRock
                break
            end
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
            local TargetRockName = Rayfield.Flags.SelectedRockToFarm.CurrentOption[1]
            for _, Rock in TrainingFolder:GetChildren() do
                if Rock.PrimaryPart and Rock.PrimaryPart.Position.Y > 1000 then continue end
                if Rock.Name ~= TargetRockName then continue end
                CurrentRockTarget = Rock
                break
            end

            -- Handle target tracking
            CharacterMaid:GiveTask(TrainingFolder.ChildAdded:Connect(function(Rock)
                self:_OnRockAdded(Rock)
            end))

            CharacterMaid:GiveTask(TrainingFolder.ChildRemoved:Connect(function(Rock)
                self:_OnRockRemoved(Rock)
            end))

            -- Handle beyblade tracking
            CharacterMaid:GiveTask(BeybladesFolder.ChildRemoved:Connect(function(Beyblade)
                self:_OnBeybladeRemoved(Beyblade)
            end))

            -- Beyblade Attack Handler
            local LastAttack = 0
            CharacterMaid:GiveTask(RunService.Heartbeat:Connect(function()
                if not UIController.States.IsBeybladeAutofarmToggled then return end

                local ClientBeyblade = self:_GetClientBeyblade()
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
                if not UIController.States.IsBeybladeAutofarmToggled then return end
                
                local ClientBeyblade = self:_GetClientBeyblade()

                if not ClientBeyblade then return end
                if not CurrentRockTarget then return end

                -- Teleport to target
                if UIController:GetHighestPriorityFarm() == "RockFarm" then
                    ClientBeyblade.PrimaryPart.CFrame = CurrentRockTarget.PrimaryPart.CFrame * CFrame.new(0, -10, 0)
                end
            end))

            CharacterMaid:GiveTask(UIController.OnBeybladeAutofarmToggled:Connect(function(IsEnabled)
                if IsEnabled then
                    self:_LaunchBeyblade()
                else
                    self:_UnlaunchBeyblade()
                end
            end))

            -- Cleanup character is removed
            CharacterMaid:GiveTask(function()
                CurrentRockTarget = nil
            end)
        end

        Client.CharacterAdded:Connect(OnCharacterAdded)
        if Client.Character then
            task.spawn(OnCharacterAdded, Client.Character)
        end
    end
end

do 
    local CONFIG_FOLDER_NAME = "Bladers Rebirth Config"

    UIController.OnBeybladeAutofarmToggled = Signal.new()    
    UIController.States = {
        IsBeybladeAutofarmToggled = false,
        ActiveFarms = {}
    }

    function UIController:Init()
        UIController.Window = Rayfield:CreateWindow({
            Name = "Blader's Rebirth",
            LoadingTitle = "Loading User Interface",
            LoadingSubtitle = "Script Credits: Jorsan",
    
            ConfigurationSaving = {
                Enabled = true,
                FolderName = CONFIG_FOLDER_NAME
            },
            
            KeySystem = false
        })

        UIController:_CreateFarmTab()
        Rayfield:LoadConfiguration()
    end

    function UIController:Start()
    end

    function UIController:GetHighestPriorityFarm()
        local HighestPriority = -1
        local SelectedFarm = nil
        
        for FarmType, FarmData in pairs(self.States.ActiveFarms) do
            if FarmData.Enabled and FarmData.Priority > HighestPriority then
                HighestPriority = FarmData.Priority
                SelectedFarm = FarmType
            end
        end
        
        return SelectedFarm
    end
    
    function UIController:_CreateFarmTab()
        local Tab = UIController.Window:CreateTab("Farming", 4483362458)
        
        -- Main Autofarm Toggle Section
        Tab:CreateSection("Main Controls")
        
        Tab:CreateToggle({
            Name = "Enable Beyblade Autofarm",
            CurrentValue = false,
            Flag = "MainAutofarmToggle",
            Callback = function(State)
                self.States.IsBeybladeAutofarmToggled = State
                self.OnBeybladeAutofarmToggled:Fire(State)
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
            CurrentOption = {RockList[1]},
            Flag = "SelectedRockToFarm",
            Callback = function() end
        })

        -- Initialize rock farm data in ActiveFarms
        self.States.ActiveFarms.RockFarm = {
            Enabled = false,
            Priority = 50
        }
        
        Tab:CreateToggle({
            Name = "Rock Autofarm",
            CurrentValue = false,
            Flag = "RockAutofarmToggle",
            Callback = function(State)
                self.States.ActiveFarms.RockFarm.Enabled = State
            end,
        })
        
        Tab:CreateSlider({
            Name = "Rock Farm Priority",
            Range = {0, 100},
            Increment = 1,
            Suffix = "Priority",
            CurrentValue = 50,
            Flag = "RockFarmPriority",
            Callback = function(Value)
                self.States.ActiveFarms.RockFarm.Priority = Value
            end,
        })
    end
end

-- Load Controllers
UIController:Init()
UIController:Start()

AutofarmController:Init()
AutofarmController:Start()
