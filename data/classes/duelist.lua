-- Duelist -- fighter x rogue multiclass discipline.
-- Signature mechanic: Duel stance -- escalating bonus while locked 1v1 with a single foe.
-- Exemplar: a swaggering blade-for-hire (character_duelist, NEW -- pending), met as a RECRUIT.
-- Gate: earned advancement -- requires a fighter subclass AND a rogue subclass unlocked, which opens
-- quest_colosseum_the_tavern_duel (pending). See docs/disciplines-plan.md.
return {
    name    = "Duelist",
    description = "Fights one foe at a time. A stance builds a bonus that grows for every turn you stay "
        .. "locked with the same opponent.",
    exemplar = "character_duelist", -- NEW, pending
    requires = { fighter = 10, rogue = 10 },
}
