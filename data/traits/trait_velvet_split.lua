-- THE VELVET QUEEN COMES APART (the King Slime's Comes Apart, data/traits/trait_split.lua), and her
-- wardrobe is shared out among the pieces: each velvet slime she divides into walks off wearing some of
-- what she took. So getting a company dressed again means putting every piece down -- and each piece
-- that falls gives back what IT is wearing (trait_wardrobe). Whatever no piece could carry goes home at
-- once.
return {
    name = "Comes Apart",
    description = "When it falls, it divides into three, and what it took is shared among them.",
    count = 3,
    health = 26,
    onDeath = function(ctx)
        local unit = ctx.unit
        if not unit then return end
        local Combat = require("models.combat")
        local pieces = {}
        for _ = 1, ctx.param("count", 3) do
            local x, y = ctx.openTileNear(unit.x, unit.y)
            if not x then break end
            local piece = ctx.summon("character_velvet_slime", x, y, {
                summoner = false, summoned = false, announce = false, noClaim = true,
                stats = { health = ctx.param("health", 26) },
            })
            if piece and piece.alive then pieces[#pieces + 1] = piece end
        end
        if #pieces > 0 then
            ctx.log("action", string.format("%s comes apart into %d.",
                (unit.char and unit.char.name) or "It", #pieces), unit)
            local i = 0
            while Combat.passStripped(ctx.combat, unit, pieces[(i % #pieces) + 1]) > 0 do i = i + 1 end
        end
        Combat.returnStripped(ctx.combat, unit)
    end,
}
