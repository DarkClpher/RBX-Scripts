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
local VirtualUser = game:GetService("VirtualUser")

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

-- Classes
local BaseFarmStrategy = {}
local RockFarmStrategy = {}

local BaseNPCBattleStrategy = {}
local TrainerFarmStrategy = {}
local BossFarmStrategy = {}

-- Variables
local Client = Players.LocalPlayer

local EventsFolder = ReplicatedStorage.Events
local BeybladesFolder = workspace.Beyblades
local TrainingFolder = workspace.Training
local NPCsFolder = workspace.NPCs

-- Class Definitions
do
    BaseFarmStrategy.__index = BaseFarmStrategy

    function BaseFarmStrategy.new()
        local self = setmetatable({}, BaseFarmStrategy)
        self._LastAttack = 0
        self._Maid = Maid.new()
        return self
    end

    function BaseFarmStrategy:Start()
        -- Override in child classes
    end

    function BaseFarmStrategy:Update()
        -- Override in child classes
    end

    function BaseFarmStrategy:Destroy()
        self._Maid:DoCleaning()
        self._Maid = nil
    end
end

do
    setmetatable(RockFarmStrategy, BaseFarmStrategy)
    RockFarmStrategy.__index = RockFarmStrategy
    
    function RockFarmStrategy.new()
        local self = setmetatable(BaseFarmStrategy.new(), RockFarmStrategy)
        self._CurrentTarget = nil

        self._Maid:GiveTask(function()
            self._CurrentTarget = nil
            AutofarmController:UnlaunchBeyblade() 
        end)
        
        return self
    end
    
    function RockFarmStrategy:ScanForTarget()
        local TargetRockName: string = UIController:GetSelectedRockName()
        for _, Rock: Model in TrainingFolder:GetChildren() do
            if Rock.PrimaryPart and Rock.PrimaryPart.Position.Y > 1000 then continue end
            if Rock.Name ~= TargetRockName then continue end
            self._CurrentTarget = Rock
            break
        end
    end
    
    function RockFarmStrategy:Update()
        local ClientBeyblade: Model = AutofarmController:GetClientBeyblade()
        if not ClientBeyblade or not self._CurrentTarget then return end
        
        -- Attack logic
        if os.clock() - self._LastAttack >= GENERAL_POLL_DELAY then
            self._LastAttack = os.clock()
            NetworkModule:fire("Attack", self._CurrentTarget, 0.9, self._CurrentTarget.PrimaryPart.Position)
        end
        
        -- Teleport logic
        ClientBeyblade.HumanoidRootPart.CFrame = self._CurrentTarget.PrimaryPart.CFrame * CFrame.new(0, -10, 0)
    end
    
    function RockFarmStrategy:Start()
        -- Initial Beyblade launch
        AutofarmController:LaunchBeyblade()

        -- Initial scan for valid target
        self:ScanForTarget()

        -- Handle beyblade tracking
        self._Maid:GiveTask(BeybladesFolder.ChildRemoved:Connect(function(Beyblade: Model)
            if Beyblade.Name == Client.Name then
                task.wait(self.GENERAL_POLL_DELAY)
                AutofarmController:LaunchBeyblade()
            end
        end))

        -- Handle rock tracking
        self._Maid:GiveTask(TrainingFolder.ChildAdded:Connect(function(Rock: Model)
            task.wait()
            local TargetRockName = UIController:GetSelectedRockName()
            if Rock.Name ~= TargetRockName then return end
            
            if Rock.PrimaryPart and Rock.PrimaryPart.Position.Y < 1000 then
                if not self._CurrentTarget then
                    self._CurrentTarget = Rock
                end
            end
        end))
        
        self._Maid:GiveTask(TrainingFolder.ChildRemoved:Connect(function(Rock: Model)
            if Rock == self._CurrentTarget then
                self._CurrentTarget = nil
                self:ScanForTarget()
            end
        end))

        self._Maid:GiveTask(UIController.OnRockTargetTypeChanged:Connect(function()
            -- Scan for a new target after changing the type of rock we want to target
            self:ScanForTarget()
        end))
    end
end

