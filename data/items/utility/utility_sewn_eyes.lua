-- SEWN EYES: the Sewn-Eyed Penitents' own (data/characters/character_sewn_eyed_penitent.lua; "Envy's Bestiary",
-- 2026-10-03, slice C). Their eyes are wired shut, so Blind takes nothing from them, and they strike the last of
-- the company to act (trait_hunts_by_ear).
return {
    name = "Sewn Eyes",
    description = "Cannot be Blinded. Strikes the last foe to act; Invisible foes and illusions do not fool it.",
    flavor = "They do not ask to see again. They ask to be let finish.",
    sprite = "assets/items/utility_sewn_eyes.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    statusImmunity = { "status_blind" },
    traits = { "trait_hunts_by_ear" },
}
