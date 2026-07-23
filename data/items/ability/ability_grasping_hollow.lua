-- The Grasping Hollow: the knight opens a patch of sucking ground. It deals nothing. It roots whatever
-- steps into it (data/hazards/hazard_grasping_hollow.lua).
--
-- Every other zone in this catalog prices OCCUPANCY -- fire hurts you for standing in it, quicksand
-- taxes you for standing in it -- so all of them are answered by not going there, and all of them are
-- worth nothing against a line that was holding its ground anyway. This prices the CROSSING. It is
-- worthless against an enemy that stays put and decisive against one that has to come to you, which is
-- exactly the fight a knight is trying to have. Sloth does not kill you; it decides where you stand.
--
-- The root LINGERS (see the status's own rule), so the hollow does not need to be large: what it takes
-- is not the step into it but the step after. A foe that crosses one tile of it is held on the far
-- side, in the open, having spent its move -- which is the setup the whole party was waiting for.
--
-- It catches a walk, a shove, a pull and a trample alike, because all four are ground movement -- so a
-- knight with a mace can put someone IN it. It does not catch a blink or a swap, on the rule every
-- per-tile effect in this game follows: you cannot be caught by ground you never crossed.
--
-- ADJACENCY: a `shield` beside it. A knight opens the hollow by setting their weight against the
-- ground, and the shelf's own armor is what they set it with -- which puts this spell in direct
-- competition with the guard redirects for the slots around the shield, and that is a decision worth
-- making rather than a tax.
return {
    name = "The Grasping Hollow",
    description = "Opens sucking ground: it roots whatever steps into it, and draws no blood.",
    flavor = "The Bastion's engineers call it a delay. Everyone who has crossed one calls it something else.",
    sprite = "assets/items/ability_grasping_hollow.png",
    type = "ability",
    tags = { "earth" },
    class = "knight",
    price = 320,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        speed = 4,
        cost = { { stat = "mana", amount = 8 }, { stat = "stamina", amount = 6 } },
        support = true, -- lands nothing; the AI weighs it as zoning rather than as a strike
        aoe = { radius = 1, shape = "square" },
        requiresAdjacent = { tag = "shield" },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_grasping_hollow", { duration = 18 + fx.level })
            end
        end,
    },
}
