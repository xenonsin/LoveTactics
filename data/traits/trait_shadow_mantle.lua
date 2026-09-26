-- SHROUDED: the Shadow Mantle's rule (data/items/utility/utility_shadow_mantle.lua). Nothing farther than
-- three tiles off can pick the bearer as a target -- an archer or a caster has to come within three to
-- reach them, and a blade was always going to.
--
-- A FLAG, read in one place (Status.concealedAt) and asked by every gate that decides whether a body may
-- be aimed at: Combat.useItem refuses the cast, Combat.abilityTargets leaves the bearer off the list, and
-- the planner measures it from the tile a striker would stand on. So it binds a body the player drives as
-- well as one the AI does, and the planner's answer is to walk in rather than to give up.
--
-- It is Invisible with a range on it, and it keeps Invisible's two limits: LIGHT overrules it (Witchlight,
-- a carried lantern, a bell), and it hides nothing from a blast centred somewhere else -- being caught is
-- not being aimed at.
return {
    name = "Shrouded",
    description = "Cannot be targeted from more than 3 tiles away.",
    concealedBeyond = 3,
}
