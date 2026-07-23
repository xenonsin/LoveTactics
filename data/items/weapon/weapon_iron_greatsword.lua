-- A two-handed greatsword: an overhead blow so heavy it must be WOUND UP before it lands. The wielder
-- raises the blade for a turn (channel), then brings it down on the aimed tile for damage nothing else
-- in the melee kit matches. Like the Crimson Greataxe it is aimed at an adjacent tile (a facing), but
-- where the axe cleaves a 3-wide arc for less, the greatsword pours everything into ONE cell -- and pays
-- for it in the wind-up, during which the target has a turn to step out of the blow (the strike reads the
-- live board, so a foe that walks clear simply isn't there when the sword falls).
--
-- Two-handed, so Dual Wield can pair it only once forged to +5. A fighter's capstone weapon.
return {
    name = "Iron Greatsword",
    description = "Winds up a turn, then falls on one tile for devastating damage.",
    flavor = "The turn you spend raising it is the turn everyone else spends deciding where to stand.",
    sprite = "assets/items/greatsword.png",
    type = "weapon",
    -- Its own archetype, NOT the sword family (docs/weapons.md): a greatsword's verb is the wind-up,
    -- and it must not inherit the sword's Parry -- a two-handed capstone does not also counter.
    tags = { "greatsword", "slash", "physical", "melee" },
    hands = 2,
    class = "fighter",
    -- Rank 1: every family's base weapon is stocked from the first visit (docs/weapons.md), and the
    -- greatsword's is no exception -- what gates it is the purse, not the standing. Dear for a rank-1
    -- (five times an iron sword) because the heaviest hit in the game should be an early thing you save
    -- toward rather than an early thing you are handed.
    price = 300,
    repRank = 1,
    activeAbility = {
        target = "tile",       -- aim an adjacent tile: it sets the facing the blow falls on
        allowOccupied = true,  -- the tile in front may hold a foe -- it's where the sword lands
        range = 1,
        minRange = 1,          -- must pick a neighbor (a facing); never the wielder's own tile
        speed = 7,             -- ponderous: you pay for the damage in turn order
        channel = 2,           -- winds up two ticks before it lands; hard control breaks the wind-up
        cost = { stat = "stamina", amount = 16 },
        damage = { 24, 27, 29, 32, 34, 37, 39, 42, 44, 47, 50 },
        effect = function(fx)
            -- Single target: whatever stands on the aimed tile when the blow finally falls.
            if fx.target then fx.damage(fx.target) end
        end,
    },
}
