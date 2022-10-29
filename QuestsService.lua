
local RunService = game:GetService('RunService')
local HttpService = game:GetService('HttpService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))
local QuestData = ReplicatedModules.Quests

local QuestRemoteEvent = ReplicatedModules.RemoteService:GetRemote("Quests", "RemoteEvent", false)

local SystemsContainer = {}

local maxActiveQuests = 3

local serverQuestRewards = {
	_SlimeQuest1 = function(LocalPlayer : Player, playerProfile)
		
	end,
	_MushroomsQuest1 = function(LocalPlayer : Player, playerProfile)

	end,
	_WeakBanditQuest1 = function(LocalPlayer : Player, playerProfile)

	end,
	_WolfQuest1 = function(LocalPlayer : Player, playerProfile)

	end,
	_StrongBanditQuest1 = function(LocalPlayer : Player, playerProfile)

	end,
}

-- // Module // --
local Module = {}

-- Create a new quest data table that goes inside the player's data's quest table
function Module:CreateDataForQuest( questConfig )
	return {
		UUID = HttpService:GenerateGUID(false),
		ID = questConfig.ID,
		Contributions = { }
	} :: DataQuest
end

-- Get quest from its UUID
function Module:GetQuestFromUUID(  playerProfile, questUUID )
	for index, questData in ipairs( playerProfile.Data.Quests ) do
		if questData.UUID == questUUID then
			return questData, index
		end
	end
	return nil, nil
end

-- Check if the player has the given quest through the questID
function Module:PlayerHasQuest( playerProfile, questID )
	for _, questData in ipairs( playerProfile.Data.Quests ) do
		if questData.ID == questID then
			return questData
		end
	end
	return nil
end

-- Give the player the quest if it can find it in the configuration
function Module:AddQuestToPlayer( LocalPlayer, questID )
	local questData = QuestData:GetQuestFromID( questID )
	local playerProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
	if questData and playerProfile and #playerProfile.Data.Quests < maxActiveQuests then
		if questData.Repeatable or (not Module:PlayerHasQuest( playerProfile, questID )) then
			
			local newDataQuestData = Module:CreateDataForQuest( questData )
			
			SystemsContainer.NotificationService:SendSimpleNotification( "Quest Recieved", "Recieved a new quest!", 'rbxassetid://129698102', 1.5, LocalPlayer )
			
			SystemsContainer.LogService:CreateClientLog( 'Quest Recieved', newDataQuestData.UUID..' - '..newDataQuestData.ID, LocalPlayer )
			
			table.insert(playerProfile.Data.Quests, newDataQuestData)
			
		end
	end
end

-- Remove the quest from the player
function Module:RemoveQuestFromPlayer( LocalPlayer, uuidString )
	local playerProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
	if not playerProfile then
		return
	end
	local _, index = Module:GetQuestFromUUID(  playerProfile, uuidString )
	if index then
		table.remove(playerProfile.Data.Quests, index)
	end
end

-- Check if the quest has all contributions filled
function Module:CheckAllQuestContributions( LocalPlayer )
	local playerProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
	
	if playerProfile then
		
		for index, questData in ipairs( playerProfile.Data.Quests ) do
			
			local questConfig = QuestData:GetQuestFromID( questData.ID )
			if not questConfig then
				continue
			end
			
			local hasRequirements = true
			for requirementName, requiredAmount in pairs( questConfig.Requirements ) do
				if (not questData.Contributions[requirementName]) or (questData.Contributions[requirementName] < requiredAmount) then
					hasRequirements = false
				end
			end
			
			if hasRequirements then
				
				table.remove(playerProfile.Data.Quests, index)
				task.defer(serverQuestRewards[questData.ID], LocalPlayer, playerProfile)
				table.insert(playerProfile.Data.CompletedQuests, questData.ID)
				
				SystemsContainer.LogService:CreateClientLog( 'Quest Completed', questData.UUID..' - '..questData.ID, LocalPlayer )
				SystemsContainer.NotificationService:SendSimpleNotification( "Quest Completed", "Completed the quest: "..questConfig.Display.Title.Text..'!', 'rbxassetid://129698102', 1.5, LocalPlayer )
				
			end
			
		end
		
	end
end

-- Check all quests to see whether the passed contributionID progresses any of the quests
function Module:ContributeToQuests( LocalPlayer, contributionID, amount )
	local playerProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
	if playerProfile then
		for index, questData in ipairs( playerProfile.Data.Quests ) do
			local questConfig = QuestData:GetQuestFromID( questData.ID )
			if not questConfig then
				continue
			end
			-- if can contribute to the quest
			if questConfig.Requirements[contributionID] then
				-- contribute to the quest
				local newContribs = questData.Contributions[contributionID] or 0
				newContribs += (amount or 1)
				if newContribs > questConfig.Requirements[contributionID] then
					newContribs = questConfig.Requirements[contributionID]
				end
				questData.Contributions[contributionID] = newContribs
			end
		end
		-- check if the player can be rewarded for quests
		Module:CheckAllQuestContributions( LocalPlayer )
	end
end

function Module:Init(otherSystems)

	for moduleName, otherLoaded in pairs(otherSystems) do
		SystemsContainer[moduleName] = otherLoaded
	end

	if SystemsContainer.SoftShutdown:IsShutdownServer() then
		return false
	end

	QuestRemoteEvent.OnServerEvent:Connect(function(LocalPlayer, Data)
		if typeof(Data) == "table" then
			local playerProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
			if not playerProfile then
				return
			end
			if Data.Job == "Discard" and typeof(Data.UUID) == "string" then
				Module:RemoveQuestFromPlayer( LocalPlayer, Data.UUID)
			elseif Data.Job == "Accept" and typeof(Data.ID) == "string" then
				Module:AddQuestToPlayer( LocalPlayer, Data.ID )
			end
		end
	end)

end

return Module
