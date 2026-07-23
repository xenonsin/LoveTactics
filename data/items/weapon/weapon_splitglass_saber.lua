-- A sword, so it answers (docs/weapons.md). Unlike the three parries beside it this one still CUTS --
-- and the same motion closes Splitglass over the swordsman (data/traits/trait_splitglass_parry.lua ->
-- status_splitglass), turning aside the next few hits of any kind entirely.
--
-- Quest-only: `class` with no `price`.
--
-- So answering is also warding, and the weapon runs inside-out: the more foes test the guard, the harder
-- the guard gets to test. What stops that being a wall you simply stand behind is the price every answer
-- in this game pays -- Trait.answerCost doubles it per answer thrown in a round (docs/weapons.md), so the
-- glass goes up against the first attacker of a press and the pool is empty by the third. It buys the
-- opening exchange, never the press.
--
-- Note the ward covers hits "of any kind", which is wider than the reflex that raised it: the parry only
-- fires on a melee blow it can reach, but the glass it leaves also eats an arrow. That is deliberate and
-- it is the whole trade -- you have to let something walk up and hit you to become hard to shoot.
return {
    name = "Splitglass Saber",
    description = "Strikes an adjacent foe, and answers a melee blow by cutting back and raising Splitglass on yourself.",
    flavor = "The Bastion's smiths never agreed on whether the glass in the name is what it is made of or what it leaves behind.",
    sprite = "assets/items/splitglass_saber.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" },
    hands = 1,
    traits = { "trait_splitglass_parry" },
    class = "knight",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        -- Under an iron sword's: this one answers with a cut AND a ward, so it gives up Power for the
        -- half of the reflex the others do not get.
        damage = { 5, 6, 6, 7, 8, 9, 10, 10, 11, 12, 13 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
