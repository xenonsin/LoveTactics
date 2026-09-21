-- THE MERE: the faction, its kit, and the one flag that keeps its kit off every counter.
--
-- The ground it fights on is tests/deep_water_spec.lua and the axis it is built on is
-- tests/race_spec.lua. What is left is the part a player actually touches -- nine pieces of gear and
-- five bodies -- and three claims about them that no single file can see:
--
--   1. THE FACTION IS ONE SENTENCE. The lancer soaks, the caller conducts, the undertow drags. Each of
--      those lives in a different file, and the value of any one of them is entirely in the other two.
--   2. `dropOnly` IS A SECOND KIND OF MONSTER DROP. It is refused at every counter forever and it
--      still sells back -- which is exactly the combination `unstocked` exists to refuse. The two have
--      to be held apart on purpose or one of them will quietly become the other.
--   3. THE PIKE AND THE WRAP ARE THE SAME TRICK, POINTED BACK. The whole pitch of the elite rung is "I
--      want the thing she just used"; here that means taking the lane off her and using it on her.

local Fixture = require("tests.support.fixture")
local Item = require("models.item")
local Character = require("models.character")
local Combat = require("models.combat")
local Status = require("models.status")
local Vendor = require("models.vendor")
local Terrain = require("models.terrain")

-- Every piece the Mere carries or drops. Named rather than swept, so adding one is a line somebody
-- writes a sentence next to -- the rule tests/discovery_spec.lua's TROPHIES list already keeps.
local KIT = {
    "weapon_silt_knife", "weapon_brackish_lance", "weapon_undertow_pike",
    "ability_brine_bolt", "ability_stormwake", "ability_riptide", "ability_breaker",
    "armor_scale_hauberk", "utility_gillscale_wrap",
}

local BODIES = {
    "character_shoalkin", "character_fen_lancer", "character_tidecaller",
    "character_undertow", "character_nethrys",
}

-- A board with a channel running down one column, and the ground's own drowning zone standing on every
-- tile of it -- exactly as models/arena.lua appends them at build time. A channel with no drowning in
-- it is not a channel, and a fixture that forgot them would report that deep water is harmless.
local function channelBoard(col)
    col = col or 4
    local deep = Terrain.get("deep")
    local patches, hazards = {}, {}
    for y = 1, 8 do
        patches[#patches + 1] = {
            x = col, y = y, type = "deep",
            moveCost = deep.moveCost, walkable = deep.walkable, sightCost = deep.sightCost,
            tags = deep.tags, swim = deep.swim, drowns = deep.drowns,
        }
        hazards[#hazards + 1] = { id = "hazard_deep_water", x = col, y = y, duration = 9999 }
    end
    local map = Fixture.new(8, 8, { tiles = patches })
    map.hazards = hazards
    return map
end

local tests = {}

tests[#tests + 1] = { name = "every piece of the Mere's kit exists and is drop-only", fn = function()
    for _, id in ipairs(KIT) do
        local def = Item.defs[id]
        assert(def, id .. " is named by this spec and is not in the data")
        assert(def.dropOnly, id .. " is the Mere's and must be `dropOnly`: no smith in the city works "
            .. "in scale and silt")
        -- The two flags are not the same statement, and carrying both would be carrying the stricter
        -- one in silence.
        assert(not def.unstocked, id .. " carries BOTH flags. `unstocked` is priceless in either "
            .. "direction; `dropOnly` sells back. Pick the claim you mean.")
        assert(not def.price, id .. " carries a price. Only abilities, consumables and a house's "
            .. "opening weapon do (docs/shelf.md); a found ware is worth what its depth implies.")
        assert(def.dropTier, id .. " has no depth, so nothing can ever drop it")
        assert(def.class, id .. " names no shelf, so tools/drop_tier.lua will never mint it a depth")
    end
end }

tests[#tests + 1] = { name = "the city refuses the Mere's kit forever, and still buys it back", fn = function()
    for _, id in ipairs(KIT) do
        local def = Item.defs[id]
        -- Refused at every rung there is, the top included. This is the half `unstocked` shares: the
        -- refusal names somewhere to go, and the somewhere is a body rather than a ladder.
        local reason = Vendor.lockReason(def, 99, nil, nil)
        assert(reason == "monster drop", id .. " is shut for " .. tostring(reason)
            .. " at the top of the ladder -- a drop-only piece is refused forever, not until a rung")
        -- ...and this is the half it does not share. A trophy answers 0 here.
        local worth = Vendor.sellValue(Item.instantiate(id))
        assert(worth > 0, id .. " sells back for nothing. `dropOnly` says the city does not STOCK it, "
            .. "not that it is worthless -- that is what `unstocked` says, and it is a different flag.")
    end
end }

tests[#tests + 1] = { name = "every naga body is a naga, and is known for something", fn = function()
    for _, id in ipairs(BODIES) do
        local def = Character.defs[id]
        assert(def, id .. " is named by this spec and is not in the data")
        assert(def.race == "naga", id .. " is in the Mere and does not declare the race")
        assert(def.kind == "humanoid", id .. ": a naga is somebody, which is what lets it carry a shelf")
        assert(def.drops and #def.drops > 0, id .. " is known for nothing -- a body with no `drops` "
            .. "list reaches the player only through the price band's long tail (docs/drops.md)")
        for _, dropped in ipairs(def.drops) do
            assert(Item.defs[dropped], id .. " drops " .. dropped .. ", which does not exist")
        end
    end
end }

tests[#tests + 1] = { name = "the lancer soaks the rank BEHIND the one it skewers", fn = function()
    local map = Fixture.new(8, 8)
    local c = Fixture.combat(map,
        { Fixture.unit("character_fen_lancer", 2, 4, { isolate = "bare",
            items = { "weapon_brackish_lance" } }) },
        { Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { health = 300, defense = 0 } }),
          Fixture.unit("character_bandit", 4, 4, { isolate = "bare", stats = { health = 300, defense = 0 } }) })
    local user, near, far = c.units[1], c.units[2], c.units[3]

    Combat.useItem(c, user, user.char.inventory[1], 3, 4)

    assert(not Status.has(near, "status_wet"), "the body on the point is skewered, not soaked")
    assert(Status.has(far, "status_wet"), "the spear's status lands on the FAR tile (docs/weapons.md)")
