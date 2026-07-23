-- A sword, so it answers (docs/weapons.md). Its answer silences the attacker's own kit
-- (data/traits/trait_sundering_parry.lua -> status_sundered): every trait, guard and reflex that body
-- carries goes quiet for the window, including whatever it was about to answer this blade with.
--
-- Quest-only: `class` with no `price`.
--
-- What it is for is the shape of fight the counter economy otherwise produces: two armoured answerers
-- standing adjacent, both throwing reflexes, both paying doubling stamina for them, and nothing moving.
-- This unplugs one side of that. Against a beast that carries no traits at all it is a sword that has
-- stopped answering -- the same wager The Unclosing Edge makes, pointed at a different half of the
-- enemy roster, which is why the two are worth carrying as a pair rather than as alternatives.
return {
    name = "Sunderer's Answer",
    description = "Strikes an adjacent foe. When struck in melee, silences every trait, guard and reflex the attacker carries.",
    flavor = "Everything they were carrying is still on them. None of it is listening.",
    sprite = "assets/items/sunderers_answer.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" },
    hands = 1,
    traits = { "trait_sundering_parry" },
    class = "knight",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
