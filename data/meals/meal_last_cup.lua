-- The gambler's order. A modest ceiling raise, and Heroics -- which does nothing at all until a member
-- is down past half, and then does a great deal (data/traits/trait_meal_heroics.lua).
--
-- Monster Hunter's Felyne Heroics is the skill everyone has a story about, and the stories are always
-- the same shape: it turned the worst minute of the hunt into the best one. That inversion is what is
-- being bought here, and it is why the flat course beside it is deliberately small -- a platter that was
-- also good while things were going well would never be the decision it is meant to be.
--
-- The health raise is not a hedge against the skill, it is part of it: a wider bar means more of the
-- fight is spent in the half where Heroics is live, and more room to survive being there.
return {
    name = "The Last Cup",
    description = "The company fights far harder once it is down past half health.",
    flavor = "Poured after the chairs are up. She will not say who named it, only that she has served it to people who came back.",
    price = 220,
    unlockPrestige = 6,
    maxBonus = { health = 10 },
    skill = "trait_meal_heroics",
}
