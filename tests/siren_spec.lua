-- Tests for LUST'S FEN (2026-09-25): the ground swap, the naga's move, and the Siren line, each rule the
-- two review rounds approved pinned on a bare board --
--   * Lust fights on the swamp and Greed in the keep; the fen's fights sit on the floors review placed
--   * Longing bills a WALK that ends farther from the singer, and nothing else (status_longing)
--   * Singing lands Longing on whoever hears -- within four, or Wet anywhere -- breaks on a blow, and
--     every song ends with its singer (status_singing, Combat.hears, releaseCharmedBy)
--   * the Only Voice shuts the heal, the ally's buff and the ally's cleanse (Status.deafToAllies)
--   * Held Note, Beeswax, the Mast-Rope, Deaf Heart, the Siren's Comb and Echo, one rule each
--   * only a swimmer's shove drowns a body on the fen (Combat.bankHolds)

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Arena = require("models.arena")
local Terrain = require("models.terrain")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local KIT = { "ability_siren_song", "utility_sirens_tail", "utility_lorelei_rock" }
local DROPS = {
    character_siren = { "utility_beeswax", "utility_sirens_comb", "utility_mast_rope", "utility_echo" },
    character_lorelei = { "utility_deaf_heart", "utility_held_note" },
}

local function sinNamed(id)
    for _, s in ipairs(Descent.SINS) do if s.id == id then return s end end
end

