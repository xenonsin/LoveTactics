-- Champion -- fighter x knight multiclass discipline.
-- Signature mechanic: Riposte-wall -- taunt, then counter every striker (rides on its signature item).
-- Exemplar: The Champion (character_champion), met as a BOSS in the capstone quest.
-- Gate: earned advancement -- requires a fighter subclass AND a knight subclass unlocked, which opens
-- champions_challenge (pending). See docs/disciplines-plan.md.
return {
    name    = "Champion",
    classes = { "fighter", "knight" },
    exemplar = "character_champion",
    requiredQuests = { "champions_challenge" }, -- pending
}
