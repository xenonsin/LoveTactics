-- The Pit Grows: a foe that dies within two tiles of the bearer comes back up as a Mandrake of the
-- bearer's -- rooting its old friends, and screaming when they cut it.
--
-- THE ANCHORESS'S RULE, NARROWED TWICE (trait_the_pit_grows, through `traitParams`). Hers grows on any
-- death within three tiles, her own garden's included; this grows only on a FOE's death, and only
-- within two. A company that carries it is a company whose kills keep fighting for a turn or two, which
-- is the most it can be without the enemy's deaths snowballing into a board of turrets.
--
-- `unstocked`: a trophy, off the Anchoress and nowhere else (tests/discovery_spec.lua names it).
return {
    name = "The Pit Grows",
    description = "When a foe dies within 2 tiles of you, a Mandrake of yours sprouts where it fell.",
    flavor = "The register writes them down as ascended. The floor writes them down as seed.",
    sprite = "assets/items/utility_the_pit_grows.png",
    type = "utility",
    tags = { "nature" },
    class = "druid",
    unstocked = true,
    unlockLevel = 9,
    traits = { "trait_the_pit_grows" },
    traitParams = { radius = 2, foesOnly = true },
}
