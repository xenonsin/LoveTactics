-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Once per battle, the wearer takes a LETHAL blow meant for an adjacent ally (trait_martyrs_vow).
-- Not a share of it, not a redirect of the first hit each turn -- the killing one, and only that one,
-- and only once.
--
-- The narrowest guard in the catalog and by some distance the most valuable when it fires, because it
-- is the only effect in this game that converts a death into a wound. Every other protection on the
-- rack -- Oathward, Shared Burden, a barrier -- reduces or moves damage and can therefore be
-- out-damaged; this one is checked against the outcome, so it cannot be.
--
-- On a PRIEST rather than a knight, which is the deliberate part. The Bastion's version of this
-- (armor_martyrs_shield) spreads its promise across everyone adjacent and bleeds the knight for it
-- continuously; the Cathedral's spends nothing until the moment somebody actually dies. Sloth is a
-- wall you maintain, lust is a body offered once -- and the stole gives no defense worth the name,
-- so the priest wearing it is genuinely likely not to survive keeping it.
--
-- Cloth: a square of pace, and the wearer needs to be standing next to the person they intend to
-- outlive by one turn.
return {
    name = "The Interceding Stole",
    description = "Once per battle, take a lethal blow meant for an adjacent ally.",
    flavor = "The Cathedral embroiders the name of the intended on the inside. It is filled in afterwards.",
    sprite = "assets/items/armor_interceding_stole.png",
    type = "armor",
    tags = { "cloth", "holy" },
    class = "priest",
    traits = { "trait_martyrs_vow" },
    bonus = { magicDefense = { 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7 }, defense = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 }, movement = -1 },
}
