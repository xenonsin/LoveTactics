-- Halting Ground: the zone a March Standard holds (data/characters/character_field_standard.lua). A
-- foe that steps onto it is Halted (data/status/status_halted.lua) -- its turn is taken without a mark
-- on its body. Laid as a 3x3 around the standard and OWNED by it: cut the standard down and
-- Hazard.dropOwnedBy takes the whole square with it. Modeled on hazard_rally, one word changed --
-- friendly inspiration becomes hostile lockdown.
return {
    name = "Halting Ground",
    description = "Inflicts Halted on foes that cross it.",
    tags = { "control" },
    -- A warden's line, not a wizard's circle: the same rune the arcane zones wear, in the standard's
    -- amber rather than the Arcanum's violet.
    fx = { color = { 0.96, 0.72, 0.26 } },
    duration = 9999, -- answers to the standard's life, not a clock (Hazard.dropOwnedBy ends it)
    disposition = "hostile", -- the enemy is the one who steps in and pays
    onEnter = function(ctx)
        if ctx.unit == ctx.hazard.owner then return end
        if ctx.isAlly(ctx.unit) then return end -- only foes of the standard's side are halted
        ctx.applyStatus(ctx.unit, "status_halted")
    end,
}
