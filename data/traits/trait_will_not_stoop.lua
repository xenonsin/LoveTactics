-- WILL NOT STOOP: the djinn's family rule (utility_will_not_stoop). Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- A flag and nothing else. Traits have no turn-start hook, so Combat.startTurn reads `willNotStoop` and hands the
-- turn to models/djinn.lua, the way it reads `spreadsPoison` for the Plague Knight.
return {
    name = "Will Not Stoop",
    description = "Start of your turn, beside a foe: blink up to 4 tiles away, free. Nowhere to go: Shamed.",
    willNotStoop = true,
}
