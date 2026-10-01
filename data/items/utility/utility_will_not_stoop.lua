-- WILL NOT STOOP: what a djinn IS, granted by its race (data/races/djinn.lua) into the first free cell of every
-- djinn ever minted. Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- The rule lives in models/djinn.lua (Djinn.willNotStoop), fired from Combat.startTurn on the trait's flag:
-- a foe beside it when its turn opens, and it Blinks free to the open tile within 4 farthest from the company;
-- nowhere to go, and it is Shamed and loses the turn. Bound and unstealable: an organ, not kit.
return {
    name = "Will Not Stoop",
    description = "Start of your turn, beside a foe: blink up to 4 tiles away, free. Nowhere to go: Shamed.",
    flavor = "It has no master in this world, and it is not about to take one by the collar.",
    sprite = "assets/items/utility_will_not_stoop.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_will_not_stoop" },
}
