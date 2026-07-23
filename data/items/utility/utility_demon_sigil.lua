-- The Demon Champion's whole fight, branded into its chest. A bound center-cell relic (like every
-- boss signature -- compare Ira's data/items/utility/utility_unappeased_heart.lua) carrying TWO rules:
--
--   * trait_boss_phases -- the data-driven phase system (data/traits/trait_boss_phases.lua). The
--     `phases` table below is the Champion's own script; the trait reads it off this relic, so the same
--     trait id drives every future boss and each one's relic carries its own stages.
--   * trait_melee_counter -- the phase-1 "warded advance" guard. It ripostes the first adjacent melee
--     each round with the Champion's claws, so rushing in and swinging is punished and the answer the
--     road taught -- the bow, from the high ground -- is the safe opening. It runs all fight (the
--     throughline that keeps Stun, which suppresses reactions, and Disarm, and shoves worth using), but
--     it self-limits: each answer costs an escalating stamina price, so a party can bait it dry.
--
-- The two-stage script:
--   66%  the guard's spell is spoken and the Champion starts winding up the Roar (status_roaring, which
--        its AI cast-rule reads) -- it calls Bomblets and quickens itself unless you break the channel.
--   33%  it stops roaring, turns FAST (status_hasted) and ENRAGES (the wrath curve): it now hunts your
--        softest body, and a trade-blows race is one you lose. Taunt it, defang it, sustain, and finish.
--
-- `bound = true` (models/item.lua): unstealable -- a rogue can't lift the Champion's whole fight off it
-- in one grab. No `class`/`price`: not gear anyone shops for.
return {
    name = "Ascendant Sigil",
    description = "Its bearer answers each wound with the next stage of the fight.",
    flavor = "Branded into the champion's chest by the Lord it serves. It does not come off.",
    sprite = "assets/items/sig_unappeased_heart.png", -- placeholder until its own art exists
    type = "utility", -- `bound` (not the type) is what locks it in the center cell
    tags = { "signature", "relic" },
    bound = true,
    traits = { "trait_boss_phases", "trait_melee_counter" },
    phases = {
        -- 66%: guard's work done, the Roar threat begins.
        { at = 0.66, responses = {
            { kind = "status", id = "status_roaring" },
            { kind = "log", text = "The Champion draws breath, and the tree line stirs behind it." },
        } },
        -- 33%: stop roaring; turn fast and enrage; fix on the weakest (its AI already presses lowest-HP).
        { at = 0.33, responses = {
            { kind = "clear",  id = "status_roaring" },
            { kind = "status", id = "status_hasted" },
            { kind = "enrage", magnitude = 20 },
            { kind = "log", text = "The Champion's wounds catch fire -- it fixes on the weakest of you." },
        } },
    },
}
