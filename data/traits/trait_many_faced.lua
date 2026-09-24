-- THE MANY-FACED KING COMES APART INTO YOU (data/characters/character_many_faced_king.lua): three mimic
-- slimes, each taking the shape of a different member of the company (Combat.mimic), and each wearing the
-- blessings the King had begrudged. A split of its own rather than trait_split, because every piece is
-- aimed at a different face.
return {
    name = "Many Faces",
    description = "When it falls, it divides into copies of three of its foes, wearing its blessings.",
    count = 3,
    health = 26,
    onDeath = function(ctx)
        local u = ctx.unit
        if not u then return end
        local Combat = require("models.combat")
        local foes = {}
        for _, other in ipairs(ctx.combat.units or {}) do
            if other.alive and other.side ~= u.side and other.char and not other.summoned then foes[#foes + 1] = other end
        end
        local blessings = {}
        for _, st in ipairs(u.statuses or {}) do
            if st.def and not st.def.debuff and not st.def.hideLog and (st.remaining or 0) < 1e6 then
                blessings[#blessings + 1] = st
            end
        end
        local born = 0
        for i = 1, ctx.param("count", 3) do
            local x, y = ctx.openTileNear(u.x, u.y)
            if not x then break end
            local piece = ctx.summon("character_mimic_slime", x, y, {
                summoner = false, summoned = false, announce = false, noClaim = true,
                stats = { health = ctx.param("health", 26) },
            })
            if piece and piece.alive then
                born = born + 1
                if #foes > 0 then Combat.mimic(ctx.combat, piece, foes[((i - 1) % #foes) + 1]) end
                for _, st in ipairs(blessings) do
                    ctx.applyStatus(piece, st.id, { duration = st.remaining, magnitude = st.magnitude, echoed = true })
                end
            end
        end
        if born > 0 then
            ctx.log("action", string.format("%s comes apart into %d faces.", (u.char and u.char.name) or "It", born), u)
        end
    end,
}
