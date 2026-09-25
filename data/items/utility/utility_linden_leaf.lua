-- The Linden Leaf: Siegfried bathed in the dragon's blood and it turned his skin to horn -- except where a
-- linden leaf had stuck between his shoulders. Off the Gilt Wyrm (data/characters/character_gilt_wyrm.lua),
-- reviewed 2026-09-25.
--
-- Hide against all three physical tags, and one of them, rolled at the bell, left open: the bearer wears
-- that tag's Vulnerable badge for the whole fight (data/traits/trait_linden_leaf.lua), so the weak spot is
-- on the board where both sides can read it. Near-proof, with one known way in.
return {
    name = "The Linden Leaf",
    description = "Resist slashing, piercing and impact hits. One of the three, chosen as a fight starts, leaves you Vulnerable.",
    flavor = "Every inch of him was proof against steel but one, and the whole story is about which inch.",
    sprite = "assets/items/utility_linden_leaf.png",
    type = "utility",
    class = "bulwark",
    unlockLevel = 6,
    unstocked = true,
    resist = { slash = 3, pierce = 3, impact = 3 },
    traits = { "trait_linden_leaf" },
}
