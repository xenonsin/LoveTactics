-- THE BEAST-LINE: the hinge between the human and creature halves of the bestiary.
--
-- A human company that fields beasts, which is exactly the relationship the bestiary contract states --
-- a wolf is not a Beastmaster, a wolf is what a Beastmaster HAS (tests/bestiary_spec.lua). The totem
-- anchors ground, the pack fights inside its aura, and the alpha keeps the grunts coming; killing the
-- two humans is the answer and killing wolves is the trap.
--
-- It is also the reason wild fauna belongs on every floor rather than in one circle: the player meets
-- wolves as somebody's tool here, and as weather everywhere else.
return {
    name = "The Beast-Line",
    kind = "combat",
    weight = 3,
    minDay = 4,
    composition = function(ctx)
        local list = {
            "character_totemist",    -- multiplier: the totem, and the ground the pack is worth more on
            "character_beastmaster", -- setup: the bond that keeps the pack arriving
            "character_wolf_alpha",  -- payoff: the pack's own force multiplier, inside the aura
            "character_wolf_grunt",
        }
        for _ = 1, 1 + math.floor((ctx.day or 1) / 11) do list[#list + 1] = "character_wolf_grunt" end
        return list
    end,
}
