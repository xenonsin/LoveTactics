-- Arcanum rank-3. When mana runs dry, spells are paid for in HEALTH instead (trait_overchannel).
--
-- The only armor in the catalog that makes its wearer more DANGEROUS and less able to survive, in the
-- same line, and it does it without touching either number. Nothing here adds damage: what it removes
-- is the moment a mage stops being a mage. An empty pool used to be the end of the fight for a caster;
-- with this it is a price list.
--
-- Which is pride's item exactly. The sin is not that the mage is strong, it is that the mage will not
-- accept a limit -- and this file is that refusal written as a rule the engine obeys. The failure case
-- needs no explanation and gets none: a wearer who keeps casting dies casting.
--
-- Its steel is real but small, and that is the trap working as designed. A weave that also kept its
-- wearer alive would be removing the consequence it exists to sell. Read against
-- utility_bloodstone_focus and utility_overflowing_focus, which grant the same rule from a cell -- and
-- note that all three stacking changes nothing, because a pool only runs out once.
--
-- Cloth: a square of pace.
return {
    name = "Overchannel Weave",
    description = "When mana runs dry, spells are paid for in health instead.",
    flavor = "The Arcanum grades it as a teaching aid. It is worn almost exclusively by people it has finished teaching.",
    sprite = "assets/items/armor_overchannel_weave.png",
    type = "armor",
    tags = { "cloth", "arcane" },
    class = "mage",
    price = 380,
    repRank = 3,
    traits = { "trait_overchannel" },
    bonus = { magicDefense = { 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9 }, movement = -1 },
    resist = { magical = { 2, 2, 3, 3, 3, 4, 4, 4, 4, 5, 5 } },
}
