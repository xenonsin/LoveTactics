-- THE PAYMASTER: Greed's elite on floor five that is not what it looks like. Reviewed over five rounds,
-- 2026-09-25/26 ("The Paymaster"); the body is data/characters/character_the_paymaster.lua and the rules are
-- models/paymaster.lua.
--
-- A DWARF CREW AND THE MAN WHO PAYS IT. Vesh salted the deep seams with gold to draw greedy dwarves down for
-- fresh bodies, and the Paymaster is the hand that throws it: a heap beside a living dwarf at the start of each
-- of his turns, which the crew runs for, pockets and sickens on -- three and a dwarf is a Gilt Wyrm. He never
-- pockets one himself, and that is the only tell. When the last of the crew falls he turns into the Lure, a
-- shade of Vesh's own, and every dwarf of the crew that fell gets back up on his side (a Bone Wyrm where a
-- wyrm fell) up to the elite cap. Kill him first and he dies as the Paymaster, and nothing rises.
--
-- SO THE PUZZLE IS KILL ORDER TWICE OVER. The heaps make the crew worse the longer it stands, and the crew
-- standing is the only thing keeping the dead in the ground.
--
-- THE CREW is the Strongroom's line (a Hornblower and two Delvers) with the Hearthguard walking in at depth,
-- in the Band idiom encounter_greed_the_strongroom.lua uses: the Delvers roll one either side of two on the
-- fight's seed, and every rating reads the two. Six at the very most, the elite cap -- and the raise only
-- ever runs with the crew gone, so his side always has room to stand some of it back up.
--
-- ON THE APPROACH (rung 1), Vesh's own floor -- the dead of this floor are his catch -- and billed as a spare
-- (Descent.SINS). Locked to the cave, as every Greed stop is.
local Band = require("models.band")

return {
    name = "The Paymaster",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    composition = function(ctx)
        local list = { "character_the_paymaster", "character_dwarf_hornblower" }
        -- Two Delvers at the centre of the band, one either side on the fight's own seed -- the Strongroom's
        -- roll, so the crew he pays is not the same head-count every visit. Every rating reads the centre.
        Band.fill(list, ctx, "character_dwarf_delver", { base = 2, max = 3 })
        -- The Hearthguard at depth: none on a shallow approach, one from floor six down. `vary = 0` so the
        -- band never rolls it in early -- depth is the gate here, and the roll would only blur it.
        return Band.fill(list, ctx, "character_dwarf_hearthguard", { base = 0, min = 0, per = 6, max = 1, vary = 0 })
    end,
}
