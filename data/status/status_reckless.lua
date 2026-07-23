-- Reckless: guard dropped. Raised Damage and gutted defenses, both flat, both through the same
-- `statBonus` fold every other stat status runs through (Combat.flatStat) -- so it is one status doing
-- two things in opposite directions rather than a mechanic anyone had to invent.
--
-- The cleanest statement of what wrath's shelf is FOR. Every other class buys damage with a resource:
-- mana, stamina, a stack of consumables, a turn spent setting up. Wrath buys it with the only thing
-- it has an unlimited supply of, which is willingness to be hit (docs/classes.md: "Trades its own
-- health and tempo for damage"). Desperate Strike spends health outright and Fury spends the whole
-- health bar; this spends the ARMOR, which is the version you can walk into a fight already wearing.
--
-- A DEBUFF, so Cure strips it -- and that is not a mistake to be corrected. A negative statBonus is a
-- debuff by the rule the Acid status already set, and a fighter who wants out of its own recklessness
-- should be able to be talked down by the party's priest. The alternative -- a buff nobody can end --
-- would make the drawback optional, and the drawback is the item.
--
-- Long, because the point is that you committed. A window you could open for one swing and close again
-- would be a free damage buff with extra clicking.
return {
    name = "Reckless",
    abbr = "Rck",
    description = "Guard dropped: raised Damage, and far weaker defenses.",
    color = { 0.88, 0.32, 0.16 }, -- badge tint (raw orange -- rage without Fury's blood-red)
    duration = 20, -- ~4 turns at Status.TICKS_PER_TURN: a commitment, not a swing
    debuff = true, -- a negative statBonus is a debuff; the priest may talk you down
    statBonus = { damage = 12, defense = -10, magicDefense = -10 },
}
