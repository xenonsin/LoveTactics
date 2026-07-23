-- A staff, so it swaps Wait into Focus (docs/weapons.md). Its extra is that the meditation feeds the line
-- rather than only the hand holding it: every Focus lays hazard_renewal on the ground around the holder,
-- and allies standing in it recover health.
--
-- Quest-only: `class` with no `price`.
--
-- Read against data/items/weapon/weapon_crozier.lua, which is the other staff that pays the party. The
-- Crozier's `covers` hands adjacent allies MANA -- a mage's answer to "my mana ran out" spread across the
-- line -- and it pays out once, on the beat, to whoever happens to be standing there. This lays GROUND,
-- which is a different promise: it keeps paying for as long as the square holds, to anybody who walks
-- into it, including people who were not there when the priest sat down.
--
-- So it is the only healing in the game that costs nothing to aim and nothing to maintain. The priest
-- Focuses once and there is a place on the board where the wounded can go. What it gives up is control:
-- it cannot be pointed at the person who needs it, and a fight that moves away from the square wastes it
-- entirely.
--
-- The mana it returns is a plain staff's, untouched -- this weapon adds rather than trades, which is why
-- it is given rather than sold.
return {
    name = "The Renewal Staff",
    description = "Replaces Wait with Focus: recover mana, and leave ground behind you where allies mend.",
    flavor = "The Cathedral teaches that rest is a place rather than an interval. The staff was made to make that literally true.",
    sprite = "assets/items/renewal_staff.png",
    type = "weapon",
    tags = { "staff", "magical", "holy", "melee" },
    class = "priest",
    waitBehavior = {
        kind = "focus",
        mana = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 },
        speed = 10,
        -- The 3x3 the priest sits in the middle of. `amount` scales with the forge and `radius` does not,
        -- on the same principle every zone in this game follows: an upgrade buys a deeper blessing, never
        -- a wider floor.
        hazard = { id = "hazard_renewal", radius = 1, duration = 16 },
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