end }

tests[#tests + 1] = { name = "the knife collects on what the rest of the faction leaves", fn = function()
    -- WET IS THE MERE'S SHARED VERB, and this is the case that makes the faction one sentence rather
    -- than four bodies. The knife is worth looting precisely because the player can make things Wet
    -- too -- Tidesbreak, the Brackish Lance, a Rain cloud, any fight near water.
    local function hit(soaked)
        local c = Fixture.combat(Fixture.new(8, 8),
            { Fixture.unit("character_shoalkin", 2, 4, { isolate = "bare",
                items = { "weapon_silt_knife" }, stats = { damage = 0 } }) },
            { Fixture.unit("character_bandit", 3, 4, { isolate = "bare",
                stats = { health = 300, defense = 0, magicDefense = 0, luck = 0 } }) })
        local user, foe = c.units[1], c.units[2]
        if soaked then Status.apply(c, foe, "status_wet") end
        local before = foe.char.stats.health.current
        Combat.useItem(c, user, user.char.inventory[1], foe.x, foe.y)
        return before - foe.char.stats.health.current
    end

    local dry, wet = hit(false), hit(true)
    assert(dry > 0, "the knife hits a dry target at all")
    assert(wet > dry, string.format(
        "silt in an open cut: %d against a soaked target is no more than %d against a dry one", wet, dry))
end }

tests[#tests + 1] = { name = "the pike reaches past the front rank and drags the body behind it", fn = function()
    local c = Fixture.combat(Fixture.new(8, 8),
        { Fixture.unit("character_undertow", 2, 4, { isolate = "bare",
            items = { "weapon_undertow_pike" }, stats = { damage = 0 } }) },
        { Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { health = 300, defense = 0 } }),
          Fixture.unit("character_bandit", 4, 4, { isolate = "bare", stats = { health = 300, defense = 0 } }) })
    local user, near, far = c.units[1], c.units[2], c.units[3]

    Combat.useItem(c, user, user.char.inventory[1], 3, 4)

    assert(near.x == 3 and near.y == 4, "the body on the point holds its ground")
    assert(far.x == 4 and far.y == 4,
        "the far body cannot come forward: the near body is standing in the only tile it would go to")

    -- ...and with the near tile empty, the same thrust brings it a step. Aimed at an EMPTY tile, which
    -- the weapon allows (`allowOccupied` is permission, not a requirement).
    local d = Fixture.combat(Fixture.new(8, 8),
        { Fixture.unit("character_undertow", 2, 4, { isolate = "bare",
            items = { "weapon_undertow_pike" }, stats = { damage = 0 } }) },
        { Fixture.unit("character_bandit", 4, 4, { isolate = "bare", stats = { health = 300, defense = 0 } }) })
    Combat.useItem(d, d.units[1], d.units[1].char.inventory[1], 3, 4)
    assert(d.units[2].x == 3, "the far body is dragged one step toward the bearer")
