-- The generic binding for a summon that is called for free and paid for when it FALLS: its summoner
-- loses half the health they have at that moment -- the conjured thing goes back where it came from
-- and takes a share of its summoner's flesh with it.
--
-- Paying on death rather than on the call is what makes such a summon a bargain worth weighing instead
-- of a flat toll: the strength is free while it stands, and the bill lands at the worst possible moment
-- -- when whatever killed it is still on the field and its summoner is suddenly half of themselves.
--
-- Any summoning ability binds this to what it raises by naming it in the call's `traits`
-- (models/summon.lua) -- the Wolfsong Horn's true call is the first (data/items/utility/
-- sig_wolfsong_horn.lua). The price belongs to the ABILITY that struck the bargain, not to the
-- creature's blueprint: the same body called by some other means owes nothing. It lands on the
-- creature all the same, because the creature is what knows it died. Trait.onDeath fires from killUnit
-- before the field is unwound, so the summoner is still there to bill.
--
-- Only a killed summon pays. Combat.dismiss -- a lapsed binding, or a summoner cut down beneath it --
-- never reaches this hook, and rightly: a summoner who falls does not then bleed for the thing that
-- vanished with them.
--
-- The price is a `drain` (ctx.drain, models/trait.lua), not damage: no armor softens it, no barrier eats
-- it, and it can never be lethal -- half of what remains always leaves something behind.
return {
    name = "Blood Price",
    description = "When it falls, its summoner loses half their remaining health.",
    magnitude = 0.5, -- the share of the summoner's CURRENT health the death takes
    onDeath = function(ctx)
        local summoner = ctx.unit.summoner
        if not (summoner and summoner.alive) then return end
        local hp = summoner.char.stats.health
        local toll = math.floor((hp.current or 0) * ctx.def.magnitude)
        if toll <= 0 then return end
        ctx.drain(summoner, "health", toll)
        ctx.log("damage", string.format("%s falls, and %s pays the blood-price: %d health.",
            (ctx.unit.char and ctx.unit.char.name) or "The summon",
            (summoner.char and summoner.char.name) or "its summoner", toll))
    end,
}