do
    setmetatable(BaseNPCBattleStrategy, BaseFarmStrategy)
    BaseNPCBattleStrategy.__index = BaseNPCBattleStrategy

    type DialogueChoice = {
        Id: number,
        Text: string,
        Type: string?,
    }    

    function BaseNPCBattleStrategy.new()
        local self = setmetatable(BaseFarmStrategy.new(), BaseNPCBattleStrategy)
        self._CurrentNPC = nil
        self._NPCBeyblade = nil

        self._Maid:GiveTask(function()
            self._CurrentNPC = nil
            self._NPCBeyblade = nil
        end)

        return self
    end

    function BaseNPCBattleStrategy:HandleDialogue(Responses: { DialogueChoice }, NPC: Model)
        if not Responses or not NPC then return end

        local FirstResponseId, FirstReplyId
        
        for _, Choice in ipairs(Responses) do
            if Choice.Type == "Response" and not FirstResponseId then 
                FirstResponseId = Choice.Id
            elseif Choice.Type == "Reply" and not FirstReplyId then
                FirstReplyId = Choice.Id
            end
        end
        
        local DelayTime = FirstReplyId and 2 or 0.5
        local ChoiceId = FirstReplyId or FirstResponseId
        
        task.wait(DelayTime)
        NetworkModule:fire("DialogueChoice", ChoiceId)
    end

    function BaseNPCBattleStrategy:Update()
        local ClientBeyblade: Model = AutofarmController:GetClientBeyblade()
        
        if not ClientBeyblade or not self._NPCBeyblade then return end
        
        if os.clock() - self._LastAttack >= GENERAL_POLL_DELAY then
            self._LastAttack = os.clock()
            NetworkModule:fire("Attack", self._NPCBeyblade, 0.9, self._NPCBeyblade.HumanoidRootPart.Position)
        end

        ClientBeyblade.HumanoidRootPart.CFrame = self._NPCBeyblade.HumanoidRootPart.CFrame * CFrame.new(0, -5, 0)
    end

    function BaseNPCBattleStrategy:Start()
        self._Maid:GiveTask(task.spawn(function()
            while true do
                task.wait(1)
                if not self._CurrentNPC and not self._NPCBeyblade then
                    self:BeginFarming()
                end
            end
        end))

        self._Maid:GiveTask(EventsFolder.UpdateDialogue.OnClientEvent:Connect(function(DialogueResponses, NPC)
            self:HandleDialogue(DialogueResponses, NPC)
        end))
        
        self._Maid:GiveTask(BeybladesFolder.ChildAdded:Connect(function(Beyblade)
            task.wait(0.5)
            if Beyblade:GetAttribute("TargetPlayer") == Client.Name then
                self._NPCBeyblade = Beyblade
            end
        end))

        self._Maid:GiveTask(BeybladesFolder.ChildRemoved:Connect(function(Beyblade)
            if Beyblade == self._NPCBeyblade then
                self._NPCBeyblade = nil
                task.wait(1)
                self:BeginFarming()
            end
        end))
        
        self:BeginFarming()
    end

    function BaseNPCBattleStrategy:BeginFarming()
        AutofarmController:UnlaunchBeyblade()
                
        self._CurrentNPC = self:FindAvailableNPC()
        if not self._CurrentNPC then return end
        
        local Character = Client.Character
        if not Character then return end
        
        Character.HumanoidRootPart.CFrame = self._CurrentNPC.HumanoidRootPart.CFrame
        task.wait(1)
        fireproximityprompt(self._CurrentNPC.HumanoidRootPart.Dialogue)
    end

    function BaseNPCBattleStrategy:FindAvailableNPC()
    end
end

do
    setmetatable(TrainerFarmStrategy, BaseNPCBattleStrategy)
    TrainerFarmStrategy.__index = TrainerFarmStrategy

    function TrainerFarmStrategy.new()
        return setmetatable(BaseNPCBattleStrategy.new(), TrainerFarmStrategy)
    end

    function TrainerFarmStrategy:FindAvailableNPC()
        for _, NPC in NPCsFolder:GetChildren() do
            if not string.find(NPC.Name, "Trainer") then continue end

            local CooldownEndTime = NPC:GetAttribute("CooldownEnd")            
            if CooldownEndTime and os.time() < CooldownEndTime then continue end

            local NPCLevel = NPC:GetAttribute("Level")
            if NPCLevel < UIController:GetMinimumTrainerLevel() then continue end
            if NPCLevel > UIController:GetMaximumTrainerLevel() then continue end
            
            return NPC
        end

        return nil
    end
