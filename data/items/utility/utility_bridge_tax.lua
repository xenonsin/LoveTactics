-- BRIDGE TAX: the Toll-Troll's drop, on the Mammonite's shelf. Approved 2026-10-04 ("Sloth's Bestiary", slice B).
--
-- The Toll, narrowed for a person: abilities only, 2 tiles out, and billed a swing's stamina like any other answer
-- (data/traits/trait_bridge_tax.lua). A Mammonite's because it is a price levied for standing near you.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Bridge Tax",
    description = "A foe that uses an ability within 2 of you is struck first.",
    flavor = "Collected in advance, on the principle that nobody pays after.",
    sprite = "assets/items/utility_bridge_tax.png",
    type = "utility",
    tags = { "charm" },
    class = "mammonite",
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_bridge_tax" },
}
