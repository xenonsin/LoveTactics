-- A longbow, so it is drawn before it looses and reaches five tiles (docs/weapons.md). Its extra is that
-- it does not deal a death, it NAMES one: the target is marked for an hour (status_knell), and when the
-- count runs out it dies regardless of how much health it had.
--
-- Quest-only: `class` with no `price`.
--
-- Read against data/items/weapon/weapon_knell_point.lua, which does the same thing with a spear into the
-- second rank. The two are the same idea at opposite ends of the board and the difference is entirely
-- about who can be reached: the pike has to be thrust THROUGH somebody, so the enemy's own front rank
-- decides whether the mark can be placed. This has to be drawn for a full turn in the open, so what
-- decides is whether the archer can survive standing still. Two costs, one effect, and a party carrying
-- both can mark two bodies a turn from opposite directions.
--
-- What makes the mark worth a whole turn of draw is that it ignores the enemy's health bar entirely.
-- Every other thing in the hunter's kit is arithmetic against a number that a boss has an enormous amount
-- of; this asks a different question, and the enemy has to answer it with a cleanse -- which is a turn
-- their healer spends not healing, and is the real payoff even when the bell never rings.
--
-- Knell is deliberately not `resistible` (see its header: the resist system buys duration, and duration is
-- the wrong axis for a fixed countdown), so a warded body is marked exactly as surely as an unwarded one.
return {
    name = "The Knell-Shaft",
    description = "A drawn shaft that marks its target for death: when the count runs out, it dies.",
    flavor = "The arrow is not what kills him. The arrow is only the part that is delivered.",
    sprite = "assets/items/knell_shaft.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        requiresSight = true,
        speed = 5, -- slower than an iron longbow: the mark is not a snap decision
        cost = { stat = "stamina", amount = 12 },
        channel = 2,
        -- The lowest curve in the family by a wide margin. A weapon that kills outright must not also
        -- hit hard, and this one's damage exists mostly so the shot is not literally nothing.
        damage = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.damage(t)
            if t.alive then
                fx.applyStatus(t, "status_knell")
                fx.log("action", string.format("A bell is rung for %s.", (t.char and t.char.name) or "the target"))
            end
        end,
    },
}
