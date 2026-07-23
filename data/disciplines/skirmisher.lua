-- Skirmisher -- fighter x hunter multiclass discipline.
-- Signature mechanic: Hit-and-run -- reposition after a strike (a free move once you have swung).
-- Exemplar: a raider outrider (character_skirmisher, NEW -- pending), met as a BOSS.
-- Gate: earned advancement -- requires a fighter subclass AND a hunter subclass unlocked, which opens
-- the_running_fight (pending). See docs/disciplines-plan.md.
return {
    name    = "Skirmisher",
    classes = { "fighter", "hunter" },
    exemplar = "character_skirmisher", -- NEW, pending
    requiredQuests = { "the_running_fight" }, -- pending
}
