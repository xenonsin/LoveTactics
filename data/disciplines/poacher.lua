-- Poacher -- rogue x hunter multiclass discipline.
-- Signature mechanic: Snare-execute -- traps set up your blink-kill; bonus damage vs Rooted targets.
-- Exemplar: a bounty-jumping trapper (character_poacher, NEW -- pending), met as a RECRUIT.
-- Gate: earned advancement -- requires a rogue subclass AND a hunter subclass unlocked, which opens
-- the_marked_quarry (pending). See docs/disciplines-plan.md.
return {
    name    = "Poacher",
    classes = { "rogue", "hunter" },
    exemplar = "character_poacher", -- NEW, pending
    requiredQuests = { "the_marked_quarry" }, -- pending
}
