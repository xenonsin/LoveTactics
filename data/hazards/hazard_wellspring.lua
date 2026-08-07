-- Wellspring: a footprint that has filled with water, and the ground half of the Wellspring Sandals
-- (data/items/utility/utility_wellspring_sandals.lua). An ALLY stepping into it drinks it dry and gets
-- mana back -- the one pool that otherwise never comes back on its own.
--
-- ONE MOUTHFUL, and that is the whole balance of the item. Every other friendly zone in the game pays
-- out on every crossing, because what they hand over is a status that refreshes rather than stacks (a
-- Sanctuary's Regeneration, a Renewal Banner's) -- so walking a Sanctuary twice buys nothing the second
-- time and nobody had to write a rule for it. A direct pour has no such ceiling: without `ctx.consume`
-- a mage could pace back and forth across one print and mint mana until the print aged out, which is
-- the exact thing the game's scarcest resource cannot survive. So the print is spent by the body that
-- drinks it.
--
-- Consumed only if it actually POURED. A full-mana fighter walking the wearer's wake to the front takes
-- nothing and leaves every print standing for the caster coming up behind -- which matters, because the
-- party has no way to reserve a tile and the front rank crosses first. Combat.restoreResource returning
-- 0 for a full pool is what makes that fall out for free.
--
-- Sided to the wearer (Combat.layTrail passes `unit.side`), so a foe chasing the party down its own
-- footsteps gains nothing -- the same terms Pilgrim's Sandals lays hallowed ground on.
--
-- `disposition = "friendly"` puts it on the enemy AI's list of ground worth standing in, weighed
-- side-aware in Hazard.tileBias -- so an enemy caster is drawn to its OWN wellsprings and ignores the
-- party's. It reads as a BUFF rather than a heal in ui/field_fx.lua (hazardHeals looks for health), and
-- that is right: a refilled pool is not a closed wound.
-- Two-thirds of a Mana Potion (12), and under rather than over on purpose: a flask costs a whole turn
-- and a slot, and a print costs the drinker only a detour on a walk they were making anyway. A trail
-- passes no magnitude of its own (Combat.layTrail hands over a side and a duration, nothing else), so
-- this is the figure that actually pours -- it is quoted in the sandals' description, and changing one
-- without the other makes the shop lie.
local MANA = 8

return {
    name = "Wellspring",
    description = "The first ally to step in it drinks it dry, and gets mana back.",
    tags = { "arcane" },
    duration = 10, -- ~2 turns; Combat.layTrail overrides it with the sandals' own figure
    disposition = "friendly",
    onEnter = function(ctx)
        if not ctx.isAlly(ctx.unit) then return end
        -- A body with NO mana at all is not a body with an empty pool, and the difference is not
        -- cosmetic: Combat.restoreResource treats a missing stat as a plain number and would MINT one
        -- on a fighter who has never had mana in their life -- then report 8 poured, and the print
        -- would be drunk by somebody who cannot cast. Guarded exactly as the Cafe's Bottomless Pot
        -- guards the same call (data/traits/trait_meal_bottomless_pot.lua). It is also the case that
        -- matters most in play: at MAX_FIELD 4 the front rank is usually mana-less and always crosses
        -- the wearer's wake first, and every print it walks has to still be there for the caster behind.
        local pool = ctx.unit.char and ctx.unit.char.stats and ctx.unit.char.stats.mana
        if type(pool) ~= "table" or (pool.max or 0) <= 0 then return end
        local poured = ctx.restore(ctx.unit, "mana", ctx.amount or MANA)
        if poured > 0 then ctx.consume() end
    end,
}
