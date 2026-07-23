-- Powder Keg: the alchemist rolls a barrel out onto a tile and walks away from it.
--
-- It places the SAME object the map generator scatters (data/props/prop_explosive_barrel.lua) rather
-- than a private copy of one, which is the entire design: everything the party has already learned
-- about barrels on a castle board -- one hit sets them off, the blast takes friend and foe alike at
-- radius 1, they chain into each other, they can be heaved -- is true of this one too, and none of it
-- had to be re-taught or re-tuned. An alchemist on a board that HAS barrels is simply an alchemist who
-- can put one where there wasn't one.
--
-- That makes it a slow, deliberate weapon rather than a nuke: the keg does nothing on the turn it is
-- set down. Somebody has to hit it -- an arrow, a spell, a shove into it, a Heave that carries it into
-- a crowd -- so it is a threat you PLANT and then spend a second action, or an enemy's own advance, to
-- cash. The alchemist's whole class reads that way (docs/classes.md: the Bombardier, who covets other
-- people's power rather than casting any): this ability's damage number is not on this file at all. It
-- is on the barrel.
--
-- Aimed at empty ground (no `allowOccupied`): a keg needs a tile to stand on, and Prop.place refuses an
-- occupied one anyway -- so the standard tile-target rule keeps the player from wasting a turn finding
-- that out. Range 3 keeps the alchemist honest about how close they have to get.
--
-- Upgrade level scales the blast the keg carries (prop.amount), exactly as a forged Spike Trap stabs
-- harder: 16 base, +2 per level.
return {
    name = "Powder Keg",
    description = "Sets down an explosive barrel. Anything that hits it sets off a blast around it.",
    flavor = "Envy's arithmetic: I need not be strong where I can leave something strong behind me.",
    sprite = "assets/items/ability_detonate.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "fire", "explosive" },
    class = "alchemist",
    price = 240,
    repRank = 2,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 5,
        cost = { stat = "mana", amount = 12 },
        support = true, -- placing an object, not a strike: it reads green and lands no damage itself
        effect = function(fx)
            fx.placeProp(fx.tx, fx.ty, "prop_explosive_barrel", { amount = 16 + 2 * fx.level })
        end,
    },
}
