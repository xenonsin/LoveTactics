-- THE IRON IN HIM: a hunter's shot, taken a long time ago and never taken out. It is the reason there
-- is anything wrong with this animal at all, and it is where his fight is written.
--
-- A bound centre-cell relic like every boss signature (compare data/items/utility/utility_demon_sigil.lua,
-- which this follows exactly), carrying the data-driven phase script. trait_boss_phases reads `phases`
-- off this item, so one trait id drives every boss and each one's relic holds its own stages.
--
-- THE SCRIPT IS ONE STAGE, and it is the only stage, because the fight has exactly one thing to say:
--
--   50%  THE TURNING. He stops being a boar. models/transform.lua exchanges the body for
--        character_the_turning -- same unit, same tile, same health bar, a new kit and a new sprite --
--        so the wound total carries across and the second half opens already half-spent. The transform
--        changes what he can do, never how much killing he takes.
--
-- WHY ONE STAGE AND NOT THREE. The Champion's relic runs two because its fight is an escalation; this
-- one is an INVERSION, and an inversion only works if the player has fully committed to the thing being
-- inverted. Phase one teaches one lesson -- kill the clan, the clan is the problem -- and the turning is
-- the board answering that every body you put down is his. A middle stage would soften the moment the
-- lesson is taken away, which is the only moment this fight has.
--
-- HALF, not a third, for the same arithmetic reason the Champion fires at 33% and not 66%: the second
-- half is where his damage lives (he cannot attack at all before it), so opening it too late leaves a
-- party that has already won walking through a formality, and too early hands them a mobile attacker
-- while the clan is still at full strength. Half is the first point at which the corpses on the floor
-- are worth taking, which is what the second phase is for.
--
-- `bound = true` (models/item.lua): unstealable. No `class`... no `price`: this is not gear, and per
-- docs/bestiary.md creature kit carries no axis at all, so neither the drop pool nor a counter can mint
-- it. A rogue cannot lift a boss's whole fight off it in one grab, and nobody can carry the curse home.
return {
    name = "The Iron in Him",
    description = "The old shot festers: at half his blood, the thing inside him takes over.",
    flavor = "Someone shot him, once, and went home. This is the rest of what that did.",
    sprite = "assets/items/utility_the_iron_in_him.png",
    type = "utility", -- `bound` (not the type) is what locks it in the centre cell
    class = "creature",
    tags = { "signature", "relic" },
    bound = true,
    noSteal = true,
    traits = { "trait_boss_phases" },
    phases = {
        { at = 0.5, responses = {
            { kind = "log", text = "The old wound splits, and something inside it unfolds." },
            { kind = "transform", id = "character_the_turning" },
        } },
    },
}
