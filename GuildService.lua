local Players = game:GetService('Players')
local HttpService = game:GetService('HttpService')
local DataStoreService = game:GetService('DataStoreService')
local MessagingService = game:GetService('MessagingService')

local GuildDatabaseDataStore = false
local DataStoreIsActive = false

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedCore = require(ReplicatedStorage:WaitForChild('Core'))
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))

local GuildConfigModule = ReplicatedModules.GuildConfig
local ItemsConfigModule = ReplicatedModules.Items
local SettingsModule = ReplicatedModules.Settings

local RemoteService = ReplicatedModules.RemoteService
local GuildDataFunction = RemoteService:GetRemote('GuildDataFunction', 'RemoteFunction', false)
local GuildDataEvent = RemoteService:GetRemote('GuildDataEvent', 'RemoteEvent', false)

local TableUtility = ReplicatedModules.Table

local ReplicatedData = ReplicatedCore.ReplicatedData

local SystemsContainer = {}

local ActiveGuildData = {}
local PlayerToGuildUUID = {}
local ActiveDataTick = {}
local GuildInviteCache = {}

local UPDATE_INTERVAL = 30

-- // Module // --
local Module = {}

function Module:NewGuildData()
	return {
		UUID = HttpService:GenerateGUID(false),
		GuildDisplay = { DisplayName = 'NULL', IconNumber = 1, },
		
		OwnerUserId = false,
		
		Members = {
			-- [UserId] = RoleName,
		},
		
		OverrideDefaultPermissions = { },
	}
end

function Module:UpdateFromGuildDatabase(guildUUID)
	if not DataStoreIsActive then
		return ActiveGuildData[guildUUID] or 2
	end
	
	-- check to see whether or not to update
	local LastUpdate = tick() - ActiveDataTick[guildUUID]
	if ActiveDataTick[guildUUID] and (LastUpdate < UPDATE_INTERVAL) then
		return ActiveGuildData[guildUUID]
	end
	
	-- try get guild data from UUID
	local gotGuildData = false
	local success, err = pcall(function()
		gotGuildData = GuildDatabaseDataStore:GetAsync(guildUUID)
	end)
	
	-- if we get it, set cache table data and return it
	if gotGuildData then
		ActiveDataTick[guildUUID] = tick()
		ActiveGuildData[guildUUID] = gotGuildData
		return gotGuildData
	elseif LastUpdate > 90 then
		-- otherwise if this guild data for sure is no longer existent, clear it out and return nil
		ActiveGuildData[guildUUID] = nil
		return 2 -- this data no longer exists, wipe from player data
	end
	
	return 1 -- could not get async
end

function Module:JoinGuild(LocalPlayer, guildUUID)
	warn('Player '..LocalPlayer.Name..' is joining the guild of ID '..tostring(guildUUID))
	local playerProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
	local guildData = Module:UpdateFromGuildDatabase(guildUUID)
	if typeof(guildData) == 'table' and playerProfile then
		guildData.Members[LocalPlayer.UserId] = 'Rookie'
		playerProfile.Data.GuildUUID = guildData.UUID
		GuildInviteCache[LocalPlayer] = nil -- clear guild invites
		if DataStoreIsActive then
			GuildDatabaseDataStore:UpdateAsync(guildData.UUID, function(oldData)
				oldData.Members[LocalPlayer.UserId] = 'Rookie'
				return oldData
			end)
		end
		
		task.defer(function()
			MessagingService:PublishAsync('GuildMembersChanged', guildData.UUID, LocalPlayer.UserId, 'Rookie')
		end)
		
		return true, 'Successfully joined the guild.'
	end
	return false, 'Could not join the guild: '..(guildData and 'No player profile data.' or 'No guild data found.')
end

function Module:AcceptGuildInvite(LocalPlayer, GuildUUID)
	local ActiveInviteData = GuildInviteCache[LocalPlayer]
	if (not ActiveInviteData) then -- no guild invites
		return false, 'No pending Invites'
	end
	
	local index = 1
	while index <= #ActiveInviteData do
		local data = ActiveInviteData[index]
		if tick() - data[1] > 60 then -- expired
			table.remove(ActiveInviteData, index)
			continue
		end
		-- if its the invite the player is referring about
		if data[2] == GuildUUID then
			local duration = math.floor((tick() -  data[1]) * 10) / 10
			warn('Player has accepted invite to guild with uuid ', GuildUUID, ' after ', duration, ' seconds')
			Module:JoinGuild(LocalPlayer, GuildUUID)
			return true, 'Accepted invite.'
		end
	end
	
	return false, 'Could not find pending invite to this guild.'
