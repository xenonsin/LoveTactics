-- A two-handed greatsword: an overhead blow so heavy it must be WOUND UP before it lands. The wielder
-- raises the blade for a turn (channel), then brings it down on the aimed tile for damage nothing else
-- in the melee kit matches. Like the Crimson Greataxe it is aimed at an adjacent tile (a facing), but
-- where the axe cleaves a 3-wide arc for less, the greatsword pours everything into ONE cell -- and pays
-- for it in the wind-up, during which the target has a turn to step out of the blow (the strike reads the
-- live board, so a foe that walks clear simply isn't there when the sword falls).
--
-- Two-handed, so Dual Wield can pair it only once forged to +5. A fighter's capstone weapon.
return {
    name = "Greatsword",
    description = "A massive two-handed blade. Winds up a turn, then falls on one tile for devastating damage.",
    sprite = "assets/items/greatsword.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" },
    hands = 2,
    class = "fighter",
    price = 760,
    repRank = 4,
    activeAbility = {
        target = "tile",       -- aim an adjacent tile: it sets the facing the blow falls on
        allowOccupied = true,  -- the tile in front may hold a foe -- it's where the sword lands
        range = 1,
        minRange = 1,          -- must pick a neighbor (a facing); never the wielder's own tile
        speed = 7,             -- ponderous: you pay for the damage in turn order
        channel = 1,           -- winds up one turn before it lands; hard control breaks the wind-up
        cost = { stat = "stamina", amount = 16 },
        damage = { 24, 27, 29, 32, 34, 37, 39, 42, 44, 47, 50 },
        effect = function(fx)
            -- Single target: whatever stands on the aimed tile when the blow finally falls.
            if fx.target then fx.damage(fx.target) end
        end,
    },
}
