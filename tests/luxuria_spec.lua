-- LUXURIA, QUEEN OF THE SUCCUBI: the Lust general's fight, re-premised on review 2026-09-25 (a succubus
-- Queen with a large army of charmed followers that protect her, who charms the company "easily but not
-- unfairly"). Her army is bound to her and sworn to her; what reaches her is split across everyone she
-- holds; she holds one of the company above half health and two below, the first as her Consort; she
-- changes partners when reached; her court goes for whoever she Marked; and her stair is a wave battle won
-- on her body. Then the pieces she hands over. Each rule is held by the behaviour it promises, against the
-- real blueprints (models/court.lua). Headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local AI = require("models.ai")
local Court = require("models.court")

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

-- The Queen at (5,5) with whatever of her side the case seats, against the named company.
local function nave(court, company)
    local enemies = { { char = Character.instantiate("character_general_lust"), x = 5, y = 5 } }
    for _, e in ipairs(court or {}) do
        enemies[#enemies + 1] = { char = Character.instantiate(e.id), x = e.x, y = e.y }
    end
    local party = {}
    for _, p in ipairs(company or { { id = "character_bandit", x = 1, y = 1 } }) do
        party[#party + 1] = { char = Character.instantiate(p.id), x = p.x, y = p.y }
    end
    local c = Combat.new(arena(10, 10), party, enemies)
    local queen
    for _, u in ipairs(c.units) do
        if u.char.id == "character_general_lust" then queen = u end
    end
    return c, queen
end

local function named(c, id, side)
    local out = {}
    for _, u in ipairs(c.units) do
        if u.char.id == id and (not side or Status.ownSide(u) == side) then out[#out + 1] = u end
    end
    return out
end

local function setHp(u, frac)
    local hp = u.char.stats.health
    hp.current = math.floor(hp.max * frac)
end

-- Land her charm on a company member the way her Anointing does, without the roll.
local function charm(c, queen, victim)
    return Status.apply(c, victim, "status_charm", { applier = queen })
end

return {
    {
        name = "the Queen is a demon boss who carries the Court, the Congregation and her mark beside the Anointing",
        fn = function()
            local def = Character.defs["character_general_lust"]
            assert(def.name == "Luxuria, Queen of the Succubi", "she is the Queen: " .. tostring(def.name))
            assert(def.boss, "a quest objective: charm and execute do not take her")
            assert(def.race == "demon", "the Queen from the first turn, with no human phase")
            local c, queen = nave()
            assert(def.startingItems[5] == "utility_the_court", "her rule rides utility_the_court, centre cell")
            assert(Trait.has(queen, "trait_the_court"), "the Court rides her vessel")
            assert(Trait.has(queen, "trait_the_congregation"), "and the Congregation beside it")
            assert(Trait.has(queen, "trait_her_court"), "she wears her own reliquary")
            assert(not Trait.has(queen, "trait_rapture"), "Rapture left her kit on review")
            assert(Status.has(queen, "status_the_court"), "her turn-start rule is on her from the bell")
            -- Mark Target needs a ranged weapon beside it; the Anointing is that weapon.
            local grid = def.startingItems
            assert(grid[2] == "weapon_the_anointing" and grid[3] == "ability_mark_target",
                "Mark Target sits beside the Anointing")
            assert(Item.defs["weapon_the_anointing"].tags and table.concat(Item.defs["weapon_the_anointing"].tags, ","):find("ranged"),
                "the Anointing is the ranged weapon Mark Target needs")
            assert(not Status.has(c.units[1], "status_charm"), "and nothing of the company opens charmed")
        end,
    },
    {
        name = "she opens holding every humanoid on her side, bound to her and sworn to take her blows",
        fn = function()
            local c, queen = nave({
                { id = "character_knight", x = 5, y = 6 }, { id = "character_priest", x = 8, y = 8 },
                { id = "character_knight", x = 2, y = 9 }, { id = "character_harpy", x = 6, y = 5 },
            })
            local knights = named(c, "character_knight")
            local priests = named(c, "character_priest")
            for _, u in ipairs({ knights[1], knights[2], priests[1] }) do
                assert(Court.isThrall(u, queen), u.char.name .. " is bound to her")
                assert(u.guard and u.guard.kind == "oathward" and u.guard.ward == queen,
                    u.char.name .. " is sworn to her and to nobody else")
            end
            -- No ceiling: three here, where the Blooded keeps two.
            local harpy = named(c, "character_harpy")[1]
            assert(not Status.has(harpy, "status_charm"), "a harpy is a neighbour, not a thrall")
        end,
    },
    {
        name = "a thrall beside her takes the first blow meant for her, and a far one does not",
        fn = function()
            local c, queen = nave({ { id = "character_knight", x = 5, y = 6 } })
            local knight = named(c, "character_knight")[1]
            assert(Combat.tryRedirect(c, queen, 10, {}) == knight, "the knight throws itself in front")
            assert(Combat.tryRedirect(c, queen, 10, {}) == nil, "one blow a turn: the second lands")

            local c2, queen2 = nave({ { id = "character_knight", x = 9, y = 9 } })
            assert(Combat.tryRedirect(c2, queen2, 10, {}) == nil, "a thrall across the room guards nothing")
        end,
    },
    {
        name = "what still reaches her is split across everyone she holds, and she takes none of it",
        fn = function()
            local c, queen = nave({
                { id = "character_knight", x = 9, y = 1 }, { id = "character_priest", x = 9, y = 9 },
            })
            local knight = named(c, "character_knight")[1]
            local priest = named(c, "character_priest")[1]
            local q0 = queen.char.stats.health.current
            local k0, p0 = knight.char.stats.health.current, priest.char.stats.health.current
            Combat.dealFlatDamage(c, queen, 40, {}, "test")
            assert(queen.char.stats.health.current == q0, "the Queen took nothing while she held anyone")
            assert(knight.char.stats.health.current < k0 and priest.char.stats.health.current < p0,
                "both of her court bled for her")
        end,
    },
    {
        name = "cut her and the whole court comes back to itself and walks out",
        fn = function()
            local c, queen = nave({
                { id = "character_knight", x = 9, y = 1 }, { id = "character_priest", x = 9, y = 9 },
            })
            -- The Congregation is hers: strip the court's shelter by Sunder, as the fight's second key.
            Status.apply(c, queen, "status_sundered", { duration = 50 })
            Combat.dealFlatDamage(c, queen, 9999, {}, "test")
            assert(not queen.alive, "she falls when her rules are silenced")
            for _, u in ipairs(c.units) do
                if u.char.id == "character_knight" or u.char.id == "character_priest" then
                    assert(not u.alive, u.char.name .. " walked out when she fell")
                end
            end
        end,
    },
    {
        name = "a newcomer kneels at the start of her turn, not before",
        fn = function()
            local c, queen = nave()
            local late = Combat.addUnit(c, Character.instantiate("character_knight"), "enemy", 8, 8)
            assert(late and not Status.has(late, "status_charm"), "the Procession walks in hers-by-side only")
            Status.onTurnStart(c, queen)
            assert(Court.isThrall(late, queen), "and kneels when she next acts")
            assert(late.guard and late.guard.ward == queen, "sworn with the rest")
        end,
    },
    {
        name = "she holds one of the company above half her health, and two below it",
        fn = function()
            local company = {
                { id = "character_bandit", x = 1, y = 1 }, { id = "character_bandit", x = 1, y = 3 },
                { id = "character_bandit", x = 3, y = 1 },
            }
            local c, queen = nave(nil, company)
            local party = named(c, "character_bandit", "party")
            assert(charm(c, queen, party[1]), "the first charm takes")
            charm(c, queen, party[2])
            assert(not Status.has(party[2], "status_charm"), "the second is shaken off above half")
            assert(party[2].side == "party", "and its side came back with it")
            assert(#Court.held(c, queen) == 1, "she holds exactly one")

            setHp(queen, 0.4)
            assert(charm(c, queen, party[2]) and Status.has(party[2], "status_charm"),
                "below half, a second takes")
            charm(c, queen, party[3])
            assert(not Status.has(party[3], "status_charm"), "and a third never does")
        end,
    },
    {
        name = "the first she holds is her Consort, and the badge and the oath leave with the charm",
        fn = function()
            local company = { { id = "character_bandit", x = 1, y = 1 }, { id = "character_bandit", x = 1, y = 3 } }
            local c, queen = nave(nil, company)
            local first, second = named(c, "character_bandit", "party")[1], named(c, "character_bandit", "party")[2]
            local before = Combat.flatStat(first, "damage")
            charm(c, queen, first)
            assert(Status.has(first, "status_consort"), "the first she takes is her Consort")
            assert(Combat.flatStat(first, "damage") > before, "fighting at half again its damage")
            assert(first.guard and first.guard.ward == queen, "and sworn to her")

            Status.remove(c, first, "status_charm") -- a Cure
            assert(not Status.has(first, "status_consort"), "the Consort leaves with the charm")
            assert(Combat.flatStat(first, "damage") == before, "and keeps none of the damage")
            assert(not (first.guard and first.guard.ward == queen), "or the oath")

            setHp(queen, 0.4)
            charm(c, queen, second)
            assert(not Status.has(second, "status_consort"), "one Consort a fight")
        end,
    },
    {
        name = "reached, she changes partners with the thrall farthest from the company",
        fn = function()
            local c, queen = nave({
                { id = "character_knight", x = 6, y = 5 }, { id = "character_priest", x = 10, y = 10 },
            }, { { id = "character_bandit", x = 4, y = 5 } })
            local priest = named(c, "character_priest")[1]
            Status.onTurnStart(c, queen)
            assert(queen.x == 10 and queen.y == 10, "she is where the priest was")
            assert(priest.x == 5 and priest.y == 5, "and the priest is where she was, facing the bandit")

            -- Nobody beside her, and she stays put.
            local c2, queen2 = nave({ { id = "character_priest", x = 10, y = 10 } },
                { { id = "character_bandit", x = 1, y = 1 } })
            Status.onTurnStart(c2, queen2)
            assert(queen2.x == 5 and queen2.y == 5, "unpressed, she does not move")
        end,
    },
    {
        name = "below half her health the Procession quickens, once",
        fn = function()
            local c, queen = nave()
            c.objective.waves = { { at = 10, every = 60, composition = { "character_knight" } } }
            Status.onTurnStart(c, queen)
            assert(c.objective.waves[1].every == 60, "above half the court comes at its own pace")
            setHp(queen, 0.4)
            Status.onTurnStart(c, queen)
            assert(c.objective.waves[1].every == Court.QUICKEN_EVERY, "below half it comes faster")
        end,
    },
    {
        name = "her court scores the body she Marked; a knight of nobody's does not",
        fn = function()
            local c, queen = nave({ { id = "character_knight", x = 5, y = 6 } },
                { { id = "character_bandit", x = 1, y = 1 } })
            local knight = named(c, "character_knight")[1]
            local bandit = named(c, "character_bandit")[1]
            local w = AI.WEIGHTS
            assert(AI.courtBonus(knight, { target = bandit }, w) == 0, "nothing marked, nothing preferred")
            Status.apply(c, bandit, "status_mark", { applier = queen })
            assert(AI.courtBonus(knight, { target = bandit }, w) == w.TARGET_PREF,
                "a thrall goes for whoever she Marked")

            local c2 = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_bandit"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_knight"), x = 3, y = 3 } })
            local free, mark = c2.units[2], c2.units[1]
            Status.apply(c2, mark, "status_mark")
            assert(AI.courtBonus(free, { target = mark }, w) == 0, "an unbound knight has no queen to obey")
        end,
    },
    {
        name = "her stair is a wave battle of her court, won on her body",
        fn = function()
            local lust
            for _, s in ipairs(Descent.SINS) do if s.id == "lust" then lust = s end end
            assert(lust.guardian.lead == "character_general_lust", "she holds the fen's last stair")
            assert(lust.guardian.filler == "character_knight", "her escort is her court, not a lamia")
            local waves = lust.guardian.waves
            assert(waves and waves[1] and waves[1].every == 60 and waves[1].maxAlive, "the Procession recurs, capped")
            local win = Descent.stairWin(lust, true)
            assert(win.type == "assassinate" and win.target == "character_general_lust", "the win is her")
            win.waves[1].every = 1
            assert(waves[1].every == 60, "a fight's quickening never writes back into Descent.SINS")
        end,
    },
    {
        name = "her drops: the reliquary first, then her escape, the counter to her charm and the Chalice",
        fn = function()
            local list = Descent.DROPS.lust.general
            assert(list[1] == "utility_reliquary_unbidden", "the relic leads")
            local want = { "ability_changing_partners", "utility_smelling_salts", "utility_saints_chalice" }
            for i, id in ipairs(want) do
                assert(list[i + 1] == id, "slot " .. (i + 1) .. " is " .. tostring(list[i + 1]) .. ", expected " .. id)
                assert(Item.defs[id], id .. " loads")
            end
            -- The four priest finds that waited here went to bodies of their own.
            local moved = {
                weapon_censer_of_the_hollow_dark = "character_swooncap_thurifer",
                weapon_censer_of_the_unravelling = "character_swooncap_thurifer",
                weapon_censer_of_the_grasping_hollow = "character_alraune_anchoress",
                weapon_renewal_staff = "character_hamadryad",
            }
            for item, body in pairs(moved) do
                local found = false
                for _, d in ipairs(Character.defs[body].drops or {}) do if d == item then found = true end end
                assert(found, item .. " falls off " .. body)
                for _, d in ipairs(list) do assert(d ~= item, item .. " still waits on her list") end
            end
        end,
    },
    {
        name = "the Reliquary is her court handed over: a tenth again per foe you hold, live",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { { char = Character.instantiate("character_bandit"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 3, y = 1 },
                  { char = Character.instantiate("character_bandit"), x = 5, y = 1 } })
            local me = c.units[1]
            me.char.stats.damage, me.char.stats.defense = 20, 10
            local item = Item.instantiate("utility_reliquary_unbidden")
            me.traits = me.traits or {}
            me.traits[#me.traits + 1] = Trait.instantiate("trait_her_court", item)
            assert(Trait.liveBonus(me, "damage") == 0, "holding nobody, it is only a relic")
            Status.apply(c, c.units[2], "status_charm", { applier = me })
            Status.apply(c, c.units[3], "status_charm", { applier = me })
            assert(Trait.liveBonus(me, "damage") == 4, "two held: +20% of 20 damage")
            assert(Trait.liveBonus(me, "defense") == 2, "and +20% of 10 defense")
            Status.remove(c, c.units[3], "status_charm")
            assert(Trait.liveBonus(me, "damage") == 2, "a charm broken is a tenth gone at once")
        end,
    },
    {
        name = "the Saint's Chalice drains the struck foe and every foe beside it, and passes over Xin",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { { char = Character.instantiate("character_rowan"), x = 4, y = 4 },
                  { char = Character.instantiate("character_bandit"), x = 5, y = 4 },
                  { char = Character.instantiate("character_xin"), x = 4, y = 5 },
                  { char = Character.instantiate("character_bandit"), x = 8, y = 8 } },
                { { char = Character.instantiate("character_priest"), x = 3, y = 4 } })
            local rowan, near, xin, far, me = c.units[1], c.units[2], c.units[3], c.units[4], c.units[5]
            me.traits = me.traits or {}
            me.traits[#me.traits + 1] = Trait.instantiate("trait_rapture", Item.instantiate("utility_saints_chalice"))
            setHp(me, 0.5)
            local hp0 = me.char.stats.health.current
            local function pools(u) return Combat.resource(u.char, "stamina"), Combat.resource(u.char, "mana") end
            local rs, rm = pools(rowan)
            local ns, nm = pools(near)
            local xs, xm = pools(xin)
            local fs, fm = pools(far)
            Trait.onCast(c, me, { tx = rowan.x, ty = rowan.y })
            local a, b = pools(rowan)
            assert(a == math.max(0, rs - 10) and b == math.max(0, rm - 10), "the struck foe gives 10 of each")
            a, b = pools(near)
            assert(a == math.max(0, ns - 10) and b == math.max(0, nm - 10), "so does the foe beside it")
            a, b = pools(xin)
            assert(a == xs and b == xm, "Xin holds nothing back, and gives nothing")
            a, b = pools(far)
            assert(a == fs and b == fm, "a foe across the room is out of the draught")
            assert(me.char.stats.health.current > hp0, "and half of it comes back as health")
        end,
    },
    {
        name = "Smelling Salts: the first charm of a fight breaks at once, the second takes",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_bandit"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 3, y = 3 } })
            local me, foe = c.units[1], c.units[2]
            me.traits = me.traits or {}
            me.traits[#me.traits + 1] = Trait.instantiate("trait_smelling_salts", Item.instantiate("utility_smelling_salts"))
            Status.apply(c, me, "status_charm", { applier = foe })
            assert(not Status.has(me, "status_charm") and me.side == "party", "the first charm does not take")
            Status.apply(c, me, "status_charm", { applier = foe })
            assert(Status.has(me, "status_charm") and me.side == "enemy", "the second one does")
        end,
    },
    {
        name = "Changing Partners trades places with an ally up to five tiles off",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { { char = Character.instantiate("character_bandit"), x = 1, y = 1 },
                  { char = Character.instantiate("character_bandit"), x = 5, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 9, y = 9 } })
            local me, ally = c.units[1], c.units[2]
            me.initiative = 0
            assert(Combat.startTurn(c) == me, "the caster is up")
            assert(Combat.useItem(c, me, Item.instantiate("ability_changing_partners"), ally.x, ally.y),
                "the trade is cast")
            assert(me.x == 5 and ally.x == 1, "and the two have changed places")
        end,
    },
}
