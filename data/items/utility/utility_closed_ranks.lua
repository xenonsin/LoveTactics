-- CLOSED RANKS: worth more for every shoulder beside yours.
--
-- WAS A RUN RELIC (`relic_rank_and_file`, uncommon tier) until the relic shelf was parked on
-- 2026-09-17; see models/relic.lua's park note for the whole move. The effect is unchanged in kind and
-- RESCOPED: a relic was held by the run and felt by the whole company, and this is worn by one body and
-- felt by that body.
--
-- RENAMED, BECAUSE "Rank and File" IS ALREADY TAKEN and by a thing the player cannot have.
-- `utility_rank_and_file` is Pride's creature kit -- `class = "creature"`, `noSteal`, no price, pinned
-- by tests/pride_circle_spec.lua as "nothing here is for sale" -- and it already carries this trait
-- plus `trait_formation_fighter`. So the gilded suits' version of the rule exists and is unlootable,
-- and this is the player's, which is a separate blueprint rather than a second owner of one file (see
-- the shared-blueprint rule: grep every owner before tagging one).
--
-- THE NAME IS PROVISIONAL and is mine rather than the author's. "Closed Ranks" was picked to keep the
-- formation reading while leaving Pride's own name where it stands; a better one is welcome and costs
-- an id sweep plus this header.
--
-- A TRAIT, which items already carry -- this one needed no new vocabulary at all, only the rescope.
-- `scope = "party"` on the relic meant everybody got the reflex; the item gives it to whoever wears it,
-- and a company that wants the whole line holding it buys the whole line one.
return {
    name = "Closed Ranks",
    description = "Raises damage by 1 for each ally adjacent to you.",
    flavor = "A drill token, stamped with a number that says where in the line its holder stands.",
    sprite = "assets/items/closed_ranks.png",
    type = "utility",
    tags = { "trinket" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that commands from inside the formation this rewards.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "warlord",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: damage per neighbour: enormous in a line, nothing at all out of one.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.90,
    unlockLevel = 10,
    traits = { "trait_close_ranks" },
}
