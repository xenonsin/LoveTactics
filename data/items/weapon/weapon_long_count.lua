-- A greatsword, so it winds up (docs/weapons.md). Its extra is that it remembers: every turn its bearer
-- has taken this battle (the `turnTaken` tally, Combat.tally) adds to the blow. It opens the fight as the
-- weakest greatsword in the game and ends a long one as the heaviest thing on the board.
--
-- Quest-only: `class` with no `price`.
--
-- It is the deliberate opposite of Saber's signature, and the header of
-- data/items/weapon/weapon_first_motion.lua is worth reading beside this one. That weapon pays for
-- OPENING a fight -- hardest into a full-health foe, and explicitly "not an accumulate-by-idling design,
-- because dead turns are downtime, not patience." This one pays for outlasting it. The two are not in
-- tension so much as in conversation: Saber's rule is that a bout is won in the first exchange, and the
-- Long Count is what the people who survived her first exchange went and had forged.
--
-- The distinction from idling still holds, and it matters. The tally counts turns TAKEN, not turns
-- passed -- walking, swinging, waiting, all of them count the same, so nothing here rewards standing
-- still. What it rewards is being alive on turn twelve, which is a thing the player earns with the whole
-- rest of the party rather than with this weapon.
return {
    name = "The Long Count",
    description = "Winds up, then falls on one tile -- harder for every turn you have taken in this battle.",
    flavor = "Its first swing of the day is an embarrassment. Nobody who has seen the twentieth brings that up.",
    sprite = "assets/items/long_count.png",
    type = "weapon",
    tags = { "greatsword", "slash", "physical", "melee" },
    hands = 2,
    class = "fighter",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 7,
        channel = 2,
        cost = { stat = "stamina", amount = 16 },
        -- Well under an iron greatsword's, and that is the floor rather than the number: this is what it
        -- lands on turn one, before the count has anything in it.
        damage = { 12, 14, 15, 17, 18, 20, 21, 23, 24, 26, 28 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local Combat = require("models.combat")
            -- +12% per turn taken, uncapped. Uncapped on purpose: a ceiling would turn the weapon back
            -- into an ordinary greatsword the moment it was reached, and the thing being sold here is a
            -- curve that keeps going. What bounds it is that battles end.
            local turns = Combat.tallyCount(fx.user, "turnTaken") or 0
            fx.damage(t, { amount = math.floor(fx.amount * (1 + 0.12 * turns)) })
        end,
    },
}
