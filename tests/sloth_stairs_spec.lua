-- Tests for SLOTH'S STAIRS ("Sloth's Bestiary", slice G, 2026-10-04): the circle's two stair bosses, designed from
-- the circle's brief and approved rule by rule. Acedia and the Long Winter's stand-in left the stairs.
--
--   THE SANDMAN (floor 9)   Sand in the Eyes      a cross, a ring, a row, sown a turn ahead; what stands on it at
--                                                 his next turn falls Asleep, either side
--                           Run Through the Glass a foe ending its turn beside him sends him to his shown mark; the
--                                                 tile he left sleeps whoever stops on it
--                           Bad Dreams            woken from his sleep by a blow: Rattled to the end of its next turn
--   DESIDIA (floor 10)      The Long Sleep        Dormant; a turn banked a round, each with a marked row; 10 Stir or a
--                                                 blow wakes her, and every banked turn sweeps its row at once
--                           The Drowse            whoever took a turn and did not move gains Drowsy, either side
--                           What the Sleepers     a sleeping foe's shade stands up on her side until it wakes
--                           Dream
--                           Awake, and Worse      woken and spent, a round with no blow on her puts her back under
--
-- And the six trophies: the Sandman's Pouch, the Hourglass, the Long Sleep, Lull, the Nightmare Lantern and Restless
-- Mail. Each case pins a rule on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Hazard = require("models.hazard")
local Bank = require("models.bank")
local Sandman = require("models.sandman")
local Desidia = require("models.desidia")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local ORGANS = {
    "utility_sand_in_the_eyes", "utility_run_through_the_glass", "utility_bad_dreams", "weapon_sand_from_his_hands",
    "utility_the_dreamer", "utility_the_drowse", "utility_what_the_sleepers_dream", "weapon_desidias_breath",
}
-- id -> { shelf, rung }
local TROPHIES = {
    ability_sandmans_pouch = { "trapper", 9 },
    utility_the_hourglass = { "ninja", 9 },
    utility_the_long_sleep = { "knight", 10 },
    ability_lull = { "warden", 10 },
    utility_nightmare_lantern = { "necromancer", 10 },
    armor_restless_mail = { "knight", 10 },
}

