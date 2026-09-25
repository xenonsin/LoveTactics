-- The vessel Luxuria's rule rides on (data/characters/character_general_lust.lua). A blueprint's own
-- `traits` field is never collected -- only an item's is (models/trait.lua) -- so a general's rule is a
-- piece in her grid, bound to her and never dropped.
--
-- Two rules, and together they are "an army of charmed followers that protect her":
--   * THE COURT (trait_the_court) -- she holds every humanoid on her side and each newcomer, they are
--     sworn to take her blows, and she may hold one of the company at a time (two below half health),
--     the first of whom is her Consort.
--   * THE CONGREGATION (trait_the_congregation) -- what does reach her is split across everyone she
--     holds. Settled on review ("have damage go to all charmed" -> "split among them"): it is the
--     Abbess's rule, which her line already teaches, worn by the one it was always pointing at.
--
-- Sunder silences both at once (Trait.flag), which is the same second key the Lady Chapel hands out.
return {
    name = "The Court",
    description = "Holds every allied humanoid, who take your blows. Damage dealt to you is split among "
        .. "the bodies you have Charmed.",
    flavor = "Nobody at her court was ever asked to kneel. They only ever found they already had.",
    sprite = "assets/items/utility_the_court.png",
    type = "utility",
    class = "creature",
    tags = { "charm", "dark" },
    noSteal = true,
    traits = { "trait_the_court", "trait_the_congregation" },
}
