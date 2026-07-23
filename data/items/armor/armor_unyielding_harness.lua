-- Bastion rank-3. Spend mana to shrug off ANY debuff the moment it lands (trait_unyielding). No
-- cooldown -- only the pool.
--
-- The knight's hybrid resource made into armour, and the only piece of gear on the shelf that spends
-- mana passively. docs/classes.md characterizes knight as stamina + mana and is careful to call that a
-- description rather than a law; this is the item that makes the mana half matter to a player who
-- never casts anything, because the harness is the only thing in their grid that draws on it.
--
-- Read against armor_reliquary_mantle (the Cathedral's, quest-only): that one refuses ONE debuff and
-- then recharges on a clock. This refuses every debuff and bills each time. Same problem, two
-- economies -- and the difference is what the two sins are. Lust's answer is a mercy that arrives when
-- it arrives; sloth's is a flat refusal that keeps working exactly as long as you can pay for it, and
-- stops dead when you cannot.
--
-- The failure case is the good part: a knight who has been drained has no answer at all, so an enemy
-- whose plan is control can beat the harness by throwing cheap afflictions at it until the pool is
-- gone and then throwing the real one. That is a fight the player can see coming and can play around
-- by not spending mana on the first Bleed.
--
-- utility_unyielding_seal is the charm form. Solid steel, unremarkable numbers: what the wearer is
-- buying is the rule.
return {
    name = "Unyielding Harness",
    description = "Spend mana to shrug off any debuff the moment it lands. No cooldown -- only the pool.",
    flavor = "The Bastion's drill for it is a single word, repeated, until the recruit stops treating it as an answer.",
    sprite = "assets/items/armor_unyielding_harness.png",
    type = "armor",
    tags = { "heavy", "plate" },
    class = "knight",
    price = 480,
    repRank = 3,
    traits = { "trait_unyielding" },
    bonus = { defense = { 8, 9, 9, 10, 11, 12, 12, 13, 14, 15, 15 }, magicDefense = { 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7 }, movement = -2 },
    resist = { physical = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
}
