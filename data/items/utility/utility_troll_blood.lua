-- INDIFFERENT: what a troll IS, granted by its race (data/races/troll.lua) into the first free cell of every troll
-- ever minted. Reviewed 2026-10-04 ("Sloth's Bestiary").
--
-- The bearer never dodges, and regrows a fifth of its health at the top of each of its turns unless fire or acid
-- reached it since its last (trait_indifferent -> status_indifferent). Bound and unstealable: an organ, not kit.
-- The player's version of the rule is Troll Blood, the apothecary's draught -- a different item on purpose.
return {
    name = "Indifferent",
    description = "Never dodge. Regrow a fifth of your health each turn, unless fire or acid reached you since your last.",
    flavor = "It does not get out of the way. It has never needed to.",
    sprite = "assets/items/utility_troll_blood.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_indifferent" },
}
