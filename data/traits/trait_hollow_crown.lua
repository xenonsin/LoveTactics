-- The Demon Lord's rule. It has no sin of its own -- the seven were its appetites -- and so it has no
-- fight of its own either. As it is worn down it reaches for the generals you already killed and puts
-- them back on, one at a time.
--
-- Mechanically this is the same `onDamaged` hook Wrath's general uses (data/traits/wrath_rising.lua),
-- pointed at health thresholds instead of a damage counter. One engine feature, two bosses. Because
-- onDamaged fires only on a SURVIVOR (see Combat.dealFlatDamage), a blow that kills the Crown outright
-- never summons the shade it was owed -- which is the correct reading: burst it down and it never gets
-- to wear anything.
--
-- The shades are summoned, so they vanish with it: kill the Crown and the fight is over, whatever else
-- is still standing. That is what keeps the `assassinate` objective honest.
return {
    name = "The Hollow Crown",
    description = "As it fails, it wears the dead.",
    -- Fractions of max health. Each one crossed calls up the next name in `shades`.
    thresholds = { 0.75, 0.50, 0.25 },
    -- The dead it reaches for, in order. As the remaining five generals are authored, put them here --
    -- this list IS the fight. Wrath and Sloth have been written; the Crown falls back on the champions
    -- of the world above for the shapes it has not yet been given.
    --
    -- Sloth second is deliberate. The Crown wearing Acedia at half health is her own thesis argued by
    -- the board: you already killed her, and here she is, and nothing you did stuck. That is the
    -- argument the whole middle act is a rebuttal to (docs/story.md).
    shades = { "character_general_wrath", "character_general_sloth", "character_champion" },
    onDamaged = function(ctx)
        local hp = ctx.unit.char.stats.health
        local fraction = hp.current / hp.max

        -- A single enormous blow can cross two thresholds at once, and should call up both.
        while ctx.trait.stacks < #ctx.def.thresholds
            and fraction <= ctx.def.thresholds[ctx.trait.stacks + 1] do
            ctx.trait.stacks = ctx.trait.stacks + 1

            local shade = ctx.def.shades[ctx.trait.stacks]
            local x, y = ctx.openTileNear(ctx.unit.x, ctx.unit.y)
            if shade and x then
                ctx.log("system", "The Crown remembers another name.")
                ctx.summon(shade, x, y)
            end
        end
    end,
}
