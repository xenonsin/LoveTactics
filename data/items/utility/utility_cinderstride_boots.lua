-- Cinderstride Boots: the ground burns BEHIND the wearer. Every tile it steps off is left holding Fire
-- (data/hazards/hazard_fire.lua) -- the mage's own blaze, not a lesser imitation of it.
--
-- Nothing here needs to make anybody fireproof, and that is the point of it. Every trail in the game is
-- laid behind (Combat.layTrail), so the wearer is simply never standing on what it lays: it stays one
-- step ahead of its own flames. The alternatives were a sided fire that is not really fire, or a flat
-- immunity bolted onto the wearer; instead the fire it leaves is ordinary, unsided, unmodified fire and
-- the wearer's safety is nothing but where it happens to be.
--
-- What follows from using the real hazard rather than a tame copy:
--   * it burns ALLIES, and the wearer too if it ever doubles back. Retreat down a corridor and it
--     closes behind you; walk back up it and you pay what everyone else pays. There is no protection
--     here, only position.
--   * it SPREADS into burnable terrain, so a walk through forest sets the wood alight well past the
--     tiles actually touched -- and can catch up with the wearer from the side. These boots are worn
--     going somewhere, not standing somewhere.
--   * it is DOUSED by water, so an enemy Rain answers the whole trail in one turn.
--
-- The mage's shelf remakes the ground rather than hitting what stands on it (docs/classes.md), and
-- since the enemy AI steps around fire (`disposition = "hostile"`) this is less a damage item than a
-- wall the wearer draws by walking away.
--
-- The trail is deliberately shorter-lived than a cast Fire (8 ticks against 15), on the Pilgrim's
-- Sandals' rule: a spell that spends a turn to set one patch alight must outlast prints that cost
-- nothing at all.
return {
    name = "Cinderstride Boots",
    description = "The tile you step off bursts into flame. The fire is real -- do not walk back through it.",
    flavor = "The Collegium files them under 'walking hazard' and means it in both senses.",
    sprite = "assets/items/cinderstride_boots.png",
    type = "utility",
    tags = { "boots", "fire" },
    class = "mage",
    price = 600,
    repRank = 3,
    trail = { hazard = "hazard_fire", duration = 8 },
}
