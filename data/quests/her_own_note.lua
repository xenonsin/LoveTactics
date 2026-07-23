-- Slot 8 of the Undercroft's ten: the break, and the moment charity stops being a habit and becomes a
-- position.
--
-- Clem's craft is the Bank's own, run backwards: she takes from the rich and keeps none of it -- burns
-- the notes, forges the clean slate, walks the ruined out before the men come (docs/story.md, "Clem,
-- the same craft answered the other way"). Her failure mode is the one every reformed collector has,
-- and slot 7 named it: she has cleared everyone's ledger except her own, because keeping her own entry
-- open is the only penance the arrangement allows her and she has been paying it on purpose.
--
-- So the beat is that she sets her own debt down. Not by settling it -- settling is what the Bank
-- wants and it is how the machine eats jubilees -- but by going to the branch that holds the entry and
-- taking it out of the book, for herself, which is the one thing she has never once done for herself.
-- Charity that never includes the giver is not charity, it is a way of staying owed, and the finale
-- does not work without a Clem who has stopped being owed. Aurea's whole existence is the proof: a
-- woman who pacted never to owe again and is owed by everyone and starves at her own table.
--
-- The sponsor is the obstacle from here. The Undercroft does not disown her -- it INVOICES her, and
-- sends the firm's current best to serve it, and he is polite about it.
--
-- `assassinate`: the firm's blade is the mark. He is what she was, doing what she did, entirely
-- without malice, and the fight should read as a mirror rather than a betrayal.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. This slot owes CLEM'S SECOND RELIC
-- (story.md slot 8: "Borrowed Time keeps one kill's tempo for herself" -- the mechanical form of the
-- same sentence) and the line's slot-8 unbuyable; neither is written, so no `rewardItems`
-- entry points at them.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Her Own Note",
    description = "Clem has cleared everybody's ledger but hers. Tonight she goes to the branch that " ..
        "holds her entry, and the firm sends its current best to explain why she should not.",
    difficulty = "Hard",
    sponsor = "undercroft",
    rewardItems = { "weapon_slipknife" },
    rewardGold = 320,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "undercroft", rank = 3 }, -- Shadow
    map = {
        biome = "castle",
        encounters = { min = 9, max = 12, always = { "encounter_elite" } },
        objective = {
            name = "The Firm's Current Best",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_champion" end
                return list
            end,
            win = { type = "assassinate", target = "character_bandit_chief" },
        },
        keyCount = 2,
    },
}
