-- Champion -- fighter x knight multiclass discipline.
-- Signature mechanic: Riposte-wall -- taunt, then counter every striker (rides on its signature item).
-- Exemplar: The Champion (character_champion), met as a BOSS in the capstone quest.
-- Gate: earned advancement -- requires a fighter subclass AND a knight subclass unlocked, which opens
-- quest_colosseum_champions_challenge (pending). See docs/disciplines-plan.md.
return {
    name    = "Champion",
    description = "Draws the whole field onto you. Taunts pull attacks your way, and every foe that takes "
        .. "the bait is struck back automatically.",
    exemplar = "character_champion",
    requires = { fighter = 6, knight = 6 },
}
