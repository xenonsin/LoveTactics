-- UNTOUCHABLE: the Elf Bladedancer's (data/items/utility/utility_untouchable.lua). Approved 2026-09-30 ("Pride's
-- Bestiary"). While it is Unblemished it evades EVERY attack that rolls to hit: Combat.hitChance answers 0, so the
-- forecast says so before anybody swings. Only what does not ask the dice can mar it -- a spell, an area, a
-- hazard, an unavoidable blow -- and once marred it is an ordinary swordsman.
--
-- Not Dodge (trait_dodge): Dodge slips one physical blow and then waits a cooldown. This has no cooldown and no
-- school; its whole condition is the race's own status.
return {
    name = "Untouchable",
    description = "While Unblemished, evade every attack that rolls to hit.",
    untouchable = true,
}
