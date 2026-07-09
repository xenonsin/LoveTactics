-- Call a wolf to fight beside you. A tile-target ability (Combat.useItem hands the clicked, empty,
-- in-range cell to the effect as fx.tx / fx.ty), which fx.summon turns into a real unit: it joins
-- the turn order, obeys the player, and carries the wolf blueprint's own fangs.
--
-- The wolf isn't paid for, it is SUSTAINED: `reserve` locks a quarter of the summoner's maximum
-- mana away for as long as the wolf lives, and hands it straight back when it falls (or when the
-- summoner does). The lock lowers the ceiling the archer's mana may reach; it never touches the max.
--
-- `power` scales the creature through `scaling`: each entry is added on top of the blueprint's base
-- (health +2 per point, damage +0.5 per point), so a stronger caster fields a stronger wolf.
return {
    name = "Summon Wolf",
    description = "Call a wolf to your side. Reserves a quarter of your maximum mana while it lives.",
    sprite = "assets/items/ability_summon_wolf.png",
    type = "ability",
    tags = { "summon", "beast" },
    activeAbility = {
        name = "Summon Wolf",
        target = "tile",
        range = 1,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        power = 10,
        effect = function(fx)
            fx.summon("wolf_grunt", fx.tx, fx.ty, {
                scaling = { health = 2, damage = 0.5 },
                power = fx.power,
            })
        end,
    },
}
