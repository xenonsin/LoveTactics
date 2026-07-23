-- A sword, so it answers (docs/weapons.md). Its extra is WHO the answer pays: every parry it throws also
-- braces every ally standing beside the warden (data/traits/trait_wardens_parry.lua), so the swordsman's
-- private exchange becomes the line's cue to close up.
--
-- Quest-only: `class` with no `price`, so it tallies toward knight growth and no vendor stocks it.
--
-- It is the sword-shaped member of the `covers` family -- armor_oathkeeper_shield spreads a brace,
-- weapon_crozier spreads mana, and this spreads the brace off a REFLEX rather than off a spent turn.
-- That difference is the whole reason it exists: the shield and the crozier both cost you your action to
-- share anything, and this one shares whatever the enemy chose to provoke. You do not decide when it
-- fires; they do. Which makes it the only weapon in the game that gets better the more the enemy commits.
return {
    name = "The Warden's Tongue",
    description = "Strikes an adjacent foe. Every parry it throws also braces the allies beside you.",
    flavor = "A warden does not call the line to close. A warden gets hit, and the line closes.",
    sprite = "assets/items/wardens_tongue.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" },
    hands = 1,
    traits = { "trait_wardens_parry" },
    class = "knight",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }, -- an iron sword's: the answer is the extra
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
