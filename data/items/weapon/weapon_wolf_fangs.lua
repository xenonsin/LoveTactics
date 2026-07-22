-- A wolf's bite, and the pack's hit-and-run. It bites an adjacent foe and immediately gives ground a
-- tile. Because a melee counter is thrown only once the WHOLE action has resolved, and re-checks reach
-- at that point (data/traits/trait_melee_counter.lua, Combat.beginAnswers), stepping back out of
-- adjacency means the bite is answered by nothing: the wolf darts in, takes its bite, and is gone
-- before the jaws can snap back. A blocked step (a wall, an edge, a body behind it) simply doesn't
-- move, and then the wolf eats the counter like anything else -- give it room and it never does.
--
-- Distinct from the still bite of data/items/weapon/weapon_fangs.lua, which a stag or boar makes
-- standing its ground. Given to the wolf blueprints (grunt, alpha, wolfsong spirit) via startingItems;
-- the same fixed damage array and cheap stamina, so a wolf's initiative and reach are unchanged.
return {
    name = "Fangs",
    description = "Bites an adjacent foe, then gives ground a tile -- too quick to be countered.",
    flavor = "A wolf is born holding it. It does not trade blows; it takes one and is gone.",
    sprite = "assets/items/fangs.png",
    type = "weapon",
    tags = { "natural", "bite", "physical", "melee" },
    noSteal = true, -- a pickpocket cannot lift the teeth out of a wolf's head
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = { 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10 },
        effect = function(fx)
            fx.damage(fx.target)
            -- Give ground a tile away from the foe just bitten. Out of adjacency, the melee counter that
            -- would answer this blow finds nothing in reach to answer (see the header).
            fx.retreat(fx.target, 1)
        end,
    },
}
