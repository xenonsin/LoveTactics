-- A sword, so it answers (docs/weapons.md). Its answer deals nothing at all: it opens a wound that
-- cannot be mended (data/traits/trait_unclosing_parry.lua -> status_unclosing_wound) and lets somebody
-- else do the killing.
--
-- Quest-only: `class` with no `price`.
--
-- The read it asks for is the enemy roster rather than the exchange. Against a warband with no healer it
-- is a sword that has stopped answering; against one built around a priest it removes the priest from
-- one body permanently, which is worth more than any number this blade could have cut for. That is the
-- point of pricing it in zero damage -- a weapon that both cut AND forbade healing would simply be the
-- best sword, and this one has to be the WRONG sword sometimes to be an interesting right one.
return {
    name = "The Unclosing Edge",
    description = "Strikes an adjacent foe. When struck in melee, opens a wound on the attacker that cannot be healed.",
    flavor = "It does not kill anyone. It only decides, quietly, which of them the priest is going to have to give up on.",
    sprite = "assets/items/unclosing_edge.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" },
    hands = 1,
    traits = { "trait_unclosing_parry" },
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
