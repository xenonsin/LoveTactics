-- THE STILL HUNT, as the Larder Mother carries it: the same rule (trait_still_hunt) as the player's drop
-- off her (utility_the_still_hunt), on a creature's unstealable slot. The two share one sprite, which is
-- how the art spec lets two items draw one silhouette -- they are one thing, held by two kinds of hand.
return {
    name = "Waits at the Hub", -- her own name for it: the player's drop is "The Still Hunt", and two items
                              -- sharing a name share a wiki anchor
    description = "Each turn ended without moving adds a stack, up to 3. The next blow consumes them.",
    flavor = "She has not moved since you came into the glade. That is not the good news it sounds like.",
    sprite = "assets/items/utility_the_still_hunt.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    traits = { "trait_still_hunt" },
}
