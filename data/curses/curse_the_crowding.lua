-- THE CROWDING: the bearer cannot fight with something in their face.
--
-- `rules.contactPenalty = 4`, subtracted from the whole swing whenever an enemy is within arm's reach
-- (Combat's outgoing-blow path, where The Far Mark's own contact charge lands). Four against a reference
-- blow of about nine is a little under half the hit, which is enough to make a melee body genuinely bad
-- at melee without making it useless at everything.
--
-- THE EXACT MIRROR OF THE SHORTENED ARM, and the pair is why either is interesting. That one spares the
-- knight and guts the archer; this one spares the archer and is only ever about the knight. Between them
-- the rift can hex any body in a way that body actually feels, and neither is the flat "you are worse
-- now" that a stat penalty would have been.
--
-- DOES NOT BIND, because this is the one a player can answer by PLAYING rather than by paying: back out
-- of contact, shoot from the second rank, let somebody else hold the line. A hex with a tactical answer
-- should not also be nailed on.
return {
    name = "The Crowding",
    description = "The bearer's blows land 4 softer with any enemy in arm's reach.",
    depth = 4,
    fee = 150,
    rules = { contactPenalty = 4 },
}
