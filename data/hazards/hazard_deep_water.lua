-- Deep water: the black channel, and the only ground in the game that kills outright.
--
-- IT IS THE GROUND, NOT A SPELL. models/arena.lua stands one of these on every `deep` tile a board
-- lays (Arena.TERRAIN_ZONES), so this is the drowning half of a terrain type rather than anything
-- anybody casts -- which is why its duration is quoted at 9999 by the caller: a channel does not
-- expire. Nothing in the game places it by hand and nothing should.
--
-- WHY THE DEATH LIVES HERE AND NOT IN models/terrain.lua. Ground that heals and ground that bogs are
-- both hazards in this codebase, and have been since long before the fort existed -- one word per
-- mechanic. A `kills = true` key on the terrain row would have had to be taught separately to the turn
-- loop, the enemy planner and the field shader; a zone is read by all three already. `disposition`
-- alone is worth the file: Hazard.tileBias makes every AI on the board route around this without a
-- line of pathing code being written.
--
-- WHO EVER ENTERS IT. Two bodies, and the shape of the whole feature is in that list:
--
--   * a SWIMMER, which is what this refuses to touch -- Combat.isAquatic, off the `swim` tag a naga's
--     coils carry and the Gillscale Wrap grants. For them the channel is a road.
--   * a body that was PUT here. `deep` is walkable = false, so nothing can walk in; what reaches this
--     onEnter is a shove, a throw or a pull, through the one exception footprintCanShift carries. That
--     is the entire design: deep water is a threat somebody else delivers.
--
-- A FLIER IS OVER THE WATER, NOT IN IT, and takes nothing -- docs/terrain.md's own rule held in both
-- directions. A flier already forfeits the forest's cover and the hill's reach for the same reason;
-- this is the half of that bargain that pays.
--
-- Combat.drown is the verb rather than a large number through ctx.damage, and the difference is the
-- one thing a player would notice: drowning SEALS. No incapacitated window, no hourglass, no corpse on
-- the water for a necromancer to read -- a window is a promise somebody can reach the body, and
-- nobody can reach this one. A party casualty still walks home after the win
-- (Combat.reviveFallenParty reads the `sank` flag), so this costs the fight and the trip, never the
-- character. That is docs/the-count.md's law, and it is not negotiable for a piece of terrain.
return {
    name = "Deep Water",
    description = "Drowns anything that cannot swim.",
    tags = { "water" },
    duration = 9999,          -- the ground does not expire; the caller quotes this too
    disposition = "hostile",  -- the enemy planner routes around it without being told twice
    onEnter = function(ctx)
        ctx.drown(ctx.unit)
    end,
}