local function board(n) return Fixture.new(n or 11, n or 11) end

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 300, health or 300
    return spawn
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function party(c)
    local out = {}
    for _, u in ipairs(c.units) do if u.side == "party" then out[#out + 1] = u end end
    return out
end

local function sloth()
    for _, s in ipairs(Descent.SINS) do if s.id == "sloth" then return s end end
end

local function sameList(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

local function sownCount(c)
    local n = 0
    for _, h in ipairs(c.hazards or {}) do if h.alive and h.id == "hazard_sown_sand" then n = n + 1 end end
    return n
end

-- A Desidia board: her at (4, 4) before the bell, and `spawns` for the company.
local function desidiaBoard(spawns, extraEnemies)
    local enemies = { unit("character_general_sloth", 4, 4) }
    for _, e in ipairs(extraEnemies or {}) do enemies[#enemies + 1] = e end
    local c = Fixture.combat(board(11), spawns, enemies)
    return c, one(c, "character_general_sloth")
end

return {
    -- ------------------------------------------------------------------------------ the content and the stairs
    {
        name = "the Sandman is an elemental lieutenant carrying his three rules as organs",
        fn = function()
            local def = Character.defs["character_the_sandman"]
            assert(def and def.race == "elemental" and def.tier == 4, "a tier-4 elemental")
            assert(def.boss and def.referenceLevel, "a stair centrepiece")
            local c = Character.instantiate("character_the_sandman")
            for _, id in ipairs({ "utility_sand_in_the_eyes", "utility_run_through_the_glass", "utility_bad_dreams",
                                  "weapon_sand_from_his_hands" }) do
                assert(itemNamed(c, id), "he carries " .. id)
            end
            assert(sameList(def.drops, { "ability_sandmans_pouch", "utility_the_hourglass" }), "he drops his two")
        end,
    },
    {
        name = "Desidia is a 3x3 giant on Acedia's id who never moves, carrying her rules as organs",
        fn = function()
            local def = Character.defs["character_general_sloth"]
            assert(def.name == "Desidia, the Dreamer", "the general is Desidia")
            assert(def.race == "giant" and def.tier == 4 and def.boss and def.referenceLevel, "a boss giant")
            assert(def.footprint.w == 3 and def.footprint.h == 3, "a 3x3 face")
            assert(def.stats.movement == 0, "she does not move")
            local c = Character.instantiate("character_general_sloth")
            for _, id in ipairs({ "utility_the_dreamer", "utility_the_drowse", "utility_what_the_sleepers_dream",
                                  "weapon_desidias_breath" }) do
                assert(itemNamed(c, id), "she carries " .. id)
            end
            assert(sameList(def.drops, { "utility_the_long_sleep", "ability_lull", "utility_nightmare_lantern",
                                         "armor_restless_mail" }), "she drops her four, relic first")
        end,
    },
    {
        name = "the organs are creature kit, and the trophies sit unstocked on their real shelves",
        fn = function()
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal and not def.price, id .. " is creature kit")
            end
            for id, want in pairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.class == want[1], id .. " sits on " .. tostring(def.class) .. ", not " .. want[1])
                assert(def.unstocked and def.noSteal and def.price == nil, id .. " is an unpriced trophy")
                assert(def.unlockLevel == want[2], id .. " is on its stair's rung, " .. want[2])
            end
        end,
    },
    {
        name = "the Sandman holds floor 9's stair and Desidia floor 10's, and each pays its own list",
        fn = function()
            local sin = sloth()
            assert(sin.minor.lead == "character_the_sandman" and sin.guardian.lead == "character_general_sloth")
            assert(sin.gate.kind == "none", "she is asleep and the stair stands open")
            assert(Descent.guardList(sin, false, 9, 2)[1] == "character_the_sandman", "his stair is his")
            assert(Descent.guardList(sin, true, 10, 2)[1] == "character_general_sloth", "hers is hers")
            assert(sameList(Descent.DROPS.sloth.minor, { "ability_sandmans_pouch", "utility_the_hourglass" }),
                "the minor stair pays the Pouch, then the Hourglass")
            assert(sameList(Descent.DROPS.sloth.general, { "utility_the_long_sleep", "ability_lull",
                "utility_nightmare_lantern", "armor_restless_mail" }), "the general pays her four, relic first")
            -- Off the lists, still on disk. (The ten Bastion pieces that queued behind the Pike are not named here:
            -- they are on tests/support/untested_items.lua's backlog, and naming one would count as testing it.)
            for _, id in ipairs({ "weapon_forsworn_pike", "utility_unblown_horn" }) do
                assert(Item.defs[id], id .. " stays on disk")
            end
        end,
    },

    -- ------------------------------------------------------------------------------------ the Sandman
    {
        name = "Sand in the Eyes: sown at the end of his turn, and what stands on it at his next falls Asleep",
        fn = function()
            local c = Fixture.combat(board(), { walker(6, 9) },
                { unit("character_the_sandman", 6, 2), unit("character_ice_elemental", 1, 1) })
            local sm, ally = one(c, "character_the_sandman"), one(c, "character_ice_elemental")
            local foe = party(c)[1]
            Trait.onAnyTurnEnd(c, sm)
            assert(sm.sandman.cycle == 1, "the first shape is the cross")
            assert(sownCount(c) == 9, "a cross of nine tiles")
            assert(Hazard.at(c, foe.x, foe.y, "hazard_sown_sand"), "aimed where it catches the foe")
            assert(not Status.has(foe, "status_sleep"), "and nothing sleeps until it comes due")
            -- His own side steps onto it too: the sand does not ask.
            local spare
            for _, h in ipairs(c.hazards) do
                if h.alive and h.id == "hazard_sown_sand" and not Combat.unitAt(c, h.x, h.y) then spare = h end
            end
            assert(Combat.teleportUnit(c, ally, spare.x, spare.y), "an ally of his stands on the sand")
            Trait.onAnyTurnStart(c, sm)
            assert(Status.has(foe, "status_sleep"), "the foe on it falls Asleep")
            assert(Status.has(ally, "status_sleep"), "and so does his own, on either side")
            assert(not Status.has(sm, "status_sleep"), "never the sower")
            assert(sownCount(c) == 0, "the sand is spent")
        end,
    },
    {
        name = "the sand cycles a cross, a ring and a row",
        fn = function()
            local c = Fixture.combat(board(), { walker(6, 6) }, { unit("character_the_sandman", 1, 1) })
            local sm = one(c, "character_the_sandman")
            local shapes = {}
            for i = 1, 4 do
                local shape, aim = Sandman.sowNext(c, sm)
                shapes[i] = shape
                if shape == "ring" then assert(#aim.cells == 8, "a ring is the eight around its heart") end
                if shape == "row" then assert(#aim.cells == 11, "a row is the whole row of the board") end
            end
            assert(sameList(shapes, { "cross", "ring", "row", "cross" }), "cross, ring, row, and round again")
        end,
    },
    {
        name = "Run Through the Glass: a foe ending its turn beside him sends him to his shown mark",
        fn = function()
            local c = Fixture.combat(board(), { walker(6, 6), walker(2, 2) }, { unit("character_the_sandman", 6, 5) })
            local sm = one(c, "character_the_sandman")
            local foe, other = party(c)[1], party(c)[2]
            local mark = sm.sandman.mark
            assert(mark and mark.alive and mark.id == "hazard_hourglass_mark", "the mark is shown from the bell")
            assert(math.abs(mark.x - 6) + math.abs(mark.y - 5) >= 8, "across the board")
            local mx, my = mark.x, mark.y
            Trait.onAnyTurnEnd(c, foe)
            assert(sm.x == mx and sm.y == my, "he reforms on the mark")
            assert(Hazard.at(c, 6, 5, "hazard_sand_patch"), "the tile he left is a sand patch")
            assert(sm.sandman.mark and sm.sandman.mark.alive and not (sm.sandman.mark.x == mx and sm.sandman.mark.y == my),
                "and the hourglass marks a new tile")
            -- Whoever ends a turn on the patch falls Asleep.
            assert(Combat.teleportUnit(c, other, 6, 5), "a body walks onto the patch")
            Trait.onAnyTurnEnd(c, other)
            assert(Status.has(other, "status_sleep"), "and stopping there puts it under")
        end,
    },
    {
        name = "a stunned Sandman does not run",
        fn = function()
            local c = Fixture.combat(board(), { walker(6, 6) }, { unit("character_the_sandman", 6, 5) })
            local sm, foe = one(c, "character_the_sandman"), party(c)[1]
            Status.apply(c, sm, "status_stun", {})
            Trait.onAnyTurnEnd(c, foe)
            assert(sm.x == 6 and sm.y == 5, "a run is a reflex")
        end,
    },
    {
        name = "Bad Dreams: woken from his sleep by a blow, Rattled until the end of its next turn; Cured, not",
        fn = function()
            local c = Fixture.combat(board(9), { walker(2, 2), walker(4, 4), walker(6, 6), walker(2, 8) },
                { unit("character_the_sandman", 8, 8) })
            local sm = one(c, "character_the_sandman")
            local a, b, d, e = party(c)[1], party(c)[2], party(c)[3], party(c)[4]
            -- A blow.
            assert(Sandman.sleep(c, a, sm), "his sleep lands")
            Combat.dealFlatDamage(c, a, 5, { "physical" }, "test", sm, { raw = true })
            assert(not Status.has(a, "status_sleep"), "the blow wakes it")
            local r = Status.get(a, "status_rattled")
            assert(r, "and it wakes Rattled")
            assert(r.remaining == math.floor(a.initiative) + 1, "until the end of its next turn")
            Status.tick(c, math.floor(a.initiative))
            assert(Status.has(a, "status_rattled"), "still Rattled as its turn comes round")
            Status.tick(c, 1)
            assert(not Status.has(a, "status_rattled"), "and clear on the first beat after it")
            -- A Cure.
            assert(Sandman.sleep(c, b, sm))
            Status.cleanse(c, b)
            Combat.dealFlatDamage(c, b, 5, { "physical" }, "test", sm, { raw = true })
            assert(not Status.has(b, "status_rattled"), "a Cure leaves no bad dream")
            -- Left to wake on its own.
            assert(Sandman.sleep(c, d, sm))
            Status.remove(c, d, "status_sleep")
            Combat.dealFlatDamage(c, d, 5, { "physical" }, "test", sm, { raw = true })
            assert(not Status.has(d, "status_rattled"), "nor does the clock")
            -- Somebody else's sleep is only a sleep.
            assert(Status.apply(c, e, "status_sleep", {}))
            Combat.dealFlatDamage(c, e, 5, { "physical" }, "test", sm, { raw = true })
            assert(not Status.has(e, "status_rattled"), "only his sleep carries the dream")
        end,
    },

    -- ------------------------------------------------------------------------------------ his trophies
    {
        name = "the Sandman's Pouch sows a 3x3 that puts its occupants under as the caster's next turn comes",
        fn = function()
            local c = Fixture.combat(board(9),
                { unit("character_archer", 2, 5, { isolate = "bare", items = { "ability_sandmans_pouch" },
                    stats = { stamina = 60 } }) },
                { unit("character_bandit", 5, 5), unit("character_bandit", 6, 6), unit("character_bandit", 8, 8) })
            local me = party(c)[1]
            local pouch = itemNamed(me.char, "ability_sandmans_pouch")
            assert(pouch.activeAbility.windup == 5, "a turn's wind-up: the sand comes due at your next turn")
            openTurn(c, me)
            assert(Combat.useItem(c, me, pouch, 5, 5), "the sand is sown")
            local inArea, outside = Combat.unitAt(c, 5, 5), Combat.unitAt(c, 8, 8)
            local corner = Combat.unitAt(c, 6, 6)
            assert(not Status.has(inArea, "status_sleep"), "nothing sleeps until it comes due")
            assert(Combat.resolveChannel(c, me), "it comes due")
            assert(Status.has(inArea, "status_sleep") and Status.has(corner, "status_sleep"), "the 3x3 falls Asleep")
            assert(not Status.has(outside, "status_sleep"), "outside it, nothing")
        end,
    },
    {
        name = "the Hourglass reappears up to 4 away when a foe ends its turn beside you, leaving a patch",
        fn = function()
            local c = Fixture.combat(board(),
                { unit("character_archer", 6, 6, { isolate = "bare", items = { "utility_the_hourglass" } }) },
                { unit("character_bandit", 6, 5) })
            local me, foe = party(c)[1], one(c, "character_bandit")
            Trait.onAnyTurnEnd(c, foe)
            local d = math.abs(me.x - 6) + math.abs(me.y - 6)
            assert(d >= 1 and d <= 4, "it reappears within 4 (moved " .. d .. ")")
            assert(math.abs(me.x - foe.x) + math.abs(me.y - foe.y) > 1, "away from the foe that came")
            assert(Hazard.at(c, 6, 6, "hazard_sand_patch"), "the tile it left puts sleepers under")
            for _, h in ipairs(c.hazards or {}) do
                assert(not (h.alive and h.id == "hazard_hourglass_mark"), "a bearer's hourglass marks nothing")
            end
        end,
    },

    -- ------------------------------------------------------------------------------------ Desidia
    {
        name = "the Long Sleep: she is seated at the far edge and opens Dormant",
        fn = function()
            local c, d = desidiaBoard({ walker(2, 10), walker(8, 10) })
            assert(d.x == 5 and d.y == 1, "centred on the edge the company is not on, got " .. d.x .. "," .. d.y)
            assert(Status.has(d, "status_dormant") and Desidia.isAsleep(d), "asleep from the bell")
        end,
    },
    {
        name = "a round she sleeps banks a turn and marks the row her foes crowd most",
        fn = function()
            local c, d = desidiaBoard({ walker(2, 9), walker(8, 9), walker(5, 11) })
            Trait.onAnyTurnEnd(c, d)
            assert(Bank.count(d) == 1, "one turn banked")
            assert(d.desidia.rows[1] == 9, "on the row two of them share")
            assert(Hazard.at(c, 1, 9, "hazard_waking_row") and Hazard.at(c, 11, 9, "hazard_waking_row"),
                "the whole row is marked")
            Trait.onAnyTurnEnd(c, d)
            Trait.onAnyTurnEnd(c, d)
            assert(Bank.count(d) == 3, "no cap: every round she sleeps is one more")
            assert(Status.has(d, "status_dormant"), "and she sleeps on")
        end,
    },
    {
        name = "ten Stir wake her, and every banked turn sweeps its row at once",
        fn = function()
            local c, d = desidiaBoard({ walker(2, 9), walker(8, 9), walker(5, 11) })
            local p = party(c)
            local onRow, offRow = p[1], p[3]
            Trait.onAnyTurnEnd(c, d)
            Trait.onAnyTurnEnd(c, d)
            local before, beforeOff = hp(onRow), hp(offRow)
            for _ = 1, 9 do Trait.onAnyCast(c, onRow, { item = {} }) end
            assert(Status.stacksOf(d, "status_stir") == 9 and Desidia.isAsleep(d), "nine: still asleep")
            Trait.onAnyCast(c, onRow, { item = {} })
            assert(not Status.has(d, "status_dormant") and not Desidia.isAsleep(d), "ten: awake")
            assert(Status.has(d, "status_rude_awakening"), "and worse for it")
            assert(Bank.count(d) == 0 and not Status.has(d, "status_stir"), "the bank and the Stir are spent")
            assert(hp(onRow) < before, "the foe on the marked row is swept")
            assert(hp(offRow) == beforeOff, "the foe off it is not")
            assert(not Hazard.at(c, 1, 9, "hazard_waking_row"), "the rows are lifted")
        end,
    },
    {
        name = "a blow wakes her early, and the bank is spent the same way",
        fn = function()
            local c, d = desidiaBoard({ walker(2, 9), walker(5, 11) })
            local foe = party(c)[1]
            Trait.onAnyTurnEnd(c, d)
            Trait.onAnyTurnEnd(c, d)
            local before = hp(foe)
            Combat.dealFlatDamage(c, d, 5, { "physical" }, "test", foe, { raw = true })
            assert(not Desidia.isAsleep(d) and not Status.has(d, "status_dormant"), "the blow wakes her")
            assert(Bank.count(d) == 0, "every banked turn is taken")
            assert(before - hp(foe) > 0, "both sweeps came down the foe's row")
        end,
    },
    {
        name = "awake and spent, a round with no blow on her puts her back to sleep, banking from zero",
        fn = function()
            local c, d = desidiaBoard({ walker(2, 9), walker(5, 11) })
            local foe = party(c)[1]
            -- Woken by a blow: that round she was struck, so she stays up.
            Combat.dealFlatDamage(c, d, 5, { "physical" }, "test", foe, { raw = true })
            Trait.onAnyTurnEnd(c, d)
            assert(not Desidia.isAsleep(d), "struck this round: awake")
            -- Nothing lands this round.
            Trait.onAnyTurnEnd(c, d)
            assert(Desidia.isAsleep(d) and Status.has(d, "status_dormant"), "untouched: back to sleep")
            assert(Bank.count(d) == 0 and Status.stacksOf(d, "status_stir") == 0, "from zero")
            Trait.onAnyTurnEnd(c, d)
            assert(Bank.count(d) == 1, "and banking again")
        end,
    },
    {
        name = "the Drowse: whoever took a turn and did not move gains Drowsy, either side; never her",
        fn = function()
            local c, d = desidiaBoard({ walker(2, 9), walker(8, 9), walker(5, 11) },
                { unit("character_ice_elemental", 10, 5) })
            local still, mover, idle = party(c)[1], party(c)[2], party(c)[3]
            local ally = one(c, "character_ice_elemental")
            Combat.tally(still, "turnTaken", 1)
            Combat.tally(mover, "turnTaken", 1)
            Combat.tally(mover, "tilesMoved", 2)
            Combat.tally(ally, "turnTaken", 1)
            Trait.onAnyTurnEnd(c, d)
            assert(Status.has(still, "status_drowsy"), "the one that stood still is Drowsy")
            assert(not Status.has(mover, "status_drowsy"), "the one that walked is not")
            assert(not Status.has(idle, "status_drowsy"), "the one that took no turn is not judged")
            assert(Status.has(ally, "status_drowsy"), "and her own side is not spared")
            assert(not Status.has(d, "status_drowsy"), "never her")
            -- Three rounds of it and the body is Asleep.
            for _ = 1, 2 do
                Combat.tally(still, "turnTaken", 1)
                Trait.onAnyTurnEnd(c, d)
            end
            assert(Status.has(still, "status_sleep"), "at 3, it falls Asleep")
        end,
    },
    {
        name = "What the Sleepers Dream: a sleeping foe's shade stands up on her side until it wakes",
        fn = function()
            local c, d = desidiaBoard({ walker(2, 9), walker(8, 9) })
            local sleeper = party(c)[1]
            assert(Status.apply(c, sleeper, "status_sleep", {}), "a foe falls asleep")
            Trait.onAnyTurnStart(c, d)
            local shade
            for _, u in ipairs(c.units) do if u.alive and u.shadeOf == sleeper then shade = u end end
            assert(shade and shade.side == d.side, "its nightmare stands up on her side")
            assert(shade.char.name == sleeper.char.name .. "'s Nightmare", "with its face")
            for i = 1, Character.MAX_INVENTORY do
                local item = sleeper.char.inventory[i]
                if item then assert(itemNamed(shade.char, item.id), "and its kit: " .. item.id) end
            end
            Trait.onAnyTurnStart(c, d)
            local n = 0
            for _, u in ipairs(c.units) do if u.alive and u.shadeOf == sleeper then n = n + 1 end end
            assert(n == 1, "one dreamer, one nightmare")
            Status.remove(c, sleeper, "status_sleep")
            Trait.onAnyTurnEnd(c, sleeper)
            assert(not shade.alive, "the shade goes when the sleeper wakes")
        end,
    },

    -- ------------------------------------------------------------------------------------ her trophies
    {
        name = "the Long Sleep banks a turn for each round you use nothing, up to 3, and a blow takes them all",
        fn = function()
            local c = Fixture.combat(board(9),
                { unit("character_knight", 2, 2, { isolate = "bare", items = { "utility_the_long_sleep" },
                    stats = { health = 200 } }) },
                { unit("character_bandit", 8, 8) })
            local k = party(c)[1]
            for _ = 1, 4 do
                Trait.onAnyTurnStart(c, k)
                Trait.onAnyTurnEnd(c, k)
            end
            assert(Bank.count(k) == 3, "banked to the cap of 3")
            Bank.spend(c, k)
            Trait.onAnyTurnStart(c, k)
            Combat.tally(k, "cast", 1)
            Trait.onAnyTurnEnd(c, k)
            assert(Bank.count(k) == 0, "a round you used something banks nothing")
            for _ = 1, 3 do
                Trait.onAnyTurnStart(c, k)
                Trait.onAnyTurnEnd(c, k)
            end
            k.initiative = 20
            Combat.dealFlatDamage(c, k, 5, { "physical" }, "test", one(c, "character_bandit"), { raw = true })
            assert(Bank.count(k) == 0, "struck: the bank is taken")
            assert(k.initiative == 0, "the turn comes round at once")
            assert(k.extraActions == 2, "with the rest of the bank as actions back to back")
        end,
    },
    {
        name = "Lull: at the end of the caster's round, every foe that did not move falls Asleep",
        fn = function()
            local c = Fixture.combat(board(9),
                { unit("character_archer", 2, 2, { isolate = "bare", items = { "ability_lull" },
                    stats = { mana = 60 } }) },
                { unit("character_bandit", 6, 6), unit("character_bandit", 8, 8) })
            local me = party(c)[1]
            local walkerFoe, stillFoe = Combat.unitAt(c, 6, 6), Combat.unitAt(c, 8, 8)
            openTurn(c, me)
            assert(Combat.useItem(c, me, itemNamed(me.char, "ability_lull"), me.x, me.y), "Lull is cast")
            assert(Status.has(me, "status_lull"), "the round is watched")
            Combat.tally(walkerFoe, "tilesMoved", 1)
            Status.onTurnStart(c, me)
            assert(Status.has(stillFoe, "status_sleep"), "the foe that stood still falls Asleep")
            assert(not Status.has(walkerFoe, "status_sleep"), "the one that walked does not")
            assert(not Status.has(me, "status_lull"), "and the Lull is done")
        end,
    },
    {
        name = "the Nightmare Lantern: while a foe sleeps, a shade of it fights for you",
        fn = function()
            local c = Fixture.combat(board(9),
                { unit("character_archer", 2, 2, { isolate = "bare", items = { "utility_nightmare_lantern" } }) },
                { unit("character_bandit", 8, 8) })
            local me, foe = party(c)[1], one(c, "character_bandit")
            assert(Status.apply(c, foe, "status_sleep", {}))
            Trait.onAnyTurnStart(c, me)
            local shade
            for _, u in ipairs(c.units) do if u.alive and u.shadeOf == foe then shade = u end end
            assert(shade and shade.side == "party", "a shade of the sleeper stands up on your side")
            Status.remove(c, foe, "status_sleep")
            Trait.onAnyTurnEnd(c, foe)
            assert(not shade.alive, "and it is gone when the foe wakes")
        end,
    },
    {
        name = "Restless Mail: put to Sleep, wake at once, and the next blow is Empowered by half your Damage",
        fn = function()
            local c = Fixture.combat(board(9),
                { unit("character_knight", 2, 2, { isolate = "bare", items = { "armor_restless_mail" } }) },
                { unit("character_bandit", 8, 8) })
            local k = party(c)[1]
            local before = k.initiative
            local half = math.max(1, math.floor(Combat.flatStat(k, "damage") * 0.5))
            Status.apply(c, k, "status_sleep", {})
            assert(not Status.has(k, "status_sleep"), "it does not stay down")
            assert(k.initiative == before, "and loses no time to it")
            local emp = Status.get(k, "status_empowered")
            assert(emp and emp.magnitude == half, "its next blow carries half its Damage again")
        end,
    },
}