end

function Module:HasPermissionTo(LocalPlayer, PermissionID)
	local LocalProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
	local GuildData = Module:GetPlayerGuildData(LocalPlayer)
	if not GuildData then
		return false, "Could not get the player's guild."
	end
	
	local LocalRank = GuildData and GuildData.Members[LocalPlayer.UserId]
	
	local DefaultPermissionIDValue = ReplicatedModules.GuildConfig.PermissionTree[LocalRank][PermissionID] or ReplicatedModules.GuildConfig.PermissionTree.Rookie[PermissionID]
	local OverridenPermissionIDValue = GuildData.OverrideDefaultPermissions[LocalRank] and GuildData.OverrideDefaultPermissions[LocalRank][PermissionID]
	
	if typeof(OverridenPermissionIDValue) == 'nil' then
		return DefaultPermissionIDValue
	end
	return OverridenPermissionIDValue
end

function Module:InviteToGuild(LocalPlayer, TargetPlayer)
	if typeof(TargetPlayer) ~= 'Instance' or (TargetPlayer.Parent ~= Players) then
		return false, 'Target Player is not a Player.'
	end
	
	-- self-invite prevention
	if LocalPlayer == TargetPlayer then
		return false, 'Cannot invite self to the guild.'
	end
	
	-- get for data profiles
	local LocalProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
	local TargetProfile = SystemsContainer.DataService:GetPlayerProfile(TargetPlayer)
	if (not LocalProfile) or (not TargetProfile) then
		return false, 'Could not get profile data for '..(LocalProfile and 'Target Player' or 'Local Player')
	end
	
	-- check if the player is in a guild
	if not LocalProfile.Data.GuildUUID then
		return false, 'You are not in a guild.'
	end
	
	if not Module:HasPermissionTo(LocalPlayer, 'CanInvite') then
		return false, 'You do not have permission to invite players to the guild.'
	end
	
	-- Check if the target is already in a guild
	if TargetProfile.Data.GuildUUID then
		return false, 'Target player is already in a guild.'
	end
	
	local GuildData = Module:GetPlayerGuildData(LocalPlayer)
	if not GuildData then
		return false, 'Could not get the guild data. '..tostring(LocalProfile.Data.GuildUUID)
	end

	if GuildInviteCache[TargetPlayer] then
		-- if they have invites already, check if this guild has sent an invite to that player
		for _, t in ipairs( GuildInviteCache[TargetPlayer] ) do
			if t[2] == GuildData.UUID then
				return false, 'Already has received an invite for your guild.'
			end
		end
		-- if not, send invite
		table.insert(GuildInviteCache[TargetPlayer], {tick(), GuildData.UUID})
	else
		-- if there is no invites, create a new invite array
		GuildInviteCache[TargetPlayer] = { {tick(), GuildData.UUID} }
	end
	-- tell the client that they were invited
	GuildDataEvent:FireClient(TargetPlayer, 'GuildInvite', LocalPlayer, GuildData)
	return true, 'Sent invite to player.'
end

function Module:HasRequirementsForGuildCreation(LocalPlayer)
	-- get their profile
	local playerProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
	if not playerProfile then
		return false, 'Could not get player profile'
	end
	
	local guildCreationRequirements = GuildConfigModule.GuildCostRequirement
	
	-- the player does not have enough level to create a guild
	if playerProfile.Data.Level < guildCreationRequirements.Level then
		return false, 'Not high enough level.'
	end
	
	-- check coin cost
	local creationCost = SystemsContainer.CurrencyService:ToCopperCoins(guildCreationRequirements.Coins)
	local playerCoins = SystemsContainer.CurrencyService:ToCopperCoins(playerProfile.Data.Currency)
	if playerCoins < creationCost then
		-- they don't have enough coins
		return false, "You don't have enough coins to create a guild."
	end
	
	-- check if they have the required items
	for _, itemID in ipairs( guildCreationRequirements.Items ) do
		if #ItemsConfigModule:GetItemsFromInventoryByID( playerProfile.Data.Inventory, itemID ) == 0 then
			return false, 'You are missing the item '..tostring(itemID)..' to create a guild.'
		end
	end
	
	-- has all the requirements
	return true
end

