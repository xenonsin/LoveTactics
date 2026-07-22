-- Gyeom's signature relic (docs/story.md, "The Arcanum": the mage answers pride with humility). A
-- grimoire she writes herself -- the build-around at the center of her loadout grid, and her whole
-- character in one item: she is not a prodigy, she is the sum of her practice.
--
-- It carries her rule as a passive (data/traits/trait_ledger_diligence.lua): every action she takes lifts
-- her magic a little and keeps it, so she peaks LATE -- the exact inverse of Saber's one-motion front-load
-- (data/items/weapon/weapon_first_motion.lua). A long fight is study, not downtime.
--
-- Its own answer is concealment made a verb: RELEASE. It does nothing until she has done her best enough
-- times -- committed to four actions ("cast", banked by Combat.useItem) -- and only then may the suppression
-- drop and the banked practice land at once, on the enemy that took her for a weak mage. The conditional-
-- signature system greys it with a "Do your best (n/4)" badge until earned and re-locks after each use
-- (Combat.unlockMet / itemBlockReason), exactly as the Knight's Sworn Aegis re-locks after its sweep
-- (data/items/armor/armor_sworn_aegis.lua) and Amana's reliquary after its ward
-- (data/items/utility/utility_reliquary_kept_trust.lua). Because the Release scales off her MagicDamage,
-- every Diligence stack banked before it makes the reveal hit harder -- the practice is the payoff.
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. No `price`;
-- `class = "mage"` still tallies mage growth. Its magic floor climbs with the forge -- the little she lets
-- anyone see.
return {
    name = "The Ledger",
    description = "Do your best four times over, then release what you kept back -- one strike, scaled by your practice.",
    flavor = "A book she is always writing and never finishes. She would tell you she has a great deal left to learn.",
    sprite = "assets/items/sig_ledger.png",
    type = "utility",
    tags = { "signature", "magical" },
    class = "mage",
    bound = true,
    traits = { "trait_ledger_diligence" },
    bonus = { magicDamage = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 } }, -- the suppressed floor; the little she shows
    activeAbility = {
        description = "Releases the strength she kept hidden: one heavy magical strike on a foe.",
        target = "enemy",
        range = 3,
        requiresSight = true, -- a released bolt still needs a clear line
        speed = 5,
        cost = { stat = "mana", amount = 16 },
        unlock = { event = "cast", count = 4, text = "Do your best" },
        -- The reveal: power + every MagicDamage stack Diligence banked getting here, minus Magic Defense.
        damage = { 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
