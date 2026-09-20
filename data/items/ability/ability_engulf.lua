-- ENGULF: the King flows over the arm, and the arm comes back out empty. Inflicts Disarm
-- (data/status/status_disarmed.lua) and nothing else -- no damage, no shove, no wound.
--
-- THE KING'S ALONE, and the size is the reason. A common slime can corrode what it touches
-- (data/items/ability/ability_corrosive_touch.lua); it takes a body this big to close over a whole
-- sword arm, and giving the ordinary fen traffic a disarm would mean a party of four losing four
-- weapons to a stop that is meant to be a lesson rather than a reversal.
--
-- IT IS THE SECOND HALF OF THE SAME SENTENCE the body has been saying since the first fen ooze: your
-- steel does not work here. The slime says it by being uncuttable; this says it by taking the steel
-- away. Aimed at the body that lives by its weapon, which against a slime is the body already having
-- the worst fight of its life -- and that is the intended cruelty, not an oversight. The answer is
-- not to bring a better sword.
--
-- THE COUNTERPLAY IS THE SAME THREE GATES the Corrosive Touch keeps, and one more that is the
-- status's own:
--
--   RANGE 1     it has to reach you, on a body that moves 3 and acts at speed 3.
--   WINDUP 1    telegraphed, so a stun, a shove or a step out of reach denies it outright.
--   A DEBUFF    Disarmed is `debuff = true` -- Cure and Panacea strike it off.
--   THE FISTS   Disarmed takes the blade and not the hand (see the status): a disarmed body still
--               punches, still casts, still drinks. It is a tax on one turn's damage, never a body
--               removed from the fight -- which is what keeps it from being a strictly better Stun.
--
-- No `price` and `class = "creature"`: this is what the thing IS, not something it holds. It is
-- deliberately NOT data/items/ability/ability_disarm.lua, which is the Undercroft's priced trick and
-- belongs to a shelf -- a creature carries natural kit only (docs/bestiary.md), and a boss handing
-- over a rogue ability for being killed is the exact leak tests/spoils_spec.lua exists to refuse.
return {
    name = "Engulf",
    description = "Inflicts Disarm.",
    flavor = "It closes over the wrist without hurrying. There is no grip to break.",
    sprite = "assets/items/ability_engulf.png",
    type = "ability",
    class = "creature",
    -- NOT `acid`, which the first cut carried and which was wrong twice. It is wrong in the fiction --
    -- this is a grapple, and nothing about it dissolves anything; the corrosion is the other cast's
    -- whole job. And it is wrong on screen: the icon composer tints an ability by its element tag, so
    -- two casts on one grid that both said `acid` composed the SAME green glyph, and the King's two
    -- abilities were a matched pair the player could not tell apart in the slot or in the telegraph.
    tags = { "utility" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        -- 10 of the King's 24 stamina at 2 a tick: it engulfs, then owes the board several turns of
        -- ordinary work before it can do it again. A King that could disarm every turn would simply
        -- be removing the party's weapons one per turn, which is a countdown rather than a fight.
        cost = { stat = "stamina", amount = 10 },
        windup = 1,
        effect = function(fx)
            fx.applyStatus(fx.target, "status_disarmed")
        end,
    },
}
