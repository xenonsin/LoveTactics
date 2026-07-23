-- A spear, so it owes the family's contract (docs/weapons.md): it skewers the two tiles directly in
-- front of the wielder, and the aimed neighbour sets the direction the thrust runs. What it adds over
-- data/items/weapon/weapon_iron_spear.lua is that armour has no say in it, and that the man in the
-- SECOND rank loses his turn.
--
-- Both halves are one idea: a pike is the weapon a wall of armour is answered with. So the thrust is
-- `raw` -- it skips defense and every tag resist (the flag in Combat.mitigatedDamage, the same one
-- data/status/status_bleed.lua and data/items/ability/ability_penetrating_strike.lua use) -- and the
-- far tile is left Halted, ordered off its own turn without being wounded any further.
--
-- Two deliberate borrows, both named here rather than left to look like drift (docs/classes.md):
--   * `raw` is FIGHTER's keyword. It is on the knight's shelf because of what it is spent on: this is
--     not a bigger number, it is the removal of the enemy's biggest one. Wrath pierces armour to kill
--     faster; the Bastion pierces it because a wall that cannot be answered is not a wall, it is a
--     stalemate, and the Bastion's whole trade is deciding where people stand.
--   * `status_halted` is the knight's OWN (docs/classes.md), and the second rank is the honest place
--     for it: the pike goes through the man in front and pins the one behind him, who spends his turn
--     getting off it. He may still walk. He may still answer. He simply may not act -- which is Sloth
--     inflicted rather than suffered, exactly as data/items/ability/ability_shout.lua's cousin is.
--
-- The price of both is the damage curve, which sits under an iron spear's at every level: this weapon
-- is worse than the base one against anything unarmoured, and increasingly better the heavier the line
-- in front of it gets. Against a naked skirmisher it is a bad spear. That is the intended shape.
return {
    name = "Mailpiercer",
    description = "Skewers the two tiles ahead, ignoring armour entirely, and Halts whoever is in the far one.",
    flavor = "The Bastion's answer to a shield wall is not a bigger shield.",
    sprite = "assets/items/mailpiercer.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    hands = 2, -- a two-handed polearm, as every spear is
    class = "knight",
    price = 420,
    repRank = 4,
    activeAbility = {
        target = "tile",       -- the aimed neighbour sets the direction the thrust runs
        allowOccupied = true,
        range = 1,
        minRange = 1,          -- a facing, never the wielder's own tile
        speed = 4,             -- a notch slower than an iron spear: it is driven, not flicked
        cost = { stat = "stamina", amount = 10 },
        -- Under the iron spear's curve at every level, and it lands WHOLE: no defense, no resist. What
        -- the number gives up is what the armour would have taken anyway.
        damage = { 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10 },
        aoe = { shape = "line", length = 2 }, -- the family's two tiles (docs/weapons.md)
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u, { raw = true }) -- armour-piercing: defense and every tag resist are skipped
            end
            -- The second rank. The thrust runs from the wielder through the aimed tile, so one more
            -- step along that same direction is the far end of the line -- and whoever is standing
            -- there is the one the pike has pinned. Nobody there is the common case, and costs nothing.
            local dx, dy = fx.tx - fx.user.x, fx.ty - fx.user.y
            local pinned = fx.unitAt(fx.tx + dx, fx.ty + dy)
            if pinned and pinned.side ~= fx.user.side then
                fx.applyStatus(pinned, "status_halted")
            end
        end,
    },
}
