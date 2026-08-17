-- Skirmisher -- fighter x hunter multiclass discipline.
-- Signature mechanic: Hit-and-run -- reposition after a strike (a free move once you have swung).
-- Exemplar: a raider outrider (character_skirmisher, NEW -- pending), met as a BOSS.
-- Gate: earned advancement -- requires a fighter subclass AND a hunter subclass unlocked, which opens
-- quest_hunters_lodge_the_running_fight (pending). See docs/disciplines-plan.md.
return {
    name    = "Skirmisher",
    description = "Hit and run. A free move once you have swung, so a strike never leaves you standing where it landed.",
    classes = { "fighter", "hunter" },
    exemplar = "character_skirmisher", -- NEW, pending
    hire = "character_fen",
    requiredQuests = { "quest_hunters_lodge_the_running_fight" }, -- pending
}
