-- SWEETBRIAR: the forest's signature ground, and the one the biome shipped without.
--
-- Every other surface stratum declares a hazard on its blueprint -- the swamp's grasping hollow, the
-- tundra's black ice, the desert's quicksand, the volcanic rifts' fire. Forest, castle and underworld
-- declared none, so three of the seven circles had no ground of their own and read as a tileset rather
-- than as a place.
--
-- CHARM, because that is what this circle is. Lust's whole mechanic is being called out of your line
-- (data/traits/trait_lure.lua) and the `glades` carve is the game's ambush board -- open trails through
-- thick cover, where a body pulled out of formation is a body fighting alone against things it cannot
-- see. A hazard that damaged would be any biome's hazard; one that takes a unit out of your control for
-- a moment is this one's.
--
-- Unsided, like all terrain: it has no owner and no allegiance, so a party routing carelessly through
-- its own briar pays exactly what the enemy pays. That symmetry is the whole difference between ground
-- and a spell.
--
-- Charm is a heavy status to put on the floor, so the duration is the SHORTEST of any terrain hazard --
-- a briar you blunder into costs you a moment, not a fight, and the Chorister standing behind it is what
-- costs you the fight.
return {
    name = "Sweetbriar",
    description = "Inflicts Charm on units standing on it.",
    tags = { "nature" },
    duration = 16,           -- shorter than black ice's 24: Charm is worth more per tick than Cripple
    disposition = "hostile", -- the enemy AI paths around it rather than through
    -- The status takes the body (data/status/status_charm.lua): it stashes the victim's side and
    -- command and moves it onto the charmer's. Ground names no applier, so the victim simply turns on
    -- its own line -- which is the unsided reading above, stated from the other end.
    --
    -- A SHORTER CHARM THAN ANYTHING ELSE INFLICTS. The status runs 10 ticks -- two turns, which is a
    -- fight -- and this ground is authored as a moment (see above). 6 is the smallest number that is
    -- still worth landing: past Status.TICKS_PER_TURN, so the body it takes is certain to get one turn
    -- on the other side rather than shaking the flowers off before it ever acts. It costs the line one
    -- body for one turn, and the Chorister standing behind the briar is what costs it the fight.
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_charm", { duration = 6 })
    end,
}
