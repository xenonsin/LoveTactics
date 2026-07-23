-- Slot 9 of the Cathedral's ten: the approach, and the scale of what killing her will NOT stop.
--
-- The player takes the proof up. Not to a court -- to the church's own inner circle, the small ring
-- around the Saint that has known the whole time, and the quest is what they do when the register and
-- the pit are laid on the table in front of them. They do not deny it. They ask, reasonably, what the
-- player imagines happens to the frontier if the anointed stand down: who holds the wall, who takes
-- the refugees, who fights the demons the crown cannot reach. And then they call the guard.
--
-- That is the beat, and it is the same one every line reaches at slot 9 (docs/story.md). The sleepers
-- are already seeded. Every anointed in the field is already blooded, already hers, already unaware.
-- Luxuria dying does not unblood one child, does not empty the pit, and does not disband an order the
-- world is genuinely relying on. The player is not walking toward a cure. They are walking toward the
-- end of one woman, and the line is honest enough to say so a quest early.
--
-- What it costs Amana: nothing left to cost -- slot 8 spent it. She is the one who lays the register
-- on the table, and she is the one who hears the reasonable question, and she has no answer to it. She
-- goes anyway. That is what devotion is when it stops being comfort.
--
-- `assassinate`: the inner circle's own champion, in the anointed's own colours. The rest is a wall.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. `character_anointed` is the blueprint this
-- slot wants for the guard; `character_champion` and `character_knight` stand in.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Saint Unmasked",
    description = "You lay the register and the pit in front of the men who have always known. They " ..
        "do not deny a word of it. They ask you who will hold the wall.",
    difficulty = "Hard",
    sponsor = "cathedral",
    rewardItems = { "armor_robes_unbidden" },
    rewardGold = 400,
    rewardRep = 35,
    rewardPrestige = 2,
    requiredPrestige = 5,
    requiredRep = { vendor = "cathedral", rank = 3 }, -- Confessor
    map = {
        biome = "castle",
        encounters = { min = 10, max = 13, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "The Inner Circle's Own",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_knight" end
                return list
            end,
            win = { type = "assassinate", target = "character_champion" },
        },
        keyCount = 2,
    },
}
