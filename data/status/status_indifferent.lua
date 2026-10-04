-- INDIFFERENT: the badge a troll wears all fight (data/traits/trait_indifferent.lua). It does not get out of the
-- way: avoid -100, the Mantling hawk's own number, so every blow that rolls lands. The regrowth is the trait's;
-- this is the half the board needs to show.
--
-- Not a debuff and undispellable: it is what the body is, so no Cure lifts it and no strip takes it.
return {
    name = "Indifferent",
    abbr = "Indf",
    description = "Indifferent: never dodges. Regrows a fifth of its health each turn unless burned since its last.",
    color = { 0.470, 0.560, 0.400 }, -- badge tint (moss green)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    statBonus = { avoid = -100 },
}
