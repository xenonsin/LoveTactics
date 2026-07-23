-- Struck Ledger: a price has been written against this body, and the Undercroft honours it whoever
-- collects. When the bearer falls, the promise settles into the party's purse (Status.onDeath ->
-- Combat.bounty), and it settles regardless of who struck the blow -- an ally, a fire, its own poison.
--
-- WHY A STATUS AND NOT A TRAIT. The promise is made about the TARGET, so it has to travel with the
-- target: onto whoever the mark is moved to, through a Cure that lifts it, across a Charm that flips
-- the marked unit's side. A trait could not do any of that, because a trait lives on its bearer's own
-- grid -- and the bearer here is the person the rogue is pricing, who has no reason to carry the
-- rogue's paperwork. Status.onDeath exists for exactly this shape of rule.
--
-- The mark also LIGHTS the body while it holds (`revealsBearer`, the same flag Witchlight uses): you
-- cannot hide from a price, which is the flavour and also the mechanical reason a thief would ever
-- spend a turn on one against a rogue. Two effects, one cast, and the second is the one that makes it
-- worth casting against the enemy who was going to be hard to finish.
--
-- Greed's own economy: the bounty is banked on the COMBAT (models/combat.lua's Combat.bounty), so it
-- pays out with the spoils and pays nothing at all if the battle is lost. You are not paid for marking.
-- You are paid for winning with the mark collected.
return {
    name = "Struck Ledger",
    abbr = "Ldgr",
    description = "Priced: lit up, and worth coin to the company when it falls.",
    color = { 0.90, 0.76, 0.30 }, -- badge tint (coin gold)
    duration = 25,                -- ~5 turns for the price to be collected
    magnitude = 40,               -- the coin it settles for; the granting ability raises it per level
    debuff = true,
    resistible = "physical",
    revealsBearer = true,         -- a priced body does not get to be hidden
    onDeath = function(ctx)
        local paid = ctx.combat and require("models.combat").bounty(ctx.combat, ctx.magnitude or 0) or 0
        if paid <= 0 then return end
        ctx.log("action", string.format("The price on %s is collected: %d gold.",
            (ctx.unit.char and ctx.unit.char.name) or "Unit", ctx.magnitude or 0), ctx.unit)
    end,
}
