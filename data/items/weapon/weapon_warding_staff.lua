-- A staff, so it swaps Wait into Focus (docs/weapons.md). Its extra is that meditating also raises a
-- ward: every Focus grants the holder a Magical Barrier (status_magical_barrier), which negates the next
-- magical attack aimed at them outright.
--
-- The mage shelf's top rung. It answers the exact moment a caster is most likely to die, which is the
-- turn they spend Focusing: a mage out of mana has to stop and refill, and stopping in front of an enemy
-- caster is how mages get killed. This makes the refill and the defence the same button.
--
-- What it gives up is depth -- it focuses for less than a plain staff, so a mage using it purely as a
-- mana engine is running behind. It is worth carrying when the enemy has magic in it and worth trading
-- away when they do not, which is the read the whole shelf is built around.
--
-- The barrier answers ONE magical attack and does nothing about a sword, so it does not solve being
-- charged. What it solves is the counter-battery duel.
return {
    name = "Warding Staff",
    description = "Replaces Wait with Focus: recover mana, and raise a ward that negates the next spell aimed at you.",
    flavor = "The Arcanum's second lesson about mana is that you have to stop to get it back. This is the third lesson.",
    sprite = "assets/items/warding_staff.png",
    type = "weapon",
    tags = { "staff", "magical", "melee" },
    class = "mage",
    price = 560,
    repRank = 4,
    -- Shallower than a plain staff's 8-18: the ward is paid for out of the meditation's own depth.
    -- `status` is applied to the focuser on every Focus (Combat.focus).
    waitBehavior = {
        kind = "focus",
        mana = { 6, 7, 7, 8, 9, 9, 10, 11, 12, 12, 13 },
        speed = 10,
        status = "status_magical_barrier",
    },
    activeAbility = {
        target = "enemy",
        range = 1, -- adjacent only: a staff is not a wand
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, -- feeble, as every staff's strike is
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
