-- THE ASSAY: the one warband whose difficulty the player sets themselves.
--
-- It attacks the PURSE rather than the party. Pickpocket and Shakedown take coin off you, the
-- mammonite's Open Account spends coin back at you, and the whole company reads better the better the
-- run has gone -- so a player who has been hoarding meets a harder fight than one who spent at the
-- Forge. That is a real decision made three stops earlier, which is what the money kit is for.
--
-- Deliberately NOT locked to the Greed circle. Coin is campaign-wide and so is this; the circle's own
-- stock (the Tally, the Assayer, the Coin-Chitters) is what makes Greed *about* it.
return {
    name = "The Assay",
    kind = "combat",
    weight = 3,
    minDay = 4,
    composition = function(ctx)
        local list = {
            "character_mammonite",   -- payoff: output priced in coin, and it is holding yours
            "character_thief",       -- setup: Pickpocket, which is where the coin comes from
            "character_cass",        -- multiplier: interest, on everything the other two took
            "character_bandit_chief", -- the body that makes standing still expensive
        }
        -- FILLER REPEATS A BODY ALREADY LISTED, and that is a rule rather than a preference:
        -- Arena.clampComposition keeps one of every DISTINCT id before it trims anything, so a fifth
        -- distinct body is not filler at all -- it walks straight past Arena.SKIRMISH_CAP and opens a
        -- five-body skirmish (tests/skirmish_spec.lua catches exactly this).
        for _ = 1, math.floor((ctx.day or 1) / 15) do list[#list + 1] = "character_bandit_chief" end
        return list
    end,
}
