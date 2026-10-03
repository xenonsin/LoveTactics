-- Tests for THE MANY FACED ONE, Envy's general (slice F of "Envy's Bestiary", reviewed 2026-10-01..03; the rows
-- g_premise, g_forms, g_split, g_shuffle, g_relic and g_drops, with the author's overrides). It replaced Livia on
-- character_general_envy.
--
--   the forms       every general above Envy in this run, in the order met (Gula, Luxuria, Avaritia, Furor,
--                   Acedia), each worn through the transform; topped up from the circles BELOW when Envy comes early
--   the shares      one bar cut in equal shares, a form apiece and the split's last; dropping through one moves on.
--                   Reduced on purpose: a share is 90 of 540, about three-eighths of a general's own bar
--   the court       each form calls its own stair's escort, swarm and waves; when a form breaks, its surviving
--                   adds shapeshift into the next form's, role for role
--   the split       an exact copy of each body in the company on ONE pool: a blow on any is a blow on all, and
--                   when it empties every copy falls at once
--   the drops       the Pretender's Crown (an alchemist's trophy) first, then Splitting Image and Unmasking Powder
--
-- Every case runs with no save being played (Player.active cleared), so the forms read the authored order unless a
-- case hands one in.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Item = require("models.item")
local Status = require("models.status")
local Transform = require("models.transform")
local ManyFaced = require("models.many_faced")
local Fixture = require("tests.support.fixture")

local unit, hp = Fixture.unit, Fixture.hp

local AUTHORED = { "gluttony", "lust", "greed", "wrath", "sloth" }
local LEADS = {
    "character_general_gluttony", "character_general_lust", "character_general_greed",
    "character_general_wrath", "character_general_sloth",
}

-- Run `fn` with no save being played, so ManyFaced.runOrder falls back to the authored order.
local function unplayed(fn)
    local Player = require("models.player")
    local was = Player.active
    Player.active = nil
    local ok, err = pcall(fn)
    Player.active = was
    if not ok then error(err, 0) end
end

