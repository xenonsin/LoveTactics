-- A heavy blunt weapon: it hits, and the same blow SHOVES. The knockback rides on the strike (two
-- tiles straight back along the line from the wielder), so a KILLING hit still throws the body --
-- the corpse-to-be slides and slams into whatever is behind it before it drops (Combat.dealFlatDamage
-- carries a mortally-wounded target through the shove, then finishes the kill). If a wall, the board
-- edge, or another unit stops it short,
-- everything involved in the collision takes impact damage -- the Power, and more of it the more
-- travel the shove was robbed of (a foe pinned flat against a wall eats the worst). Slow (speed 4)
-- and dear in stamina -- you buy the displacement, not the damage.
return {
    name = "Iron Mace",
    description = "Drives the target back two tiles. A collision hurts everyone in it.",
    flavor = "You are not buying the damage. You are buying where they end up.",
    sprite = "assets/items/mace.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    class = "knight", -- the Bastion's: displacement is the wall's trade, not wrath's (docs/classes.md)
    price = 190,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = { 8, 9, 10, 10, 11, 12, 13, 14, 14, 15, 16 },
        effect = function(fx)
            -- The shove is folded INTO the blow (opts.knockback), not a separate step, so a lethal hit
            -- throws the body before it falls rather than dropping it on the spot -- see the mace's
            -- header and Combat.dealFlatDamage's `mortallyWounded` handling.
            fx.damage(fx.target, { knockback = { distance = 2, amount = fx.amount } })
        end,
    },
}
