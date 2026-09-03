-- Tests for the audio cue wiring (docs/audio-assets.md). The sound files themselves do not exist yet
-- and models/sound.lua resolves a missing one to silence, so these do NOT assert that anything is
-- audible -- they pin the SIGNALS the cues ride on, which is the part that regresses invisibly:
--
--   * the model raises a `status` fx cue when a condition lands and a `miss` cue when a blow is voided,
--   * the view (ui/combat_fx.lua) turns each combat cue into the right Sound.play id,
--   * and the two sound-only cues raise no visible reaction, so an action that has nothing else to
--     show still resolves at once instead of sitting through an impact pause (states/battle.lua).
--
-- A regression here is a cue that has gone silent at its source -- a file dropped at its path would
-- then play nothing, which is exactly the debt this wiring was meant to close.

local Combat = require("models.combat")
local Status = require("models.status")
local CombatFx = require("ui.combat_fx")
local Sound = require("models.sound")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do tiles[y][x] = { type = "ground", moveCost = 1, walkable = true } end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = require("models.character").instantiate(id), x = x, y = y } end

-- Count fx cues of a given type in a drained list (nil -> 0).
local function countType(events, ty)
    local n = 0
    for _, e in ipairs(events or {}) do if e.type == ty then n = n + 1 end end
    return n
end

-- CombatFx.new builds fonts, which love.graphics.newFont refuses without a window; stub it for the
-- length of construction exactly as tests/combat_fx_spec.lua does.
local function newFx()
    local gfx = love.graphics
    local real = gfx.newFont
    gfx.newFont = function() return { getHeight = function() return 18 end } end
    local ok, fx = pcall(CombatFx.new)
    gfx.newFont = real
    assert(ok, "could not construct CombatFx: " .. tostring(fx))
    return fx
end

