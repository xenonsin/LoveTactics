-- The Griffin's temper: it carries Answers Every Blow (data/traits/trait_answers_every_blow.lua), Heroes of
-- Might and Magic's unlimited retaliation, and Mated for Life (data/traits/trait_mated_for_life.lua), the
-- pair's grief as hunger. Natural kit.
return {
    name = "Griffin's Temper",
    description = "Bites back at every melee blow for half its damage. Eats its fallen mate and is Gorged.",
    flavor = "There is always another griffin. It is always the one you did not kill.",
    sprite = "assets/items/utility_griffin_temper.png",
    type = "utility",
    class = "creature",
    tags = { "natural", "beast" },
    noSteal = true,
    traits = { "trait_answers_every_blow", "trait_mated_for_life" },
}
