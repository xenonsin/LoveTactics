-- UNSTEERED: what makes the Goblin Fanatic a Fanatic (approved as pitched, 2026-09-26, "The Goblins of
-- Wrath"). Nobody controls it -- not its warband, not you: Taunt and Charm do nothing to it (`statusImmunity`,
-- the Hollow Helm's shape) -- and its spin does not stop at lava (trait_unsteered, read by ability_spin_out).
-- Bound and unstealable: an organ, not kit. What the company takes off a Fanatic is its Spin Out.
return {
    name = "Unsteered",
    description = "Cannot be Taunted or Charmed. Spin Out does not stop at lava.",
    flavor = "The mushroom brew is for courage. The chain is for everyone else's.",
    sprite = "assets/items/utility_unsteered.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    statusImmunity = { "status_taunt", "status_charm" },
    traits = { "trait_unsteered" },
}
