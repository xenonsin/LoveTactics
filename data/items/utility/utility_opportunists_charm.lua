-- Hemophage Charm: the Poacher's piece of the rogue's Bloodletting engine (docs/engines.md). When a
-- bleeding foe falls, every stack of its Bleed opens on the nearest body of its own side
-- (trait_hemophage). A pack fought by a bleeder stays bleeding: the wound outlives the body that wore it.
--
-- Reworked from the Opportunist's Charm (2026-11-18), which carried the same trait and text as the
-- Opportunist's Harness -- one rule sold twice. The harness keeps the rule; the id stays so saves and
-- drop lists keep their piece.
return {
    name = "Hemophage Charm",
    description = "When a bleeding foe falls, its Bleed jumps to the nearest of its allies.",
    flavor = "The Undercroft's poachers wear it on a cord. It is warm.",
    sprite = "assets/items/opportunists_charm.png",
    type = "utility",
    tags = { "charm" },
    class = "poacher",
    unlockLevel = 5,
    traits = { "trait_hemophage" },
    bonus = { luck = 3 },
}
