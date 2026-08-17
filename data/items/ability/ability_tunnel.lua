-- Tunnel: the wyrm form's crossing (data/characters/character_wild_wyrm.lua). It submerges and comes up
-- somewhere else, which is the one axis none of the other three Wild Shapes touch -- the raven flies
-- OVER the board, and this goes under it.
--
-- WHY IT IS A TELEPORT AND NOT A LONG MOVE. A walk of the same distance would still be a walk: it pays
-- terrain, it can be Rooted, and anything standing in the way stops it. Going under the board is the
-- form's whole idea, so the cast has to ignore all three -- fx.teleportUser springs the arrival tile and
-- nothing in between (models/combat.lua's Combat.teleportUnit), which is exactly "whatever was standing
-- there did not matter".
--
-- It also banks `tilesBlinked`, like every teleport, which is worth knowing rather than designing
-- around: a druid carrying somebody else's blink-gated relic would charge it with this. Nothing on
-- Mira's own shelf reads that tally, so for her it is inert.
--
-- The wyrm's movement stat is a modest 4 precisely because this exists. A body that crosses six tiles
-- through the ground for a stamina price should not also walk like a wolf.
--
-- `natural`, `noSteal`, sold by nobody -- creature gear, outside every family roster.
return {
    name = "Tunnel",
    description = "Submerges and surfaces on a tile up to 6 away, passing under anything between.",
    flavor = "It does not go around. Going around is a surface idea.",
    sprite = "assets/items/tunnel.png",
    type = "ability",
    tags = { "natural", "primal", "utility" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        range = 6,
        -- No line of sight: the whole point is that it does not travel the line. A wall between here
        -- and there is a thing to go under, not a thing to see past.
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            fx.teleportUser(fx.tx, fx.ty)
        end,
    },
}
