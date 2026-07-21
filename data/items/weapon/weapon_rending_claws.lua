-- A demon grunt's natural weapon, and the first thing in this game that HURTS. Where an imp's Cinder
-- Spit is a nuisance thrown from two tiles off (data/items/weapon/weapon_cinder_spit.lua), this is a
-- body's whole weight swung at arm's length.
--
-- ITS POWER IS AIMED AT THE PROLOGUE, and specifically at one beat of it. The village lesson asks the
-- player to spend their ENTIRE mana pool on a Jolt purely to push a card down the turn order
-- (data/tutorials/village.lua, step 6), and nobody spends everything they have to delay something
-- that tickles. The grunt walks on, charges, and takes a THIRD of the avatar's health off in one
-- swing -- and the next card in the timeline is its. That is the argument for the Jolt, and it is
-- made in damage rather than in dialogue. Against the avatar's opening kit the arithmetic is exactly
-- the power below: 20 + the grunt's 8 Damage - the avatar's 8 Defense.
--
-- The counterweight is SPEED, and it is the same bargain Great Claws strikes: this lands once for
-- what a sword lands twice, so a grunt is a thing you get a turn to answer rather than a thing that
-- grinds you down. That is also why delaying its turn is worth a whole mana bar -- a slow, heavy
-- attacker is precisely the shape of foe the timeline can be used against, which is the lesson.
--
-- It deliberately does NOT parry. The grunt used to swing a borrowed iron sword and inherited the
-- sword's answer with it, so every blow the closing stretch of the lesson lands came back at the
-- party uninvited. A creature's body owes no family contract (see Item.ARCHETYPES) -- what a demon's
-- claws do is the demon's business, and these only rend.
return {
    name = "Rending Claws",
    description = "Rends an adjacent foe with a demon's whole weight behind it.",
    flavor = "An imp spits at you from across the lane. This one comes and takes hold.",
    sprite = "assets/items/rending_claws.png",
    type = "weapon",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6, -- heavy: it swings once where a swordsman swings twice
        cost = { stat = "stamina", amount = 12 },
        --        level:  0  1  2  3  4  5  6  7  8  9  10
        damage = { 20, 21, 22, 24, 25, 26, 28, 29, 30, 31, 32 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
