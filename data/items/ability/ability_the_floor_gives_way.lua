-- THE FLOOR GIVES WAY: a bombardier's trophy off the Hollow Crown (slice D). Hides a mine on a tile
-- (data/traps/the_floor_gives_way.lua): the first foe to step on it falls through -- heavy damage, and Rooted.
--
-- THE BEAR TRAP IS ITS COUSIN (ability_bear_trap, a trapper's: bite and Root). Checked on the review's ask: the
-- trapper's stock has no mine, and the bear trap is the one piece that already pairs a wound with a Root. This one is
-- the deep version on the Crucible's rack -- twice the bite, impact, paid in mana as the Blast Charge is.
return {
    name = "The Floor Gives Way",
    description = "Hide a mine on a tile. The first foe to step on it falls through: heavy damage, and Rooted.",
    flavor = "The Crown took the board's edge a ring at a time. You only need the one tile.",
    sprite = "assets/items/ability_the_floor_gives_way.png",
    type = "ability",
    tags = { "trap", "impact" },
    class = "bombardier",
    unlockLevel = 15,
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            -- The forged hole bites deeper: base 24, +2 per upgrade level. The Root does not scale.
            fx.placeTrap(fx.tx, fx.ty, "the_floor_gives_way", { amount = 24 + 2 * fx.level })
        end,
    },
}
