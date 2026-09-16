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
-- (data/traits/trait_counter_magic.lua), and Gyeom shows nothing worth taking -- a spell answered off her
-- is answered off her suppressed value, which is nothing. You can glance a spell; you cannot glance the
-- hours she never put on display.
--
-- Fired from onCast (Trait.onCast), so any action she commits to feeds it. It rides on the bound Ledger,
-- not on the blueprint -- a character's own `traits` field is never collected, only an item's (models/
-- trait.lua) -- which is what keeps it true once her recruit-fight boss flag goes inert and she is yours.
return {
    name = "Diligence",
    description = "Increase magic damage by 2 per action she takes, kept this battle.",
    -- magicDamage banked per action, and 2 is correct again now that the BODY is correct. It was briefly
    -- 4, raised to compensate for a base of 6 -- a body that opened below both healers needed the climb to
    -- do two jobs, get her to competent and then past it. Her base is the mage template's 18 now
    -- (character_gyeom.lua), so the compensation would be a second fix for a problem already solved, and
    -- stacking them puts her at 34 in four actions: 2.1x the reference body, on the caster who also has
    -- the biggest single strike in her own kit waiting at the end of the same four.
    --
    -- SO THE CLIMB IS A BONUS, NOT THE REVEAL. She arrives a full mage and gets better while a fight
    -- runs -- 18 to 26 across four actions, with the Release reading off the top of it. "A long fight is
    -- study, not downtime" is a thing that happens to a competent body, which is the version of her that
    -- is true on the sheet as well as in the header.
    step = 2,
    onCast = function(ctx)
        local gained = ctx.addBonus("magicDamage", ctx.def.step)
        ctx.log("action", string.format("%s is a little better than she was.",
            (ctx.unit.char and ctx.unit.char.name) or "She"))
        return gained
    end,
}
