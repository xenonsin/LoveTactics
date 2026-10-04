-- LISTLESS: the noonday's weight on a body that has stopped trying ("Sloth's Bestiary", 2026-10-04, slice C).
-- Laid by the Noonday Demon (data/traits/trait_the_noonday_demon.lua) on a foe within 4 that ends its turn having
-- dealt no damage, and by the Meridian Charm within 3. The bookkeeping is models/sloth_bog.lua's.
--
-- -3 Damage a stack, to 3. ANY DAMAGE IT DEALS CLEARS EVERY STACK (SlothBog.struck), which is the whole answer:
-- fight. A healer standing back is the body it was made for.
--
-- AT THREE, THE DEMON'S STACKS TAKE THE TURN: the instance the Demon laid carries `shames`, and at the top of the
-- bearer's next turn it is spent and Shamed goes on -- no act, no move, ending with the turn. The charm's stacks
-- never do; they only weigh. A debuff with no clock, so a Cure lifts it, and so does a blow.
return {
    name = "Listless",
    abbr = "List",
    description = "Listless: -3 Damage a stack. Dealing damage clears it.",
    color = { 0.820, 0.700, 0.380 }, -- badge tint (noon haze)
    duration = math.huge,
    hideDuration = true,
    debuff = true,
    magnitude = 1,
    stacks = 3,
    statBonus = { damage = -3 },
    statBonusScales = true,
    onTurnStart = function(ctx)
        local s = ctx.status
        if not (s.shames and (s.magnitude or 0) >= 3) then return end
        ctx.expire()
        ctx.log("status", string.format("%s cannot be bothered.", (ctx.unit.char and ctx.unit.char.name) or "Unit"),
            ctx.unit)
        ctx.applyStatus(ctx.unit, "status_shamed", { applier = ctx.unit })
    end,
}
