-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Spike Mail's envy twin: melee attackers are Poisoned by the blood they draw (trait_spiteful_ichor),
-- where the fighter's version turns a share of the damage straight back (trait_thorns).
--
-- The difference is the whole reason both exist. Thorns is wrath's answer -- immediate, proportional,
-- and it does nothing to a foe who hits you once and walks away. Poison is envy's: it costs the
-- attacker nothing at the moment of the blow and then takes something from them for the rest of the
-- fight, whether or not they ever come back. One of them punishes the exchange; this one punishes
-- having touched you at all.
--
-- Poison is also a DEBUFF, which the returned damage is not, and that quietly makes the coat a build
-- piece rather than a retaliation: every debuff-count scaler on the rogue's shelf, every Opportunist
-- trigger, and the Crucible's own spoil-the-afflicted vocabulary all read it. A wearer being swarmed
-- is applying the setup for somebody else's payoff, without spending a turn.
--
-- utility_spiteful_ichor is the charm form.
return {
    name = "Ichor Coat",
    description = "Melee attackers are Poisoned by the blood they draw.",
    flavor = "The Crucible's alchemists are asked, at intake, whether they consent to what is already in them.",
    sprite = "assets/items/armor_ichor_coat.png",
    type = "armor",
    tags = { "leather", "poison" },
    class = "alchemist",
    traits = { "trait_spiteful_ichor" },
    bonus = { defense = { 5, 5, 6, 7, 7, 8, 8, 9, 10, 10, 11 } },
    resist = { poison = { 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7 } },
}