end

do
    setmetatable(BossFarmStrategy, BaseNPCBattleStrategy)
    BossFarmStrategy.__index = BossFarmStrategy

    function BossFarmStrategy.new()
        return setmetatable(BaseNPCBattleStrategy.new(), BossFarmStrategy)
    end

    function BossFarmStrategy:FindAvailableNPC()
        for _, NPC in NPCsFolder:GetChildren() do
            if not string.find(NPC.Name, "Boss") then continue end
            if not table.find(UIController:GetTargetBossNames(), NPC:GetAttribute("Name")) then
                continue
            end

            local CooldownEndTime = NPC:GetAttribute("CooldownEnd")            
            if CooldownEndTime and os.time() < CooldownEndTime then continue end
                        
            return NPC
        end

        return nil
    end
end

-- Controller Definitions
do
    local FarmStrategyClasses = {
        RockFarm = RockFarmStrategy,
        TrainerFarm = TrainerFarmStrategy,
        BossFarm = BossFarmStrategy
    }

    function AutofarmController:GetClientBeyblade() : Model
        return BeybladesFolder:FindFirstChild(Client.Name)
    end
    
    function AutofarmController:LaunchBeyblade()
        local ClientBeyblade: Model = self:GetClientBeyblade()
        if not ClientBeyblade then
            repeat
                NetworkModule:fire("Launch")
                task.wait(GENERAL_POLL_DELAY)
            until self:GetClientBeyblade()
        end
    end

    function AutofarmController:UnlaunchBeyblade()
        local Character = Client.Character
        if Character and Character:GetAttribute("Launching") then
            Character:GetAttributeChangedSignal("Launching"):Wait()
        end
        local ClientBeyblade: Model = self:GetClientBeyblade()
        if ClientBeyblade then
            repeat
                NetworkModule:fire("Launch")
                task.wait(GENERAL_POLL_DELAY)
            until not self:GetClientBeyblade()
        end
    end

    function AutofarmController:SwitchStrategy(NewStrategyType: string?)
        if self.CurrentFarmStrategy then
            self.CurrentFarmStrategy:Destroy()
            self.CurrentFarmStrategy = nil
        end

        if NewStrategyType and FarmStrategyClasses[NewStrategyType] then
            -- Create a new instance of the strategy class
            self.CurrentFarmStrategy = FarmStrategyClasses[NewStrategyType].new()

            if UIController:IsBeybladeAutofarmToggled() then
                self.CurrentFarmStrategy:Start()
            end
        end
    end

    function AutofarmController:Init()
        self.CurrentFarmStrategy = nil
    end
    
    function AutofarmController:Start()
        local CharacterMaid = Maid.new()
        
        local function OnCharacterAdded(Character)
            CharacterMaid:DoCleaning()

            Character:WaitForChild("HumanoidRootPart")
            Character:WaitForChild("Humanoid")

            -- Handle Beyblade autofarm updates
            CharacterMaid:GiveTask(RunService.Heartbeat:Connect(function()
                if not UIController:IsBeybladeAutofarmToggled() then return end
                if self.CurrentFarmStrategy then
                    self.CurrentFarmStrategy:Update()
                end
            end))
            
            -- Handle priority changes
            CharacterMaid:GiveTask(UIController.OnHighestPriorityFarmChanged:Connect(function(NewHighestFarmType: string?)
                self:SwitchStrategy(NewHighestFarmType)
            end))

            CharacterMaid:GiveTask(UIController.OnBeybladeAutofarmToggled:Connect(function(IsEnabled: boolean)
                local CurrentStrategy = self.CurrentFarmStrategy
                
                if CurrentStrategy then
                    if IsEnabled then
                        CurrentStrategy:Start()
                    else
                        self:SwitchStrategy(nil)
                    end
                elseif IsEnabled then
                    self:SwitchStrategy(UIController:GetHighestPriorityFarm())
                end
            end))

            -- Cleanup
            CharacterMaid:GiveTask(function()
                self:SwitchStrategy(nil) -- Clean up current strategy
            end)
        end

        Client.CharacterAdded:Connect(OnCharacterAdded)
        if Client.Character then
            task.spawn(OnCharacterAdded, Client.Character)
        end
    end
