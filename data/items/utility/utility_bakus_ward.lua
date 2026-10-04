-- BAKU'S WARD: Baku's trophy (data/characters/character_baku.lua), on the Exorcist's shelf. Approved on "Sloth's
-- Bestiary" (2026-10-04). Allies within 2 cannot be put to Sleep, and each sleep turned away heals the bearer
-- (trait_bakus_ward, through Status.allyWard).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Baku's Ward",
    description = "Allies within 2 cannot be put to Sleep. Each sleep you turn away heals you.",
    flavor = "A tapir carved in camphor wood, hung over the bed. The exorcists hang it over the line.",
    sprite = "assets/items/utility_bakus_ward.png",
    type = "utility",
    tags = { "ward" },
    class = "exorcist",
    unlockLevel = 10,
    unstocked = true,
    traits = { "trait_bakus_ward" },
}
