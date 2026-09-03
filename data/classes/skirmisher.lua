-- Skirmisher -- fighter x hunter multiclass discipline.
-- Signature mechanic: Hit-and-run -- reposition after a strike (a free move once you have swung).
-- Exemplar: a raider outrider (character_skirmisher, NEW -- pending), met as a BOSS.
-- Gate: earned advancement -- requires a fighter subclass AND a hunter subclass unlocked, which opens
-- quest_hunters_lodge_the_running_fight (pending). See docs/disciplines-plan.md.
return {
    name    = "Skirmisher",
    description = "Hit and run. A free move once you have swung, so a strike never leaves you standing where it landed.",
    exemplar = "character_skirmisher", -- NEW, pending
    requires = { fighter = 7, hunter = 7 },
}
