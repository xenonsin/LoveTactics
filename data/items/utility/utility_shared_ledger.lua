-- The Shared Ledger: the priest half of the Apothecary (priest x alchemist). Everyone you heal also
-- borrows a share of your own guard.
--
-- The item that makes this discipline a fusion rather than a second cleric. Every other heal in the
-- catalog GIVES -- a number leaves the caster's mana bar and arrives in somebody's health bar, and the
-- transaction is over. This one LENDS: the guard comes off the apothecary, goes onto the patient, and
-- comes back. That is envy's verb performed with the priest's hands, which is exactly what
-- priest x alchemist is supposed to sound like (docs/classes.md: the alchemist "covets others' power
-- rather than casting its own").
--
-- It attaches to healing rather than to a particular spell, so it pays out on whatever the apothecary
-- already owns -- Transfusion, a potion thrown to an ally, a Litany, a totem's healing. The apothecary
-- does not need a new heal; it needs its existing ones to mean two things.
--
-- The first draft of this shelf was three healing items and the author turned all three down. The
-- diagnosis was right: they were a field medic, and this shelf's word is borrowing.
return {
    name = "The Shared Ledger",
    description = "Anyone you heal also borrows a share of your own guard.",
    flavor = "She writes both columns in the same hand. It is a loan, and she does expect it back.",
    sprite = "assets/items/utility_shared_ledger.png",
    type = "utility",
    tags = { "charm" },
    class = "priest",
    discipline = "apothecary",
    price = 410,
    unlockQuests = 4,
    traits = { "trait_shared_ledger" },
    -- your guard, lent to whoever you mend
    bonus = { magicDefense = 2 },
}
