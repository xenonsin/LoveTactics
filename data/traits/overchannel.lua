-- The Mage's innate: an arcanist who refuses to stop casting. When a spell's mana cost outruns the
-- pool, the shortfall is paid out of health instead (1 HP per missing point) -- so the deep-pool glass
-- cannon can keep hurling fire past empty, bleeding for every cast.
--
-- Unlike every other trait, this one hangs no hook. There is no "onSpend" event to react to, so the
-- effect lives where the cost is actually paid: Combat.spendCost consults Combat.canOverchannel (which
-- is just Trait.has "overchannel"), and Combat.itemBlockReason lets a mana-short cast through when the
-- blood is there to cover it. The def exists so the trait can be attached and detected; its mechanic
-- is that capability read, documented in models/combat.lua.
return {
    name = "Overchannel",
    description = "When mana runs dry, spells are paid for in health instead.",
}
