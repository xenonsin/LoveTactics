-- Shared Burden: swear yourself to one ally, and take half of everything that reaches them.
--
-- The knight's third guard verb, and the only one with RANGE. Oathward covers whoever is standing
-- beside you and Martyr's Vow throws you in front of a killing blow -- both are a body in a doorway,
-- and both stop working the instant the line moves. This one is a promise instead of a position: it is
-- sworn once, at 3 tiles, and then holds wherever the two of you end up. Guard the archer on the far
-- ridge, or the mage you have no intention of standing next to all fight.
--
-- What it costs is the thing the other two get for free: the knight cannot parry, dodge or armor away
-- its half. The bond's toll lands raw (Combat.shareBurden), past every reflex the knight owns, which
-- makes this an ability that spends the knight's health as a resource rather than its position. A
-- knight at full health can carry a fragile ally through a battle; one at a third cannot, and swearing
-- anyway is how a party loses two members to one fireball.
--
-- Ends when its duration runs out, or the moment the knight falls -- a dead swearer's ward is simply
-- released (the status strips itself; see Combat.shareBurden's first refusal).
--
-- Self-target is refused: a bond with yourself is arithmetic, not a promise.
return {
    name = "Shared Burden",
    description = "Bonds an ally: half of every wound they take is borne by you instead, wherever you stand.",
    flavor = "The oath does not say 'if I am beside you'. She has read it more carefully than most.",
    sprite = "assets/items/ability_aegis.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "impact" },
    class = "knight",
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "unit",
        range = 3,
        speed = 4,
        support = true, -- a promise, not a strike
        cost = { stat = "stamina", amount = 10 },
        effect = function(fx)
            local ward = fx.target
            if not ward or ward == fx.user or ward.side ~= fx.user.side then return end
            -- Duration scales with the forge; the SHARE deliberately does not. A better-kept oath is
            -- kept longer, never more cheaply -- half is what the promise says, at every level.
            local st = fx.applyStatus(ward, "status_shared_burden", { duration = 30 + 2 * fx.level })
            if st then st.bonded = fx.user end -- who carries the other half
        end,
    },
}
