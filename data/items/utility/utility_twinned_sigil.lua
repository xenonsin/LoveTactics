-- The Twinned Sigil: a single-target working beside it in the 3x3 grid forks, and lands on one more
-- body standing next to the one it was aimed at (Combat.twinTarget).
--
-- One of the five sigils; see data/items/utility/utility_distant_sigil.lua for the family.
--
-- SINGLE-TARGET ONLY, and that restraint is the whole item. A twinned Fireball would be two Fireballs
-- and this would be the only charm anybody bought; a twinned Jolt is a bolt that FORKS, which is a
-- different and much better thing to own. It gates on Combat.isSingleTarget -- the same predicate the
-- counter rules read to tell a blow aimed at somebody from a blast thrown at ground -- so "is this
-- aimed at one body" has exactly one answer in the codebase and this cannot drift out of step with it.
--
-- The fork is found on the board rather than aimed: the nearest enemy orthogonally beside the target,
-- and nothing if there isn't one. You do not get to choose where the second one lands, because the
-- sigil COPIES a working rather than casting it -- which turns the mage's targeting question upside
-- down. Ordinarily you pick the most dangerous foe; with this in the grid you start picking the foe
-- with a friend standing next to it, and the enemy's formation becomes your damage stat.
--
-- The fork re-enters the very same fx.damage the first hit went through, so it carries everything the
-- original carried -- the aura's granted tags, its on-hit status, its lifesteal. A twinned, envenomed,
-- fire-stoned bolt poisons and burns both bodies. It cannot fork again (one twin, never a chain).
return {
    name = "Twinned Sigil",
    description = "Adjacent single-target magic also strikes one foe beside its target.",
    flavor = "Two is not twice as hard as one. That is the part the Arcanum finds indecent.",
    sprite = "assets/items/utility_twinned_sigil.png",
    type = "utility",
    tags = { "arcane", "sigil" },
    class = "mage",
    price = 480,
    repRank = 3,
    aura = {
        appliesTo = { "ability", "weapon" },
        requiresTags = { "magical" },
        twin = true, -- a single-target neighbour forks into a second body
    },
}
