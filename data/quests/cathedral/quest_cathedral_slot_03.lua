-- The Cathedral's second contract. Gated on its predecessor only, like every other house's slot 3 --
-- the `requiredSponsorQuests` ladder starts at slot 4 (see quest_cathedral_slot_04.lua).
--
-- It did once carry `{ vendor = "cathedral", count = 3 }`, and that DEADLOCKED THE CAMPAIGN. Only two
-- Cathedral quests can precede this one (slots 1 and 2; all four of the house's named capstones require
-- this very file), so a count of 3 could never be reached, and the whole line from here down was
-- unreachable -- including slot 10, which is one of the Gate Below's seven keys. The game had no
-- ending. Found by `. progression-report`, which walks the board and reports what it cannot reach;
-- tests/progression_report_spec.lua now fails if any quest becomes unreachable again.
--
-- A `survive` objective: hold the consecrated ground while the rite burns down.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Rite of Ashes",
    description = "The rite takes eight turns and cannot be hurried. Something in the dark knows it.",
    difficulty = "Hard",
    sponsor = "cathedral",
    rewardItems = { "weapon_sealed_censer", "armor_interceding_stole" },
    rewardGold = 220,
    requiredQuests = { "quest_cathedral_slot_02" }, -- slot 3: the line runs in order
    requiredPrestige = 1,
    map = {
        biome = "volcanic",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Consecration",
            composition = function(ctx)
                local list = { "character_miller_ghost" }
                for i = 1, 2 + math.floor((ctx.day or 1) / 2) do list[#list + 1] = "character_wolf_grunt" end
                return list
            end,
            win = { type = "survive", duration = 40 }, -- TICKS to outlast, not turns (the clock's unit)
        },
        keyCount = 1,
    },
}
