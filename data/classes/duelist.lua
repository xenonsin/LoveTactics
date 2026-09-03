-- Duelist -- fighter x rogue multiclass discipline.
-- Signature mechanic: Duel stance -- escalating bonus while locked 1v1 with a single foe.
-- Exemplar: a swaggering blade-for-hire (character_duelist, NEW -- pending), met as a RECRUIT.
-- Gate: earned advancement -- requires a fighter subclass AND a rogue subclass unlocked, which opens
-- quest_colosseum_the_tavern_duel (pending). See docs/disciplines-plan.md.
return {
    name    = "Duelist",
    description = "One blade, one opponent. A stance whose bonus escalates for as long as you stay locked 1v1.",
    exemplar = "character_duelist", -- NEW, pending
    requires = { fighter = 7, rogue = 7 },
}
