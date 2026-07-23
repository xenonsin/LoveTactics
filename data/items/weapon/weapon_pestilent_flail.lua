-- Pestilent Flail: the Plague Knight (knight x alchemist) carries a mace, so it SHOVES like every mace
-- (docs/weapons.md -- the blow drives the target two tiles back). Its EXTRA is Contagion: the head is
-- caked in filth, so the struck body AND everyone adjacent to it is Poisoned (data/status/status_poison
-- .lua). Sloth's displacement fused with envy's rot -- a wall that sickens the line it pushes.
--
-- Home shelf is the Bastion (`class = "knight"`, where a mace belongs and its family reads true); the
-- discipline stocks it on the Crucible's shelf too, and using it grows both knight and alchemist.
return {
    name = "Pestilent Flail",
    description = "Drives a foe back two tiles and Poisons it and everything adjacent to it.",
    flavor = "The Bastion forges the head. The Crucible only ever has to suggest what to pack it with.",
    sprite = "assets/items/weapon_pestilent_flail.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee", "poison" },
    class = "knight",
    discipline = "plague_knight", -- knight x alchemist; the Contagion mechanic's first stock
    price = 280,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = { 8, 9, 10, 10, 11, 12, 13, 14, 14, 15, 16 },
        effect = function(fx)
            fx.damage(fx.target, { knockback = { distance = 2, amount = fx.amount } })
            -- Contagion: the rot spreads to the struck body and everyone packed in around it.
            for _, u in ipairs(fx.unitsNear(fx.target.x, fx.target.y, 1)) do
                if u.alive and u.side ~= fx.user.side then
                    fx.applyStatus(u, "status_poison")
                end
            end
        end,
    },
}
