-- Red Tithe: the barbarian's Blood Price builder (docs/engines.md). Pay 15% of your health, and your
-- stamina is full again. A price, not a blow: no armour softens it, and it never takes the last point
-- (Engine.payHealth). Paid on your own turn, so it is a self-wound -- it banks Blood for a Sanguine
-- Font, and a Scab gives it back on a kill.
--
-- Stamina is the pool every fighter runs short of, and this turns the one pool a barbarian has a lot of
-- into it. A full refill rather than a fixed amount (the author's call, round 3), so the trade stays
-- worth making at depth where a stamina bar is long.
return {
    name = "Red Tithe",
    description = "Pay 15% of your health. Refills your stamina.",
    flavor = "The Colosseum's oldest price, and the only one it never raised.",
    sprite = "assets/items/ability_red_tithe.png",
    type = "ability",
    tags = { "physical" },
    class = "barbarian",
    price = 240,
    unlockLevel = 7,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2,
        share = 0.15,
        support = true,
        effect = function(fx)
            local stats = fx.user and fx.user.char and fx.user.char.stats or {}
            local hp = type(stats.health) == "table" and stats.health or { max = stats.health or 0 }
            local price = math.max(1, math.floor((hp.max or 0) * (fx.item.activeAbility.share or 0.15)))
            local paid = fx.engine.payHealth(price)
            if paid <= 0 then
                fx.log("action", "There is no blood to spare.")
                return
            end
            local st = stats.stamina
            local missing = (type(st) == "table") and ((st.max or 0) - (st.current or 0)) or 0
            if missing > 0 then fx.restore(fx.user, "stamina", missing) end
        end,
    },
}
