-- THE HOARD: Avaritia's rules, carried in the centre of her grid as creature kit (a boss's machinery, not
-- for sale -- the Court's pattern, data/items/utility/utility_the_court.lua). Reviewed over three rounds on
-- 2026-09-25 ("Avaritia, the Unspent").
--
--   trait_the_hoard     her hoard laid round her at the bell, Every Coin Counted, Wing Buffet
--   trait_gilded_belly  armour per heap within 2, lent to her side within 2; off, and bare to pierce, while
--                       she winds up
--   trait_boss_phases   her three thirds:
--                         60%  she takes wing -- Over the Deeps arms her strafe
--                         30%  she comes down for good, every heap left melts to Molten Gold, and the
--                              Mountain Burns: +25% damage, and the lava spreads a tile every turn
--
-- A dragon's hide: fire does nothing to her (`immune`), and neither Burn nor the gilding of her own melted
-- gold takes (`statusImmunity`). Bound: it is what she is.
return {
    name = "The Hoard",
    description = "Her hoard, her belly and her three thirds. Immune to fire.",
    flavor = "Nobody has ever counted it. She has, every coin, every night.",
    sprite = "assets/items/utility_the_hoard.png",
    type = "utility",
    tags = { "relic" },
    class = "creature",
    noSteal = true,
    bound = true,
    immune = { fire = true },
    statusImmunity = { "status_burn", "status_gilded", "status_in_molten_gold" },
    traits = { "trait_the_hoard", "trait_gilded_belly", "trait_boss_phases" },
    phases = {
        { at = 0.60, responses = {
            { kind = "status", id = "status_over_the_deeps" },
            { kind = "log", text = "Avaritia takes wing over the deeps." },
        } },
        { at = 0.30, responses = {
            { kind = "clear", id = "status_over_the_deeps" },
            { kind = "ground", from = "hazard_coin_heap", to = "hazard_molten_gold" },
            { kind = "status", id = "status_the_mountain_burns" },
            { kind = "log", text = "The hoard melts, and the mountain burns." },
        } },
    },
}
