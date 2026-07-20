-- The two-simulations-in-one-process test: the primary instrument for lockstep.
--
-- Two independent battles, built the same way, driven by the same command list, fingerprinted after
-- EVERY command. If they ever differ, the two machines running that duel would have been playing
-- different games from that moment on -- and this catches it in a second, in the headless suite,
-- instead of in a window with a peer attached and nothing but a mismatched digest to go on.
--
-- This is where the bulk of netcode bugs die. It needs no network, no threads and no second
-- process, because the model is deterministic and commands are the wire format: everything the real
-- thing does between two machines, this does between two tables.
--
-- WHAT IT CANNOT SEE, stated plainly so nobody trusts it further than it goes. Both peers here run
-- in ONE process at ONE moment, so anything they read from a shared environment looks identical to
-- both of them and slips through:
--
--   * A clock read. Replacing the seeded generator with an os.time() one was tried: this spec still
--     passed, because both peers got the same wrong seed. The golden vector in determinism_spec is
--     what catches that.
--   * String hash order. A build hashes a key the same way all day; the source-level guard in
--     determinism_spec is what catches that.
--
-- So this instrument answers one question well -- given identical inputs, does the model take two
-- boards to the same place -- and the other two guards cover what makes the inputs identical in the
-- first place. Three instruments, three blind spots, arranged so each covers another's.
--
-- Pure logic, runs headless.

local Combat = require("models.combat")
local Command = require("models.command")
local StateHash = require("models.state_hash")
local Character = require("models.character")
local Item = require("models.item")

local function arena(cols, rows, seed)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" }, seed = seed }
end

local function fighter(id, x, y)
    local char = Character.instantiate(id)
    char.traits = {}
    char.inventory = {}
    Character.addItem(char, Item.instantiate("weapon_iron_sword"))
    return { char = char, x = x, y = y }
end

-- One duel, built from nothing but a seed and two rosters -- exactly what a peer would be handed.
local function duel()
    return Combat.new(arena(8, 8, 4242),
        { fighter("character_knight", 4, 8) },
        { fighter("character_bandit", 4, 2) })
end

-- Open a turn for whoever the timeline says is next, the way the battle state does.
local function openTurn(c)
    return Combat.startTurn(c)
end

-- A legal one-tile move for whoever is currently acting, walking toward the middle of the board.
-- Relative to the ACTOR rather than a fixed tile, because the timeline decides who acts and a
-- command aimed at the wrong side of the board is refused by both peers alike -- which looks like
-- agreement and proves nothing.
local function advance(unit, tiles)
    local dir = (unit.side == "party") and -1 or 1
    return { kind = "move", x = unit.x, y = unit.y + dir * (tiles or 1) }
end

