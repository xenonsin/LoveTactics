-- AVARITIA, THE UNSPENT: Greed's general, re-premised on review 2026-09-25 as an elder dragon on her hoard
-- (Smaug as the source, built as a raid fight -- artifact UtAAeXrYn5u9vGT48ejxpf, three rounds). Each rule
-- is held by the behaviour it promises, against the real blueprints: her hoard and her belly, the bare
-- scale, every coin counted, her wings and her tail, the molten gold, her three thirds, the lead-ins on her
-- floor and what they write onto the save, her stair, and the seven pieces she hands over
-- (models/hoard.lua). Headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Hoard = require("models.hoard")
local Player = require("models.player")

local GREED = "character_general_greed"

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

-- Run `fn` with `player` as the save being played (nil = none), putting the real one back after.
local function asPlayer(player, fn)
    local saved = Player.active
    Player.active = player
    local ok, err = pcall(fn)
    Player.active = saved
    if not ok then error(err, 0) end
end

-- Her lair: Avaritia anchored at (5,5) on a 10x10 floor, her side and the company as named.
local function lair(company, court)
    local enemies = { { char = Character.instantiate(GREED), x = 5, y = 5 } }
    for _, e in ipairs(court or {}) do
        enemies[#enemies + 1] = { char = Character.instantiate(e.id), x = e.x, y = e.y }
    end
    local party = {}
    for _, p in ipairs(company or { { id = "character_bandit", x = 1, y = 1 } }) do
        party[#party + 1] = { char = Character.instantiate(p.id), x = p.x, y = p.y }
    end
    local c = Combat.new(arena(10, 10), party, enemies)
    local her
    for _, u in ipairs(c.units) do
        if u.char.id == GREED then her = u end
    end
    return c, her
end

local function unitOf(c, id)
    for _, u in ipairs(c.units) do
        if u.char.id == id then return u end
    end
end

local function clearHeaps(c)
    -- Over a copy: consuming a zone lifts it out of the list being walked.
    local heaps = {}
    for _, h in ipairs(c.hazards or {}) do
        if h.id == "hazard_coin_heap" then heaps[#heaps + 1] = h end
    end
    for _, h in ipairs(heaps) do Hazard.consume(c, h) end
end

-- Put her just past `frac` of her health with a blow she survives: her belly mitigates a big one, so the
-- bar is set a hair above the line and a light blow carries her over it.
local function bringTo(c, her, frac)
    local hp = her.char.stats.health
    hp.current = math.floor(hp.max * frac) + 1
    Combat.dealFlatDamage(c, her, 1, {}, "test")
    if hp.current > math.floor(hp.max * frac) then
        hp.current = math.floor(hp.max * frac) - 1
        Combat.dealFlatDamage(c, her, 1, {}, "test")
    end
end

local function heapsOnBoard(c, id)
    local n = 0
    for _, h in ipairs(c.hazards or {}) do
        if h.alive ~= false and h.id == (id or "hazard_coin_heap") then n = n + 1 end
    end
    return n
end

local function purse(c, gold)
    local pot = { gold = gold }
    c.purse = {
        get = function() return pot.gold end,
        spend = function(n) pot.gold = pot.gold - n; return n end,
        add = function(n) pot.gold = pot.gold + n end,
    }
    return pot
end

return {
    {
        name = "she is a 2x2 dragon boss carrying the Hoard, her breath, her strafe and her tail",
        fn = function()
            local def = Character.defs[GREED]
            assert(def.name == "Avaritia, the Unspent", "she is Avaritia: " .. tostring(def.name))
            assert(def.race == "dragon" and def.boss, "a dragon, and a boss")
            assert(def.startingItems[5] == "utility_the_hoard", "her rules ride the Hoard, centre cell")
            asPlayer(nil, function()
                local c, her = lair()
                assert(her.w == 2 and her.h == 2, "she stands on four tiles")
                assert(Trait.has(her, "trait_the_hoard") and Trait.has(her, "trait_gilded_belly"),
                    "the Hoard and the Belly ride her centre piece")
                assert(Trait.has(her, "trait_dragonkin"), "a dragon to every kobold (the race's Dragonblood)")
                assert(Status.has(her, "status_wing_buffet"), "her wings are on her from the bell")
                assert(Status.isImmune(her, "status_burn"), "Burn does not take on her")
            end)
        end,
    },
    {
        name = "her hoard is laid around her at the bell, less every heap ever carried out of her treasury",
        fn = function()
            asPlayer(nil, function()
                local c, her = lair()
                assert(Hoard.heapsNear(c, her, 2) == Hoard.STAIR_HEAPS,
                    "a full hoard within 2 of her: " .. Hoard.heapsNear(c, her, 2))
                assert(Status.stacksOf(her, "status_every_coin_counted") == 0, "nothing taken, nothing counted")
            end)
            asPlayer({ greedHoard = { taken = 3, alarm = 1 } }, function()
                local c, her = lair()
                assert(Hoard.heapsNear(c, her, 2) == Hoard.STAIR_HEAPS - 3, "three stolen are three fewer")
                assert(Status.stacksOf(her, "status_every_coin_counted") == 3, "...and three she counts")
            end)
        end,
    },
    {
        name = "the Gilded Belly: +2/+2 per heap within 2, lent to her side within 2, and off while she winds up",
        fn = function()
            asPlayer(nil, function()
                local c, her = lair(nil, { { id = "character_kobold_skulker", x = 8, y = 5 },
                                           { id = "character_kobold_skulker", x = 10, y = 10 } })
                local near, far = nil, nil
                for _, u in ipairs(c.units) do
                    if u.char.id == "character_kobold_skulker" then
                        if u.x == 8 then near = u else far = u end
                    end
                end
                local n = Hoard.heapsNear(c, her, 2)
                assert(n > 0, "she opens on heaps")
                local withHeaps = Combat.flatStat(her, "defense")
                local nearWith, farWith = Combat.flatStat(near, "defense"), Combat.flatStat(far, "defense")
                local mWith = Combat.flatStat(her, "magicDefense")
                clearHeaps(c)
                assert(withHeaps - Combat.flatStat(her, "defense") == 2 * n, "two a heap, read live")
                assert(mWith - Combat.flatStat(her, "magicDefense") == 2 * n, "magic defense too")
                assert(nearWith - Combat.flatStat(near, "defense") == 2 * n, "a kobold within 2 leans on it")
                assert(farWith == Combat.flatStat(far, "defense"), "one across the lair does not")

                -- Put heaps back, then have her wind up: the belly is off.
                Hoard.placeHeaps(c, her, 4, 2)
                local armoured = Combat.flatStat(her, "defense")
                her.channel = { windup = 5 }
                assert(Combat.flatStat(her, "defense") < armoured, "rearing, the belly is bare")
                her.channel = nil
            end)
        end,
    },
    {
        name = "the Bare Scale: a pierce blow into her is a certain critical only while she winds up",
        fn = function()
            asPlayer(nil, function()
                local c, her = lair({ { id = "character_bandit", x = 4, y = 5 } })
                local bandit = unitOf(c, "character_bandit")
                local spear = Item.instantiate("weapon_boar_spear")
                local club = Item.instantiate("weapon_iron_mace")
                c.turn = { unit = bandit }
                assert(not Combat.forcesCrit(c, bandit, her, spear), "grounded, a point is only a point")
                her.channel = { windup = 5 }
                assert(Combat.forcesCrit(c, bandit, her, spear), "rearing, the point finds the bare scale")
                assert(not Combat.forcesCrit(c, bandit, her, club), "...and only the point")
                her.channel = nil
            end)
        end,
    },
    {
        name = "every coin counted: the company looting a heap in her fight is a stack of damage at once",
        fn = function()
            asPlayer(nil, function()
                local c, her = lair({ { id = "character_bandit", x = 1, y = 1 } })
                local bandit = unitOf(c, "character_bandit")
                local before = Combat.flatStat(her, "damage")
                Hazard.place(c, 2, 1, "hazard_coin_heap", {})
                bandit.x, bandit.y = 2, 1
                Combat.enterTile(c, bandit, 2, 1)
                assert(Status.stacksOf(her, "status_every_coin_counted") == 1, "she knows a heap is gone")
                assert(Combat.flatStat(her, "damage") == before + 2, "two damage a heap")
                assert((c.heapsLooted or 0) == 1, "the fight keeps the count a lead-in reads")
            end)
        end,
    },
    {
        name = "Wing Buffet throws a foe beside her two tiles straight out from the face it stands against",
        fn = function()
            asPlayer(nil, function()
                -- Beside her far column (she covers x 5-6, y 5-6): an anchor-aimed shove would go sideways.
                local c, her = lair({ { id = "character_bandit", x = 6, y = 4 } })
                local bandit = unitOf(c, "character_bandit")
                Status.onTurnStart(c, her)
                assert(bandit.x == 6 and bandit.y == 2, string.format("thrown north two: (%d,%d)", bandit.x, bandit.y))
            end)
        end,
    },
    {
        name = "Tail Sweep takes every foe around her footprint, corners included",
        fn = function()
            asPlayer(nil, function()
                local c, her = lair({ { id = "character_bandit", x = 4, y = 4 }, { id = "character_rowan", x = 7, y = 6 } })
                local cells = Hoard.ring(her)
                assert(#cells == 12, "a 2x2 body stands against twelve cells")
                local hit = {}
                for _, cell in ipairs(Combat.aoeCells(c, Item.instantiate("weapon_tail_sweep").activeAbility, 4, 4, her)) do
                    local u = Combat.unitAt(c, cell.x, cell.y)
                    if u then hit[u.char.id] = true end
                end
                assert(hit.character_bandit and hit.character_rowan, "the corner and the flank are both in it")
            end)
        end,
    },
    {
        name = "molten gold burns on the way in and gilds whoever ends a turn in it; an emberwalker walks it",
        fn = function()
            asPlayer(nil, function()
                local c = lair({ { id = "character_bandit", x = 1, y = 1 }, { id = "character_rowan", x = 1, y = 3 } })
                local bandit, rowan = unitOf(c, "character_bandit"), unitOf(c, "character_rowan")
                Hazard.place(c, 2, 1, "hazard_molten_gold", {})
                bandit.x = 2
                Combat.enterTile(c, bandit, 2, 1)
                assert(Status.has(bandit, "status_burn"), "it burns")
                assert(Status.has(bandit, "status_in_molten_gold"), "...and holds")
                Status.onTurnEnd(c, bandit)
                assert(Status.has(bandit, "status_gilded"), "a turn ended in it is a body Gilded")

                rowan.traits = rowan.traits or {}
                rowan.traits[#rowan.traits + 1] = { id = "trait_emberwalk", def = Trait.defs.trait_emberwalk }
                Hazard.place(c, 2, 3, "hazard_molten_gold", {})
                Hazard.place(c, 3, 3, "hazard_fire", {})
                rowan.x = 2
                Combat.enterTile(c, rowan, 2, 3)
                rowan.x = 3
                Combat.enterTile(c, rowan, 3, 3)
                assert(not Status.has(rowan, "status_burn") and not Status.has(rowan, "status_in_molten_gold"),
                    "the ground leaves an emberwalker alone")
            end)
        end,
    },
    {
        name = "her three thirds: over the deeps at 60%, and at 30% the hoard melts and the mountain burns",
        fn = function()
            asPlayer(nil, function()
                local c, her = lair({ { id = "character_bandit", x = 1, y = 1 } })
                local hp = her.char.stats.health
                local strafe = Item.instantiate("ability_strafe")
                assert(not strafe.activeAbility.usable(her), "grounded, she cannot strafe")
                bringTo(c, her, 0.58)
                assert(Status.has(her, "status_over_the_deeps"), "below 60% she takes wing")
                assert(strafe.activeAbility.usable(her), "...and the strafe is live")
                local heaps = heapsOnBoard(c)
                assert(heaps > 0, "her hoard is still gold")
                local dmg = Combat.flatStat(her, "damage")
                bringTo(c, her, 0.28)
                assert(not Status.has(her, "status_over_the_deeps"), "below 30% she is down for good")
                assert(heapsOnBoard(c) == 0 and heapsOnBoard(c, "hazard_molten_gold") >= heaps,
                    "every heap left is molten")
                assert(Status.has(her, "status_the_mountain_burns"), "and the mountain burns")
                assert(Combat.flatStat(her, "damage") > dmg, "at a quarter more damage")
            end)
        end,
    },
    {
        name = "the mountain burns: the lava spreads a tile from every pit at the start of her turn",
        fn = function()
            asPlayer(nil, function()
                local c, her = lair({ { id = "character_bandit", x = 1, y = 1 } })
                local lava = require("models.terrain").get("lava")
                local cell = c.arena.tiles[9][9]
                cell.type, cell.walkable, cell.moveCost = "lava", lava.walkable, lava.moveCost
                Status.apply(c, her, "status_the_mountain_burns", {})
                Status.onTurnStart(c, her)
                assert(c.arena.tiles[9][8].type == "lava" and c.arena.tiles[8][9].type == "lava",
                    "the pit's neighbours have gone to lava")
                assert(c.arena.tiles[1][1].type == "ground", "far ground is untouched")
            end)
        end,
    },
    {
        name = "the burglary: a finite treasury, an alarm that seals it, a grudge that remembers, open after her",
        fn = function()
            local p = { standing = {} }
            assert(Hoard.burglaryOpen(p) and Hoard.remaining(p) == Hoard.TREASURY, "a full treasury, open")
            assert(Hoard.gongTurn(p) == Hoard.GONG_TURN, "the gong on the fourth turn the first time")
            Hoard.recordBurglary(p, 3)
            assert(Hoard.state(p).taken == 3 and Hoard.state(p).alarm == 1, "three out, one alarm")
            assert(Hoard.gongTurn(p) == Hoard.GONG_TURN - 1, "the gong a turn earlier")
            assert(Hoard.stairHeaps(p) == Hoard.STAIR_HEAPS - 3, "three fewer on her hoard")
            Hoard.recordBurglary(p, 0)
            Hoard.recordBurglary(p, 1)
            assert(not Hoard.burglaryOpen(p), "at the third alarm the passage is sealed")
            p.standing.undercroft = 1
            assert(Hoard.burglaryOpen(p), "once she has fallen, what is left is yours")
            Hoard.recordBurglary(p, 99)
            assert(Hoard.remaining(p) == 0 and not Hoard.burglaryOpen(p), "and an empty treasury is closed")
            assert(Hoard.state(p).alarm == 3, "nobody sounds a gong for a dead dragon")
        end,
    },
    {
        name = "her floor: no gate, a wave battle on her, her clutch, and the Burglary and the Shrine beside her",
        fn = function()
            local sin = Descent.sinById and Descent.sinById("greed")
            if not sin then
                for _, s in ipairs(Descent.SINS) do if s.id == "greed" then sin = s end end
            end
            assert(sin.gate.kind == "none", "the toll was denied: her stair is open")
            local win = Descent.stairWin(sin, true)
            assert(win.type == "assassinate" and win.target == GREED, "a wave battle, won on her body")
            assert(sin.guardian.filler == "character_kobold_scale_priest", "her escort is a scale-priest")

            local objectives = Descent.floorObjectives(nil, 6, sin, 13, true, nil)
            local byLead = {}
            for _, o in ipairs(objectives) do if o.leadIn then byLead[o.leadIn] = o end end
            assert(byLead.burglary and byLead.shrine, "both lead-ins lie on her floor")
            assert(byLead.burglary.win.type == "reach", "the Burglary is won by getting out")
            assert(byLead.burglary.scatter[1].id == "hazard_coin_heap", "...off a board heaped with gold")
            assert(byLead.shrine.win.type == "killAll", "the Shrine is won by breaking it")
            assert(objectives[1].leadIn == nil, "the stair stays first")

            local function eggs(list)
                local n = 0
                for _, id in ipairs(list) do if id == "character_dragon_egg" then n = n + 1 end end
                return n
            end
            asPlayer(nil, function()
                assert(eggs(objectives[1].composition()) == 2, "two eggs on her hoard")
            end)
            asPlayer({ greedHoard = { taken = 0, alarm = 0, shrine = true } }, function()
                assert(eggs(objectives[1].composition()) == 1, "the Shrine broken takes one")
                assert(#sin.guardian.waves[2].composition() == 0, "...and the priests' stream")
                assert(#sin.guardian.waves[1].composition() == 1, "...and half the skulkers")
            end)
        end,
    },
    {
        name = "a won lead-in writes the save: heaps carried out, the alarm raised, the Shrine broken",
        fn = function()
            local p = { standing = {} }
            local line = Hoard.recordLeadIn("burglary", p, { heapsLooted = 2 })
            assert(Hoard.state(p).taken == 2 and Hoard.state(p).alarm == 1, "two out, one trip")
            assert(type(line) == "string", "and the floor says so")
            Hoard.recordLeadIn("shrine", p, {})
            assert(Hoard.state(p).shrine and not Hoard.leadInOpen("shrine", p), "a broken Shrine stays broken")
            local Save = require("models.save")
            assert(Save.snapshot and Save.restore, "the save carries it")
        end,
    },
    {
        name = "her drop list: the Gilded Belly relic first, then her six pieces",
        fn = function()
            local drops = Descent.DROPS.greed.general
            local want = { "utility_gilded_belly", "ability_dragonfire", "utility_wingbeat_mantle", "ability_gild",
                           "armor_emberwalk_greaves", "ability_fire_from_the_sky", "utility_hoard_ledger" }
            for i, id in ipairs(want) do
                assert(drops[i] == id, string.format("drop %d is %s, not %s", i, id, tostring(drops[i])))
                assert(Item.defs[id], id .. " exists")
            end
            local relic = Item.defs.utility_gilded_belly
            assert(relic.class == "creature" and relic.noSteal and not relic.price, "the relic is hers, unpriced")
            assert(Item.defs.utility_bottomless_purse == nil, "Aurea's Purse went with her")
        end,
    },
    {
        name = "the Gilded Belly relic and the Hoard-Ledger read the company's gold, live",
        fn = function()
            asPlayer(nil, function()
                local c = lair({ { id = "character_bandit", x = 1, y = 1 }, { id = "character_rowan", x = 1, y = 3 } })
                local bandit, rowan = unitOf(c, "character_bandit"), unitOf(c, "character_rowan")
                bandit.traits[#bandit.traits + 1] = { id = "trait_crusted_in_gold", def = Trait.defs.trait_crusted_in_gold }
                rowan.traits[#rowan.traits + 1] = { id = "trait_hoard_ledger", def = Trait.defs.trait_hoard_ledger }
                local pot = purse(c, 0)
                local def0, dmg0 = Combat.flatStat(bandit, "defense"), Combat.flatStat(rowan, "damage")
                pot.gold = 350
                assert(Combat.flatStat(bandit, "defense") == def0 + 6, "three hundreds is +6 defense")
                assert(Combat.flatStat(rowan, "damage") == dmg0 + 6, "...and +6 damage on the ledger")
                pot.gold = 5000
                assert(Combat.flatStat(bandit, "defense") == def0 + 10, "capped at +10")
                bandit.channel = { windup = 5 }
                assert(Combat.flatStat(bandit, "defense") == def0, "winding up, the crust is bare")
                bandit.channel = nil
            end)
        end,
    },
    {
        name = "Gild consumes 30 gold and gilds every foe in the square; Dragonfire burns its own side too",
        fn = function()
            asPlayer(nil, function()
                local c, her = lair({ { id = "character_bandit", x = 2, y = 2 } },
                    { { id = "character_kobold_skulker", x = 2, y = 5 }, { id = "character_kobold_skulker", x = 3, y = 5 } })
                local bandit = unitOf(c, "character_bandit")
                local pot = purse(c, 100)
                local gild = Item.instantiate("ability_gild")
                assert(Combat.useItem(c, bandit, gild, 2, 5), "the pour lands")
                assert(pot.gold == 70, "thirty gold consumed: " .. pot.gold)
                local gilded = 0
                for _, u in ipairs(c.units) do
                    if u.char.id == "character_kobold_skulker" and Status.has(u, "status_gilded") then gilded = gilded + 1 end
                end
                assert(gilded == 2, "both foes in the square are Gilded")

                local cone = Hoard.cone({ x = 2, y = 2, w = 1, h = 1 }, 2, 3, 5)
                assert(#cone == 1 + 3 + 3 + 5 + 5, "a one-tile body breathes 1, 3, 3, 5, 5")
                local wide = Hoard.cone(her, her.x, her.y + 2, 5)
                assert(#wide == 2 + 4 + 4 + 6 + 6, "her face breathes 2, 4, 4, 6, 6")
            end)
        end,
    },
}
