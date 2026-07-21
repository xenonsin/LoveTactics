-- Amana's rule, and the mechanical face of devotion: "gives what is offered, refuses what is not"
-- (docs/story.md, "The other seven" -- the priest answers lust). Her will is the one thing that cannot
-- be taken, because she gave everything away first: there is nothing left in her to seize.
--
-- So this is a standing refusal of any seizure of self. When Charm lands on her -- the one status in the
-- game that takes a unit's allegiance (data/status/status_charm.lua) -- she sheds it the instant it
-- touches her, on the "recipient" side of Trait.onStatusApplied, exactly as Cleansing Ward sheds a
-- debuff (data/traits/trait_cleansing_ward.lua) but with no cooldown at all: a will that was never held
-- back cannot be prised loose even once. Removing the status fires its onExpire, which undoes the
-- side-flip Charm stashed, so she ends the exchange on her own side (data/status/status_charm.lua).
--
-- It is also the flag Lust's own rule reads. Luxuria takes what a foe held back (data/traits/
-- trait_rapture.lua); Amana holds nothing back, so Rapture finds nothing on her and passes. The general
-- and her foil are the same axis read the two ways -- one takes the unoffered, the other has already
-- offered it all.
--
-- Unlike a boss's blanket Charm-immunity (character.boss, which goes inert the moment she is an ally),
-- this rides on Amana herself and stays true once she is in your party -- which is the only time it
-- matters, since the recruit fight already had the boss guard.
return {
    name = "Unbidden",
    description = "Her will cannot be taken: Charm sheds off her the instant it lands.",
    onStatusApplied = function(ctx)
        if ctx.role ~= "recipient" then return end
        if not ctx.status or ctx.status.id ~= "status_charm" then return end
        ctx.clearStatus(ctx.unit, ctx.status.id)
        ctx.log("action", string.format("%s cannot be taken.", (ctx.unit.char and ctx.unit.char.name) or "She"))
    end,
}
