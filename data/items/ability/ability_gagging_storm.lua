-- The Gagging Storm: a squall of screaming static laid over a patch of ground. Nothing standing in it
-- can spend mana on a working (data/hazards/hazard_gagging_storm.lua).
--
-- Silence as GROUND rather than as a debuff, and that difference is the whole item. A silence cast at a
-- mage is answered by the mage having already cast; a silence laid on the mage's tile is answered only
-- by the mage leaving, which costs them the turn either way. It also catches whoever walks in after --
-- the enemy's second caster, the priest who came to cleanse the first one -- so a well-placed storm
-- taxes a back line rather than a body.
--
-- AND IT INTERRUPTS. Silence carries `interruptsChannel = "mana"`, so a storm dropped on a caster
-- mid-wind-up shatters the working and the mana is gone unrefunded (see Combat.interruptChannel: a
-- broken channel is a fully wasted cast, never a refund). Against an enemy mage winding up something
-- large, this is the cheapest turn in the game.
--
-- Silence rather than Denial, and the line matters: denial refuses the whole craft however it is paid
-- for, which over a zone for several turns would simply delete the enemy caster. Silence gags what is
-- paid in mana and nothing else, so a mage in the storm still swings its enchanted staff. See the two
-- flags' comments in models/status.lua.
--
-- ADJACENCY: a `lightning` item beside it. The storm is static, and the cloud it lays is tagged
-- `conductable` -- so a bolt cast into your own storm arcs through it (Combat.conductLightning). The
-- lightning slot is not just a gate here; it is the combo.
return {
    name = "The Gagging Storm",
    description = "Lays a screaming squall: nothing in it can spend mana, and channels in it shatter.",
    flavor = "The Arcanum's least dignified working, and the one its rivals most resent.",
    sprite = "assets/items/ability_gagging_storm.png",
    type = "ability",
    tags = { "lightning", "magical" },
    class = "mage",
    price = 360,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 5,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 15 },
        support = true, -- lands no damage: reads green, and the AI weighs it as control
        aoe = { radius = 1, shape = "square" },
        requiresAdjacent = { tag = "lightning" },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_gagging_storm", { duration = 12 + fx.level })
            end
        end,
    },
}
