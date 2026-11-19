-- Storm Vessel: the mage's engine core and its grid piece (docs/engines.md). It gathers a charge every
-- turn its bearer takes, up to three (the `storm` pool, banked off `turnTaken`), and the spell or
-- enchanted blade beside it spends the WHOLE pool for half again its damage per charge
-- (Engine.stormFactor, read by castAmount on every cast path so the forecast quotes it). A turn-five
-- spell is far bigger than a turn-one spell, in a game where mana never comes back mid-fight.
--
-- The aura filters by the `magical` tag, the same tag the damage core reads to route a hit through
-- magic defense, so it sharpens exactly what counts as magic when it lands -- a Battlemage's enchanted
-- blade beside it spends the storm too (the Battlemage's twist, round 2).
--
-- Reworked from the Resonance Prism (2026-11-18), whose flat bonus to adjacent magic was a stat stick
-- in a cell. Named Storm Vessel in round 3 (the author's pick over Wellstone and Gathering Stone; the
-- machine word went to the Artificer for later). The id stays so the slime's drop list keeps its piece.
return {
    name = "Storm Vessel",
    description = "Gathers 1 Storm a turn, up to 3. A spell next to it consumes it for +50% damage per Storm. +1 magic defense per Storm.",
    flavor = "It hums when the weather turns. The Arcanum says that is the only thing it does on its own.",
    sprite = "assets/items/resonance_prism.png",
    type = "utility",
    tags = { "arcane" },
    class = "mage",
    unlockLevel = 6,
    charge = { key = "storm", from = { "turnTaken" }, max = 3 },
    traits = { "trait_storm_vessel" },
    aura = {
        appliesTo = { "ability", "weapon" }, -- a spell and an enchanted blade are the same school
        requiresTags = { "magical" },        -- ...and only the ones that actually ARE magic
        stormMult = 0.5,                     -- per Storm spent (Engine.stormFactor)
    },
    bonus = { magicDamage = 1 },
}
