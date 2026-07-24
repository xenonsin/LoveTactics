-- Spell Eater: the mage half of the Spellbreaker (knight x mage). Magic lands lighter on you, and what
-- it fails to do is refunded as mana.
--
-- Anti-magic as absorption, which is the one shape of it this shelf could keep. Every version that
-- refused the enemy something was turned down; this one lets the spell through, swallows a share, and
-- hands it back to you as fuel. The caster gets to cast, and gets to watch it pay for the answer.
--
-- It is also the item that fixes the shelf's parent balance. Spellbreaker's other three pieces are all
-- knight-side -- Mana Sunder, the Silencing Blade, the Dampening Oath -- so the Arcanum was announcing a
-- discipline and selling nothing for it. This and Empty Vessel are the mage's half.
--
-- The refund is exactly the eaten half, so there is one number rather than two, and an absorbing charm
-- that grew stronger would automatically feed harder.
return {
    name = "Spell Eater",
    description = "Magical blows land lighter on you, and refund you mana for the difference.",
    flavor = "It is not resistance. It is an appetite, and it is specific.",
    sprite = "assets/items/utility_spell_eater.png",
    type = "utility",
    tags = { "charm", "magical" },
    class = "mage",
    discipline = "spellbreaker",
    price = 460,
    repRank = 4,
    traits = { "trait_spell_eater" },
}