end }

tests[#tests + 1] = { name = "the pike may never aim at water, so the lane cast is what drowns you", fn = function()
    -- THE PAYOFF, AND THE CORRECTION THAT FOUND IT. The pike drags the far body onto the AIMED tile,
    -- and a tile-targeted cast is refused outright when that tile is not walkable ("blocked tile") --
    -- so the one aim that would put somebody in the channel is the one aim the weapon may never name.
    -- This spec was written claiming it could and failed, which is the file's own header being wrong
    -- rather than the engine.
    --
    -- A LANE CAST HAS NO SUCH LIMIT, because a knockback along a lane never names the tile it ends on:
    -- it aims at the adjacent tile (walkable, as every lane cast does) and shoves each body one step
    -- along, through whatever the lane crosses. So Riptide drags a body off the FAR bank into the
    -- channel between -- which is the Undertow's real killing verb, and the reason her pike and her
    -- cast are a pair rather than two copies of one idea.
    local blocked = Fixture.combat(channelBoard(3),
        { Fixture.unit("character_undertow", 2, 4, { isolate = "bare",
            items = { "weapon_undertow_pike" }, stats = { damage = 0 } }) },
        { Fixture.unit("character_bandit", 4, 4, { isolate = "bare", stats = { health = 300, defense = 0 } }) })
    -- Combat.useItem is where the tile is judged ("blocked tile"), so the refusal is read off the
    -- attempt itself: the mark does not move and the water does not take it.
    local mark0 = blocked.units[2]
    local ok = Combat.useItem(blocked, blocked.units[1], blocked.units[1].char.inventory[1], 3, 4)
    assert(not ok, "a thrust aimed into the channel is refused rather than quietly doing nothing")
    assert(mark0.alive and mark0.x == 4, "and nothing on the board moved for it")

    -- ...and the cast that can. Caster on the near bank, channel at column 4, mark on the far bank at
    -- (5,4): the lane runs (3,4) (4,4) (5,4), the mark is dragged one step toward her, and the step
    -- lands in the water.
    local c = Fixture.combat(channelBoard(4),
        { Fixture.unit("character_undertow", 2, 4, { isolate = "bare",
            items = { "ability_riptide" }, stats = { magicDamage = 0, mana = 99 } }) },
        { Fixture.unit("character_bandit", 5, 4, { isolate = "bare", stats = { health = 300, defense = 0 } }) })
    local user, mark = c.units[1], c.units[2]

    Combat.useItem(c, user, user.char.inventory[1], 3, 4)

    assert(not mark.alive, "the channel took it")
    assert(mark.sank, "it went under rather than falling over -- there is no body on the water")
    assert(not mark.corpse and not mark.incapacitated, "and nothing left for anybody to reach")
end }

tests[#tests + 1] = { name = "a shove into the channel drowns a walker and spares a swimmer", fn = function()
    for _, kit in ipairs({ {}, { "utility_gillscale_wrap" } }) do
        local swims = #kit > 0
        local c = Fixture.combat(channelBoard(4),
            { Fixture.unit("character_undertow", 2, 4, { isolate = "bare" }) },
            { Fixture.unit("character_bandit", 3, 4,
                { isolate = "bare", items = kit, stats = { health = 300, defense = 0 } }) })
        local shover, victim = c.units[1], c.units[2]
        Combat.knockback(c, shover, victim, 1)
        assert(victim.x == 4, "the shove carried into the channel either way")
        if swims then
            assert(victim.alive and not victim.sank, "a swimmer stands in the channel")
        else
            assert(not victim.alive and victim.sank, "and a walker goes under it")
        end
    end
end }

