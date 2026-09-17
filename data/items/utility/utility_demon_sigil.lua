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
--   33%  it stops roaring, turns FAST (status_hasted), ENRAGES (the wrath curve), and MARKS ROWAN
--        (status_champion_fixation). On its next turn it crosses the board and puts her down. It now
--        hunts your softest body, and it has just removed the one body that stood in front of them.
--
-- WHY THE STAGE ANNOUNCES ITSELF BY KILLING THE KNIGHT. Stage 3's authored answers were all Rowan --
-- taunt it onto her, let Oathward intercept, sustain behind her -- so felling her is the stage stating
-- that this one is not answered the way the last two were. It is also the game's first WOUND, inflicted
-- on somebody the player has fought beside since the first scene, which is what the Cathedral beat after
-- this fight is written from (states/prologue.lua): the mechanic is introduced by happening to a person
-- rather than by a tooltip. See models/combat.lua's Combat.fell for why it cannot be parried, warded or
-- revived -- a scripted beat a player can answer is one they will replay the fight trying to answer.
--
-- IT FIRES AT 33% AND NOT 66% FOR AN ARITHMETIC REASON. The party here is two bodies, the avatar and
-- Rowan, putting roughly 40 a round into 150 health (character_demon_champion.lua does this sum). Felled
-- at 66% the avatar finishes 100 health alone through the Roar AND the Fixation -- five rounds solo, and
-- a loss restarts the fight, so the player loops on something the script made unwinnable. At 33% it is
-- about 50 health: two or three rounds, alone, which is a climax.
--
-- THE FIXATION ENTRY IS PROLOGUE-ONLY, and this relic is the one thing standing between that and a bug.
-- The Champion's header offers it as a reusable mid-tier demon boss, and today the flight leg is its only
-- composer (states/prologue.lua). The moment a second fight fields it, Rowan -- who is in the party for
-- the rest of the game -- gets felled again, silently, in a scene nobody wrote. Reuse the Champion by
-- giving that fight a twin relic without this entry (the pattern character_saber_bout already uses for a
-- scripted variant), never by fielding this one. tests/demon_champion_spec.lua pins the count.
--
-- `bound = true` (models/item.lua): unstealable -- a rogue can't lift the Champion's whole fight off it
-- in one grab. No `class`/`price`: not gear anyone shops for.
return {
    name = "Ascendant Sigil",
    description = "Its bearer answers each wound with the next stage of the fight.",
    flavor = "Branded into the champion's chest by the Lord it serves. It does not come off.",
    sprite = "assets/items/sig_unappeased_heart.png", -- placeholder until its own art exists
    type = "utility", -- `bound` (not the type) is what locks it in the center cell
    class = "creature",
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
        -- The MARK goes on last, after the stage has turned and said so, so the log reads in the order
        -- the fight happens: the change, then who it has picked, then -- a turn later -- the proof.
        { at = 0.33, responses = {
            { kind = "clear",  id = "status_roaring" },
            { kind = "status", id = "status_hasted" },
            { kind = "enrage", magnitude = 20 },
            { kind = "log", text = "The Champion's wounds catch fire -- it fixes on the weakest of you." },
            -- ...AND IT MARKS HER, rather than killing her here. A phase crosses inside Trait.onDamaged,
            -- which runs inside the resolution of the PLAYER's blow -- so felling on the crossing put the
            -- teleport and the kill on top of the sword that caused them, with no turn boundary between.
            -- The status spends itself on the CHAMPION'S OWN TURN instead (Status.onTurnStart), which is
            -- where a scripted moment belongs: shake, blink, fell, with the board settled around it. It
            -- also buys the player a full turn of warning, because Rowan speaks when this lands.
            { kind = "status", id = "status_champion_fixation" },
        } },
    },
}
