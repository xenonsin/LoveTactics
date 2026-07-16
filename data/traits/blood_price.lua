-- The binding on the Wolfsong Spirit (data/characters/wolfsong_spirit.lua): what the great wolf costs
-- is not paid when it is called, but when it FALLS. The archer who sounded the horn loses half the
-- health she has at that moment -- the beast goes back where it came from and takes a share of its
-- summoner's flesh with it.
--
-- Paying on death rather than on the call is what makes the Spirit a bargain worth weighing instead of
-- a flat toll: the strength is free while it stands, and the bill lands at the worst possible moment --
-- when whatever killed the wolf is still on the field and the archer is suddenly half of herself.
--
-- The toll rides on the CREATURE, not the horn, because the creature is what knows it died -- delivered
-- through its grid by data/items/utility/wolfsong_binding.lua, the way every trait reaches its bearer.
-- Trait.onDeath fires from killUnit before the field is unwound, so the summoner is still there to bill.
--
-- Only a killed spirit pays. Combat.dismiss -- a lapsed binding, or a summoner cut down beneath it --
-- never reaches this hook, and rightly: an archer who falls does not then bleed for the wolf that
-- vanished with her.
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
