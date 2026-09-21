-- Poacher -- rogue x hunter multiclass discipline.
-- Signature mechanic: Snare-execute -- traps set up your blink-kill; bonus damage vs Rooted targets.
-- Exemplar: a bounty-jumping trapper (character_poacher, NEW -- pending), met as a RECRUIT.
-- Gate: earned advancement -- requires a rogue subclass AND a hunter subclass unlocked, which opens
-- quest_hunters_lodge_the_marked_quarry (pending). See docs/disciplines-plan.md.
return {
    name    = "Poacher",
    description = "Traps first, kills second. A snare leaves the quarry Rooted, and your strikes hit a "
        .. "Rooted foe far harder.",
    exemplar = "character_poacher", -- NEW, pending
    requires = { rogue = 8, hunter = 8 },
}
