-- The Burning Halo: a ring of white fire that hangs a foot off its bearer's shoulders. Enemies
-- standing in it burn, and cannot see far enough to shoot (data/hazards/hazard_burning_halo.lua).
--
-- Two effects, chosen to answer each other's weakness, which is the reason this is one item and not
-- two. Burn is a CLOCK: it pays out whether or not the wearer does anything, so the halo is worth
-- carrying by a character who spends their turns walking rather than swinging. Blind is a REACH cut
-- (Status.rangeMalus shortens every ability a victim owns, floored at 1), so the archers and casters
-- caught in the ring have to step out before they can work at all.
--
-- Which is what makes it a front-line item rather than a damage item: the burn asks its wearer to
-- stand in the enemy's line, and the blindness is what makes standing there survivable, because
-- everything that would shoot them has to leave first. It is a shove that shoves nobody.
--
-- IT DOES NOT BURN ALLIES, unlike most fire in this game -- the zone is sided. That is a real
-- concession and it is made on purpose: an unsided burning aura would be unwearable in a formation,
-- and the whole item is about being in one.
--
-- Rain puts it out. The halo is fire, and fire in this game answers to water wherever it is standing
-- (dousedByTags on the hazard) -- so an enemy mage with a rain cloud simply turns this item off for a
-- few turns, which is the counterplay and costs them a cast to use.
return {
    name = "The Burning Halo",
    description = "Enemies beside its bearer burn, and cannot see far enough to shoot.",
    flavor = "The Cathedral consecrated one, once, and then spent a century explaining that it had not.",
    sprite = "assets/items/utility_burning_halo.png",
    type = "utility",
    tags = { "fire" },
    class = "priest",
    price = 480,
    repRank = 4,
    incense = { hazard = "hazard_burning_halo", radius = 1,
                amount = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 } },
}
