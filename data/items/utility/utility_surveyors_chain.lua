-- The Surveyor's Chain: the bearer makes the ground cheap for everybody ELSE. Any ally stepping
-- through a tile beside the wearer crosses it at the cost of open field, whatever it is made of.
--
-- THE GENUINELY NEW VERB IN THIS CATALOG. Every other movement item in the game changes how its own
-- wearer moves -- flight, phasing, blink, haste, the Trackless Boots beside this on the shelf. Not one
-- of the ~640 items changes how somebody ELSE moves, in any direction, and support has therefore never
-- been able to answer the single most common thing that goes wrong with a party: the column is strung
-- out across broken country and the back half cannot get to the front half in time.
--
-- A body carrying this is a bridge. It stands in the bad ground and the line walks past it.
--
-- HOW IT WORKS: `escortsMovement = 1` is read by Combat.terrainEase from the MOVER's point of view --
-- while pricing a tile for some unit, the engine looks for an ally of that unit standing beside the
-- tile who carries this. So the wearer does not project a zone it maintains; it is simply consulted,
-- by whoever is walking, about the ground it is standing next to. Same cap as the boots (never below
-- open field), same exclusion (it does not ease the tax an enemy's Overwatch lays -- see
-- Combat.watchTax): a surveyor makes country passable, not people harmless.
--
-- Note it does not help the WEARER, who is an ally of everyone but themselves -- the escort read skips
-- the moving body's own grid. That is deliberate and it is the item's whole cost: a Warden who wants
-- to cross the bog easily has to buy the boots too, or stand still and let the company do it. Being
-- the bridge means being the one who is already there.
--
-- WHY THE WARDEN'S. Knight x hunter is the pair that holds ground it does not own -- the escort, the
-- march, the road kept open. A chain is a surveyor's tool and a road-builder's tool, which is what
-- this discipline is for; the knight half stands in it and the hunter half knows which ground needed
-- it. It is also the Warden's answer to the Bastion's Held Ground on the same shelf: one item makes a
-- square expensive for enemies, the other makes it cheap for friends.
return {
    name = "The Surveyor's Chain",
    description = "Allies crossing a tile beside you pay open-field cost for it, whatever the ground is.",
    flavor = "The road was not built. It was measured, loudly, by a man who refused to move until it existed.",
    sprite = "assets/items/surveyors_chain.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    discipline = "warden", -- multiclass: stocked on the hunter's shelf too once the gate is cleared
    price = 420,
    unlockQuests = 8,
    -- Flat, like the boots': 1 is open field and a cap has nowhere below it to grow.
    escortsMovement = 1,
}