function Module:LeaveGuild(LocalPlayer)
	local playerProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
	if not playerProfile then
		return false, 'Could not get player profile'
	end
	
	local guildData = Module:GetPlayerGuildData(LocalPlayer)
	if not guildData then
		return true, 'Player has no guild data.' -- no longer in guild
	end
	
	local playerCount = TableUtility:CountDictionary(guildData.Members)
	if guildData.OwnerUserId == LocalPlayer.UserId and playerCount > 1 then
		return false, 'You have to transfer ownership of the guild first.'
	end
	
	if guildData.OwnerUserId == LocalPlayer.UserId then
		-- destroy the guild
		ActiveGuildData[guildData.UUID] = nil
		if DataStoreIsActive then
			GuildDatabaseDataStore:RemoveAsync(guildData.UUID)
		end
		
		task.defer(function()
			MessagingService:PublishAsync('GuildDestroyed', guildData.UUID)
		end)
	else
		-- remove from cached guild data
		guildData.Members[LocalPlayer.UserId] = nil
		
		-- remove from datastore guild data
		if DataStoreIsActive then
			GuildDatabaseDataStore:UpdateAsync(guildData.UUID, function(oldData)
				oldData.Members[LocalPlayer.UserId] = nil
				return oldData
			end)
		end
		
		task.defer(function()
			MessagingService:PublishAsync('GuildMemberRemoved', guildData.UUID, LocalPlayer.UserId)
		end)
	end
	
	-- remove cache data
	PlayerToGuildUUID[LocalPlayer] = nil
	-- remove from player profile
	playerProfile.Data.GuildUUID = nil
	
	return true, 'You have left the guild you were in.'
end

