-- THE TOLL: the Toll-Troll's rule, carried on its organ (data/items/utility/utility_the_toll.lua). Approved
-- 2026-10-04 ("Sloth's Bestiary", slice B).
--
-- A foe that USES something -- an attack, an ability, an item -- within the troll's reach is struck first, before
-- the use resolves. A body that only walks through, or waits, is left alone. The rule is models/sloth_trolls.lua's
-- (Trolls.collect, asked by Combat.useItem); this file is the flag and the words. Free: the troll does not pay to
-- collect, so the toll is every use, all fight -- and a troll that is Stunned or asleep collects nothing.
return {
    name = "The Toll",
    description = "A foe that uses an attack, ability or item within your weapon's reach is struck first.",
    toll = {}, -- no radius: the reach is the maul's
}
