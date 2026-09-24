-- COMES APART: kill the body and you have not removed it from the board, you have divided it.
--
-- The King Slime's rule (data/characters/character_king_slime.lua, carried on its bound
-- data/items/utility/utility_sovereign_mass.lua). A boss's identity is machinery rather than a shelf
-- (docs/bestiary.md), and this is the whole of the machine: the fight does not end where the health
-- bar does, and the party has to still have an answer left when it gets there.
--
-- WHAT COMES OUT IS A REAL BODY, NOT A CONJURATION, and all three of Summon.spawn's `false` options
-- below are that one decision:
--
--   summoner = false  killUnit dismisses everything the fallen were sustaining, one loop AFTER
--                     Trait.onDeath fires. A piece spawned with the default would be conjured and
--                     swept off the board in the same beat, by the very death that made it.
--   summoned = false  a summon is not a real combatant: `assassinate` skips it, the allyDown/foeDown
--                     broadcast passes over it, and it holds no ground. A piece of a King is a body
--                     and has to be killed like one, or a `killAll` resolves over its head.
--   announce = false  "King Slime summons Slime" is not what happened.
--
-- THE PIECES ARE UNADAPTED, which is the fight's last turn of the screw. A company that put the King
-- down with fire is now looking at three bodies that have never met fire and will each take the first
-- one they are shown -- so the element that won the fight is the element that is about to stop
-- working, three times over. Nothing here has to arrange that; they are fresh bodies, and
-- data/traits/trait_adaptive.lua starts empty on every one of them.
--
-- The pieces are smaller than the blueprint they come off (`health` below). A King is one body's worth
-- of slime with more of it; the parts are the same body with less. Overriding the stat rather than
-- authoring a third blueprint is deliberate -- a "Lesser Slime" file would be the Slime file with a
-- different number in it, and the two would drift.
--
-- onDeath rather than a threshold: Trait.onDeath runs from killUnit before the field is unwound, so
-- the pieces land around the body while it is still standing on its tile. A blow that KILLS never
-- fires onDamaged, which is exactly why a split has to hang off the death itself
-- (data/traits/trait_volatile.lua makes the same argument for the same reason).
return {
    name = "Comes Apart",
    description = "When it falls, it divides into three bodies.",
    spawn = "character_slime",
    count = 3,
    health = 24, -- what each piece is worth; the blueprint's own 46 is a whole slime
    onDeath = function(ctx)
        local unit = ctx.unit
        if not unit then return end
        local id = ctx.param("spawn", "character_slime")
        local born = 0
        local pieces = {}
        -- `spawns` names a body per piece (the Glacier King comes apart into one of each Sloth slime);
        -- `pieceStatus`/`pieceMagnitude` start every piece wearing something (the Caldera King's pieces
        -- are already Seething).
        local spawns = ctx.param("spawns", nil)
        local pieceStatus = ctx.param("pieceStatus", nil)
        for n = 1, ctx.param("count", 3) do
            if spawns then id = spawns[((n - 1) % #spawns) + 1] end
            -- One free tile at a time: each piece occupies the one before it, so the next call finds
            -- the next square of the ring. `nil` means the body died hemmed in, and a King cut down in
            -- a corridor leaves fewer pieces than one cut down in the open -- which is a real reason
            -- to fight it somewhere tight.
            local x, y = ctx.openTileNear(unit.x, unit.y)
            if not x then break end
            local piece = ctx.summon(id, x, y, {
                summoner = false, summoned = false, announce = false, noClaim = true,
                stats = { health = ctx.param("health", 24) },
            })
            -- A piece can fail to draw breath -- it arrives on its tile like anything else, and the
            -- trap or the fire under it is still there (models/summon.lua says so outright).
            if piece and piece.alive then
                born = born + 1
                pieces[#pieces + 1] = piece
                if pieceStatus then
                    ctx.applyStatus(piece, pieceStatus, { magnitude = ctx.param("pieceMagnitude", 1) })
                end
            end
        end
        -- GREED'S KING SHARES HIS ACCOUNT (data/status/status_interest.lua): what he had banked -- the
        -- growth and the purse -- is divided among the pieces instead of paid out, so the gold is still
        -- owed and now it is walking about in three places. Marked `passed` so his own death pays nothing.
        local Status = require("models.status")
        local acct = Status.get(unit, "status_interest")
        if acct and #pieces > 0 then
            acct.passed = true
            local n = #pieces
            for i, piece in ipairs(pieces) do
                local s = Status.get(piece, "status_interest")
                if not s then
                    ctx.applyStatus(piece, "status_interest")
                    s = Status.get(piece, "status_interest")
                    if s then s.step, s.gold, s.cap, s.turns, s.purse = acct.step, acct.gold, acct.cap, 0, 0 end
                end
                if s then
                    s.magnitude = (s.magnitude or 0) + math.floor((acct.magnitude or 0) / n)
                    local share = math.floor((acct.purse or 0) / n)
                    if i == 1 then share = share + (acct.purse or 0) - share * n end
                    s.purse = (s.purse or 0) + share
                end
            end
        end
        if born > 0 then
            ctx.log("action", string.format("%s comes apart into %d.",
                (unit.char and unit.char.name) or "It", born), unit)
        end
    end,
}
