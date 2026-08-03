-- Ira's heart, still beating for a fight that is over. It carries the general of Wrath's TWO rules:
--
--   * trait_wrath_rising (data/traits/wrath_rising.lua): every blow she survives is added to her next
--     one. (Distinct from data/items/armor/armor_mail_of_the_unappeased.lua, the mail YOU lift off her
--     body, which carries the same trait id for the player -- one rule, two relics.)
--   * trait_boss_phases (data/traits/trait_boss_phases.lua): the data-driven phase system, whose
--     `phases` script below sheds her human body for her demon one at a low-health threshold -- the
--     pact she chose coming due, the restraint breaking at the brink (see character_general_wrath_demon).
--
-- The phase trigger lives on THIS relic, which is `bound` to Ira and never leaves her, so it can never
-- reach the player: the mail they loot carries only trait_wrath_rising, so wearing Ira's rule never
-- turns the wearer into Ira.
--
-- `bound = true` (models/item.lua): it can never be stolen off her. A rogue that could pickpocket the
-- heart would end her fight in one lift -- bound forbids it. Her blueprint places it in her grid's center.
--
-- No `class`/`price`: not gear anyone shops for. The damage curve is flavor -- the player never forges
-- an enemy's relic -- so only its base value is ever seen.
local Curve = require("models.curve")

return {
    name = "The Unappeased Heart",
    description = "Increase damage by 1 per blow you take, plus up to +20 by the fraction of health missing.",
    flavor = "Ira's heart, still fighting for a freedom the fight can no longer give. It does not come off her.",
    sprite = "assets/items/sig_unappeased_heart.png",
    type = "utility", -- `bound` (not the type) is what locks it in place
    tags = { "signature", "relic" },
    bound = true,
    traits = { "trait_wrath_rising", "trait_boss_phases" },
    bonus = { damage = Curve.paired(2, 7) }, -- levels 0..10 (only base is ever used)
    -- The two-phase script (read by trait_boss_phases off ctx.item.phases). One threshold: at 40%
    -- health she sheds the human shape for her demon one. Deliberately low -- she wakes as she dies, so
    -- the pact answers on the same threshold her rule already lives on -- which also leaves the demon a
    -- real final third to be fought rather than a body swap on the killing blow. Because onDamaged fires
    -- only on a SURVIVOR, bursting her from above 40% to dead in one blow skips the transform entirely:
    -- the honest reading (you never had to face the second form), the same one every phased boss keeps.
    -- Add a { kind = "log", text = "..." } response here for the phase TELL when you write the line --
    -- left out for now so no unwritten prose ships. The transform fires with or without it.
    phases = {
        { at = 0.40, responses = {
            { kind = "transform", id = "character_general_wrath_demon" },
        } },
    },
}