end

do 
    local CONFIG_FOLDER_NAME: string = "TEST-CONFIG1"

    UIController.OnBeybladeAutofarmToggled = Signal.new()

    UIController.OnTrainerFarmToggled = Signal.new() 
    UIController.OnBossFarmToggled = Signal.new()
    UIController.OnRockFarmToggled = Signal.new() 

    UIController.OnHighestPriorityFarmChanged = Signal.new()
    UIController.OnRockTargetTypeChanged = Signal.new()

    UIController.OnTrainerLevelChanged = Signal.new()

    -- State management
    UIController.State = {
        IsAutofarmEnabled = false,
        ActiveFarms = {
            RockFarm = {
                Enabled = false,
                Priority = 10,
                SelectedRock = "Rock"
            },

            TrainerFarm = {
                Enabled = false,
                Priority = 10,
                MinimumLevel = 5,
                MaximumLevel = 5
            },

            BossFarm = {
                Enabled = false,
                Priority = 10
            }
        }
    }

    -- Helpers
    function UIController:_CheckAndFirePriorityChange()
        local NewHighestPriorityFarm = self:GetHighestPriorityFarm()

        -- Store the last highest priority farm if we haven't yet
        if not self._LastHighestPriorityFarm then
            self._LastHighestPriorityFarm = NewHighestPriorityFarm
            self.OnHighestPriorityFarmChanged:Fire(NewHighestPriorityFarm, nil)
            return
        end
        
        -- If the highest priority farm has changed, fire the signal
        if self._LastHighestPriorityFarm ~= NewHighestPriorityFarm then
            self.OnHighestPriorityFarmChanged:Fire(NewHighestPriorityFarm, self._LastHighestPriorityFarm)
            self._LastHighestPriorityFarm = NewHighestPriorityFarm
        end
    end

    -- State getters
    function UIController:IsBeybladeAutofarmToggled(): boolean
        return self.State.IsAutofarmEnabled
    end

    function UIController:GetSelectedRockName(): string
        return self.State.ActiveFarms.RockFarm.SelectedRock
    end

    function UIController:GetMaximumTrainerLevel()
        return self.State.ActiveFarms.TrainerFarm.MaximumLevel
    end

    function UIController:GetMinimumTrainerLevel()
        return self.State.ActiveFarms.TrainerFarm.MinimumLevel
    end

    function UIController:GetTargetBossNames()
        return Rayfield.Flags.SelectedBossToFarm.CurrentOption
    end

    function UIController:GetHighestPriorityFarm(): nil | string
        local HighestPriority: number = -1
        local SelectedFarm: (nil | string) = nil
        
        for FarmType: string, FarmData in self.State.ActiveFarms do
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
        self.State.ActiveFarms.RockFarm.SelectedRock = RockName
        self.OnRockTargetTypeChanged:Fire()
    end

    function UIController:SetFarmState(FarmType: string, IsEnabled: boolean, Priority: number?)
        if IsEnabled ~= nil then
            self.State.ActiveFarms[FarmType].Enabled = IsEnabled
        end

        if Priority then
            self.State.ActiveFarms[FarmType].Priority = Priority
        end

        -- Check if this change affected the highest priority farm
        self:_CheckAndFirePriorityChange()
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
            CurrentOption = {self.State.ActiveFarms.RockFarm.SelectedRock},
            Flag = "SelectedRockToFarm",
            Callback = function(Option)
                self:SetSelectedRock(Option[1])
            end
        })

        --[[
        Tab:CreateSlider({
            Name = "Priority",
            Range = {0, 10},
            Increment = 1,
            Suffix = "Priority",
            CurrentValue = self.State.ActiveFarms.RockFarm.Priority,
            Flag = "RockFarmPriority",
            Callback = function(Value)
                -- Update priority change
                self:SetFarmState("RockFarm", nil, Value)
            end,
        })
        --]]
        
        Tab:CreateToggle({
            Name = "Rock Autofarm",
            CurrentValue = self.State.ActiveFarms.RockFarm.Enabled,
            Flag = "RockAutofarmToggle",
            Callback = function(State)
                self:SetFarmState("RockFarm", State)
                UIController.OnRockFarmToggled:Fire(State)
            end,
        })

        -- Trainer NPC Autofarm Section
        Tab:CreateSection("Auto Trainer Farm")

        -- Get the highest level trainer in the game
        local MaxTrainerLevel = -math.huge
        for _, NPC in NPCsFolder:GetChildren() do
            if not string.find(NPC.Name, "Trainer") then continue end
            local NPCLevel = NPC:GetAttribute("Level")
            if NPCLevel < MaxTrainerLevel then continue end
            MaxTrainerLevel = NPCLevel
        end

        Tab:CreateSlider({
            Name = "Minimum Trainer Level",
            Range = {5, MaxTrainerLevel},
            Increment = 5,
            CurrentValue = self.State.ActiveFarms.TrainerFarm.MinimumLevel,
            Flag = "MinimumTrainerLevel",
            Callback = function(Value)
                self.State.ActiveFarms.TrainerFarm.MinimumLevel = tonumber(Value)
                self.OnTrainerLevelChanged:Fire()
            end,
        })

        Tab:CreateSlider({
            Name = "Maximum Trainer Level",
            Range = {5, MaxTrainerLevel},
            Increment = 5,
            CurrentValue = self.State.ActiveFarms.TrainerFarm.MaximumLevel,
            Flag = "MaximumTrainerLevel",
            Callback = function(Value)
                self.State.ActiveFarms.TrainerFarm.MaximumLevel = tonumber(Value)
                self.OnTrainerLevelChanged:Fire()
            end,
        })

        --[[
        Tab:CreateSlider({
            Name = "Priority",
            Range = {0, 10},
            Increment = 1,
            Suffix = "Priority",
            CurrentValue = self.State.ActiveFarms.TrainerFarm.Priority,
            Flag = "TrainerFarmPriority",
            Callback = function(Value)
                -- Update priority change
                self:SetFarmState("TrainerFarm", nil, Value)
            end,
        })
        --]]

        Tab:CreateToggle({
            Name = "Trainer Autofarm",
            CurrentValue = false,
            Flag = "TrainerAutofarmToggle",
            Callback = function(State)
                self:SetFarmState("TrainerFarm", State)
                self.OnTrainerFarmToggled:Fire(State)
            end,
        })

        -- Boss NPC Autofarm Section
        Tab:CreateSection("Auto Boss Farm")
	
        local BossList = {}
        for _, NPC in ipairs(NPCsFolder:GetChildren()) do
            if not string.find(NPC.Name, "Boss") then continue end
            table.insert(BossList, NPC:GetAttribute("Name"))
        end
        
        Tab:CreateDropdown({
            Name = "Select Bosses to Farm",
            Options = BossList,
            CurrentOption = {BossList[1]},
            Flag = "SelectedBossToFarm",
            MultipleOptions = true,
            Callback = function() end
        })

        --[[
        Tab:CreateSlider({
            Name = "Priority",
            Range = {0, 10},
            Increment = 1,
            Suffix = "Priority",
            CurrentValue = self.State.ActiveFarms.BossFarm.Priority,
            Flag = "BossFarmPriority",
            Callback = function(Value)
                -- Update priority change
                self:SetFarmState("BossFarm", nil, Value)
            end,
        })
        --]]
        
        Tab:CreateToggle({
            Name = "Boss Autofarm",
            CurrentValue = false,
            Flag = "BossAutofarmToggle",
            Callback = function(State)
                self:SetFarmState("BossFarm", State)
                self.OnBossFarmToggled:Fire(State)
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

    Client.Idled:connect(function()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    UIController:Init()
    AutofarmController:Init()

    UIController:Start()
    AutofarmController:Start()
end

LoadControllers()
