-- The Stilled Hour: the mage stops time over a patch of ground. Anything standing there may walk and
-- may answer a blow, and may not ACT (data/hazards/hazard_stillness.lua).
--
-- The most expensive thing on the pride shelf, and it deals nothing. What it buys is the enemy's TURN
-- ORDER, which is the most valuable commodity on this board and the one nothing else can touch: every
-- other control in the game takes one body's turn, and this takes a REGION's, for three turns, from
-- whoever is unlucky enough to be standing in it.
--
-- Halted rather than Stunned, which is the whole reason it is castable rather than broken. A stunned
-- region would be a mass execution -- nothing in it could answer, so the party could walk in and kill
-- at leisure. Halted leaves every parry, riposte, thorn and guard standing, so the stillness stops the
-- enemy WORKING without making them safe to touch. The party still has to win the exchange; it just
-- gets to have the exchange on a board where half the enemy cannot cast.
--
-- IT STILLS YOUR OWN PEOPLE. The zone reads nobody's colours, and a mage who drops it over a melee has
-- taken their own knight out of the fight for three turns. The long channel is the mercy: everyone,
-- including the player, gets a turn to look at where the circle is going to be.
--
-- ADJACENCY: an `arcane` neighbour, like the Indrawn Breath -- and for the same reason. There is
-- nothing elemental about stopping an hour, so no coating and no elemental charm can improve it. It
-- asks for craft, and craft is the one thing that competes for grid space with everything else the
-- mage wants.
return {
    name = "The Stilled Hour",
    description = "Stops an hour over a wide patch: nothing standing in it may take an action.",
    flavor = "The Arcanum's masters do not say what it costs. They say it is a matter of record that it can be done.",
    sprite = "assets/items/ability_stilled_hour.png",
    type = "ability",
    tags = { "arcane", "magical" },
    class = "mage",
    price = 600,
    repRank = 4,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 6, -- the slowest cast in the game: an hour costs an hour
        channel = 5,
        cost = { stat = "mana", amount = 30 },
        support = true, -- it deals nothing; the AI weighs it as control rather than as a strike
        aoe = { radius = 1, shape = "square" },
        requiresAdjacent = { tag = "arcane" },
        ai = { priority = "high", act = "cast",
               when = { subject = "any_foe", test = "count_at_least", value = 2 } },
        effect = function(fx)
            -- Painted per cell rather than applied per unit, deliberately: the stillness is GROUND, so
            -- a foe that walks into the circle after the cast is stilled too, and one that walks out is
            -- free the moment it is clear. A status applied to whoever happened to be standing there at
            -- cast time would be a much worse spell wearing the same name -- and would let the enemy AI
            -- ignore it, since it steers around hostile ground but cannot steer around a debuff.
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_stillness", { duration = 15 + fx.level })
            end
        end,
    },
}
