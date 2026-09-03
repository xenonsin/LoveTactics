-- Ninja -- rogue x mage multiclass discipline. (Named in models/growth.lua years before it could be
-- sold.)
-- Signature mechanic: Shadowclone -- the ninja fights by NOT being where you strike. Blink between
-- positions, leave a decoy clone behind that draws the blow, and vanish from sight (invisibility)
-- until the killing strike. Its vocabulary is the blink (rogue's return-to-origin move-swap) fused
-- with mage illusion: clones, misdirection, and disappearing -- not the elements.
-- Exemplar: a dedicated Ninja (character_ninja), met as a BOSS -- you fight a shape that keeps not being
-- there. Kaen (character_kaen) remains the marquee named boss of the unlock quest; this is the plain
-- discipline body the draft and stray encounters field, so the discipline reads as itself on the board.
-- Gate: earned advancement -- requires a rogue subclass AND a mage subclass unlocked, which opens
-- quest_undercroft_the_shadowless (pending). See docs/disciplines-plan.md.
return {
    name    = "Ninja",
    description = "Fights by not being where you strike. Blink away, leave a clone to take the blow, and stay unseen until the killing one.",
    classes = { "rogue", "mage" },
    exemplar = "character_ninja", -- was character_kaen (kept as the marquee named boss); dedicated body authored
    requiredLevel = { rogue = 7 }, -- pending
}
