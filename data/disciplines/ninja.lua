-- Ninja -- rogue x mage multiclass discipline. (Named in models/growth.lua years before it could be
-- sold.)
-- Signature mechanic: Shadowclone -- the ninja fights by NOT being where you strike. Blink between
-- positions, leave a decoy clone behind that draws the blow, and vanish from sight (invisibility)
-- until the killing strike. Its vocabulary is the blink (rogue's return-to-origin move-swap) fused
-- with mage illusion: clones, misdirection, and disappearing -- not the elements.
-- Exemplar: Kaen (character_kaen, NEW -- pending), met as a BOSS -- you fight a shape that keeps not
-- being there.
-- Gate: earned advancement -- requires a rogue subclass AND a mage subclass unlocked, which opens
-- the_shadowless (pending). See docs/disciplines-plan.md.
return {
    name    = "Ninja",
    classes = { "rogue", "mage" },
    exemplar = "character_kaen", -- NEW, pending
    requiredQuests = { "the_shadowless" }, -- pending
}
