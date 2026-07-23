-- Unyielding: a refusal you pay for. When a debuff lands on the bearer, it spends mana and the
-- affliction slides off -- and it does that for EVERY debuff, for as long as the mana lasts.
--
-- Read it against the Cleansing Ward (data/traits/trait_cleansing_ward.lua), which is the same reflex
-- priced the other way. The Ward shrugs off the first thing to touch you and then goes quiet for
-- twenty ticks, whatever happens next; this one never goes quiet, and asks 8 mana each time. The
-- trade is a cooldown for a pool, and it is the trade the game already made everywhere else it could:
-- an answer paced by a price is one the player can watch draining and plan around, where an answer
-- paced by a hidden timer is one they can only be surprised by (see docs/weapons.md, "pricing a
-- triggered reflex").
--
-- What that buys the knight specifically is a bad afternoon for anyone whose plan was a status. Walk a
-- mage's Silence, a hammer's Stun and a dagger's Bleed into it one after another and all three come
-- off -- and then the mana is gone, and the fourth sticks. It does not make the knight immune; it
-- decides how many afflictions this fight is worth, and lets the enemy find the number.
--
-- Priced in MANA on a shelf that mostly spends stamina, deliberately. Stamina is what the knight's
-- body does -- swinging, bracing, shoving -- and refusing an affliction is not a thing the body does.
-- It also means the reflex competes with nothing else the knight is doing, and empties the one pool a
-- knight has the least of (docs/classes.md: knight is the genuinely hybrid shelf).
--
-- Strips only the status that just landed (ctx.status.id), never the whole slate: this is a refusal,
-- not a cleanse.
return {
    name = "Unyielding",
    description = "Spend mana to shrug off any debuff the moment it lands. No cooldown -- only the pool.",
    cost = { stat = "mana", amount = 8 },
    onStatusApplied = function(ctx)
        if ctx.role ~= "recipient" then return end
        local landed = ctx.status and ctx.status.def
        if not (landed and landed.debuff) then return end
        -- Cost LAST, after every free refusal, so a firing that declines is never billed
        -- (models/trait.lua, `ctx.pay`). No attacker in this event, so `pay` charges the def's own
        -- cost rather than an answer's escalating swing price -- which is right: refusing an
        -- affliction is not a blow thrown back at anyone.
        if not ctx.pay() then return end
        ctx.clearStatus(ctx.unit, ctx.status.id)
        ctx.log("action", string.format("%s refuses it.", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
    end,
}
