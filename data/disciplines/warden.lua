-- Warden -- knight x hunter multiclass discipline.
-- Signature mechanic: Lockdown zone -- mark an area; enemies entering it are Rooted/Halted. Border
-- control that answers "where do we stand" from the far edge of the field.
-- Exemplar: a march-warden (character_warden, NEW -- pending), met as a MENTOR.
-- Gate: earned advancement -- requires a knight subclass AND a hunter subclass unlocked, which opens
-- quest_bastion_the_border_watch (pending). See docs/disciplines-plan.md.
return {
    name    = "Warden",
    description = "Border control. Mark a zone, and anything that steps into it is Rooted or Halted.",
    classes = { "knight", "hunter" },
    exemplar = "character_warden", -- NEW, pending
    requiredQuests = { "quest_bastion_the_border_watch" }, -- pending
}
