-- A varnish the Crucible sells by the pot: brushed over everything you carry, it will not let a second
-- hand close on any of it.
--
-- A DELIBERATE BORROW, said out loud as docs/classes.md asks. `steal` is the rogue's keyword and the
-- Undercroft's craft; nothing on this shelf steals. What the Crucible has is the SIN under the craft --
-- envy is wanting the thing in someone else's hand -- and this is that sin turned around and applied to
-- your own possessions. The rogue's answer to a thief would have been a better thief: a knot, a false
-- pocket, guild tradecraft. The alchemist's answer is chemical and dumb and works on anybody, which is
-- why it belongs here and not there. It is the same move the Tempered Gut makes -- the shelf selling
-- the proof rather than the affliction -- one shelf over.
--
-- Not tagged `coating`: that tag means the consumable family you paint onto a weapon for a few swings
-- (consumable_envenom and its kin, `consumesItem`). This is set for the fight and painted on nothing.
--
-- No stats of its own -- the charm family standard (see the Tempered Gut): the cost is the cell. A
-- situational item by design, dead weight against beasts and worth its slot the moment the enemy roster
-- has hands in it.
--
-- Grants trait_jealous_resin, whose one flag Combat.steal reads.
return {
    name = "Jealous Resin",
    description = "Blocks any attempt to steal an item from you.",
    flavor = "Envy taught the Crucible what a thing is worth to the man who does not have it. The pot " ..
        "is what they did with the lesson.",
    sprite = "assets/items/jealous_resin.png",
    type = "utility",
    tags = { "charm", "ward" },
    class = "alchemist",
    unlockQuests = 2,
    dropTier = 2,
    traits = { "trait_jealous_resin" },
    -- a coating that refuses to let go of anything
    bonus = { defense = 2 },
}
