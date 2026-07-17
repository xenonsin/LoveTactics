-- Call a wolf to fight beside you. A tile-target ability (Combat.useItem hands the clicked, empty,
-- in-range cell to the effect as fx.tx / fx.ty), which fx.summon turns into a real unit: it joins
-- the turn order, obeys the player, and carries the wolf blueprint's own fangs.
--
-- The wolf is paid for AND sustained: `reserve` spends a quarter of the summoner's maximum mana on
-- the cast (so the archer must hold that much to call it at all) and keeps it locked away for as
-- long as the wolf lives -- the lock lowers the ceiling the archer's mana may regenerate back to,
-- never the max itself. The ceiling is restored when the wolf falls (or when the summoner does).
--
-- The item's UPGRADE LEVEL scales the creature through `scaling`: `amount` is the base 10 plus the
-- forged level (fx.level), and each `scaling` entry is added on top of the blueprint's base (health +2
-- per point, damage +0.5 per point), so a more-forged horn calls a stronger wolf.
--
-- One wolf at a time: the ability is refused while the last one it called still stands (the rule is
-- automatic for anything that summons -- see Combat.activeSummon).
--
-- The wolf has no `duration`, so it is called for good: it stands until something kills it, or until
-- the archer sustaining it falls. Compare ability_summon_fire_elemental.lua, whose binding lapses on
-- a timer -- the same reservation buys a permanent body here and a temporary one there.
return {
    name = "Summon Wolf",
    description = "Calls a wolf to your side. One at a time; reserves a quarter of your max mana while it lives.",
    flavor = "Called for good, not bound for a while. It stands until something takes it down.",
    sprite = "assets/items/ability_summon_wolf.png",
    type = "ability",
    tags = { "summon", "beast" },
    class = "hunter",
    price = 420,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 1,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        effect = function(fx)
            fx.summon("character_wolf_grunt", fx.tx, fx.ty, {
                scaling = { health = 2, damage = 0.5 },
                amount = 10 + fx.level, -- base 10, +1 per upgrade level
            })
        end,
    },
}
