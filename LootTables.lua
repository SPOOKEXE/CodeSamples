
local Module = {}

Module.LootTables = {
	{
		ID = 'Generic_SlimeA',

		Currency = {
			Copper = { 1, 3 },
		},

		Experience = { 3, 7 },

		ItemDropChance = (1 / 3),
		Items = { -- ORDER OF ITEMS IS IMPORTANT (RAREST LAST)
			{ ID = 'RedPotion', Quantity = { 1, 1 }, Weight = 1 }, --, Properties = { Enchantments = { }, } },
		},
		Attributes = false,
		Skills = false,
		Quests = false,
	},
	{
		ID = 'Generic_Mushroom',

		Currency = {
			Copper = { 3, 6 },
		},

		Experience = { 5, 9 },

		ItemDropChance = (1 / 4),
		Items = { -- ORDER OF ITEMS IS IMPORTANT (RAREST LAST)
			{ ID = 'RedPotion', Quantity = { 1, 3 }, Weight = 1 }, --, Properties = { Enchantments = { }, } },
		},
		Attributes = false,
		Skills = false,
		Quests = false,
	},
	{
		ID = 'Generic_WeakBandit',

		Currency = {
			Copper = { 7, 12 },
		},

		Experience = { 9, 15 },

		ItemDropChance = (1 / 4),
		Items = { -- ORDER OF ITEMS IS IMPORTANT (RAREST LAST)
			{ ID = 'WoodenBow', Quantity = { 0, 1 }, Weight = 5 }, --, Properties = { Enchantments = { }, } },
			{ ID = 'IronKnife', Quantity = { 0, 1 }, Weight = 3 }, --, Properties = { Enchantments = { }, } },
		},
		Attributes = false,
		Skills = false,
		Quests = false,
	},
	{
		ID = 'Generic_WolfB',

		Currency = {
			Copper = { 10, 15 },
		},

		Experience = { 12, 19 },

		ItemDropChance = (1 / 4),
		Items = { -- ORDER OF ITEMS IS IMPORTANT (RAREST LAST)
			{ ID = 'WoodenSword', Quantity = { 1, 1 }, Weight = 5 }, --, Properties = { Enchantments = { }, } },
			{ ID = 'WoodenBow', Quantity = { 1, 1 }, Weight = 5 }, --, Properties = { Enchantments = { }, } },
			{ ID = 'RedPotion', Quantity = { 1, 4 }, Weight = 3 }, --, Properties = { Enchantments = { }, } },
			{ ID = 'IronKnife', Quantity = { 1, 1 }, Weight = 2 }, --, Properties = { Enchantments = { }, } },
		},
		Attributes = false,
		Skills = false,
		Quests = false,
	},
	{
		ID = 'Generic_WolfA',

		Currency = {
			Copper = { 13, 18 },
		},

		Experience = { 15, 22 },

		ItemDropChance = (1 / 4),
		Items = { -- ORDER OF ITEMS IS IMPORTANT (RAREST LAST)
			{ ID = 'WoodenSword', Quantity = { 1, 1 }, Weight = 4 }, --, Properties = { Enchantments = { }, } },
			{ ID = 'WoodenBow', Quantity = { 1, 1 }, Weight = 4 }, --, Properties = { Enchantments = { }, } },
			{ ID = 'RedPotion', Quantity = { 1, 5 }, Weight = 3 }, --, Properties = { Enchantments = { }, } },
			{ ID = 'IronKnife', Quantity = { 1, 1 }, Weight = 3 }, --, Properties = { Enchantments = { }, } },
			{ ID = 'RedPotion', Quantity = { 3, 6 }, Weight = 1 }, --, Properties = { Enchantments = { }, } },
		},
		Attributes = false,
		Skills = false,
		Quests = false,
	},
	{
		ID = 'Generic_BanditBoss',

		Currency = {
			Copper = { 20, 25 },
		},

		Experience = { 23, 32 },

		ItemDropChance = (1 / 4),
		Items = { -- ORDER OF ITEMS IS IMPORTANT (RAREST LAST)
			{ ID = 'WoodenSword', Quantity = { 1, 3 }, Weight = 5 }, --, Properties = { Enchantments = { }, } },
			{ ID = 'WoodenBow', Quantity = { 1, 3 }, Weight = 5 }, --, Properties = { Enchantments = { }, } },
			{ ID = 'RedPotion', Quantity = { 3, 6 }, Weight = 3 }, --, Properties = { Enchantments = { }, } },
			{ ID = 'IronKnife', Quantity = { 1, 3 }, Weight = 2 }, --, Properties = { Enchantments = { }, } },
			{ ID = 'RedPotion', Quantity = { 4, 7 }, Weight = 2 }, --, Properties = { Enchantments = { }, } },
		},
		Attributes = false,
		Skills = false,
		Quests = false,
	},
}

function Module:GetLootTableByID( lootTableID )
	for i, lootTable in ipairs( Module.LootTables ) do
		if lootTable.ID == lootTableID then
			return lootTable, i
		end
	end
	return nil, nil
end

for _, matrix in ipairs( Module.LootTables ) do
	table.sort( matrix.Items, function(a, b)
		return (a.Weight or 1) > (b.Weight or 1) and (a.Chance or 1) > (b.Chance or 1)
	end)
end

return Module

