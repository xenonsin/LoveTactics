-- THE LORELEI'S ROCK (data/characters/character_lorelei.lua): what makes her the Siren plus one sentence.
-- She does not move (`noMove`); she sings the Only Voice as well as Longing (trait_only_voice); and her
-- song holds through the first blow each battle (trait_held_note), which is the rock handed over in the
-- Held Note drop. Bound and unstealable: the rock is where she is, not a thing she carries.
return {
    name = "The Lorelei's Rock",
    description = "Cannot move. Her song also carries the Only Voice, and holds through the first blow each battle.",
    flavor = "The boats came to the rock. The rock never once came to the boats.",
    sprite = "assets/items/utility_lorelei_rock.png",
    type = "utility",
    tags = { "relic" },
    class = "creature",
    noSteal = true,
    bound = true,
    rules = { noMove = true },
    traits = { "trait_only_voice", "trait_held_note" },
}