-- Play a single-beat batch through the view with Sound.play captured. Returns the list of cue ids the
-- view fired. `Sound` is the very table ui/combat_fx.lua holds, so swapping .play here is seen there.
local function soundsFor(events)
    local fx = newFx()
    local realPlay = Sound.play
    local fired = {}
    Sound.play = function(id) fired[#fired + 1] = id end
    local ok, err = pcall(function() fx:ingest(events, nil) end)
    Sound.play = realPlay
    assert(ok, "ingest raised: " .. tostring(err))
    return fired, fx
end

local function fired(list, id)
    for _, x in ipairs(list) do if x == id then return true end end
    return false
end

return {
    {
        name = "a fresh status landing raises a `status` cue; a refresh of it raises none",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_rowan", 1, 1) }, { unit("character_bandit", 3, 3) })
            local bandit = c.units[2]

            Status.apply(c, bandit, "status_stun", { magnitude = 5 })
            local first = Combat.drainFx(c)
            assert(countType(first, "status") == 1,
                "a fresh status should raise exactly one status cue, got " .. countType(first, "status"))

            -- Re-applying the same status only refreshes its duration -- no new condition landed, so no
            -- new cue (the same rule that keeps the combat log from spamming a refresh).
            Status.apply(c, bandit, "status_stun", { magnitude = 5 })
            local second = Combat.drainFx(c)
            assert(countType(second, "status") == 0,
                "refreshing a status must not re-raise the cue, got " .. countType(second, "status"))
        end,
    },
    {
        name = "the view turns a `status` cue into battle.status and nothing visible",
        fn = function()
            local u = { x = 1, y = 1, alive = true, char = { name = "mark" } }
            local sounds, fx = soundsFor({ { type = "status", unit = u, beat = 0 } })
            assert(fired(sounds, "battle.status"), "a status cue did not play battle.status")
            assert(#fx.floaters == 0, "a status cue floated a number it should not have")
            assert(not fx:busy(), "a status cue held the turn hand-off -- it must be sound-only")
        end,
    },
    {
        name = "the view splits a status cue by valence: debuff def -> battle.debuff, else battle.buff",
        fn = function()
            local u = { x = 1, y = 1, alive = true, char = { name = "mark" } }
            local bad = soundsFor({ { type = "status", unit = u, status = { def = { debuff = true } }, beat = 0 } })
            assert(fired(bad, "battle.debuff") and not fired(bad, "battle.buff"),
                "a debuff status should ring battle.debuff")
            local good = soundsFor({ { type = "status", unit = u, status = { def = { name = "Blessing" } }, beat = 0 } })
            assert(fired(good, "battle.buff") and not fired(good, "battle.debuff"),
                "a non-debuff status should ring battle.buff")
        end,
    },
    {
        name = "an offensive cast rings battle.cast; a support cast does not (its heal/buff cue speaks for it)",
        fn = function()
            local u = { x = 1, y = 1, alive = true, char = { name = "mark" } }
            local offensive = soundsFor({ { type = "cast", unit = u, tx = 1, ty = 1, support = false, beat = 0 } })
            assert(fired(offensive, "battle.cast"), "an offensive cast should ring battle.cast")
            local support = soundsFor({ { type = "cast", unit = u, tx = 1, ty = 1, support = true, beat = 0 } })
            assert(not fired(support, "battle.cast"), "a support cast must not ring battle.cast")
        end,
    },
    {
        name = "a channel cue (a wind-up starting) rings battle.channel and nothing visible",
        fn = function()
            local u = { x = 1, y = 1, alive = true, char = { name = "mark" } }
            local sounds, fx = soundsFor({ { type = "channel", unit = u, beat = 0 } })
            assert(fired(sounds, "battle.channel"), "a channel cue did not play battle.channel")
            assert(#fx.floaters == 0, "a channel cue floated a number it should not have")
            assert(not fx:busy(), "a channel cue held the turn hand-off -- it must be sound-only")
        end,
    },
    {
        -- REVERSED BY ACCURACY, and the reversal is the point rather than a relaxation.
        --
        -- This case used to assert a miss was sound-only and never held the turn hand-off. That was
        -- right while a miss meant one of three rare reflexes had fired (a Dodge, a Smoke Bomb, a
        -- Substitution) -- a noise was proportionate to how often the player heard it. Since the hit
        -- roll, a miss is the most common thing that happens to an attack, and an outcome whose only
        -- feedback is a sound reads as the game having ignored the click. So it floats a word now, and
        -- because it floats, it holds the hand-off exactly as a damage number does -- which is the
        -- behaviour that makes the word readable rather than a flicker under the next unit's turn.
        name = "the view turns a `miss` cue into battle.miss and a MISS the player can read",
        fn = function()
            local u = { x = 1, y = 1, alive = true, char = { name = "mark" } }
            local sounds, fx = soundsFor({ { type = "miss", unit = u, beat = 0 } })
            assert(fired(sounds, "battle.miss"), "a miss cue did not play battle.miss")
            assert(#fx.floaters == 1, "a miss must say so on the board, not only in the speakers")
            assert(fx.floaters[1].text == "MISS",
                "expected a MISS floater, got " .. tostring(fx.floaters[1].text))
            assert(not fx.floaters[1].big, "a miss is not an emphasis -- nothing happened")
            -- floatersDone, not busy: `busy` covers the sprite animations and deliberately excludes
            -- floaters, and it is floatersDone that the turn hand-off waits on so a number is never
            -- still climbing when the next unit takes over. A MISS is now subject to that same wait,
            -- which is what keeps it on screen long enough to be read.
            assert(not fx:floatersDone(), "the float has to hold the hand-off or nobody reads it")
        end,
    },
    {
        name = "a light blow rings battle.hit, a heavy one battle.crit, and a kill defers to battle.death",
        fn = function()
            local u = { x = 1, y = 1, alive = true, char = { name = "mark" } }

            local light = soundsFor({ { type = "damage", unit = u, amount = 4, beat = 0 } })
            assert(fired(light, "battle.hit") and not fired(light, "battle.crit"),
                "a 4-damage blow should ring battle.hit alone")

            local heavy = soundsFor({ { type = "damage", unit = u, amount = 20, beat = 0 } })
            assert(fired(heavy, "battle.crit") and not fired(heavy, "battle.hit"),
                "a 20-damage blow should ring battle.crit, not battle.hit")

            -- A killing blow's audio is the death cue, not a hit stacked under it.
            local kill = soundsFor({ { type = "damage", unit = u, amount = 30, lethal = true, beat = 0 } })
            assert(not fired(kill, "battle.hit") and not fired(kill, "battle.crit"),
                "a lethal blow must not also ring a hit -- the death cue carries it")
        end,
    },
    {
        name = "a blow's impact is chosen by damage type: an element rings hit_<motif>, else the generic hit",
        fn = function()
            local u = { x = 1, y = 1, alive = true, char = { name = "mark" } }
            local fire = soundsFor({ { type = "damage", unit = u, amount = 5, tags = { "fire" }, beat = 0 } })
            assert(fired(fire, "battle.hit_fire") and not fired(fire, "battle.hit"),
                "fire damage should ring battle.hit_fire, not the generic hit")
            local slash = soundsFor({ { type = "damage", unit = u, amount = 5, tags = { "dagger", "slash", "physical" }, beat = 0 } })
            assert(fired(slash, "battle.hit_slash"),
                "a slash blow should ring battle.hit_slash (motif reads past the family/routing tags)")
            -- No element/strike tag the sound layer knows -> the generic hit carries it.
            local plain = soundsFor({ { type = "damage", unit = u, amount = 5, tags = { "physical", "melee" }, beat = 0 } })
            assert(fired(plain, "battle.hit") and not fired(plain, "battle.hit_slash"),
                "an untyped blow should fall back to the generic battle.hit")
        end,
    },
    {
        name = "the view rings battle.heal on a heal and battle.death on a death",
        fn = function()
            local u = { x = 1, y = 1, alive = true, char = { name = "mark" } }
            assert(fired(soundsFor({ { type = "heal", unit = u, amount = 6, beat = 0 } }), "battle.heal"),
                "a heal cue did not play battle.heal")
            assert(fired(soundsFor({ { type = "death", unit = u, beat = 0 } }), "battle.death"),
                "a death cue did not play battle.death")
        end,
    },
}
