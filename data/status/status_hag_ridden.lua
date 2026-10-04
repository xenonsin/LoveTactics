-- HAG-RIDDEN: the Mare is sitting on a sleeper ("Sloth's Bestiary", 2026-10-04, approved). Laid by the Mare's
-- Hag's Weight on a body that is Asleep (data/items/weapon/weapon_hags_weight.lua).
--
-- WHILE IT RIDES, BLOWS DO NOT WAKE THE SLEEPER (Combat.sparesSleep reads this badge and the Mare beside it), and the
-- sleeper takes the Mare's damage at the top of each of the Mare's turns (trait_hag_ridden). The ride ends when the
-- Mare is struck or moved, when it falls, or when the sleeper wakes some other way -- a Cure, or the Sleep running out.
--
-- THIS STATUS OWNS THE TIE, both ends, as Mantled does for the hawk: onApply ties the Mare to the sleeper and puts
-- status_riding on the Mare; onExpire, which fires on every removal path, unties it. Not a debuff: a Cure does not
-- lift the Mare off a body (it wakes the body, and a waking body throws her).
return {
    name = "Hag-Ridden",
    abbr = "Hag",
    description = "The Mare sits on it: blows do not wake it, and it takes the Mare's damage each turn.",
    color = { 0.330, 0.260, 0.420 }, -- badge tint (nightmare violet)
    duration = 999,
    hideDuration = true,
    onApply = function(ctx)
        local body, mare = ctx.unit, ctx.applier
        if not (mare and mare.alive) or body.riddenBy then return end
        body.riddenBy, mare.ridingBody = mare, body
        ctx.applyStatus(mare, "status_riding", { applier = mare })
    end,
    onExpire = function(ctx)
        local body = ctx.unit
        local mare = body.riddenBy
        if mare then
            mare.ridingBody = nil
            require("models.status").remove(ctx.combat, mare, "status_riding")
        end
        body.riddenBy = nil
    end,
}
