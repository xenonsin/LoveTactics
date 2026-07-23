-- A staff, so it swaps Wait into Focus (docs/weapons.md). Its extra is that the meditation is paid for in
-- BLOOD: it returns roughly twice what a plain staff does, and takes health for it every time.
--
-- Quest-only: `class` with no `price`.
--
-- The whole staff family exists because a caster's real constraint is mana and the only way to get it
-- back is to spend a turn doing nothing else. This does not fix that -- it changes what the turn costs.
-- A mage using it stops running out of mana and starts running out of health, which is a completely
-- different fight to manage and puts the priest to work.
--
-- What makes it a decision rather than a strict upgrade is that health is the one resource in this game
-- with no floor beneath it. Mana running out costs you a turn; health running out costs you the
-- character. So the staff is at its best in the hands of somebody with a healer behind them and at its
-- worst in a party that is already losing -- which is exactly when a mage most wants to Focus twice in a
-- row.
--
-- The toll is a DRAIN rather than damage (see `waitBehavior.toll` in Combat.focus): nothing mitigates it,
-- nothing reflects it, no barrier eats it, and it cannot kill -- it floors at zero. A mage can meditate
-- itself to the edge and not over it, which is the one mercy the design allows.
return {
    name = "The Overchannelled Staff",
    description = "Replaces Wait with Focus: recover far more mana than any staff, and pay for it in your own blood.",
    flavor = "The Arcanum has never banned it. The Arcanum has simply never had to replace one.",
    sprite = "assets/items/overchannelled_staff.png",
    type = "weapon",
    tags = { "staff", "magical", "arcane", "melee" },
    class = "mage",
    waitBehavior = {
        kind = "focus",
        -- Roughly double a plain staff's 8-18, which is the sale.
        mana = { 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36 },
        speed = 10,
        -- ...and the price, flat rather than scaling. Deliberate: the mana climbs with the forge and the
        -- toll does not, so an upgraded staff is a BETTER bargain rather than a bigger gamble. The
        -- decision the weapon asks should get easier to make correctly, never harder.
        toll = { stat = "health", amount = 8 },
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
