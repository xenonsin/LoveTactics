-- Channeling: the caster is winding up a powerful spell (a large AOE like Meteor Storm). It is a
-- pure marker -- the whole mechanic lives in models/combat.lua: the pending spell is held on
-- `unit.channel`, this badge shows it, and the caster's next turn IS the resolution. It is NOT a
-- debuff (Cure must never cancel your own channel), and it is applied/removed only by combat.lua
-- (useItem starts it, resolveChannel/interruptChannel clear it), so `duration` is just a safety cap
-- -- each cast overrides it with `opts.duration = ab.channel + 1`, one tick past the wind-up so
-- Status.tick can't expire the badge on the very rebase that surfaces the caster. Hard control
-- (Stun, Freeze) and forced movement break it; see `interruptsChannel` on those statuses.
return {
    name = "Channeling",
    abbr = "Ch",
    description = "Winding up a powerful spell; disrupted by hard control or forced movement.",
    color = { 0.65, 0.45, 0.95 }, -- badge tint (arcane violet)
    duration = 99,                -- safety cap; overridden per-cast to ab.channel + 1
    debuff = false,               -- NOT removable by Cure
    hideLog = true,               -- begin/resolve/interrupt are logged explicitly by combat.lua
}