local function sameList(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

local function stair()
    return Fixture.new(14, 14, { objective = { type = "assassinate", target = ManyFaced.ID, waves = {} } })
end

local function find(c, pred)
    for _, u in ipairs(c.units) do if pred(u) then return u end end
end

local function general(c) return find(c, function(u) return u.manyFaced ~= nil end) end

-- The general, its escort (a wolf alpha, the stair's seated escort) and one of the swarm, against a company.
local function field(company, opts)
    opts = opts or {}
    local c
    unplayed(function()
        c = Fixture.combat(opts.map or stair(), company or {
            unit("character_knight", 2, 2), unit("character_archer", 2, 4),
        }, {
            unit(ManyFaced.ID, 11, 11),
            unit("character_wolf_alpha", 13, 11),
            unit("character_glass_mote", 13, 13),
        })
    end)
    return c, general(c)
end

-- Put the bar just under share line `k` (1 = the first line below full) and let the badge read the wound.
local function dropThrough(c, g, k)
    local pool = g.char.stats.health
    local shares = ManyFaced.shares(g)
    pool.current = math.floor(pool.max * (shares - k) / shares) - 1
    ManyFaced.onDamaged(c, g)
end

return {
    -- ------------------------------------------------------------------ the body
    {
        name = "the Many Faced One holds Livia's id and stair: a faceless sovereign, a boss, on its crown",
        fn = function()
            local def = Character.defs[ManyFaced.ID]
            assert(def.name == "The Many Faced One", "it is named " .. tostring(def.name))
            assert(def.race == "faceless" and def.boss and def.tier == 4, "the Faceless race's own crown")
            assert(def.startingItems[1] == "utility_crown_of_a_thousand_faces",
                "the crown opens first, before the race's own opener can reshape it")
            local crown = Item.defs.utility_crown_of_a_thousand_faces
            assert(crown.bound and crown.noSteal and crown.class == "creature", "the crown is an organ")
            local envy = ManyFaced.sinById("envy")
            assert(envy.guardian.lead == ManyFaced.ID, "Envy's stair is still led on this id")
            assert(envy.gate.kind == "carry" and envy.gate.n == 3, "and its gate is unchanged")
            local win = Descent.stairWin(envy, true)
            assert(win.type == "assassinate" and win.target == ManyFaced.ID,
                "a wave battle, taken on its body whatever its forms call")
        end,
    },

    -- ------------------------------------------------------------------ the forms, in order
    {
        name = "it wears the generals above Envy in the order met: Gula, Luxuria, Avaritia, Furor, Acedia",
        fn = function()
            unplayed(function()
                assert(sameList(ManyFaced.runOrder(), Descent.INFERNO), "no save: the authored order")
                assert(sameList(ManyFaced.formsFor(ManyFaced.runOrder()), AUTHORED),
                    "the authored forms are the five circles above Envy, top down")
            end)
            local c, g = field()
            assert(g and g.faceLocked, "its forms are its own rule; Reshape never chooses for it")
            assert(Status.has(g, ManyFaced.STATUS), "it wears the Many Faces badge")
            assert(g.char.id == LEADS[1], "it opens wearing Gula, got " .. tostring(g.char.id))
            assert(Transform.originalChar(g).id == ManyFaced.ID, "underneath it is still itself")
            assert(g.char.boss, "a form is a boss: no execute, no Charm")
            for k = 2, #LEADS do
                dropThrough(c, g, k - 1)
                assert(g.char.id == LEADS[k], string.format("share %d puts on %s, got %s",
                    k, LEADS[k], tostring(g.char.id)))
            end
        end,
    },
    {
        name = "when Envy comes early it tops its forms up from the circles below, nearest first",
        fn = function()
            local below = { "envy", "pride", "wrath", "gluttony", "sloth", "lust", "greed" }
            assert(sameList(ManyFaced.formsFor(below), { "pride", "wrath", "gluttony", "sloth", "lust" }),
                "first of the seven: the five below it")
            local second = { "lust", "envy", "pride", "wrath", "gluttony", "sloth", "greed" }
            assert(sameList(ManyFaced.formsFor(second), { "lust", "pride", "wrath", "gluttony", "sloth" }),
                "one above, then four below")
            local last = { "pride", "lust", "greed", "wrath", "sloth", "gluttony", "envy" }
            assert(#ManyFaced.formsFor(last) == 6, "last of the seven: every general above it, all six")

            -- ...and through a real shuffled run: find a seed that deals Envy first.
            local found
            for seed = 1, 400 do
                local order = Descent.sinOrder(seed, true)
                if order[1].id == "envy" then found = seed break end
            end
            assert(found, "no seed in 400 dealt Envy first")
            local run = { seed = found, shuffled = true }
            local order = ManyFaced.runOrder(run)
            assert(order[1] == "envy", "the run order is the shuffle's")
            assert(sameList(ManyFaced.formsFor(order), { order[2], order[3], order[4], order[5], order[6] }),
                "an early Envy wears what the company has not reached yet")
        end,
    },

    -- ------------------------------------------------------------------ the shares
    {
        name = "one bar in six equal shares, each a reduced general: 90 of 540, under half of any general's own",
        fn = function()
            local def = Character.defs[ManyFaced.ID]
            local max = def.stats.health
            assert(max == 540, "the bar is six shares of 90, got " .. tostring(max))
            local share = max / (ManyFaced.FORMS + 1)
            for _, id in ipairs(LEADS) do
                local own = Character.defs[id].stats.health
                assert(share < own / 2, string.format("a form of %s holds %d of her %d: not reduced", id, share, own))
            end
            assert(ManyFaced.stageAt(540, 540, 6) == 1 and ManyFaced.stageAt(451, 540, 6) == 1,
                "a scratch stays in the first form")
            assert(ManyFaced.stageAt(450, 540, 6) == 2, "the line itself is the next form")
            assert(ManyFaced.stageAt(90, 540, 6) == 6 and ManyFaced.stageAt(1, 540, 6) == 6, "the last share splits")
        end,
    },
    {
        name = "a real blow through a share breaks the form; a scratch does not, and a heal never puts one back",
        fn = function()
            local c, g = field()
            local pool = g.char.stats.health
            local line = math.floor(pool.max * 5 / 6)
            pool.current = line + 20
            Combat.dealFlatDamage(c, g, 5, {}, "test", nil, { raw = true })
            assert(g.char.id == LEADS[1] and g.alive, "above the line it is still Gula")
            Combat.dealFlatDamage(c, g, 40, {}, "test", nil, { raw = true })
            assert(g.alive and g.char.id == LEADS[2], "through the line it wears Luxuria, got " .. tostring(g.char.id))
            assert(hp(g) < line, "and the wound is the one bar's")
            Combat.applyHeal(c, g, 200)
            ManyFaced.onDamaged(c, g)
            assert(g.char.id == LEADS[2], "the shares only run forward")
            -- A blow across two lines skips the form between them.
            pool.current = math.floor(pool.max * 3 / 6) - 1
            ManyFaced.onDamaged(c, g)
            assert(g.char.id == LEADS[4], "from Luxuria straight to Furor, got " .. tostring(g.char.id))
        end,
    },

    -- ------------------------------------------------------------------ the court
    {
        name = "each form's court is its stair's: the escort and swarm are re-cast at the bell",
        fn = function()
            local c, g = field()
            local escort = find(c, function(u) return u.courtRole == "escort" end)
            local swarm = find(c, function(u) return u.courtRole == "swarm" end)
            assert(escort and escort.char.id == "character_wolf_alpha", "Gula's escort is her wolf alpha")
            assert(swarm and swarm.char.id == "character_hawk",
                "the swarm wears Gula's lieutenant's filler, got " .. tostring(swarm and swarm.char.id))
            assert(Transform.originalChar(swarm).id == "character_glass_mote", "and is still the mote underneath")
            local obj = c.objective
            assert(#obj.waves == #ManyFaced.sinById("gluttony").guardian.waves,
                "Gula's form brings the wood's streams, got " .. #obj.waves)
            assert(obj.waves[1].at >= (c.clock or 0), "re-timed from now")
        end,
    },
    {
        name = "when a form breaks, its surviving adds shapeshift into the next form's, keeping their share",
        fn = function()
            local c, g = field()
            local escort = find(c, function(u) return u.courtRole == "escort" end)
            local swarm = find(c, function(u) return u.courtRole == "swarm" end)
            local shp = swarm.char.stats.health
            shp.current = math.floor(shp.max / 2)
            dropThrough(c, g, 1)
            assert(g.char.id == LEADS[2], "Luxuria")
            assert(escort.alive and escort.char.id == "character_knight",
                "the escort becomes her knight, got " .. tostring(escort.char.id))
            assert(swarm.alive and swarm.char.id == "character_swooncap_puffer",
                "the swarm becomes the swamp's puffer, got " .. tostring(swarm.char.id))
            local frac = swarm.char.stats.health.current / swarm.char.stats.health.max
            assert(math.abs(frac - 0.5) < 0.1, "a shift keeps the share of health it had, got " .. frac)
            local waves = c.objective.waves
            assert(#waves == 1 and waves[1].composition[1] == "character_knight",
                "and Luxuria's procession replaces the wood's streams")
            -- Avaritia's lieutenant does not escort her, so her swarm is her own scale-priests.
            dropThrough(c, g, 2)
            assert(g.char.id == LEADS[3], "Avaritia")
            assert(escort.char.id == "character_kobold_scale_priest" and swarm.char.id == "character_kobold_scale_priest",
                "Avaritia's court is her scale-priests")
            dropThrough(c, g, 3)
            assert(escort.char.id == "character_asura_adept", "Furor's escort is an Asura Adept")
            assert(#c.objective.waves == 0, "Furor's stair sends no waves")
        end,
    },
    {
        name = "a form whose escort has fallen calls a fresh one as it is put on",
        fn = function()
            local c, g = field()
            local escort = find(c, function(u) return u.courtRole == "escort" end)
            Combat.dealFlatDamage(c, escort, 9999, {}, "test", nil, { raw = true })
            assert(not escort.alive, "the escort is down")
            dropThrough(c, g, 1)
            local fresh = find(c, function(u) return u.alive and u.courtRole == "escort" end)
            assert(fresh and fresh.char.id == "character_knight", "Luxuria calls her own knight")
        end,
    },

    -- ------------------------------------------------------------------ the split
    {
        name = "past the last form it splits into an exact copy of each of the company, on one pool",
        fn = function()
            local c, g = field()
            local knight = find(c, function(u) return u.side == "party" and u.char.id == "character_knight" end)
            local archer = find(c, function(u) return u.side == "party" and u.char.id == "character_archer" end)
            dropThrough(c, g, 5)
            assert(g.manyFaced.split, "the last share is the split")
            assert(g.alive and g.char.name == knight.char.name, "it wears the first of the company itself")
            local copies = {}
            for _, u in ipairs(c.units) do if u.alive and u.manyFacedOf == g then copies[#copies + 1] = u end end
            assert(#copies == 1 and copies[1].char.name == archer.char.name, "and fields a copy of the rest")
            local copy = copies[1]
            assert(rawequal(copy.char.stats.health, g.char.stats.health), "ONE pool, the same table")
            assert(Status.has(g, ManyFaced.SPLIT) and Status.has(copy, ManyFaced.SPLIT), "both wear Split")
            local kit
            for i = 1, Character.MAX_INVENTORY do kit = kit or archer.char.inventory[i] end
            assert(kit and Fixture.itemNamed(copy.char, kit.id), "the copy carries the archer's kit")
            assert(copy.char.boss, "and is still the sovereign underneath: no execute")

            local before = hp(g)
            Combat.dealFlatDamage(c, copy, 10, {}, "test", nil, { raw = true })
            assert(hp(g) == before - 10, "a blow on any copy comes off the one bar")

            g.char.stats.health.current = 3
            Combat.dealFlatDamage(c, copy, 50, {}, "test", nil, { raw = true })
            assert(not copy.alive and not g.alive, "when the pool empties every copy falls at once")
            assert(Combat.outcomeFor(c, "party") == "win", "and the stair is taken")
        end,
    },

    -- ------------------------------------------------------------------ the drops
    {
        name = "it pays the Pretender's Crown first, then Splitting Image and Unmasking Powder; the Glass is off",
        fn = function()
            local list = Descent.DROPS.envy.general
            assert(list[1] == "utility_pretenders_crown", "entry #1 is the relic")
            assert(list[2] == "ability_splitting_image" and list[3] == "consumable_unmasking_powder", "then the pieces")
            for _, id in ipairs(list) do
                assert(id ~= "utility_envious_glass", "Livia's Glass left the list with her")
            end
            local crown = Item.defs.utility_pretenders_crown
            assert(crown.class == "alchemist" and crown.unstocked and crown.noSteal and crown.price == nil,
                "the relic is an alchemist's trophy, never sold")
            assert(crown.unlockLevel == 12, "at Envy's seat")
            assert(Item.defs.ability_splitting_image.class == "ninja", "Splitting Image is the Ninja's")
            assert(Item.defs.consumable_unmasking_powder.class == "bombardier", "the powder is the Bombardier's")
            for _, id in ipairs({ "ability_splitting_image", "consumable_unmasking_powder" }) do
                assert(Item.defs[id].price == nil and Item.defs[id].unstocked, id .. " is a find, not a ware")
            end
            local Player = require("models.player")
            assert(Descent.dropFor(Player.new(), ManyFaced.sinById("envy"), true) == "utility_pretenders_crown",
                "a fresh company is paid the crown")
        end,
    },
    {
        name = "Pretender's Crown: a kill puts on the fallen's shape until the next kill, on your own pool",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 2, 2, { items = { "utility_pretenders_crown" } }) },
                { unit("character_bandit", 3, 2), unit("character_archer", 2, 3) })
            local me = find(c, function(u) return u.side == "party" end)
            local pool = me.char.stats.health
            local bandit = find(c, function(u) return u.char.id == "character_bandit" end)
            Combat.dealFlatDamage(c, bandit, 9999, {}, "test", me, { raw = true })
            assert(not bandit.alive, "the bandit falls to the bearer")
            assert(Transform.isTransformed(me) and me.char.name == bandit.char.name,
                "the bearer wears the bandit, got " .. tostring(me.char.name))
            assert(rawequal(me.char.stats.health, pool), "your health stays yours")
            assert(Fixture.itemNamed(me.char, "utility_pretenders_crown"), "the crown rides into the shape")
            local archer = find(c, function(u) return u.char.id == "character_archer" and u.side ~= "party" end)
            Combat.dealFlatDamage(c, archer, 9999, {}, "test", me, { raw = true })
            assert(me.char.name == archer.char.name, "the next kill is the next shape")
            assert(Transform.originalChar(me).id == "character_knight", "and the knight is still underneath")
        end,
    },
    {
        name = "Splitting Image: a second you for two turns on your own pool, and an empty pool fells both",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 2, 2, { items = { "ability_splitting_image" }, stats = { mana = 40 } }) },
                { unit("character_bandit", 8, 8) })
            local me = find(c, function(u) return u.side == "party" end)
            local item = Fixture.itemNamed(me.char, "ability_splitting_image")
            Fixture.openTurn(c, me)
            assert(Combat.useItem(c, me, item, 3, 2), "the cast lands")
            local double = find(c, function(u) return u.alive and u ~= me and u.side == "party" end)
            assert(double and double.summoned, "a second of you stands beside you")
            assert(double.summonRemaining == 10, "for two turns")
            assert(rawequal(double.char.stats.health, me.char.stats.health), "on one pool")
            assert(Status.has(double, ManyFaced.SPLIT), "wearing Split")
            me.char.stats.health.current = 4
            Combat.dealFlatDamage(c, double, 40, {}, "test", nil, { raw = true })
            assert(not double.alive and not me.alive, "the pool empties under the double, and both fall")
        end,
    },
    {
        name = "Unmasking Powder strips every foe's shape in a 3x3 and Halts it; the Many Faced One re-masks next turn",
        fn = function()
            local c, g = field({ unit("character_knight", 10, 9, {
                items = { "consumable_unmasking_powder" }, stats = { stamina = 40 } }) })
            assert(Transform.isTransformed(g), "it opens in a form")
            local me = find(c, function(u) return u.side == "party" end)
            local powder = Fixture.itemNamed(me.char, "consumable_unmasking_powder")
            Fixture.openTurn(c, me)
            assert(Combat.useItem(c, me, powder, g.x, g.y), "the throw lands")
            assert(not Transform.isTransformed(g) and g.char.id == ManyFaced.ID, "the crown with no head, for a moment")
            assert(Status.has(g, "status_halted"), "and Halted")
            Status.onTurnStart(c, g)
            assert(g.char.id == LEADS[1], "the top of its turn puts the form back on")
            assert(Status.has(me, "status_halted") == false, "the powder spares the thrower's side")
        end,
    },
}
