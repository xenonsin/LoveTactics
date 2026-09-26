-- THE NEST: the Brood Queen is where the gold goes. A heap a scarab rolls into her is taken into her hoard
-- (status_hoard) rather than stopping against her (Scarab.roll reads this flag), which is what makes her
-- scarabs a supply line and the hoard her clock. Reviewed 2026-09-25 ("The Coin-Eaters").
--
-- SHE OPENS ON ONE HEAP'S WORTH (NEST_START): the nest was already a hoard before the company walked in.
-- Measured on a headless fight, a Queen who started empty never reached the threshold before the fight was
-- decided -- so the puzzle never happened. One heap at the bell means the first carry home can start the
-- clock, which is where a puzzle's warning belongs: early, while the company can still act on it.
local NEST_START = 10

return {
    name = "The Nest",
    description = "Starts with 10 Hoard; a coin heap rolled into it or beside it is added to its Hoard.",
    hoardsHeaps = true,
    onCombatStart = function(ctx)
        require("models.status").apply(ctx.combat, ctx.unit, "status_hoard", { magnitude = NEST_START })
    end,
}
