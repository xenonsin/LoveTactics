-- THE DEAD HAND: Vesh's, and the name the legal term already had for it -- property held forever by
-- something that cannot die. Each dark blow you land takes 5 mana out of the target into your own pool
-- (trait_the_dead_hand). A caster's Greed: it works on every floor with a body that keeps a pool.
return {
    name = "The Dead Hand",
    description = "Your dark hits take 5 mana from the target into your own pool.",
    flavor = "A glove with nothing in it, which closes anyway.",
    sprite = "assets/items/utility_the_dead_hand.png",
    type = "utility",
    tags = { "dark" },
    class = "mage",
    unlockLevel = 5,
    unstocked = true,
    traits = { "trait_the_dead_hand" },
}
