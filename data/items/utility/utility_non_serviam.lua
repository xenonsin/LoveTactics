-- NON SERVIAM: Superbia's rejection, and her wings (reviewed over three rounds, "Pride's Generals"). A debuff a foe
-- lays on her rebounds onto whoever laid it, and nothing from outside her side touches her (trait_non_serviam).
--
-- She is an angel without Incorruptible (`raceGrants = false` on her blueprint): the first of the choir who would
-- not kneel does not refuse what is laid on her, she sends it back. So the race's wings ride here instead --
-- the `flying` tag, which the Fall takes from her (Combat.isFlying reads `grounded`).
--
-- Bound and unstealable: an organ, never kit. Her relic, the Morning Star, is this rule once per turn.
return {
    name = "Non Serviam",
    description = "Foes' debuffs rebound onto whoever laid them, and never touch you. Flies.",
    flavor = "She was asked once. Everything that has happened since is her answer.",
    sprite = "assets/items/utility_non_serviam.png",
    type = "utility",
    tags = { "natural", "flying" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_non_serviam" },
}
