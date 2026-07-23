-- The Cathedral's staff. A staff, so it owes the family's Focus swap (docs/weapons.md) -- end the turn
-- to recover mana instead of attacking. What it adds over data/items/weapon/weapon_staff.lua is who that
-- recovery reaches: `waitBehavior.covers` restores mana to every ADJACENT ALLY as well as the bearer.
--
-- The extra a named staff owes its base (docs/weapons.md), and deliberately the same word the Oathkeeper
-- Shield uses to spread its brace across a line: `covers` means "and everyone beside you" on either half
-- of the wait swap. Where you plant decides who else gets it -- a wall in the shield's case, a second
-- casting in this one.
--
-- Which is the priest's whole argument in one item. A mage's staff answers a mage's problem: MY mana ran
-- out. This one answers the party's, and it is worth a turn only if you spent the turn before it
-- standing somewhere useful.
return {
    name = "Crozier",
    description = "Replaces Wait with Focus: end your turn to recover mana, and give some to adjacent allies.",
    flavor = "The shepherd's crook. It was never for the shepherd.",
    sprite = "assets/items/crozier.png",
    type = "weapon",
    tags = { "staff", "magical", "melee" }, -- magical: routes through magicDamage / magicDefense
    class = "priest",
    price = 180,
    repRank = 3,
    -- Both payoffs climb with the forge; `speed` deliberately does not (an upgrade never buys back
    -- tempo -- see models/item.lua's WAIT_BEHAVIOR_MAGNITUDES). `covers` is the smaller number: what
    -- the neighbour draws is always less than what the bearer keeps.
    waitBehavior = {
        kind = "focus",
        mana = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 },
        covers = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 },
        speed = 10,
    },
    activeAbility = {
        target = "enemy",
        range = 1, -- adjacent only: a crozier is not a wand
        speed = 4,
        cost = { stat = "stamina", amount = 6 }, -- stamina, so a cornered priest can always swing it
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, -- feeble on purpose: the swap is the weapon
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
