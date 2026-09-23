-- THE SUPPLIANT'S BOWL: Luxuria's rule, cut down, and the Lust mini sin's whole reason to exist.
--
-- Luxuria's Reliquary Unbidden draws off the stamina and mana a foe HELD BACK on every hit
-- (data/traits/trait_rapture.lua) -- unconditionally, so a party husbanding resources is feeding her and
-- has no way to notice.
--
-- So the honour-guard floor asks first, takes less, and then stops asking:
--
--   from the bell   The Unasked: it drains whoever came back around to act having spent nothing, and
--                   heals on half of what it took (data/traits/trait_unasked.lua, gated on
--                   Combat.heldItsTurn, which reads the turn's spend tally rather than the pools)
--   at 50%          the condition comes off and it drains regardless, which is Luxuria's baseline --
--                   and the grove answers alongside it with two more Petal-Drifts and a harder touch
--
-- THAT IS THE RULE FOR THE WHOLE TIER: a mini sin's second phase is its general's first. The threshold
-- lives on the trait (`stopsAskingBelow`) rather than in the phase list below, because a trait cannot be
-- granted mid-fight -- data/traits/trait_boss_phases.lua carries no `trait` response, which is the same
-- wall the Cold Forge hits for Wrath -- and the alternative, a lesser copy of Rapture bolted on at the
-- threshold, is exactly what this tier is written against. The two numbers have to agree, so
-- tests/greed_lust_circle_spec.lua pins them to each other; the phase's own responses are what puts the
-- line in the log at the moment the asking stops.
--
-- She is the Unbidden -- the one who was never asked. This one asks: named for the office rather than
-- for the mechanic, which is how the whole tier is named.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Offered Nothing",
    description = "Drains the stamina and mana of a foe that spent nothing, heals for half, and once wounded drains regardless.",
    flavor = "It has been holding the bowl out for a very long time and has stopped minding what goes in.",
    sprite = "assets/items/offered_nothing.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_unasked", "trait_boss_phases" },
    phases = {
        -- The circle's own chaff is deleted (2026-09-22), so the threshold summons the nearest
        -- surviving body on this ground rather than nothing at all.
        --
        -- IT REACHED FOR ACT 0's IMP FOR A DAY, and that is what forced the prologue's demons onto
        -- their own `_tutorial` blueprints (see data/characters/character_demon_imp_tutorial.lua). One
        -- body cannot be both the thing that dies to the first sword stroke in the game and the thing a
        -- mini sin calls in at half health: the imp is pinned to blueprint level for the lesson's sake,
        -- so down here it would have arrived as two 14-health bodies and been chaff in the literal
        -- sense of costing nothing to clear.
        --
        -- So it summons LUST'S OWN smallest body instead -- the lesser succubus is written as "the
        -- cheapest possible statement" of the circle's third animal, and Lust's own stops already field
        -- her as traffic. Note that she brings the charm kit with her, which two imps did not, so this
        -- is a harder threshold than the line it replaces. Nothing carries this bowl today (the
        -- Suppliant is deleted and Lust's lieutenant slot holds a stand-in -- see
        -- tests/greed_lust_circle_spec.lua), so it is inert until somebody seats that slot; whoever does
        -- owes this count a look rather than inheriting it.
        { at = 0.5, responses = {
            { kind = "summon", id = "character_lesser_succubus", count = 2 },
            { kind = "bonus", stat = "magicDamage", amount = 6 },
            { kind = "log", text = "The Suppliant stops asking." },
        } },
    },
}