function Module:CreateGuild(LocalPlayer, GuildCreationData)
	if typeof(GuildCreationData) ~= 'table' or typeof(GuildCreationData.Icon) ~= 'number' or typeof(GuildCreationData.Name) ~= 'string' then
		return false, 'Invalid Guild Creation Data'
	end
	
	GuildCreationData.Icon = math.clamp(GuildCreationData.Icon, 1, #GuildConfigModule.IconArray)
	
	-- get their profile
	local playerProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
	if not playerProfile then
		return false, 'No player profile.'
	end
	
	-- check if they are in a guild
	if playerProfile.Data.GuildUUID then
		return false, 'You are already in a guild.'
	end
	
	-- check if they have the items required to make the guild
	local hasReqs, msg = Module:HasRequirementsForGuildCreation(LocalPlayer)
	if not hasReqs then
		return false, msg --'You do not have the requirements to create a guild.'
	end
	
	print('Create New Guild: ', LocalPlayer, GuildCreationData)
	
	local newGuildData = Module:NewGuildData()
	newGuildData.OwnerUserId = LocalPlayer.UserId
	newGuildData.Members[LocalPlayer.UserId] = 'Owner'
	newGuildData.GuildDisplay = {
		DisplayName = GuildCreationData.Name,
		IconNumber = GuildCreationData.Icon,
	}
	
	local keepLooping = true
	while keepLooping and DataStoreIsActive do
		GuildDatabaseDataStore:UpdateAsync(newGuildData.UUID, function(oldData)
			if oldData then
				warn('Collision with Guild UUID - generate a new one')
				newGuildData.UUID = HttpService:GenerateGUID(false)
			else
				keepLooping = false
			end
			return oldData or newGuildData
		end)
	end
	
	PlayerToGuildUUID[LocalPlayer] = newGuildData.UUID
	ActiveGuildData[newGuildData.UUID] = newGuildData
	playerProfile.Data.GuildUUID = newGuildData.UUID
	
	return true, newGuildData.UUID
end

function Module:GetPlayerGuildData(LocalPlayer)
	-- check for player data
	local playerProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
	if not playerProfile then
		return
	end
	
	-- check if they are in a guild via UUID
	local playerGuildUUID = playerProfile.Data.GuildUUID
	if not playerGuildUUID then
		return
	end
	
	-- get their guild data
	local result = Module:UpdateFromGuildDatabase(playerGuildUUID)
	
	-- set their guild uuid cache (can be update)
	PlayerToGuildUUID[LocalPlayer] = (result ~= 2) and playerGuildUUID or nil
	
	return typeof(result) == 'table' and result
end

function Module:ReleaseUnusedGuildData()
	local activeUUIDCache = {}
	
	-- find all active uuids
	for LocalPlayer, uuid in pairs(PlayerToGuildUUID) do
		table.insert(activeUUIDCache, uuid)
	end
	
	-- remove any unused uuids
	for guildUUID, _ in pairs(ActiveGuildData) do
		if not table.find(activeUUIDCache, guildUUID) then
			ActiveGuildData[guildUUID] = nil
			ActiveDataTick[guildUUID] = nil
		end
	end
end

function Module:GiveTestItemsToPlayer(LocalPlayer)
	local playerProfile = SystemsContainer.DataService:GetPlayerProfile(LocalPlayer)
	if not playerProfile then
		return false, 'Could not get profile.'
	end

	-- give them the items if they don't have it
	local guildCreationRequirements = GuildConfigModule.GuildCostRequirement
	for _, itemID in ipairs( guildCreationRequirements.Items ) do
		if #ItemsConfigModule:GetItemsFromInventoryByID( playerProfile.Data.Inventory, itemID ) == 0 then
			SystemsContainer.InventoryService:GivePlayerItemFromId(LocalPlayer, itemID, 1, false)
		end
	end

	-- give them enough coins
	local coinCost = SystemsContainer.CurrencyService:ToCopperCoins(guildCreationRequirements.Coins)
	SystemsContainer.CurrencyService:GiveCopperCoins( LocalPlayer, coinCost, false )

	-- level them up to 25
	while playerProfile.Data.Level < guildCreationRequirements.Level do
		local requiredExpToLevel = SettingsModule.RequiredExpForLevel( playerProfile.Data.Level ) - playerProfile.Data.Experience
		SystemsContainer.LevelingService:GiveExperience( LocalPlayer, requiredExpToLevel )
	end
	
	return true, 'Received items.'
end

function Module:SetupMessagingServiceHandlers()
	-- TODO: cross-server invitation to guild
	
	MessagingService:SubscribeAsync('GuildMembersChanged', function(GuildUUID, UserId, Role)
		if ActiveGuildData[GuildUUID] then
			ActiveGuildData[GuildUUID][UserId] = Role
		end
	end)
	
	MessagingService:SubscribeAsync('GuildMemberRemoved', function(GuildUUID, UserId)
		if ActiveGuildData[GuildUUID] then
			ActiveGuildData[GuildUUID][UserId] = nil
		end
	end)
	
	MessagingService:SubscribeAsync('GuildDestroyed', function(GuildUUID)
		ActiveGuildData[GuildUUID] = nil
	end)
	
	MessagingService:SubscribeAsync('GuildMemberSettingChanged', function(GuildUUID, SettingName, SettingValue)
		if ActiveGuildData[GuildUUID] then
			ActiveGuildData[GuildUUID].OverrideDefaultPermissions[SettingName] = SettingValue
		end
	end)
end

function Module:HandleServerInvoke(LocalPlayer, Job, Data)
	warn(LocalPlayer, Job, Data)
	if Job == 'GiveItemTest' then
		return Module:GiveTestItemsToPlayer(LocalPlayer)
	elseif Job == 'CreateGuild' then
		return Module:CreateGuild(LocalPlayer, Data)
	elseif Job == 'LeaveGuild' then
		return Module:LeaveGuild(LocalPlayer)
	elseif Job == 'InviteToGuild' then
		return Module:InviteToGuild(LocalPlayer, Data)
	elseif Job == 'AcceptInvite' then
		return Module:AcceptGuildInvite(LocalPlayer, Data)
	end
	return false, 'Unknown Job'
end

function Module:Init(otherSystems)
	SystemsContainer = otherSystems

	local success, err = pcall(function()
		GuildDatabaseDataStore = DataStoreService:GetDataStore('GuildDatabase_1') -- change the 1 to remove all guilds' data
		GuildDatabaseDataStore:UpdateAsync('DatabaseAccess', function(oldValue)
			return (oldValue + 1) or 1
		end)
	end)
	
	DataStoreIsActive = success

	ReplicatedData:SetData('CachedGuildData', ActiveGuildData, false)

	GuildDataFunction.OnServerInvoke = function(...)
		return Module:HandleServerInvoke(...)
	end

	GuildDataEvent.OnServerEvent:Connect(function(...)
		Module:HandleServerInvoke(...)
	end)
	
	Players.PlayerRemoving:Connect(function(LocalPlayer)
		GuildInviteCache[LocalPlayer] = nil
		PlayerToGuildUUID[LocalPlayer] = nil
	end)
	
	task.defer(function()
		Module:SetupMessagingServiceHandlers()
	end)
	
	if success then
		warn('LOADED GUILD DATABASE')
	else
		warn('COULD NOT LOAD GUILD DATABASE - ', err)
	end
	
	-- everything has to be done in a queue to prevent any mishaps
	task.defer(function()
		while task.wait(0.1) do
			
		end
	end)
	
end

return Module
