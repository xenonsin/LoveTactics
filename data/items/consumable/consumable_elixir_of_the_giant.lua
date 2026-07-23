-- Elixir of the Giant: drink someone else's arm. A long window of raised Damage
-- (data/status/status_giants_vigour.lua), bottled.
--
-- The elixir shelf is envy stated as plainly as the Crucible knows how: it does not make you stronger,
-- it makes you strong FOR A WHILE, out of a bottle, and then you are what you were. Nothing on it is
-- cast -- every one of the three is a thing somebody else had that you bought a measure of. That is
-- the same argument the Powder Keg makes about damage and the Homunculus makes about bodies, and it
-- is why the shelf holds twelve consumables and three abilities without that being a failure
-- (docs/classes.md, "Known debt").
--
-- Drunk on your own turn at a real cost in tempo (speed 3), which is what separates an elixir from the
-- charm it resembles. A charm works because it is in the grid; this works because you spent a turn
-- early in a fight betting the fight would last long enough to pay you back. Nine turns of duration is
-- that bet's payout, and drinking it on the last turn of a battle is how you lose it.
--
-- `target = "ally"` includes the drinker (a unit is its own ally), so it doubles as a way to hand the
-- fighter their courage on a turn the fighter had something better to do.
return {
    name = "Elixir of the Giant",
    description = "Raises an ally's Damage for most of the battle.",
    flavor = "Ogre marrow, mostly. The Crucible would rather you did not ask which part is 'mostly'.",
    sprite = "assets/items/consumable_elixir_of_the_giant.png",
    type = "consumable",
    tags = { "potion", "elixir", "restorative" },
    class = "alchemist",
    price = 140,
    repRank = 2,
    activeAbility = {
        target = "ally", -- includes the user: a unit is its own ally
        range = 1,
        speed = 3,
        consumesItem = true,
        ai = { priority = "low", act = "support", targetPref = "self" },
        effect = function(fx)
            -- Duration scales with the forge; the bonus is the status's own. A better-distilled
            -- elixir lasts longer rather than hitting harder -- the same principle the incense
            -- radius follows (docs/weapons.md): an upgrade buys more of the thing, never a wider one.
            fx.applyStatus(fx.target, "status_giants_vigour", { duration = 45 + 3 * fx.level })
        end,
    },
}
