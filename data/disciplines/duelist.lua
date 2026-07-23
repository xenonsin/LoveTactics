-- Duelist -- fighter x rogue multiclass discipline.
-- Signature mechanic: Duel stance -- escalating bonus while locked 1v1 with a single foe.
-- Exemplar: a swaggering blade-for-hire (character_duelist, NEW -- pending), met as a RECRUIT.
-- Gate: earned advancement -- requires a fighter subclass AND a rogue subclass unlocked, which opens
-- the_tavern_duel (pending). See docs/disciplines-plan.md.
return {
    name    = "Duelist",
    classes = { "fighter", "rogue" },
    exemplar = "character_duelist", -- NEW, pending
    requiredQuests = { "the_tavern_duel" }, -- pending
}
