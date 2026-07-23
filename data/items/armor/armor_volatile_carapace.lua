-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- When the wearer falls, it bursts, and everything nearby takes the blast (trait_volatile).
--
-- THE ONLY ITEM IN THE CATALOG WHOSE EFFECT REQUIRES ITS OWNER TO DIE, which is why it needs saying
-- carefully: this is not a survivability item that happens to have a downside. It is a death you plan
-- for. The armour it provides is real but modest, and the correct way to read the file is that the
-- defense line exists to decide WHEN the burst happens rather than whether.
--
-- It changes what a losing position is worth. Every other armour in this game makes the answer to
-- "my alchemist is about to die surrounded" worse the more true it gets; this one makes it better,
-- because the blast is worth the number of bodies standing around the corpse. The Whirlplate performs
-- the same inversion for a fighter who survives being surrounded (see its header); this is the version
-- for one who does not.
--
-- IT HITS THE PARTY TOO. A carapace-wearer who dies inside the line takes the line with them, and the
-- player's own knight standing over the body to protect it is the worst possible outcome. That is not
-- a wrinkle to be patched -- it is the reason the item is on envy's shelf. What it covets is the
-- fight's ending, and it does not much mind whose.
--
-- The enemy's own bomblets carry the same rule (utility_volatile_core, character_demon_bomblet). You
-- fought this; now you are it -- which is the shape every relic in this game takes.
return {
    name = "Volatile Carapace",
    description = "When you fall, it bursts -- everything nearby takes the blast, allies included.",
    flavor = "The Crucible logs it as a containment vessel. The containment is understood to be temporary.",
    sprite = "assets/items/armor_volatile_carapace.png",
    type = "armor",
    tags = { "leather", "explosive" },
    class = "alchemist",
    traits = { "trait_volatile" },
    bonus = { defense = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 } },
    resist = { fire = { 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5 } },
}