tests[#tests + 1] = { name = "the Wrap turns the arena's walls into the wearer's road", fn = function()
    -- What the elite's drop actually BUYS, stated as reach rather than as prose: the same body, on the
    -- same board, one item apart.
    local dry = Fixture.combat(channelBoard(4), { Fixture.unit("character_bandit", 3, 4,
        { isolate = "bare", stats = { movement = 6 } }) }, {})
    local wet = Fixture.combat(channelBoard(4), { Fixture.unit("character_bandit", 3, 4,
        { isolate = "bare", items = { "utility_gillscale_wrap" }, stats = { movement = 6 } }) }, {})

    local onFoot = Combat.reachable(dry, dry.units[1])
    local afloat = Combat.reachable(wet, wet.units[1])
    assert(not onFoot["4,4"], "the channel is a wall to a walker")
    assert(not onFoot["5,4"], "and so is everything past it")
    assert(afloat["4,4"], "a swimmer stands in it")
    assert(afloat["5,4"], "and crosses to the far bank")
end }

tests[#tests + 1] = { name = "the Scale Hauberk is dropped and never worn", fn = function()
    -- The race already carries `lightning = -4`; a naga in naga plate would sit at -8 and fold to one
    -- bolt with no file saying why. A `drops` entry is read separately from a grid (docs/drops.md), so
    -- the coat falls off a body that never had it on -- the cheapest possible way to keep one fact from
    -- being stated twice on the same body.
    local dropped = false
    for _, id in ipairs(BODIES) do
        local def = Character.defs[id]
        for _, item in ipairs(def.startingItems or {}) do
            assert(item ~= "armor_scale_hauberk", id .. " WEARS the hauberk. Its lightning line and the "
                .. "naga race's would sum to -8 on the same body.")
        end
        for _, item in ipairs(def.drops or {}) do
            if item == "armor_scale_hauberk" then dropped = true end
        end
    end
    assert(dropped, "and nobody drops it either, so the coat is unreachable")
end }

tests[#tests + 1] = { name = "Rising Water is boss machinery, on no shelf and in nobody's pack", fn = function()
    -- A boss's own rule is creature kit (docs/bestiary.md): no class shelf, no price, no depth, and
    -- bound so it never leaves her grid. Handing the player a cast that edits the board is a different
    -- game, and the flag that refuses it is the same one that keeps the Demon Sigil's phase engine out
    -- of their hands.
    local def = Item.defs.ability_rising_water
    assert(def, "ability_rising_water is missing")
    assert(def.class == "creature", "a boss's rule belongs to no job")
    assert(def.bound and def.noSteal, "and never comes off her")
    assert(not def.price and not def.dropTier, "creature kit carries no axis at all")

    local carried = false
    for _, id in ipairs(Character.defs.character_nethrys.startingItems or {}) do
        if id == "ability_rising_water" then carried = true end
    end
    assert(carried, "and the one body it exists for does not carry it")
end }

tests[#tests + 1] = { name = "the water rises only over water, and takes what was standing in it", fn = function()
    -- Nethrys's whole fight, and the guard that keeps it from being a board-deleting cast: it deepens
    -- shallows and refuses everything else, so no cast can ever open a hole under a company that chose
    -- to stand on dry ground.
    local ford = Terrain.get("water")
    local map = Fixture.new(8, 8, { tiles = {
        { x = 4, y = 4, type = "water", moveCost = ford.moveCost, walkable = ford.walkable,
          sightCost = ford.sightCost, tags = ford.tags, swim = ford.swim },
    } })
    local c = Fixture.combat(map,
        { Fixture.unit("character_nethrys", 2, 2, { isolate = "bare" }) },
        { Fixture.unit("character_bandit", 4, 4, { isolate = "bare", stats = { health = 300 } }) })
    local victim = c.units[2]

    assert(Combat.floodTile(c, 4, 4), "the ford rises")
    assert(c.arena.tiles[4][4].type == "deep", "and is a channel now")
    assert(not c.arena.tiles[4][4].walkable, "with every property the terrain table gives a channel")
    assert(not victim.alive and victim.sank, "and the body standing in it went under")

    assert(not Combat.floodTile(c, 2, 2), "open ground does not rise -- that is the whole guard")
    assert(c.arena.tiles[2][2].type == "ground", "and stays what it was")
end }

return tests
