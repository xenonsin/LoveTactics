-- The staff archetype: a staff swaps the holder's Wait into Focus (docs/weapons.md) -- end the turn
-- without attacking to recover mana instead, at a steep slice of the timeline. See Combat.waitBehavior
-- / Combat.focus; it is the same mechanism a shield uses to swap Wait into Defend, and the reason
-- data/items/utility/focus_stone.lua exists as a charm for anyone who wants Focus without a staff.
--
-- That swap IS the weapon. A caster's real constraint is mana, not damage, and a staff is what lets a
-- mage refill it from the field instead of walking back to town -- at the price of a turn spent doing
-- nothing else. The staff's own strike is a deliberate afterthought: adjacent, magical, and feeble,
-- there so a mage backed into a corner is never entirely disarmed.
--
-- The Arcanum's entry-rank staff. data/items/weapon/parasitic_staff.lua is the same family taken
-- further: it refills mana ON THE HIT rather than only on Focus.
return {
    name = "Staff",
    description = "A plain rowan staff. Replaces Wait with Focus: skip your turn to recover mana.",
    sprite = "assets/items/staff.png",
    type = "weapon",
    tags = { "staff", "magical", "melee" }, -- magical: routes through magicDamage / magicDefense
    class = "mage",
    price = 70,
    repRank = 1,
    -- The Focus swap: mana recovered per Focus, and the time it costs. Both climb with the forge --
    -- an upgraded staff meditates deeper, not faster.
    waitBehavior = { kind = "focus", mana = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }, speed = 10 },
    activeAbility = {
        target = "enemy",
        range = 1, -- adjacent only: a staff is not a wand
        speed = 4,
        cost = { stat = "stamina", amount = 6 }, -- stamina, so a cornered mage can always swing it
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, -- feeble on purpose: the Focus swap is the weapon
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
