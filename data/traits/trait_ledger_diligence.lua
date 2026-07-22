-- Gyeom's rule, and the mechanical face of humility answering pride: "meets a spell with a
-- better-practised self, not a bigger one; the mage who is never finished" (docs/story.md, "The Arcanum"
-- -- the mage answers pride). She is no prodigy; she does her best, again and again, and is a little
-- better than she was. So her power is not a technique on display -- it is accumulated practice, banked a
-- cast at a time.
--
-- DILIGENCE: every action she takes deepens her, a small permanent lift to her magic for the rest of the
-- battle (ctx.addBonus writes the per-unit `bonus` table -- rebuilt each battle, so nothing follows the
-- blueprint out). She peaks LATE, the exact inverse of Saber's one-motion front-load
-- (data/items/weapon/weapon_first_motion.lua): a long fight is not downtime for her, it is study.
--
-- CONCEALMENT is the other half, and it needs no second hook. She fights suppressed -- her blueprint
-- stats read low, so enemy targeting and the mirror alike take her for a weak mage not worth measuring --
-- and the Release on her relic (data/items/utility/utility_ledger.lua) is where she drops it and the
-- banked practice lands at once, on the enemy that dismissed her. This is also her foil-immunity, stated
-- as cleanly as Amana's "not one of the made": Pride answers only what is SHOWN
-- (data/traits/trait_perfect_recall.lua), and Gyeom shows nothing worth taking -- a spell answered off her
-- is answered off her suppressed value, which is nothing. You can glance a spell; you cannot glance the
-- hours she never put on display.
--
-- Fired from onCast (Trait.onCast), so any action she commits to feeds it. It rides on the bound Ledger,
-- not on the blueprint -- a character's own `traits` field is never collected, only an item's (models/
-- trait.lua) -- which is what keeps it true once her recruit-fight boss flag goes inert and she is yours.
return {
    name = "Diligence",
    description = "Every action she takes lifts her magic a little, and keeps it, for the rest of the battle.",
    step = 2, -- magicDamage banked per action; small, so the lift is the long game rather than a spike
    onCast = function(ctx)
        local gained = ctx.addBonus("magicDamage", ctx.def.step)
        ctx.log("action", string.format("%s is a little better than she was.",
            (ctx.unit.char and ctx.unit.char.name) or "She"))
        return gained
    end,
}