-- A board of open ground, optionally with a channel of deep water standing its own drowning zones (a
-- real board does -- tests/deep_water_spec.lua learned that the hard way), on the named biome.
local function board(opts)
    opts = opts or {}
    local cols, rows = opts.cols or 12, opts.rows or 12
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    local hazards = {}
    local deep = Terrain.get("deep")
    for _, c in ipairs(opts.deep or {}) do
        tiles[c.y][c.x] = { type = "deep", moveCost = deep.moveCost, walkable = deep.walkable,
                            sightCost = deep.sightCost, tags = deep.tags, swim = deep.swim, drowns = deep.drowns }
        local spec = Arena.TERRAIN_ZONES.deep
        hazards[#hazards + 1] = { id = spec.id, x = c.x, y = c.y, duration = spec.duration }
    end
    return { cols = cols, rows = rows, tiles = tiles, hazards = hazards, biome = opts.biome or "swamp",
             objective = { type = "killAll" } }
end

-- A sturdy company body with nothing in its grid but what a case hands it.
local function body(x, y, items, health)
    return unit("character_knight", x, y, { isolate = "bare", items = items or {},
        stats = { health = health or 200, mana = 60, movement = 6 } })
end

local function sing(c, siren)
    openTurn(c, siren)
    local song = itemNamed(siren.char, "ability_siren_song")
    assert(song, "she carries the song")
    assert(Combat.useItem(c, siren, song, siren.x, siren.y), "the song is sung")
    assert(Status.has(siren, "status_singing"), "and she is Singing")
end

local function longingOn(u)
    for _, s in ipairs(u.statuses or {}) do if s.id == "status_longing" then return s end end
end

return {
    -- ------------------------------------------------------------------------------ the ground
    {
        name = "Lust fights on the fen and Greed in the keep, and the naga came down with Lust",
        fn = function()
            assert(sinNamed("lust").biome == "swamp", "Lust's floors are the swamp")
            assert(sinNamed("greed").biome == "castle", "Greed's are the keep")
            for _, id in ipairs({ "encounter_the_shoal", "encounter_the_undertow", "encounter_the_reed_choir",
                                  "encounter_the_lorelei_rock", "encounter_the_still_water",
                                  "encounter_lust_the_open_roof", "encounter_the_velvet_queen" }) do
                local enc = Encounter.get(id)
                assert(enc.condition({ biome = "swamp" }) and not enc.condition({ biome = "castle" }),
                    id .. " is locked to the fen")
            end
            for _, id in ipairs({ "encounter_fen_ooze", "encounter_the_king_slime" }) do
                local enc = Encounter.get(id)
                assert(enc.condition({ biome = "castle" }) and not enc.condition({ biome = "swamp" }),
                    id .. " went up to the keep with Greed")
            end
            local greed = sinNamed("greed")
            assert(greed.guardian.filler ~= "character_fen_lancer" and greed.minor.lead ~= "character_fen_lancer",
                "no lancer is seated in the keep")
        end,
    },
    {
        name = "the fen's fights sit where review placed them: Choir and Rock on floor three, the rest on four",
        fn = function()
            local want = {
                encounter_the_reed_choir = { kind = "combat", rung = 1 },
                encounter_the_lorelei_rock = { kind = "elite", rung = 1 },
                encounter_the_shoal = { kind = "combat", rung = 2 },
                encounter_the_undertow = { kind = "elite", rung = 2 },
                encounter_the_still_water = { kind = "elite", rung = 2 },
            }
            for id, w in pairs(want) do
                local enc = Encounter.get(id)
                assert(enc.kind == w.kind and enc.rung == w.rung, id .. " is a rung-" .. w.rung .. " " .. w.kind)
            end
            local ctx = { biome = "swamp", depth = 3, rung = 1, seed = 1 }
            local function has(list, id) for _, x in ipairs(list) do if x == id then return true end end end
            assert(has(Encounter.get("encounter_the_reed_choir").composition(ctx), "character_siren"), "the Choir has its Siren")
            local rock = Encounter.get("encounter_the_lorelei_rock").composition(ctx)
            assert(rock[1] == "character_lorelei", "the Rock is the Lorelei's")
            ctx.rung = 2
            assert(has(Encounter.get("encounter_the_undertow").composition(ctx), "character_siren"),
                "a Siren sings in the Undertow's fight")
            assert(Encounter.get("encounter_the_still_water").composition(ctx)[1] == "character_nethrys",
                "Nethrys is an elite now, and the rift fields her")
            -- Lust's own spares list names all three new elites, so each is a board the circle can deal.
            local spares = {}
            for _, id in ipairs(sinNamed("lust").elites.spares) do spares[id] = true end
            for _, id in ipairs({ "encounter_the_lorelei_rock", "encounter_the_undertow", "encounter_the_still_water" }) do
                assert(spares[id], id .. " is one of Lust's spares")
            end
        end,
    },
    {
        name = "the Siren and the Lorelei carry creature kit, and every drop is an unstocked Cathedral trophy",
        fn = function()
            for _, id in ipairs(KIT) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal and def.price == nil,
                    id .. " is unpriced, unstealable creature kit")
            end
            assert(Item.defs["utility_lorelei_rock"].rules.noMove, "the Lorelei never leaves her rock")
            for bodyId, drops in pairs(DROPS) do
                local def = Character.defs[bodyId]
                assert(def, bodyId .. " exists")
                for _, id in ipairs(def.startingItems) do
                    if id then
                        local item = Item.defs[id]
                        assert(item, id .. " exists")
                        if id ~= "ability_brine_bolt" then
                            assert(item.class == "creature" and item.noSteal, id .. " is unstealable creature kit")
                        end
                    end
                end
                for i, id in ipairs(drops) do
                    local d = Item.defs[id]
                    assert(d and d.class == "priest" and d.unstocked and d.price == nil,
                        id .. " is seen on the Cathedral's rack and never sold")
                    assert(def.drops[i] == id, bodyId .. " drops " .. id)
                end
            end
        end,
    },

    -- ------------------------------------------------------------------------------ Longing
    {
        name = "Longing bills each step that ends farther from the singer, and not a step toward her",
        fn = function()
            local c = Combat.new(board(), { body(5, 7) }, { unit("character_siren", 5, 3) })
            local walker, siren = c.units[1], c.units[2]
            Status.apply(c, walker, "status_longing", { applier = siren })
            local start = hp(walker)
            openTurn(c, walker)
            assert(Combat.moveUnit(c, walker, 5, 9), "the walk away is legal")
            assert(start - hp(walker) == 6, "two steps away cost 3 each (lost " .. (start - hp(walker)) .. ")")
            local after = hp(walker)
            openTurn(c, walker)
            assert(Combat.moveUnit(c, walker, 5, 5), "the walk back is legal")
            assert(hp(walker) == after, "walking toward her is free")
            openTurn(c, walker)
            assert(Combat.moveUnit(c, walker, 8, 5), "a walk across is legal")
            -- (5,5) -> (8,5): each step is a sidestep or away; only the steps that open the gap bill.
            assert(hp(walker) < after, "a walk that ends farther away costs")
        end,
    },
    {
        name = "a shove away from the singer costs nothing: only a body's own feet are billed",
        fn = function()
            local c = Combat.new(board(), { body(5, 6) }, { unit("character_siren", 5, 3), unit("character_harpy", 5, 5) })
            local walker, siren, harpy = c.units[1], c.units[2], c.units[3]
            Status.apply(c, walker, "status_longing", { applier = siren })
            local start = hp(walker)
            local moved = Combat.knockback(c, harpy, walker, 2, { amount = 0 })
            assert(moved and walker.y > 6, "the gust carried it away from her")
            assert(hp(walker) == start, "and Longing billed nothing for it")
        end,
    },

    -- ------------------------------------------------------------------------------ the song
    {
        name = "the song reaches every foe within four tiles and every Wet foe anywhere, and no dry one far off",
        fn = function()
            local c = Combat.new(board(), { body(2, 5), body(11, 11), body(11, 1) },
                { unit("character_siren", 2, 2) })
            local near, wet, dry, siren = c.units[1], c.units[2], c.units[3], c.units[4]
            Status.apply(c, wet, "status_wet")
            sing(c, siren)
            assert(longingOn(near), "a foe three tiles off hears her")
            assert(longingOn(wet), "a soaked foe hears her from across the board")
            assert(not longingOn(dry), "a dry foe nine tiles off does not")
            assert(longingOn(near).singer == siren, "and the Longing names who sang it")
        end,
    },
    {
        name = "a blow breaks the song, and a Held Note shrugs off the first one each battle",
        fn = function()
            local c = Combat.new(board(), { body(2, 5) }, { unit("character_siren", 2, 2) })
            local siren = c.units[2]
            sing(c, siren)
            Combat.dealFlatDamage(c, siren, 5, { "slash" }, "a test blow")
            assert(not Status.has(siren, "status_singing"), "one blow ends a plain Siren's song")

            c = Combat.new(board(), { body(2, 5) },
                { unit("character_siren", 2, 2, { items = { "utility_held_note" } }) })
            siren = c.units[2]
            sing(c, siren)
            Combat.dealFlatDamage(c, siren, 5, { "slash" }, "a test blow")
            assert(Status.has(siren, "status_singing"), "a Held Note keeps the song through the first blow")
            Combat.dealFlatDamage(c, siren, 5, { "slash" }, "a test blow")
            assert(not Status.has(siren, "status_singing"), "and not through the second")
        end,
    },
    {
        name = "the song ends with its singer: Longing and the Only Voice lift when she falls",
        fn = function()
            local c = Combat.new(board(), { body(2, 5) }, { unit("character_lorelei", 2, 2) })
            local near, lorelei = c.units[1], c.units[2]
            sing(c, lorelei)
            assert(longingOn(near) and Status.has(near, "status_the_only_voice"),
                "the Lorelei sings both songs")
            Combat.dealFlatDamage(c, lorelei, 9999, { "slash" }, "a test blow", nil, { raw = true })
            assert(not lorelei.alive, "she falls")
            assert(not longingOn(near) and not Status.has(near, "status_the_only_voice"),
                "and both songs end with her")
        end,
    },
    {
        name = "the Only Voice shuts the heal, an ally's buff and an ally's cleanse -- and nothing else",
        fn = function()
            local c = Combat.new(board(), { body(2, 5, { "ability_cure" }), body(3, 5) },
                { unit("character_siren", 9, 9) })
            local friend, deaf, siren = c.units[1], c.units[2], c.units[3]
            Status.apply(c, deaf, "status_the_only_voice", { applier = siren })
            deaf.char.stats.health.current = 100
            assert(Combat.applyHeal(c, deaf, 20) == 0 and hp(deaf) == 100, "no heal lands")
            assert(Status.apply(c, deaf, "status_hasted", { applier = friend }) == nil, "an ally's Haste does not land")
            assert(Status.apply(c, deaf, "status_hasted", { applier = deaf }) ~= nil, "its own does")
            openTurn(c, friend)
            Combat.useItem(c, friend, itemNamed(friend.char, "ability_cure"), deaf.x, deaf.y)
            assert(Status.has(deaf, "status_the_only_voice"), "an ally's Cure does not reach it")
            assert(Status.apply(c, deaf, "status_burn", { applier = siren }) ~= nil, "a foe's debuff still lands")
        end,
    },

    -- ------------------------------------------------------------------------------ the drops
    {
        name = "Beeswax: deaf to the song and to Charm, and to an ally's buff -- but a heal still lands",
        fn = function()
            local c = Combat.new(board(), { body(2, 5, { "utility_beeswax" }), body(3, 5) },
                { unit("character_siren", 2, 2) })
            local waxed, friend, siren = c.units[1], c.units[2], c.units[3]
            sing(c, siren)
            assert(not longingOn(waxed), "the song does not reach waxed ears")
            assert(longingOn(friend), "the unwaxed friend beside it hears her")
            assert(Status.apply(c, waxed, "status_charm", { applier = siren }) == nil, "and no charm lands")
            assert(Status.apply(c, waxed, "status_hasted", { applier = friend }) == nil, "an ally's Haste does not land")
            waxed.char.stats.health.current = 100
            assert(Combat.applyHeal(c, waxed, 20) > 0, "a heal still does")
        end,
    },
    {
        name = "the Mast-Rope anchors its bearer and every ally touching it, and nobody who has stepped away",
        fn = function()
            local c = Combat.new(board(), { body(5, 6, { "utility_mast_rope" }), body(5, 7), body(8, 8) },
                { unit("character_harpy", 5, 5) })
            local rope, lashed, loose, harpy = c.units[1], c.units[2], c.units[3], c.units[4]
            assert(Status.blocksForcedMove(rope) and Status.blocksForcedMove(lashed), "both ends of the rope hold")
            assert(not Status.blocksForcedMove(loose), "a body not touching the line is loose")
            local moved = Combat.knockback(c, harpy, rope, 2, { amount = 0 })
            assert((moved or 0) == 0 and rope.y == 6, "the bearer is not thrown")
            lashed.x, lashed.y = 10, 10
            assert(not Status.blocksForcedMove(rope), "alone, the bearer is movable again")
        end,
    },
    {
        name = "Deaf Heart: a foe within two tiles of the bearer cannot be healed or buffed by its allies",
        fn = function()
            local c = Combat.new(board(), { body(2, 2, { "utility_deaf_heart" }) },
                { unit("character_harpy", 2, 4), unit("character_harpy", 9, 9), unit("character_harpy", 9, 10) })
            local near, far, friend = c.units[2], c.units[3], c.units[4]
            near.char.stats.health.current, far.char.stats.health.current = 10, 10
            assert(Combat.applyHeal(c, near, 5) == 0, "the foe beside the heart takes no heal")
            assert(Combat.applyHeal(c, far, 5) > 0, "a foe out of its reach does")
            assert(Status.apply(c, near, "status_hasted", { applier = friend }) == nil, "nor an ally's buff")
        end,
    },
    {
        name = "the Siren's Comb carries an ability two tiles further to a Wet foe, and only to a Wet one",
        fn = function()
            local c = Combat.new(board(), { body(1, 1, { "ability_jolt", "utility_sirens_comb" }) },
                { unit("character_harpy", 1, 6), unit("character_harpy", 6, 1) })
            local caster, wet, dry = c.units[1], c.units[2], c.units[3]
            Status.apply(c, wet, "status_wet")
            local reach = {}
            for _, t in ipairs(Combat.abilityTargets(c, caster, itemNamed(caster.char, "ability_jolt"))) do reach[t] = true end
            assert(reach[wet], "a Wet foe five tiles off is in reach of a range-3 spell")
            assert(not reach[dry], "a dry one five tiles off is not")
            openTurn(c, caster)
            assert(Combat.useItem(c, caster, itemNamed(caster.char, "ability_jolt"), wet.x, wet.y),
                "and the cast gate agrees with the target list")
        end,
    },
    {
        name = "Echo: an ally's cast within earshot lends the bearer a half-power copy, spent on use",
        fn = function()
            local c = Combat.new(board(), { body(1, 4, { "utility_echo" }), body(2, 4, { "ability_jolt" }) },
                { unit("character_harpy", 2, 6, { stats = { health = 500 } }) })
            local echo, caster, foe = c.units[1], c.units[2], c.units[3]
            openTurn(c, caster)
            assert(Combat.useItem(c, caster, itemNamed(caster.char, "ability_jolt"), foe.x, foe.y), "the ally casts")
            local copy
            for _, it in ipairs(Character.eachItem(echo.char)) do if it.echo then copy = it end end
            assert(copy and copy.id == "ability_jolt", "the bearer holds an echo of it")
            local full = itemNamed(caster.char, "ability_jolt").activeAbility.damage
            assert(copy.activeAbility.damage == math.max(1, math.floor(full / 2)), "at half power")
            openTurn(c, echo)
            assert(Combat.useItem(c, echo, copy, foe.x, foe.y), "the echo is thrown")
            for _, it in ipairs(Character.eachItem(echo.char)) do assert(not it.echo, "and spent") end
        end,
    },

    -- ------------------------------------------------------------------------------ the bank
    {
        name = "on the fen only a swimmer's shove drowns a body; elsewhere, and from the player, any shove does",
        fn = function()
            local channel = {}
            for x = 1, 12 do channel[#channel + 1] = { x = x, y = 8 } end
            -- A harpy's gust stops at the bank.
            local c = Combat.new(board({ deep = channel }), { body(5, 7) }, { unit("character_harpy", 5, 6) })
            local victim, harpy = c.units[1], c.units[2]
            Combat.knockback(c, harpy, victim, 1, { amount = 0 })
            assert(victim.alive and victim.y == 7, "a harpy cannot put you in the water on the fen")
            -- The Undertow can.
            c = Combat.new(board({ deep = channel }), { body(5, 7) }, { unit("character_undertow", 5, 6) })
            victim = c.units[1]
            Combat.knockback(c, c.units[2], victim, 1, { amount = 0 })
            assert(not victim.alive and victim.sank, "a naga drowns you")
            -- The player's own shove is untouched.
            c = Combat.new(board({ deep = channel }), { body(5, 6) }, { unit("character_harpy", 5, 7) })
            Combat.knockback(c, c.units[1], c.units[2], 1, { amount = 0 })
            assert(not c.units[2].alive, "a company still drowns what it throws in")
            -- And another circle's ground keeps its drop: the rule is the fen's.
            c = Combat.new(board({ deep = channel, biome = "spire" }), { body(5, 7) }, { unit("character_harpy", 5, 6) })
            Combat.knockback(c, c.units[2], c.units[1], 1, { amount = 0 })
            assert(not c.units[1].alive, "on the spire a harpy's gust still drowns")
        end,
    },
}
