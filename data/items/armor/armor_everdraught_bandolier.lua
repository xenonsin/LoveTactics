-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Bloodied by a blow, the wearer drinks a healing potion at once, with no turn spent
-- (trait_survivors_reflex). Armor that reads as armor and is actually a CONSUMABLE ENGINE: it adds no
-- survivability of its own and instead deletes the action cost of the survivability the player already
-- bought by the bottle.
--
-- Which is the envy shelf's identity almost literally (docs/classes.md: covets others' power rather
-- than casting its own). The bandolier has no healing in it. It has somebody else's healing in it,
-- and a rule about when to open it.
--
-- The real decision it creates is at the shop rather than in the fight: a party wearing this wants to
-- buy far more potions than it otherwise would, and every one of them is now worth a fraction of a
-- turn on top of its health. That is the Crucible getting paid twice, which is the correct outcome for
-- an item on this shelf.
--
-- And the failure case is honest: with an empty stock it does nothing at all, and the tooltip will not
-- warn you. A reflex that cannot afford itself is silent.
--
-- utility_survivors_reflex is the charm form.
return {
    name = "Everdraught Bandolier",
    description = "Bloodied by a blow, you drink a healing potion at once -- no turn spent.",
    flavor = "The Crucible fits it free to anyone who buys the potions to fill it, which is the entire idea.",
    sprite = "assets/items/armor_everdraught_bandolier.png",
    type = "armor",
    tags = { "leather" },
    class = "alchemist",
    traits = { "trait_survivors_reflex" },
    bonus = { defense = { 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7 } },
}
