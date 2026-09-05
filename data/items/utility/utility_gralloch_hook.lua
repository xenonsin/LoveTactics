-- THE GRALLOCH HOOK: Gula's rule, cut down, and the mini sin's whole reason to exist.
--
-- Gula's Maw of the Unfed heals her on EVERY blow she lands (data/traits/trait_ravenous.lua), so a long
-- trade fattens her and the counterplay is to starve her -- burst, kill clean, never grind. That is a
-- fine rule for the thing at the bottom of a circle and a miserable one to meet cold: a player who has
-- never seen it reads a boss that will not go down and cannot tell why.
--
-- So the honour-guard floor teaches it the cheap way and then, at half health, shows the real thing:
--
--   from the opening bell   Engorge -- it feeds when something DIES nearby (trait_engorge.lua)
--   at 50%                  Ravenous -- it feeds on every blow it lands, which is Gula's baseline
--
-- THAT IS THE RULE FOR THE WHOLE TIER: a mini sin's second phase is its general's first. You spend the
-- circle's first floor learning the sin the slow way, watch it turn up for the back half of one fight,
-- and then take the stair and meet the thing that has had it since the opening bell. The general
-- becomes a recognition rather than a surprise, which is what two floors per circle is for.
--
-- A gralloch is the act of opening a carcass in the field. Gula's own knife is named for it
-- (data/items/weapon/weapon_gralloch_knife.lua) -- the mini sin is named for her tool rather than for
-- her rule, so the family reads off the name without the mechanic being written in it.
--
-- Natural kit, so: no class, no price, noSteal (tests/bestiary_spec.lua). It is a hooked thing grown
-- into an animal, not a relic anybody could pick up.
return {
    name = "Gralloch Hook",
    description = "Feeds when something falls nearby, and on every blow once it is wounded.",
    flavor = "The Lodge left it in the fen with the rest of the offal. It has been opening things ever since.",
    sprite = "assets/items/gralloch_hook.png",
    type = "utility",
    class = "creature",
    dropTier = 2,
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_engorge", "trait_boss_phases" },
    phases = {
        -- Half: the appetite stops waiting for things to die on their own.
        { at = 0.5, responses = {
            { kind = "bonus", stat = "damage", amount = 3 },
            -- Red Thirst is heal-on-hit, which IS Ravenous by another road -- both fold into the same
            -- lifesteal path in models/combat.lua. Its authored duration is ~2.5 turns, which is a
            -- flourish rather than a phase; overridden to outlast any fight, because the promise this
            -- phase makes is "from here on, it is Gula" and a rule that quietly lapsed would be a lie.
            { kind = "status", id = "status_red_thirst", opts = { duration = 999 } },
            { kind = "log", text = "The Gralloch stops waiting for you to finish them." },
        } },
    },
}
