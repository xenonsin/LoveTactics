-- Ancestor Mask: the hunter half of the Shaman (hunter x mage). Nothing you summon takes damage from
-- ground -- fire, acid, quicksand, whatever is authored next.
--
-- The item that makes the Shaman one build instead of two. The mage half calls spirits and reserves
-- mana to hold them; the hunter half's whole vocabulary is ground -- hazards, traps, weather. Those two
-- halves were actively fighting: every zone the shaman laid was eating the spirits it had just paid a
-- fifth of its mana for. This is the treaty.
--
-- Damage only, never statuses. A spirit in a Gagging Storm is still Silenced and one in quicksand is
-- still Mired, so where the spirits stand is still a question -- just no longer a lethal one. "The
-- weather does not burn its own" is a narrower and better claim than "the weather does not touch its
-- own".
--
-- Written against `summoned` generally, so it shelters a Beastmaster's wolf and a Necromancer's dead as
-- readily as a wind spirit. The `discipline` field names the Lodge as its home; nothing in its behaviour
-- knows or cares.
return {
    name = "Ancestor Mask",
    description = "Summoned creatures take no damage from hazards.",
    flavor = "The dead of this field do not mind the weather on it. It has been theirs a long time.",
    sprite = "assets/items/utility_ancestor_mask.png",
    type = "utility",
    tags = { "charm", "spirit" },
    class = "hunter",
    discipline = "shaman",
    price = 380,
    unlockQuests = 5,
    traits = { "trait_ancestor_mask" },
}
