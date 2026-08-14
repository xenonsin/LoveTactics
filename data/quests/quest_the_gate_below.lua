-- The finale. He comes on the last day whether anyone is ready or not, and every general still alive
-- comes with him.
--
-- IT IS NO LONGER A LOCK, AND THAT IS THE WHOLE CHANGE. This quest used to require all seven generals
-- dead -- seven keys, a count climbing from 1 of 7 that was the last stretch of the game. A calendar
-- cannot carry that: seven lines to their slot 10 is about seventy expeditions and there are forty
-- (models/calendar.lua), so the ending would have been unreachable by construction.
--
-- Deleting the lock without replacing it would have made the seven lines decorative in the other
-- direction, so the count changed JOB rather than going away. It was PERMISSION; it is CONSEQUENCE.
-- A player who spent forty days on one house arrives having felled one general and faces six. A player
-- who felled all seven faces the Crown alone. Both get an ending; neither gets the same one.
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
    -- NO STANDING GATE. It asked for prestige 10 as well as the seven keys, from back when standing was
    -- a number a save could hold independently of what it had done. Standing is the quest count now
    -- (Player.standing), so seven felled generals already imply far more than ten -- the second gate
    -- could never bite, and a gate that cannot bite misleads whoever reads it next.
    endsCampaign = true,
    -- THE CALENDAR IS THE GATE. He arrives on the last day whether or not a single general is dead
    -- (models/calendar.lua), so this is not a lock and there are no keys to collect. What the count
    -- beside it says is how many generals will be standing WITH him -- a warning, not a tally of
    -- permission.
    --
    -- `showLocked` is what puts the card on the board BEFORE that day, and it is spent on one thing:
    -- the seven fragments, once all seven are in hand. It used to show from the second morning, which
    -- meant a row nobody could press under every tab for thirty-nine days; the deadline itself is the
    -- hub's day counter's job and always was. Fell seven and the place names itself; fell fewer and you
    -- meet him on day forty regardless, having simply never been shown the map.
    finale = true,
    showLocked = true,
    -- THE DEEPEST FIGHT IN THE GAME, SAID OUT LOUD. It never needed saying before: the seven-key chain
    -- implied about seventy finished quests, so everything that asks "how far in is this fight" --
    -- Quest.floorLevelFor, Balance.prestigeFor, the time-to-kill bands -- could read the depth off the
    -- prerequisites. With the keys gone that inference collapses to nothing and the finale measures as
    -- an opening skirmish, which is how the balance suite noticed.
    --
    -- 22 is Calendar.FINAL_DANGER: the level the world closes at. Written as a literal rather than
    -- required from the model because a blueprint is data, and duplicated deliberately -- if the
    -- calendar's endpoint moves, this is one of the things that has to be re-read against it.
    floorLevel = 22,

    -- The last scene in the game, played over the frozen final frame before the credits roll.
    outro = "conversation_gate_below_ending",
    -- The seven line-enders. Read for their location fragments (Quest.gateHints) and for the count that
    -- sizes the last fight -- never as a requirement. Renamed from `requiredQuests` precisely so that
    -- nothing can mistake it for one again.
    hintQuests = {
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
            -- THE GENERALS ARE THE VARIABLE, AND THE GUARD IS FIXED SMALL SO THAT THEY CAN BE.
            --
            -- The escort used to be `2 + prestige/4`, which reached twenty-five bodies and was cut to
            -- twelve by Arena.clampComposition every single time -- so the last fight was the same
            -- twelve bodies whatever the player had done, and adding the standing generals on top
            -- changed nothing at all. (Measured: 0, 3 and 7 felled all fielded twelve.) A formula
            -- permanently past its own ceiling is a formula that does not exist.
            --
            -- Two guards and one champion per general still breathing tops out at ten -- under the
            -- Hard cap -- so every general put down is one body fewer on the board, which is the whole
            -- point of felling them.
            composition = function(ctx)
                local list = { "character_demon_lord", "character_champion", "character_champion" }
                for _ = 1, (ctx.generalsStanding or 0) do list[#list + 1] = "character_champion" end
                return list
            end,
            win = { type = "assassinate", target = "character_demon_lord" },
        },
        keyCount = 0, -- see the header: the overworld's keys are not this quest's keys
    },
}
