-- Serrated Whetstone: the rogue's Bloodletting grid piece (docs/engines.md). A charm with no ability of
-- its own whose aura teaches the BLADES beside it to open a wound: every hit a dagger or a sword next to
-- it lands also adds a stack of Bleed (status_bleed counts its stacks apart from its per-tile bite, so a
-- stack is one more wound and not a deeper one).
--
-- Weak alone, on purpose. A stack of Bleed does nothing until something cashes it in -- Widen the Wound
-- doubles it, Exsanguinate turns it into raw damage, a Hemophage Charm carries it to the next body -- so
-- this cell is worth a slot only to a rogue building toward one of those.
return {
    name = "Serrated Whetstone",
    description = "Daggers and swords next to it add 1 Bleed stack on every hit.",
    flavor = "It does not sharpen anything. It roughs the edge up.",
    sprite = "assets/items/utility_serrated_whetstone.png",
    type = "utility",
    tags = { "charm" },
    class = "rogue",
    unlockLevel = 7,
    aura = {
        appliesTo = { "weapon" },
        anyTags = { "dagger", "sword" },
        status = { id = "status_bleed", opts = { stacks = 1 } },
    },
    bonus = { skill = 1 },
}
