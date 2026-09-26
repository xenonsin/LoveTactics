-- BLOOD FEUD: what a goblin IS, granted by its race (data/races/goblin.lua) into the first free cell of every
-- goblin ever minted, the way a dwarf's Stout and a kobold's Underfoot are. Reviewed 2026-09-26 ("The Goblins
-- of Wrath"), approved as pitched in round 1.
--
--   BLOOD FEUD    whoever last hit a goblin is the Feud: +2 from every goblin, and a goblin that can reach
--                 it attacks nothing else (trait_blood_feud, models/feud.lua, AI.preempt)
--   MOB COURAGE   a goblin with no kin within two cowers; the alpha and the elite never do
--                 (trait_mob_courage)
--
-- Bound and unstealable: an organ, never kit -- what the company takes off a goblin is what it carries.
return {
    name = "Blood Feud",
    description = "Whoever last hit a goblin is the Feud. Increase damage by 2 against the Feud. With no goblin within 2, Cower.",
    flavor = "It does not remember your name. It remembers your face, and it has told all the others.",
    sprite = "assets/items/utility_blood_feud.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_blood_feud", "trait_mob_courage" },
}
