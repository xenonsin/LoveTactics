-- Call a wolf to fight beside you. A tile-target ability (Combat.useItem hands the clicked, empty,
-- in-range cell to the effect as fx.tx / fx.ty), which fx.summon turns into a real unit: it joins
-- the turn order, obeys the player, and carries the wolf blueprint's own fangs.
--
-- The wolf is paid for AND sustained: `reserve` spends a quarter of the summoner's maximum mana on
-- the cast (so the archer must hold that much to call it at all) and keeps it locked away for as
-- long as the wolf lives -- the lock lowers the ceiling the archer's mana may regenerate back to,
-- never the max itself. The ceiling is restored when the wolf falls (or when the summoner does).
--
-- `power` scales the creature through `scaling`: each entry is added on top of the blueprint's base
-- (health +2 per point, damage +0.5 per point), so a stronger caster fields a stronger wolf.
--
-- One wolf at a time: the ability is refused while the last one it called still stands (the rule is
-- automatic for anything that summons -- see Combat.activeSummon).
--
-- The wolf has no `duration`, so it is called for good: it stands until something kills it, or until
-- the archer sustaining it falls. Compare ability_summon_fire_elemental.lua, whose binding lapses on
-- a timer -- the same reservation buys a permanent body here and a temporary one there.
return {
    name = "Summon Wolf",
    description = "Call a wolf to your side, one at a time. Reserves a quarter of your maximum mana while it lives.",
    sprite = "assets/items/ability_summon_wolf.png",
    type = "ability",
    tags = { "summon", "beast" },
    class = "hunter",
    price = 420,
    repRank = 3,
    activeAbility = {
        name = "Summon Wolf",
        target = "tile",
        range = 1,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        power = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 },
        effect = function(fx)
            fx.summon("wolf_grunt", fx.tx, fx.ty, {
                scaling = { health = 2, damage = 0.5 },
                power = fx.power,
            })
        end,
    },
}
