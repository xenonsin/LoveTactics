-- Reprisal: the fighter half of the Champion (fighter x knight). A charm that turns the wearer's guard
-- into a scything answer -- trait_whirl_answer: struck in melee, the wearer turns all the way round with
-- the blade out and EVERY adjacent foe takes it, not just the one who swung. Its worth is the number of
-- bodies around you, so being swarmed is what pays -- the Champion's Riposte-wall from the defensive
-- side, wrath's inversion of "surrounded" into "surrounded by targets".
--
-- A utility, not an ability: a counter is a reflex, and reflexes attach to grid items, never to an
-- active cast (docs/classes.md, traits-attach-via-items). The Provoke ability sets the wall up; this
-- makes the wall bite.
return {
    name = "Reprisal",
    description = "When struck in melee, you counter EVERY adjacent foe at once -- the more around you, the more it hurts.",
    flavor = "One of them swung. That was, on reflection, a decision that concerned all of them.",
    sprite = "assets/items/utility_reprisal.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    discipline = "champion", -- fighter x knight; the Riposte-wall mechanic's first stock
    price = 400,
    repRank = 3,
    traits = { "trait_whirl_answer" },
}
