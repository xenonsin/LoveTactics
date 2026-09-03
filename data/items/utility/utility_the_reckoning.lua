-- THE RECKONING: Aurea's rule, cut down, and the Greed mini sin's whole reason to exist.
--
-- Aurea's Bottomless Purse lifts an ITEM off an adjacent foe into her hands
-- (data/items/utility/utility_bottomless_purse.lua) -- your gear, gone, mid-fight, with a full stack of
-- turns still to play without it. Met cold that is a fight you lose the read on and then lose the
-- loadout to.
--
-- So the honour-guard floor takes coin instead, and then starts taking gear:
--
--   from the bell   it lifts COIN off what it hits -- survivable, and it adds up
--   at 50%          it starts lifting items, which is Aurea's baseline
--
-- THAT IS THE RULE FOR THE WHOLE TIER: a mini sin's second phase is its general's first. The phase does
-- it by handing over the general's own ability rather than by inventing a lesser one, so the back half
-- of this fight is literally what waits at the bottom of the stair.
--
-- A tally is a record of what is owed, kept by somebody else: named for the object rather than for the
-- mechanic, which is how the whole tier is named.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "The Reckoning",
    description = "Takes coin from what it strikes, and gear once it is wounded.",
    flavor = "It has been keeping the accounts of everyone who came down here. All of them are behind.",
    sprite = "assets/items/the_reckoning.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_assayed", "trait_boss_phases" },
    phases = {
        { at = 0.5, responses = {
            { kind = "summon", id = "character_coin_chitter", count = 2 },
            { kind = "bonus", stat = "damage", amount = 5 },
            { kind = "log", text = "The Tally closes its book. It has decided coin is not enough." },
        } },
    },
}
