-- The Shared Ledger: the standing rule of the Apothecary's charm. Anyone the bearer mends also borrows a
-- share of the bearer's own guard (status_lent_guard).
--
-- A flag (Trait.flag) read inside fx.heal -- which is the one heal path in the game that knows WHO did
-- the mending. Combat.applyHeal is handed only a patient, which is exactly why the Crusader's
-- `allyMended` tally lives there and this does not: one is a fact about the line, the other is a fact
-- about the healer.
--
-- Envy's verb applied to the priest's action, which is the whole reason this discipline is
-- priest x alchemist rather than a second cleric. Every other heal in the catalog GIVES. This one LENDS:
-- the guard is drawn off the apothecary and handed over, and it comes back.
--
-- Skips the bearer, so mending yourself does not lend you your own armour twice.
return {
    name = "The Shared Ledger",
    lendsGuard = true,
}
