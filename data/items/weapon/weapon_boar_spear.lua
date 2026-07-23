-- A spear, so it skewers a line (docs/weapons.md): the two tiles directly in front. Its extra is the
-- crossbar -- the thing an actual boar spear has, and the reason it has it: whatever is on the NEAR tile
-- is Rooted (status_root) and cannot back off the point.
--
-- The entry alternative to the plain iron spear, and the answer to the polearm's real problem. Reach is
-- the spear's whole argument, and reach is worth nothing against something that closes to your chest or
-- steps out of the line entirely. This pins the near body where the line already runs, so the second
-- tile stays behind the first and the second thrust hits the same two people.
--
-- Only the near tile, deliberately -- the far one is untouched. The crossbar stops what has run onto the
-- point; it does nothing about the man behind him, and a spear that rooted its whole line would be a
-- board-control weapon at rank 2.
return {
    name = "Boar Spear",
    description = "Skewers the two tiles ahead, and roots whatever is on the near one in place.",
    flavor = "The crossbar is not there to hurt the boar. It is there so the boar stays at the far end of the spear.",
    sprite = "assets/items/boar_spear.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    hands = 2, -- a two-handed polearm, as every spear is
    class = "knight",
    price = 180,
    repRank = 2,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = { 5, 6, 6, 7, 7, 8, 9, 9, 10, 10, 11 }, -- a shade under an iron spear's: the bar is the rest
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                -- The near tile IS the aimed cell -- a `line` footprint runs away from the wielder
                -- starting there -- so the crossbar needs no geometry of its own.
                if u.alive and u.x == fx.tx and u.y == fx.ty then
                    fx.applyStatus(u, "status_root")
                end
            end
        end,
    },
}
