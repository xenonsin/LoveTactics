-- Keystone: the Warlord's grid joker (docs/engines.md). It works only from the CENTRE cell of the grid,
-- and there every item around it lands as though forged one level higher (`forgeStep`, read by
-- castAmount off Engine.forgeStep). Gives the middle of the grid a meaning: the commander stands inside
-- the formation, and the formation is better for it.
--
-- A new item beside the Distant Sigil, which keeps its reach (the author's call, round 3).
return {
    name = "Keystone",
    description = "Works only in the centre slot: the items around it count as 1 forge level higher.",
    flavor = "The stone the arch is built around. Take it out and the arch is a pile.",
    sprite = "assets/items/utility_keystone.png",
    type = "utility",
    tags = { "charm" },
    class = "warlord",
    unlockLevel = 7,
    aura = {
        appliesTo = { "ability", "weapon", "consumable" },
        onlyCentre = true,
        forgeStep = 1,
    },
    bonus = { defense = 1 },
}
