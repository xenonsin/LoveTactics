-- En Garde: the fighter half of the Duelist (fighter x rogue). A stance of escalation -- each turn you
-- strike the SAME foe, the blow lands harder than the last; switch targets and the ardour resets to
-- nothing. No taunt, no lock: it does not make them stay, it rewards you for choosing to. The stacking
-- lives on the striker (u.enGardeTarget / u.enGardeStacks), read and bumped on each cast, so the bonus
-- is genuinely "this is the fourth time I have come for you" rather than a status anyone can Cure off.
return {
    name = "En Garde",
    description = "Strikes a foe; each consecutive strike on the SAME foe hits harder. Switch targets and it resets.",
    flavor = "The first exchange teaches. The fourth one kills. He is only ever interested in the fourth.",
    sprite = "assets/items/ability_en_garde.png",
    type = "ability",
    tags = { "slash", "physical" },
    class = "fighter",
    discipline = "duelist", -- fighter x rogue; the Duel-stance mechanic's first stock
    price = 260,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        damage = { 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
        effect = function(fx)
            local u = fx.user
            if u.enGardeTarget == fx.target then
                u.enGardeStacks = math.min((u.enGardeStacks or 0) + 1, 5)
            else
                u.enGardeTarget = fx.target
                u.enGardeStacks = 1
            end
            local perStack = 3 + fx.level -- how much each held exchange is worth; grows with the forge
            local bonus = (u.enGardeStacks - 1) * perStack
            fx.damage(fx.target, { amount = fx.amount + bonus })
        end,
    },
}
