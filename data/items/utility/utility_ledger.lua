-- Gyeom's signature relic (docs/story.md, "The Arcanum": the mage answers pride with humility). A
-- grimoire she writes herself -- the build-around at the center of her loadout grid, and her whole
-- character in one item: she is not a prodigy, she is the sum of her practice.
--
-- It carries her rule as a passive (data/traits/trait_ledger_diligence.lua): every action she takes lifts
-- her magic a little and keeps it, so she peaks LATE -- the exact inverse of Saber's one-motion front-load
-- (data/items/weapon/weapon_first_motion.lua). A long fight is study, not downtime.
--
-- Its own answer is concealment made a verb: RELEASE. It does nothing until she has put in the work --
-- committed to four actions ("cast", banked by Combat.useItem, so a staff swing counts as readily as a
-- spell) -- and only then may the suppression drop and the banked practice land at once, on the enemy that
-- took her for a weak mage. The conditional-signature system greys it with a "Take 4 actions (n/4)" badge
-- -- her diligence is the flavor, but the badge is the only place the requirement is ever stated, so it
-- names the deed and lets `flavor` carry her voice -- until earned, and re-locks after each use
-- (Combat.unlockMet / itemBlockReason), exactly as the Knight's Sworn Aegis re-locks after its sweep
-- (data/items/armor/armor_sworn_aegis.lua) and Amana's reliquary after its ward
-- (data/items/utility/utility_reliquary_kept_trust.lua). Because the Release scales off her MagicDamage,
-- every Diligence stack banked before it makes the reveal hit harder -- the practice is the payoff.
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. No `price`;
-- `class = "mage"` still tallies mage growth. Its magic floor climbs with the forge -- the little she lets
-- anyone see.
local Curve = require("models.curve")

return {
    name = "The Ledger",
    description = "Take four actions, then release what you kept back -- one strike, scaled by your practice.",
    flavor = "A book she is always writing and never finishes. She would tell you she has a great deal left to learn.",
    sprite = "assets/items/sig_ledger.png",
    type = "utility",
    tags = { "signature", "magical" },
    class = "mage",
    bound = true,
    traits = { "trait_ledger_diligence" },
    bonus = { magicDamage = Curve.ramp(2, 12) }, -- the suppressed floor; the little she shows
    activeAbility = {
        description = "Strikes for heavy magical damage.",
        target = "enemy",
        range = 3,
        requiresSight = true, -- a released bolt still needs a clear line
        speed = 5,
        cost = { stat = "mana", amount = 16 },
        unlock = { event = "cast", count = 4, text = "Take 4 actions" },
        -- The reveal: power + every MagicDamage stack Diligence banked getting here, minus Magic Defense.
        damage = Curve.ramp(16, 36),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
