-- The finale. Seven generals dead, seven relics taken, seven fragments of a location -- and only then
-- does the board admit where the last door is.
--
-- `requiredQuests` is the gate: every one of the seven general quests must be complete. Unlike the
-- prestige and reputation gates, this one is SOFT -- kill a single general and the quest appears on the
-- board `locked`, counting your keys and reciting the hints you have earned (see questGate and
-- gateHints in models/quest.lua, and the locked detail pane in ui/panels/quest_board.lua). Watching the
-- count climb from 1 of 7 is the last stretch of the game.
--
-- `showLocked` is what asks for that, and this is the only file that sets it. The board used to infer
-- it from holding one key of several, which swept in every discipline capstone -- they name two
-- prerequisites apiece and wanted none of this pane. A capstone is already advertised where it can be
-- acted on: a locked path collapses to a header on its parent vendor's shelf, and shop.lua's lockReason
-- names the missing parent class, which is a building the player can walk to. This quest has no shelf
-- and no direction to give but the fragments, so it is the one that asks to be seen locked.
--
-- What opens the Gate is the completed QUEST, never the relic it granted. Relics are meant to be worn,
-- and a key you can misplace in a loadout screen is not a key.
--
-- `keyCount = 0` deliberately: `map.keyCount` is the overworld's own locked-door puzzle (see
-- models/overworld.lua), an entirely different thing that happens to share the word. The seven keys of
-- this quest are already spent by the time the map is generated. Do not lock the last door twice.
--
-- `endsCampaign` is what makes this the LAST quest rather than merely the hardest one: states/game.lua
-- routes its outro into states/credits.lua instead of back to the hub. It is a data flag rather than a
-- quest id compared in the state, so the engine never learns this file's name and a second ending (or a
-- different one) needs no engine edit at all.
return {
    name = "The Gate Below",
    description = "Seven appetites, put down one at a time. What is left of the thing that had them " ..
        "is waiting where the fragments say it is.",
    difficulty = "Hard",
    sponsor = nil, -- no vendor sends you here; the seven of them together did
    rewardGold = 2000,
    requiredPrestige = 10,
    endsCampaign = true,
    showLocked = true, -- show on the board from the first key, counting the rest; see the header

    -- The last scene in the game, played over the frozen final frame before the credits roll.
    outro = "conversation_gate_below_ending",
    requiredQuests = {
        "quest_colosseum_slot_10",
        "quest_cathedral_slot_10",
        "quest_hunters_lodge_slot_10",
        "quest_bastion_slot_10",
        "quest_arcanum_slot_10",
        "quest_undercroft_slot_10",
        "quest_alchemist_slot_10",
    },
    map = {
        biome = "underworld",
        encounters = { min = 12, max = 16, always = { "encounter_elite", "encounter_elite", "encounter_elite" } },
        objective = {
            name = "The Hollow Crown",
            -- The only seam the Crown can speak from: `intro` plays over the hub before the party is
            -- picked, and by the time `outro` runs an assassinate target is already dead.
            opening = "conversation_gate_below_confront",
            composition = function(ctx)
                local list = { "character_demon_lord" }
                -- Its honour guard, not its arsenal -- the arsenal is what it summons out of your
                -- own past as it fails (data/traits/trait_hollow_crown.lua).
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 4) do list[#list + 1] = "character_champion" end
                return list
            end,
            win = { type = "assassinate", target = "character_demon_lord" },
        },
        keyCount = 0, -- see the header: the overworld's keys are not this quest's keys
    },
}
