-- CORROSIVE TOUCH: the slime's other verb, and the one that costs you something a fight cannot give
-- back. It deals no damage at all -- the payload is Corroding (data/status/status_corroding.lua),
-- which eats a piece of the target's kit every turn it holds until somebody washes it off.
--
-- WHY THE SLIME NEEDED A SECOND VERB. The body is immune to steel, so a melee company fighting one
-- is already doing nothing; a slime that could only lean on people was a fight the party lost by
-- attrition and nothing else. This makes the exchange cost something in BOTH directions, and it makes
-- the lesson literal rather than merely arithmetic: your weapons do not work here, and standing next
-- to it is eating them.
--
-- IT HAD TO BE A CAST AND COULD NOT BE A REFLEX, which is worth writing down because the reflex was
-- the first design and it cannot work. "Hit it with a blade and the blade corrodes" is the obvious
-- shape -- trait_spiteful_ichor's, one status along -- and an immune hit returns a true 0 from
-- Combat.dealFlatDamage BEFORE the trait dispatch (models/status.lua's immuneToDamage is read first).
-- So a slime never feels the sword that hits it, no onDamaged fires, and the reflex is dead against
-- exactly the attack it was written for. The threat has to be something the slime SPENDS A TURN ON.
--
-- ...WHICH IS ALSO THE BALANCE. A turn spent corroding is a turn not spent hitting anybody, and the
-- three gates below are the counterplay in the order a player meets them:
--
--   RANGE 1     it has to reach you, on a body that moves 3 and acts at speed 3. Kiting answers it
--               completely, which is the same answer the body already had (character_slime.lua).
--   WINDUP 1    telegraphed. A stun, a shove or a step out of reach denies it outright -- the
--               Bomblet's bargain (data/items/ability/ability_self_destruct.lua), one tick shorter
--               because this is ordinary traffic rather than a set-piece.
--   A DEBUFF    Corroding is `debuff = true`, so Cure and Panacea strip it, and every turn stripped
--               early is wear that never happens.
--
-- No `price` and `class = "creature"`: this is what the thing IS, not something it holds
-- (docs/bestiary.md). It is `noSteal` for the same reason, so it can never be lifted off the body.
return {
    name = "Corrosive Touch",
    description = "Inflicts Corroding.",
    flavor = "It is not trying to hurt you. It is trying to digest you, and it has started.",
    sprite = "assets/items/ability_corrosive_touch.png",
    type = "ability",
    class = "creature",
    tags = { "acid", "utility" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        -- A REAL SHARE OF THE POOL. 8 of a slime's 16 stamina at 2 a tick means it corrodes, then has
        -- to spend a while leaning on people before it can do it again -- so a fight against one is
        -- not a corrode every turn, and the player's window to walk away is a real one.
        cost = { stat = "stamina", amount = 8 },
        -- Telegraphed, and the whole of what makes this fair. Any knockback breaks a channel.
        windup = 1,
        effect = function(fx)
            fx.applyStatus(fx.target, "status_corroding")
        end,
    },
}
