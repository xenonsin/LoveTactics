-- Slot 9 of the Undercroft's ten: the approach, and the scale of what killing her will NOT undo.
--
-- With the owner about to become a problem, the Bank does the only thing an institution ever does: it
-- continues. A successor firm is chartered -- new name, new charter, same paper, same statutes, most
-- of the same staff walking across the street with the files under their arms -- and the transfer is
-- announced in the ordinary way, in the ordinary press, as prudence.
--
-- That is the beat. The notes do not cancel themselves at Aurea's death, the laws she bought stay
-- bought, the crown still owes, and the credit the frontier runs on has to run on (docs/story.md,
-- "Aurea, the Ever-Owed"). The player is not walking toward a cure. They are walking toward the end of
-- one woman, and the line says so a quest early rather than letting the finale pretend otherwise.
--
-- The fight is the transfer itself: the files are moving, under escort, and Clem wants them -- not to
-- burn (she has learned better since slot 7; burning a ledger prints a new one) but to READ, because
-- the successor charter names the people who signed it, and those names outlive Aurea by design.
--
-- What it costs Clem: nothing left to cost -- slot 8 spent it. What she carries into the finale is the
-- knowledge that the kill she is about to make does not settle the account, and she is going to make
-- it anyway, for the ordinary reason that Aurea will otherwise keep collecting. Charity that only acts
-- when it can fix everything never acts.
--
-- `assassinate`: the escort's captain holds the transfer, and the convoy is a wall to get through.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and the slot's own
-- unbuyable is still unwritten. The escort
-- wants a bespoke blueprint -- private security under a lawful charter, not brigands;
-- `character_champion` and `character_bandit_chief` stand in.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "A New Bank",
    description = "A successor firm has been chartered. New name, same paper, same statutes, and the " ..
        "files are crossing the street tonight under escort.",
    difficulty = "Hard",
    sponsor = "undercroft",
    rewardItems = { "armor_slipstep_leathers" },
    rewardGold = 400,
    rewardRep = 35,
    rewardPrestige = 2,
    requiredPrestige = 5,
    requiredRep = { vendor = "undercroft", rank = 3 }, -- Shadow
    map = {
        biome = "castle",
        encounters = { min = 10, max = 13, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "The Transfer",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            win = { type = "assassinate", target = "character_champion" },
        },
        keyCount = 2,
    },
}
