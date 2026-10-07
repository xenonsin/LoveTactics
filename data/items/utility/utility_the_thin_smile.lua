-- THE THIN SMILE: the Wasting One's trophy (data/characters/character_wasting_one.lua; "Envy's Bestiary", round 4).
-- The body's own rule pointed outward: every wound a foe takes in the bearer's sight heals the bearer by 2
-- (trait_the_thin_smile). A Plague Knight's, because a knight who is fed by suffering is what that house is.
return {
    name = "The Thin Smile",
    description = "Heal 2 whenever a foe you can see takes a wound.",
    flavor = "It is not a pleasant thing, to feel better every time somebody screams. It is a useful one.",
    sprite = "assets/items/utility_the_thin_smile.png",
    type = "utility",
    tags = { "charm", "dark" },
    class = "plague_knight",
    unlockLevel = 11,
    unstocked = true,
    traits = { "trait_the_thin_smile" },
}
