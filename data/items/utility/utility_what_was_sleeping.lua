-- WHAT WAS SLEEPING: the Thing Under the Seam's rules, carried in the centre of its grid as creature kit (a
-- body's machinery, not for sale -- the Hoard's pattern, data/items/utility/utility_the_hoard.lua).
-- Approved on review 2026-09-26.
--
--   the trail           WHERE IT WALKS, THE FLOOR BURNS. Every tile it steps off is left holding Fire
--                       (hazard_fire) for three turns -- the Cinderstride Boots' trail, laid across the
--                       whole footprint it vacates, so a 2x2 body stepping once leaves two tiles alight.
--                       Laid behind, never underfoot (Combat.layTrail).
--   trait_emberwalk     and its own fire does not touch it: fire ground neither Burns it nor turns its
--                       planner aside, so it walks back through its own trail as if it were floor.
--   trait_boss_phases   AT HALF HEALTH THE FLOOR FALLS AWAY, once. Every tile exactly two from its body
--                       becomes a pit of fire (Combat.openChasm): the cave's own impassable, sight-clear
--                       lava, so it stands on an island that range and reach still cross and no foot does.
--                       A body standing on the ring drops one tile to the inside edge rather than dying.
--                       Read off its own bar, so a stun does not keep the floor up (`notAReaction`), and
--                       it lands on the blow that crosses the line.
--
-- Bound: it is what the thing is.
return {
    name = "What Was Sleeping",
    description = "Every tile it steps off burns for 3 turns; fire does not touch it. At half health, the floor 2 tiles out falls away.",
    flavor = "The seam was the richest they had ever struck. It was warm, too, and they took that for a good sign.",
    sprite = "assets/items/utility_what_was_sleeping.png",
    type = "utility",
    tags = { "relic" },
    class = "creature",
    noSteal = true,
    bound = true,
    -- Three turns at Status.TICKS_PER_TURN, the approved figure -- a cast Fire's own fifteen ticks, where
    -- the boots' eight are a footprint's.
    trail = { hazard = "hazard_fire", duration = 15 },
    traits = { "trait_emberwalk", "trait_boss_phases" },
    phases = {
        { at = 0.50, responses = {
            { kind = "chasm", gap = 2 },
            { kind = "log", text = "The floor falls away round the thing under the seam, into the fire below." },
        } },
    },
}
