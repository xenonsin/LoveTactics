-- The finale. Seven generals dead, seven relics taken, seven fragments of a location -- and only then
-- does the board admit where the last door is.
--
-- `requiredQuests` is the gate: every one of the seven general quests must be complete. Unlike the
-- prestige and reputation gates, this one is SOFT -- kill a single general and the quest appears on the
-- board `locked`, counting your keys and reciting the hints you have earned (see questGate and
-- gateHints in models/quest.lua, and the locked detail pane in ui/panels/quest_board.lua). Watching the
-- count climb from 1 of 7 is the last stretch of the game.
--
-- What opens the Gate is the completed QUEST, never the relic it granted. Relics are meant to be worn,
-- and a key you can misplace in a loadout screen is not a key.
--
-- `keyCount = 0` deliberately: `map.keyCount` is the overworld's own locked-door puzzle (see
-- models/overworld.lua), an entirely different thing that happens to share the word. The seven keys of
-- this quest are already spent by the time the map is generated. Do not lock the last door twice.
return {
    name = "The Gate Below",
    description = "Seven appetites, put down one at a time. What is left of the thing that had them " ..
        "is waiting where the fragments say it is.",
    difficulty = "Hard",
    sponsor = nil, -- no vendor sends you here; the seven of them together did
    rewardGold = 2000,
    rewardRep = 0,
    rewardPrestige = 10,
    requiredPrestige = 10,
    requiredQuests = {
        "general_wrath",
        "general_lust",
        "general_gluttony",
        "general_sloth",
        "general_pride",
        "general_greed",
        "general_envy",
    },
    map = {
        biome = "underworld",
        cols = 55, rows = 37,
        encounters = { min = 12, max = 16, always = { "elite", "elite", "elite" } },
        objective = {
            name = "The Hollow Crown",
            composition = function(ctx)
                local list = { "demon_lord" }
                -- Its honour guard, not its arsenal -- the arsenal is what it summons out of your
                -- own past as it fails (data/traits/hollow_crown.lua).
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 4) do list[#list + 1] = "champion" end
                return list
            end,
            win = { type = "assassinate", target = "demon_lord" },
        },
        keyCount = 0, -- see the header: the overworld's keys are not this quest's keys
    },
}
