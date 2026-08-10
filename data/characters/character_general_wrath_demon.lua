-- Ira's phase-two body: the bargain she made, come due, made flesh. The general of Wrath begins the
-- slot-10 fight (data/quests/colosseum/slot_10_general_wrath.lua) as the sullen human -- the woman who
-- wanted out, character_general_wrath -- and sheds into THIS shape at a health threshold, driven by
-- the phase script on her Unappeased Heart relic (data/items/utility/utility_unappeased_heart.lua's
-- `phases`, read by data/traits/trait_boss_phases.lua). It is the same unit in a new body: one tile,
-- one initiative slot, and -- the rule that keeps the fight honest -- one health bar. The pool carries
-- across by reference (models/transform.lua), so a general phased at 40% opens her demon stage already
-- more than half spent. The transform changes what she can DO, never how much killing her takes.
--
-- WHOSE PACT. Hers (docs/story.md, docs/wrath-line-beats.md, "Canon revised 2026-07-28"): she CHOSE
-- it, owned all her life and promised freedom and the strength to seize it. What she bought was an
-- uncontrollable rage -- a deeper cage. The demon is not something done to her; it is the freedom she
-- reached for turned inside out. Killing her is not an execution but a release: the last door left open
-- to a woman who can never walk off the sand any other way.
--
-- WHY IT SURFACES WHEN SHE IS DYING. For twenty years the sullen human held the leash. Her whole rule
-- is that the rage rises the nearer she is to death (data/traits/trait_wrath_rising.lua): the closer to
-- gone, the less of the person is left to hold it. So she does not transform when she is winning. She
-- transforms when she is almost gone -- the moment the restraint finally breaks and the bargain she
-- made finishes eating her.
--
-- The rage rule rides on a GRID RELIC (utility_unbound_heart), not the blueprint's `traits` field --
-- character-level traits are never instantiated onto the runtime char (models/character.lua copies no
-- `traits`; only items in the 3x3 grid grant them, per Trait.attach). So the demon's echo of the Heart
-- carries the curve, and it keeps compounding through phase two off the heavier base -- not banked once
-- at the swap and dropped. The Heart governs phase one; the Unbound Heart governs phase two, and the
-- pool they scale off is the single bar both share.
--
-- STATS. A step up from the human form (damage 18 -> 30, speed 4 -> 6, movement 4 -> 5): the governor
-- off. Still deliberately SOFT TO MAGIC (magicDefense 6, unchanged): the burst answer the whole line
-- taught has to stay real, or the transform reads as "now grind her for longer" instead of "end it".
-- Health here is only for hygiene / a standalone spawn -- on the real transform it is overwritten by
-- the pool that carries across.
return {
    name = "Ira, Unbound",
    kind = "demon",
    tier = 4,
    -- WHAT LEVEL THESE NUMBERS WERE WRITTEN FOR. This body is authored as the fight it is at the end
    -- of its line, and models/growth.lua scales it DOWN toward the shallows rather than growing it up
    -- from a base -- so a descent that deals this circle as floor 1 meets a smaller version of the
    -- same thing instead of an unkillable one. At this level the numbers below are exactly the
    -- numbers. See Growth.spawn.
    referenceLevel = 13,
    boss = true, -- still a quest objective: immune to execute (Coup de Grace) and Charm past the swap
    revivable = false, -- a demon does not go down and get up: no incapacitated window (docs, downed system)
    archetype = "aggressive", -- awake now, and hunting; explicit for readability
    sprite = "assets/chars/general_wrath_demon.png",
    portrait = "assets/portraits/general_wrath_demon.png", -- falls back to the path string if the art is missing
    stats = {
        health = 180, mana = 0, stamina = 30, -- health is ignored on transform (the pool carries across)
        damage = 30, magicDamage = 0, -- the unbound base; trait_wrath_rising still compounds it as she empties
        defense = 14, magicDefense = 6, -- soft to magic on purpose: the burst answer stays real
        movement = 5,
        speed = 6,
    },
    -- Her phase-two kit: the lifesteal greataxe she always carried (an innate 3-wide cleave that heals
    -- her a third of what it opens -- her sustain), beside the Unbound Heart (utility_unbound_heart, the
    -- rage rule; no Unappeased Heart here, since that one carries the phase trigger and a body that has
    -- already transformed must not try again), plus two moves that are only hers once the governor is off:
    --   * The Only Hour (ability_the_only_hour) -- her rule made a swing: a telegraphed strike that
    --     hits twice as hard the nearer she is to gone, which past the transform is exactly where she is.
    --   * Run You Down (ability_run_you_down) -- fast and hunting, she hauls a foe who backs off back
    --     into the trade her rule feeds on.
    startingItems = {
        "ability_run_you_down",    false,                   "ability_the_only_hour",
        "weapon_crimson_greataxe", "utility_unbound_heart",  false,
        false,                     false,                    false,
    },
    defaultAction = "weapon_crimson_greataxe",
    -- Basic tactics (models/ai.lua), top-to-bottom, first legal match wins. The ordering is what keeps
    -- Run You Down's target legal: it is only reached once no foe is adjacent, so the foe it hooks is
    -- always 2-4 tiles off (its own minRange/range band).
    ai = {
        -- A foe beside her: the signature, telegraphed and enormous the nearer she is to death.
        { priority = "high", act = "cast", item = "ability_the_only_hour",
          when = { subject = "nearest_foe", test = "within", value = 1 } },
        -- Nobody in reach, but one within the hook's throw: fetch the nearest back into the trade.
        { priority = "normal", act = "cast", item = "ability_run_you_down",
          when = { subject = "nearest_foe", test = "within", value = 4 } },
        -- Otherwise close and cleave with the greataxe, pressing the body nearest to falling -- no longer
        -- only once it is already under half: the human form waited for the wound; the demon hunts it.
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
