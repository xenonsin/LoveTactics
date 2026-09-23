-- THE BLOODED: the vessel her congregation rides in -- the rite she performed on them, still holding.
--
-- A creature's rule lives on an ITEM in its grid: a blueprint's own `traits` field is never collected
-- (models/trait.lua). See data/traits/trait_the_blooded.lua for what it binds, how many, and why the
-- binding is a real `status_charm` rather than a flag of its own.
--
-- EVERY RUNG OF THE LINE CARRIES IT, which is what makes the line teachable. A lesser succubus arrives
-- holding one of the church's soldiers and nothing else; kill her and he walks out, and a player has
-- learned the whole fight for the price of some chaff. The Abbess arrives holding two AND takes one of
-- yours at the bell AND hides behind all three -- the same sentence, three times louder.
--
-- NOT DROPPED. What it hands over is a body you did not bring, which is a summon rather than a charm
-- and belongs to a different shelf entirely; and it is worthless without the congregation the
-- encounter seats around her. The rift sells the two halves a player can actually use: the kiss
-- (utility_the_offered_place) and the hiding place (utility_the_congregation).
--
-- A creature's kit: no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "The Blooded",
    description = "Opens the fight already holding nearby allied humanoids.",
    flavor = "They took the cup from her hands and they knelt, and every one of them remembers it as the happiest day of their lives.",
    sprite = "assets/items/the_blooded.png",
    type = "utility",
    class = "creature",
    tags = { "natural", "charm", "dark" },
    noSteal = true,
    traits = { "trait_the_blooded" },
}
