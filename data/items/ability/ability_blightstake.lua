-- The Blightstake: a barbed stake dressed in rotted cloth, hammered into the ground where it will be
-- in the way. It cannot move. Every so often it spits something foul at whatever is nearest
-- (data/characters/character_blightstake.lua).
--
-- EVERY OTHER SUMMON IN THIS GAME IS A BODY THAT FIGHTS -- a wolf, an elemental, a raised zombie -- and
-- all of them answer the same question: "I want another attacker." This answers a different one: "I
-- want that corridor to cost something to walk down, for the rest of the battle, without me standing
-- in it." Three stakes are not three fighters. They are a SHAPE on the board, and the shape is what
-- the hunter is buying.
--
-- Its bite is poison rather than damage, on purpose. A stake that dealt real numbers would just be a
-- cheap archer, and the Lodge already sells archers. Poison is a clock -- and four clocks the enemy
-- has to walk past is a categorically different threat from four archers it has to shoot, because the
-- poison does not stop when the stake does.
--
-- It takes turns, unlike the banner and the vigil, which is why it is `control = "none"` but NOT
-- `timeless`: it rides the initiative order like any other combatant, slowly (speed 9, against a real
-- archer's 3-5). A stake is roughly one spit for every two shots.
--
-- ONE AT A TIME through the ordinary `activeSummon` claim -- so a forest of stakes is built by having
-- them cut down, which is turns the enemy spent on furniture instead of on the party. That is the
-- item's real return, and it is collected whether or not any single stake survives.
--
-- ADJACENCY: a `bow` beside it. The stake is set the way a hunter sets anything -- from cover, at a
-- distance, with a shot ready for whoever comes to pull it out.
return {
    name = "The Blightstake",
    description = "Hammers in a rooted stake that spits poison at whatever comes nearest.",
    flavor = "The Lodge calls it a marker. Nothing that has walked past one has agreed.",
    sprite = "assets/items/ability_blightstake.png",
    type = "ability",
    tags = { "poison" },
    class = "hunter",
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 4,
        speed = 4,
        cost = { stat = "stamina", amount = 12 },
        support = true,
        requiresAdjacent = { tag = "bow" },
        effect = function(fx)
            fx.summon("character_blightstake", fx.tx, fx.ty, {
                control = "none", duration = 35 + 4 * fx.level,
            })
        end,
    },
}
