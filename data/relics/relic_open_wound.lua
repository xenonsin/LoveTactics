-- RARE. Statuses on the company never expire for the rest of a fight. Every buff is permanent -- and so
-- is every burn, poison, bleed and curse.
--
-- It re-prices a third of the shelf at a stroke: the opening boons (Hasted, warded, Emboldened,
-- regenerating) stop being an OPENING and become the whole fight, so six commons change value the moment
-- this is picked up.
--
-- THE ONE LADDER THAT WIDENS SCOPE rather than raising a number, because duration is already infinite at
-- one copy and there is nowhere up to go. At two copies statuses also carry BETWEEN fights for the rest
-- of the floor -- an Emboldened company walks into the next fight still Emboldened, and a poisoned one
-- still poisoned. Beyond two, the step is +1 magnitude on every status the company applies.
return {
    name = "The Open Wound",
    blurb = "Statuses on the company never expire.",
    tier = "rare", mark = "Ow",
    cost = "Nor do burns, poisons or curses.",
    rules = { statusesPersist = true },
    -- 1: within a fight. 2: across the floor. 3+: +1 magnitude per further copy.
    ruleScale = { statusesPersist = { 1, 1 } },
}
