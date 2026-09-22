-- MARROWLIGHT: the aspect item. Whoever holds it fights the rest of the fight as their own skeleton.
--
-- IT IS NOT A CLASS AND IT IS NOT A BODY. Every other way this game has of making somebody undead
-- exchanges the person for a different one -- Raise Dead puts a Zombie on the board, a transform
-- (models/transform.lua) swaps `unit.char` for another blueprint's kit and stats -- and neither is what
-- "your knight, as a skeleton" means. This is a CHARM in one of nine grid cells. The name over the
-- portrait, the sheet, the kit, the discipline and the growth are all exactly whose they were; what
-- changed is two standing rules about the flesh, and the flesh is the part that left.
--
-- So it goes on anybody. `class` here is the vendor shelf and never an equip gate (docs/classes.md):
-- the Undercroft is where the rite is written down, not who is allowed to undergo it.
--
-- THE TWO RULES, and they are one bargain read from its two ends. Both arrive as traits, which is the
-- only door an innate comes through (data/items/utility/utility_grave_cold.lua makes the argument):
--
--   GRAVE-COLD     every heal aimed at this body wounds it for the same amount instead. The existing
--                  trait, unchanged and deliberately re-used rather than restated -- it is what the game
--                  already means by undead, it is what the zombie the Arcanum raises has, and a second
--                  file saying the same thing in different words is how two "undead" come to disagree.
--                  The tell is free: Combat.previewAbility asks the same question, so a priest hovering
--                  a heal over this body previews it in red with the number it will actually take.
--   BONE-KNIT      falling costs mana rather than the fight. See data/traits/trait_bone_knit.lua.
--
-- WHAT THE TRADE ACTUALLY IS, and the two halves are one loop rather than an upside and a downside.
-- The bearer cannot be healed by ANYTHING -- not the line's priest, not a draught, not a sanctified
-- zone, not a night at the Ward -- so it stops being a body the company maintains. What it gets instead
-- is that dying puts it back at FULL, for forty mana. Which means:
--
--     DYING IS THE ONLY WAY THIS BODY HEALS, AND THE PRICE IS PAID IN SPELLS NOT CAST.
--
-- So the skeleton is not tanky, it is *recurring*: it walks in with a fixed number of whole bars in its
-- pool and spends them by being killed. Chip damage cannot be answered except by finishing the job, and
-- the player is asked, every time, whether this is the death worth forty. That is a decision no other
-- cell in the game offers, and it is the reason this one is worth having.
--
-- THE FORGE DEEPENS THE POOL, which is the only track that made sense: the toll per rise is fixed and
-- legible (forty, more than the costliest spell in the game), so the upgrade cannot buy a cheaper death
-- -- it buys a longer candle. It is deliberately NOT enough to carry a body on its own: fifteen at the
-- top of the track is not half a rise, so a knight who wants this has to go and buy the mana shelf,
-- and a mage already has the pool and must decide what it is for. That is a synergy the player
-- assembles rather than a rung the item hands out, and on a knight it is the most interesting thing
-- the item does.
--
-- NOTHING LEFT TO BLEED is the one flat upside, and it is one line rather than the whole undead
-- package on purpose: poison and acid are already what data/items/utility/utility_tempered_gut.lua is
-- for, and an aspect that quietly contained a rival charm's entire content would be why nobody carries
-- the rival charm.
local Curve = require("models.curve")

return {
    name = "Marrowlight",
    description = "Consume 40 mana to rise at full health each time you fall. Every heal aimed at you wounds you instead.",
    flavor = "The rite takes about a minute and the flesh about a day. He said the second part was optional and then would not say for whom.",
    sprite = "assets/items/marrowlight.png",
    type = "utility",
    tags = { "charm", "dark" },
    -- The Undercroft's shelf: raising is the necromancer's craft, and this is that craft turned on the
    -- practitioner's own line rather than on somebody else's corpse.
    class = "necromancer",
    -- FOUND IN THE RIFT, NOT DEALT OVER A COUNTER (docs/shelf.md): no `price`, so a counter stocks it
    -- only once the company has carried one out.
    --
    -- The rung is the grade RANK and it is authored (tools/drop_tier.lua's own paragraph on why it
    -- survives the recut): models/balance.lua reads it as the power level, and this sits at the top of
    -- the ladder because that is what it is. The depth is the derived half -- `. drop-tier` puts it at
    -- 6 off a grade of 11.5, and that is the number here rather than a guess.
    unlockLevel = 13,
    traits = { "trait_grave_cold", "trait_bone_knit" },
    -- AND IT IS DRAWN. The bearer's own board token, composed again in bone with a skull struck over it
    -- (Character.spriteOf resolves `<sprite>_bone.png`; tools/char_compose.lua writes one beside every
    -- token). The aspect is the one thing in the game that changes what a body IS without changing which
    -- body it is, so it is also the one thing that had to change the picture and keep the silhouette.
    wearerSkin = "bone",
    -- The candle, not the toll. See the forge note above.
    maxBonus = { mana = Curve.ramp(5, 15) },
    statusImmunity = { "status_bleed" },
}
