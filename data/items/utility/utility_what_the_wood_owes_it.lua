-- WHAT THE WOOD OWES IT: the reason hurting this animal is a mistake, and where its fight is written.
--
-- A bound centre-cell relic like every boss signature (compare utility_the_iron_in_him, which this
-- follows exactly), carrying both halves of what the Meandering Stag IS: the ground it leaves behind
-- it, and the one thing that happens when somebody takes it to half.
--
-- THE TRAIL IS THE WHOLE FIRST HALF OF THE FIGHT, and it costs nothing to build. `trail` on any item
-- in the grid is read by Combat.layTrail on every walked step (the seam Cinderstride Boots and five
-- others already use), so an animal whose entire turn is a move lays ground simply by doing the only
-- thing it does. It rides the hide rather than a weapon because there is no weapon -- this body cannot
-- strike anything, ever (`unarmed = false` on the blueprint) -- and because what it leaves is what it
-- IS rather than what it does.
--
-- SIXTY TICKS, far longer than any trail in the game (Cinderstride's fire runs 8, the Wellspring's
-- print 10). Those are laid to be used now. This one is laid to be COUNTED later: every tile still
-- standing at the threshold turns, and a print that quietly expired on turn four is a tile the company
-- never has to answer for. What they let it walk has to still be on the floor when the bill arrives.
--
-- THE SCRIPT IS ONE STAGE, and it is the only stage, because the fight has exactly one thing to say.
--
--   50%  THE WOOD ANSWERS. Two responses, in this order and in this same dispatch:
--
--        `ground` turns every square of New Growth on the board into Blight -- not the new ones, ALL
--        of them (Hazard.convert). The tiles the party has been standing on all fight because standing
--        on them was free healing are the tiles that just went wrong, and they went wrong everywhere
--        at once.
--
--        `transform` exchanges the body for character_vengeful_spirit -- same unit, same tile, same
--        health bar -- so the second half opens already half-spent and the bar does not jump when the
--        animal does.
--
-- GROUND BEFORE BODY, deliberately. The floor turning is what the transform is the CONSEQUENCE of, and
-- a player watching the beat should see the board go first: the wood answers, and then the thing the
-- wood is answering with stands up. Reversed, it reads as a monster casting a spell.
--
-- WHY ONE STAGE AND NOT TWO. The Iron in Him argues the same and for the same reason: a middle stage
-- would soften the one moment this fight has. There is also nothing a second threshold could say --
-- the board has already been converted, and it cannot be converted twice.
--
-- AND IT FIRES ONLY ON A SURVIVOR (trait_boss_phases, onDamaged). A blow that kills the stag outright
-- from above half never turns the board at all, and the blooms stay blooms. That is the engine as
-- written, kept on purpose: kill it cleanly in one stroke and nothing bad happens; kill it slowly and
-- you make the thing that comes next. At 130 health from 50% it is not reachable in practice -- it is
-- a door left open rather than a road anybody walks.
--
-- `bound = true` (models/item.lua): unstealable. No `class`, no `price`, no `dropTier` -- per
-- docs/bestiary.md creature kit carries no axis at all, so neither the drop pool nor a counter can
-- mint it, and nobody carries a boss's whole fight home.
return {
    name = "What the Wood Owes It",
    description = "Green comes up where it walks. Wound it at half, and all of it turns at once.",
    flavor = "It has been here longer than the trees have. They have noticed.",
    sprite = "assets/items/utility_what_the_wood_owes_it.png",
    type = "utility", -- `bound` (not the type) is what locks it in the centre cell
    class = "creature",
    tags = { "signature", "relic", "nature" },
    bound = true,
    noSteal = true,
    traits = { "trait_boss_phases" },
    -- Laid on the tile it just LEFT, always (Combat.layTrail), so it never stands in its own print --
    -- which is not a mercy here, it is simply where a trail goes. The duration is stated rather than
    -- left to the hazard's own, because layTrail passes this figure through and a reader comparing the
    -- two files should not have to guess which one wins.
    trail = { hazard = "hazard_bloom", duration = 60 },
    phases = {
        { at = 0.5, responses = {
            { kind = "log", text = "Something goes out of the wood, all at once, and the green turns under your feet." },
            { kind = "ground", from = "hazard_bloom", to = "hazard_blight" },
            { kind = "transform", id = "character_vengeful_spirit" },
        } },
    },
}
