-- THE LONG INVOCATION: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Theurge channels a holy spell that grows every turn she holds it. The Warden marks a line
-- around her and Roots whoever crosses it. The Totemist's totem heals the party and cancels spells
-- cast into its field. Fielded at six: a Spellbreaker, a Sentinel and a Barbarian.
--
-- How you beat it: Cross the line once and accept the Root, or break the totem first so your spells
-- reach her. Every turn you wait, her spell is bigger.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_invocation",
    name = "The Long Invocation",
    core = { "theurge", "totemist", "warden" },
    grow = { "spellbreaker", "sentinel", "barbarian" },
    combo = "The Theurge channels a holy spell that grows every turn she holds it. The Warden marks a"
        .. " line around her and Roots whoever crosses it. The Totemist's totem heals the party and"
        .. " cancels spells cast into its field. Fielded at six: a Spellbreaker, a Sentinel and a"
        .. " Barbarian.",
    counter = "Cross the line once and accept the Root, or break the totem first so your spells reach her."
        .. " Every turn you wait, her spell is bigger.",
})
