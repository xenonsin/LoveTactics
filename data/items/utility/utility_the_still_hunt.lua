-- THE STILL HUNT: the Larder Mother's patience, handed over (trait_still_hunt). Hold a post and the next
-- blow lands a quarter of Damage heavier for every turn you held it, up to three. The archer's charm --
-- and the one piece in the spider set that pays for NOT acting. A trophy: never on a counter.
return {
    name = "The Still Hunt",
    description = "Each turn ended without moving adds a stack, up to 3. Your next blow consumes them.",
    flavor = "The Lodge teaches it with a stopwatch and a cold morning. She taught it with a glade.",
    sprite = "assets/items/utility_the_still_hunt.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    unlockLevel = 5,
    unstocked = true,
    traits = { "trait_still_hunt" },
}
