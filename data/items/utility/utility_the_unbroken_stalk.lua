-- THE UNBROKEN STALK: the Longfang's hunt, worn by a person -- the same trait she carries
-- (data/traits/trait_the_unbroken_stalk.lua). A blow struck while you are Invisible that downs its target
-- keeps you Invisible, into your next turn. The Longfang's only drop.
--
-- ON THE ASSASSIN'S SHELF beside the Stalker's Mantle: the mantle pays for the first blow out of hiding,
-- and this lets a finishing blow stay there.
return {
    name = "The Unbroken Stalk",
    description = "A blow struck while Invisible that downs its target keeps you Invisible, into your next turn.",
    flavor = "The trick is to be somewhere else by the time anybody thinks to look.",
    sprite = "assets/items/utility_the_unbroken_stalk.png",
    type = "utility",
    tags = { "illusion" },
    class = "assassin",
    unlockLevel = 3,
    unstocked = true,
    traits = { "trait_the_unbroken_stalk" },
}