return {
    {
        -- The headline. Same seed, same commands, same fight -- checked after every single one, not
        -- at the end, because a desync detected late names nothing and one detected on the turn it
        -- happened names the command that caused it.
        name = "two peers fed the same commands agree after every single one",
        fn = function()
            local a, b = duel(), duel()
            assert(StateHash.of(a) == StateHash.of(b), "they should start identical")

            local accepted = 0
            for i = 1, 8 do
                local ua, ub = openTurn(a), openTurn(b)
                assert(ua.index == ub.index, "both peers should agree whose turn it is, at step " .. i)

                -- Alternate walking and waiting, aimed from wherever the actor actually stands.
                local cmd = (i % 2 == 1) and advance(ua) or { kind = "wait" }
                local ra, whyA = Command.apply(a, ua, cmd)
                local rb, whyB = Command.apply(b, ub, cmd)

                -- Accepted on BOTH, not merely refused on both: two peers rejecting the same
                -- nonsense agree about nothing worth having.
                assert(ra, "peer A refused " .. cmd.kind .. " at step " .. i .. ": " .. tostring(whyA))
                assert(rb, "peer B refused " .. cmd.kind .. " at step " .. i .. ": " .. tostring(whyB))
                accepted = accepted + 1

                assert(StateHash.of(a) == StateHash.of(b),
                    "peers diverged at command " .. i .. " (" .. cmd.kind .. ")")
            end
            assert(accepted == 8, "every command in the script should have been a real one")
        end,
    },
    {
        -- Peer B is built in a perturbed environment: a pile of interned strings first, so any
        -- string-hash-order dependence left in pathfinding or the AI has a chance to express itself.
        -- Cannot prove the absence of the bug (one process hashes a key the same way all day -- see
        -- the source-level guard in determinism_spec) but it is free and it has teeth against
        -- anything that depends on allocation order rather than key order.
        name = "a peer built in a perturbed environment still agrees",
        fn = function()
            local a = duel()
            local noise = {}
            for i = 1, 500 do noise[i] = ("k%d,%d"):format(i, i * 7) end
            local b = duel()

            for i = 1, 4 do
                local ua, ub = openTurn(a), openTurn(b)
                assert(Command.apply(a, ua, advance(ua)), "peer A should move at step " .. i)
                assert(Command.apply(b, ub, advance(ub)), "peer B should move at step " .. i)
                assert(StateHash.of(a) == StateHash.of(b), "perturbation should change nothing")
            end
            assert(#noise == 500) -- keep the noise alive to the end of the case
        end,
    },
    {
        -- A stale command -- one aimed at a board that has moved on -- must be REFUSED rather than
        -- applied. This is the case that would otherwise desync silently: the sender's board allowed
        -- it, the receiver's does not, and applying it anyway makes the two disagree forever.
        name = "a command against a board that has moved on is refused, not half-applied",
        fn = function()
            local c = duel()
            local unit = openTurn(c)
            local before = StateHash.of(c)

            local nonsense = {
                { kind = "move", x = 99, y = 99 },
                { kind = "use", cell = 9, tx = 4, ty = 2 },
                { kind = "move", x = 4.5, y = 7 },
                { kind = "sabotage" },
                { kind = "use", cell = 0, tx = 1, ty = 1 },
            }
            for _, cmd in ipairs(nonsense) do
                local res, why = Command.apply(c, unit, cmd)
                assert(res == nil, "should refuse " .. tostring(cmd.kind))
                assert(why, "and give a reason")
                assert(StateHash.of(c) == before,
                    "a refused command must leave the board exactly as it found it")
            end
        end,
    },
    {
        name = "validating never changes the board, whatever the answer",
        fn = function()
            local c = duel()
            local unit = openTurn(c)
            local before = StateHash.of(c)
            Command.validate(c, unit, { kind = "move", x = 4, y = 6 })   -- legal
            Command.validate(c, unit, { kind = "move", x = 99, y = 99 }) -- not
            Command.validate(c, unit, { kind = "use", cell = 1, tx = 4, ty = 2 })
            assert(StateHash.of(c) == before, "a validator with a side effect is worse than none")
        end,
    },
    {
        -- A unit cannot move twice, and both peers have to agree about that or one spends a move the
        -- other still thinks is available.
        name = "a spent move is spent on both boards",
        fn = function()
            local a, b = duel(), duel()
            local ua, ub = openTurn(a), openTurn(b)
            assert(Command.apply(a, ua, advance(ua)), "the first move lands")
            assert(Command.apply(b, ub, advance(ub)), "on both")
            assert(StateHash.of(a) == StateHash.of(b), "and leaves them agreeing")

            assert(Command.apply(a, ua, advance(ua)) == nil, "a second move is refused")
            assert(Command.apply(b, ub, advance(ub)) == nil, "on both")
            assert(StateHash.of(a) == StateHash.of(b), "still agreeing")
        end,
    },
    {
        -- The move is the one command that resolves over several tiles, and the captured route is
        -- what a view replays. The route must not be able to differ between a peer that animates and
        -- one that does not -- so the same command produces the same steps on both.
        name = "the captured route is identical on both peers, animated or not",
        fn = function()
            local a, b = duel(), duel()
            local ua, ub = openTurn(a), openTurn(b)
            local ra = assert(Command.apply(a, ua, advance(ua, 2)), "peer A should walk two tiles")
            local rb = assert(Command.apply(b, ub, advance(ub, 2)), "peer B should walk two tiles")
            assert(ra.moved and rb.moved, "a move should capture a route")
            assert(#ra.moved == 2, "and the route should be the two tiles asked for")
            assert(#ra.moved == #rb.moved, "of the same length")
            for i = 1, #ra.moved do
                assert(ra.moved[i].x == rb.moved[i].x and ra.moved[i].y == rb.moved[i].y,
                    "step " .. i .. " should be the same tile on both peers")
            end
        end,
    },
    {
        -- A positive control. Every other case here asserts that two peers AGREE, and a harness that
        -- had quietly stopped comparing anything would pass all of them. So: make them genuinely
        -- disagree and check the instrument says so. Without this, "all green" could mean the rig
        -- is broken rather than the code is right.
        name = "the harness actually notices when two peers do different things",
        fn = function()
            local a, b = duel(), duel()
            local ua, ub = openTurn(a), openTurn(b)
            assert(StateHash.of(a) == StateHash.of(b), "identical to begin with")

            assert(Command.apply(a, ua, advance(ua, 2)), "peer A walks two tiles")
            assert(Command.apply(b, ub, advance(ub, 1)), "peer B walks one")

            assert(StateHash.of(a) ~= StateHash.of(b),
                "two peers that did different things must not fingerprint the same")
            assert(StateHash.digestOf(a) ~= StateHash.digestOf(b),
                "and the short digest -- what actually travels -- must differ too")
        end,
    },
    {
        name = "a well-formed command survives the trip as data",
        fn = function()
            local Save = require("models.save")
            local cmd = { kind = "use", cell = 1, tx = 4, ty = 2 }
            local wire = "return " .. Save.encode(cmd, 0)
            local back = Save.decode(wire)
            assert(back and back.kind == "use" and back.cell == 1 and back.tx == 4 and back.ty == 2,
                "a command is plain data and must round-trip through the wire encoder")
            assert(Command.wellFormed(back), "and still be well formed on arrival")
        end,
    },
}
