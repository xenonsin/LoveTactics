-- Tests for deterministic status resistance (the contract at the top of models/status.lua): a
-- resistible status buys DURATION, never a coin flip, and the ticks it buys are cut by the target's
-- ward and halved again for every previous application this battle -- until it stops landing at all.
-- Pure logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

return {
    {
        name = "resistance is deterministic: the same cast on the same target always buys the same ticks",
        fn = function()
            -- The whole point of the design. Ten identical applications onto ten identical, fresh
            -- targets must agree exactly -- if anything here rolled, this is the test that would flap.
            local first
            for _ = 1, 10 do
                local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 4, 4) })
                local bandit = c.units[2]
                local s = Status.apply(c, bandit, "status_sleep")
                assert(s, "a fresh target is put under")
                first = first or s.remaining
                assert(s.remaining == first,
                    "every application agrees: expected " .. first .. ", got " .. s.remaining)
            end
        end,
    },
    {
        name = "a bigger ward buys a shorter affliction",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 4, 4) })
            local a, b = c.units[1], c.units[2]
            a.char.stats.magicDefense = 0
            b.char.stats.magicDefense = 24

            local bare = Status.resistedDuration(a, "status_sleep", 14)
            local warded = Status.resistedDuration(b, "status_sleep", 14)
            assert(bare == 14, "an unwarded body takes the full 14, got " .. bare)
            assert(warded < bare, "a warded one takes less: " .. warded .. " vs " .. bare)
            -- The curve is a softcap, so even a heavy ward never reaches zero on its own -- there is
            -- always another point of magicDefense worth having, and never a flat immunity.
            assert(warded > 0, "but a ward alone is never immunity, got " .. warded)
        end,
    },
    {
        name = "diminishing returns: each repeat is halved, and eventually nothing lands",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 4, 4) })
            local bandit = c.units[2]
            bandit.char.stats.magicDefense = 0 -- isolate the DR curve from the ward curve

            local lengths = {}
            for i = 1, 6 do
                local s = Status.apply(c, bandit, "status_sleep")
                lengths[i] = s and s.remaining or 0
                if s then Status.remove(c, bandit, "status_sleep") end -- clear the badge; keep the history
            end

            assert(lengths[1] == 14, "the first sleep is full length, got " .. lengths[1])
            assert(lengths[2] == 7, "the second is halved, got " .. lengths[2])
            assert(lengths[3] == 4, "the third is halved again, got " .. lengths[3])
            -- The guarantee that answers "being turned into a pig forever is not a game": the curve
            -- reaches nothing at all, by arithmetic, in a bounded number of casts.
            assert(lengths[6] == 0, "and by the sixth it does not land at all, got " .. lengths[6])
        end,
    },
    {
        name = "a refused application still counts, so immunity cannot be reset by casting into it",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 4, 4) })
            local bandit = c.units[2]
            bandit.char.stats.magicDefense = 0

            -- Drive the DR curve down until the spell stops landing. (A ward alone can never get here
            -- -- the softcap is asymptotic by design, see the test above -- so refusal is always the
            -- diminishing-returns curve's doing.)
            local casts = 0
            repeat
                casts = casts + 1
                local s = Status.apply(c, bandit, "status_sleep")
                if s then Status.remove(c, bandit, "status_sleep") end
            until s == nil or casts > 12
            assert(casts <= 12, "the curve reaches refusal in a bounded number of casts")

            -- The refusals keep counting. Casting into an immune target does not let the attacker
            -- wait out its own diminishing returns.
            local afterRefusal = Status.timesAfflicted(bandit, "status_sleep")
            assert(Status.apply(c, bandit, "status_sleep") == nil, "it is still refused")
            assert(Status.timesAfflicted(bandit, "status_sleep") == afterRefusal + 1,
                "and the refusal was counted too")
        end,
    },
    {
        name = "statusResist from armor wards on top of magicDefense",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 4, 4) })
            local knight = c.units[1]
            local before = Status.resistRating(knight, "magical")

            -- The Skeptic's Harness grants its ward as an ordinary flat `statusResist` bonus, folded in
            -- by applyUnitPassives like any armor stat -- no plumbing of its own.
            Character.addItem(knight.char, Item.instantiate("armor_skeptics_harness"))
            Combat.refreshPassives(knight)
            local after = Status.resistRating(knight, "magical")

            assert(after > before, "the harness raises the ward: " .. before .. " -> " .. after)
            assert(Status.resistedDuration(knight, "status_polymorph", 12)
                < Status.resistedDuration({ char = { stats = { magicDefense = 0 } } }, "status_polymorph", 12),
                "and a harnessed knight is a pig for less time than a bare body")
        end,
    },
    {
        name = "a non-resistible status is untouched by any ward",
        fn = function()
            -- Only a status that opts in (`resistible`) is scaled; everything else lands as authored,
            -- so this change cannot have quietly re-tuned the existing roster.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 4, 4) })
            local knight = c.units[1]
            knight.char.stats.magicDefense = 100
            assert(Status.resistedDuration(knight, "status_regen", 10) == 10, "a buff is never resisted")
            local s = Status.apply(c, knight, "status_stun")
            assert(s and s.remaining == Status.defs.status_stun.duration, "and Stun still lands as authored")
        end,
    },
}
