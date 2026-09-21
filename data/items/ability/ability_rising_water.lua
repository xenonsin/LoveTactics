-- Rising Water: Nethrys's fight, and the only cast in the game that edits the board.
--
-- Every shallow tile in the square she names becomes a channel (Combat.floodTile via fx.flood), and
-- anything standing in one goes under. The board you deployed onto stops being the board you are
-- standing on, one cast at a time.
--
-- IT ONLY EVER DEEPENS WATER, which is enforced one layer down rather than here -- a verb that could
-- open a hole under a company standing on dry ground would be able to delete them with no warning and
-- no counter. Cast over a board with no shallows on it, this does nothing at all, and that is the
-- correct outcome: she is the Mere's boss, and the Mere fights in water.
--
-- SO THE COUNTERPLAY IS A PLACE, not a resource. Stand away from the ford and the cast is spent; stand
-- on it because it was the fast route to her and the cast is the fight. That is the same decision the
-- whole faction is built on, made once more at the top of the ladder.
--
-- AND IT COSTS HER A TURN, which is why this is a cast rather than phase machinery. A phase engine
-- (trait_boss_phases, and the Demon Sigil that ships it) is the right shape for a body whose fight
-- changes at thresholds -- a clock nobody can touch. Hers changes every turn she is GIVEN, so a company
-- that pressures her hard enough never sees the board move. A boss whose board-warping is on a timer is
-- a timer; one that spends a turn is a decision.
--
-- No damage: what it does to the bodies in the water is not a blow, it is the ground leaving.
return {
    name = "Rising Water",
    description = "Every shallow tile nearby becomes deep water. Anything standing in one goes under.",
    flavor = "She is not doing anything. She is simply no longer holding it back.",
    sprite = "assets/items/rising_water.png",
    type = "ability",
    tags = { "water", "magical" },
    class = "creature", -- a boss's own rule: no shelf, no price, no depth (docs/bestiary.md)
    noSteal = true,
    bound = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        speed = 6,
        cost = { stat = "mana", amount = 12 },
        aoe = { shape = "square", size = 3 },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                fx.flood(c.x, c.y)
            end
        end,
    },
}
