-- The Tempered Gut: a course of the Crucible's own reagents, taken in doses too small to kill until
-- nothing the Crucible sells can. Mithridatism, which is a real practice and exactly as unpleasant as
-- it sounds. One of the four named immunities (see data/items/utility/utility_deadhand_grip.lua for
-- the family and what the grid slot buys).
--
-- It refuses Poison and Acid -- envy's own two verbs, which docs/classes.md lists as the alchemist's
-- (`poison`/`acid`). That is the joke and also the design: the shelf that sells the affliction sells
-- the proof against it, at rank 3, to the people who have already been on the wrong end of it. The
-- Crucible does not consider this a conflict of interest.
--
-- It is the widest of the four in practice, because between them Poison and Acid cover most of what
-- an alchemical enemy throws -- but note what it does NOT cover: Burn, Bleed, and every hazard on the
-- ground. A vial of liquid fire goes straight through it. The pair is chemical affliction specifically,
-- not "damage over time", and reading it as the latter is how a player wastes a slot.
return {
    name = "Tempered Gut",
    description = "Inured to the Crucible's own: immune to Poison and Acid.",
    flavor = "Taken in doses too small to kill. The Crucible is very precise about how small.",
    sprite = "assets/items/tempered_gut.png",
    type = "utility",
    tags = { "charm" },
    class = "alchemist",
    price = 420,
    repRank = 3,
    statusImmunity = { "status_poison", "status_acid" },
}
