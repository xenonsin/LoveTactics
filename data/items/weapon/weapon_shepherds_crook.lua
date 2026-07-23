-- A mace, so it displaces (docs/weapons.md) -- and it is the only weapon in the game whose target is an
-- ALLY. It deals nothing to anybody: it hooks a friend and moves them two tiles, for a fraction of a
-- turn's tempo.
--
-- Quest-only: `class` with no `price`.
--
-- A DELIBERATE DEVIATION and the largest in this batch, so it is stated plainly: the family contract says
-- a mace buys displacement rather than damage, and this keeps that exactly -- it simply stops requiring
-- that the displaced body be an enemy. What it gives up is being a weapon at all. There is no strike
-- here, and a knight carrying only this is a knight who cannot attack.
--
-- Why it is worth a slot: movement in this game is the scarcest thing there is. A unit that has already
-- acted cannot move, a rooted one cannot move, a Mired or Crippled one moves badly, and none of that has
-- ever had an answer. This is the answer -- pull the bleeding rogue out of the fire, shove the archer
-- into its band, put the priest inside the censer's smoke, drag the knight who spent their turn back
-- behind the wall. It is a turn spent entirely on somebody else's position.
--
-- Read against data/items/weapon/weapon_given_hour.lua, which gives an ally a whole ACTION. That one is
-- rarer and stronger; this one is repeatable and precise, and unlike the Given Hour it does not need the
-- recipient to still have anything left to spend.
return {
    name = "Shepherd's Crook",
    description = "Hooks an ally and moves them two tiles. Deals no damage to anyone.",
    flavor = "The Bastion issues one per company and never explains it. The companies that work it out do not give it back.",
    sprite = "assets/items/shepherds_crook.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    class = "knight",
    activeAbility = {
        target = "ally",
        range = 1,
        -- Cheap in tempo AND stamina, because it does nothing else at all. A repositioning tool that cost
        -- a full swing's tempo would never be worth the turn it displaces.
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, -- it is not a strike; see the header
        effect = function(fx)
            local t = fx.target
            if not t or not t.alive then return end
            -- `amount = 0` on the collision: a shepherd who slammed the sheep into a wall would be
            -- missing the point. The travel is the whole effect, and running out of room simply stops it.
            fx.knockback(t, 2, { amount = 0 })
            fx.log("action", string.format("%s hauls %s clear.",
                (fx.user.char and fx.user.char.name) or "Unit",
                (t.char and t.char.name) or "an ally"))
        end,
    },
}
