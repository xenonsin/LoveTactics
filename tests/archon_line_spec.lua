-- Tests for THE ARCHON COURT (2026-10-09, "The Crown's Bestiary", slice A): the four bodies that wear the Archon race
-- on the Crown's floor, their rules, their drops and their three fights.
--
--   Lesser Archon    Mana Edge: its blade lands on Magic Defense, not Defense
--   Greater Archon   the Killing Magic (a 5-tile beam through every body and every barrier) and its Ward (a Magical
--                    Barrier over an Archon struck within 3, on a cooldown, and one on itself at the bell)
--   Archon Warden    Hold the Gate (on a still turn, Archons within 2 take half from blows struck from beyond 2) and
--                    a glaive that shoves 1
--   Archon Duke      Ascension (wisps within 3 come to it; at three it Ascends, healed to full, with a new spell) and
--                    Command (the court within 3 is pulled ahead of the company on the timeline)
--
-- Each case pins one approved rule on a bare board. The race itself (Spirit Body) is tests/archon_race_spec.lua's.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Spirit = require("models.spirit")
local Court = require("models.archon_court")
local Fixture = require("tests.support.fixture")

local unit, itemNamed, hp = Fixture.unit, Fixture.itemNamed, Fixture.hp

local BODIES = {
    character_lesser_archon = 1, character_greater_archon = 2, character_archon_warden = 3,
    character_archon_duke = 4,
}
-- Each body's trophy, and the shelf and type the review approved for it.
local DROPS = {
    character_lesser_archon = { "utility_mana_edge", "battlemage", "utility" },
    character_greater_archon = { "ability_killing_magic", "mage", "ability" },
    character_archon_warden = { "utility_wardens_post", "sentinel", "utility" },
    character_archon_duke = { "utility_ascension", "champion", "utility" },
}
local ORGANS = {
    "utility_ward_of_the_court", "utility_hold_the_gate", "utility_ducal_ascension", "utility_ducal_command",
    "weapon_mana_cut_blade", "weapon_gatekeepers_glaive", "ability_sentence_of_the_court",
}
local FIGHTS = {
    encounter_crown_the_lower_court = "combat", encounter_crown_the_gatehouse = "combat",
    encounter_crown_the_dukes_court = "elite",
}

local function board() return Fixture.new(13, 13) end

local function find(c, pred)
    for _, u in ipairs(c.units) do if pred(u) then return u end end
end
local function byId(c, id) return find(c, function(u) return u.char and u.char.id == id end) end

-- A company body: a plain bare archer, given a pool to survive the case.
local function hero(x, y, items, stats)
    return unit("character_archer", x, y, { isolate = "bare", items = items, stats = stats or { health = 300 } })
end

local function fell(c, target, attacker)
    target.lastAttacker = attacker
    Combat.dealFlatDamage(c, target, 9999, { "physical" }, nil, attacker)
end

local function wispOf(c, body) return find(c, function(u) return u.alive and u.wispOf == body end) end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the four Archons are humanoid archons on their rungs, with no demon's fire or holy line",
        fn = function()
            for id, tier in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.race == "archon" and def.tier == tier, id .. " is an archon on tier " .. tier)
                local c = Character.instantiate(id)
                assert(c.kind == "humanoid", id .. " is humanoid")
                assert(itemNamed(c, Spirit.ORGAN), id .. " wears Spirit Body from its race")
                assert(not (def.resist and def.resist.holy), id .. " has no holy line")
                for _, item in ipairs(Character.eachItem(c)) do
                    for _, t in ipairs(item.tags or {}) do
                        assert(not (item.type == "weapon" and t == "fire"), id .. "'s " .. item.id .. " burns")
                    end
                end
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal, id .. " is a body's own, never loot")
            end
            local ascended = Character.defs[Court.ASCENDED]
            assert(ascended and ascended.race == "archon" and ascended.tier == 4, "the Ascended Duke is a body too")
        end,
    },
    {
        name = "each Archon drops its approved trophy, on its approved shelf",
        fn = function()
            for body, d in pairs(DROPS) do
                local def = Character.defs[body]
                assert(def.drops and def.drops[1] == d[1], body .. " drops " .. d[1])
                local item = Item.defs[d[1]]
                assert(item.class == d[2] and item.type == d[3], d[1] .. " is a " .. d[2] .. " " .. d[3])
                assert(item.unstocked and item.unlockLevel, d[1] .. " is a trophy with a depth")
            end
        end,
    },
    {
        name = "the three fights live on the underworld, carry no rung, and field the approved courts",
        fn = function()
            for id, kind in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e and e.kind == kind, id .. " is a " .. kind)
                assert(e.rung == nil, id .. " carries no rung: the ground is its pin")
                assert(e.condition({ biome = "underworld" }) and not e.condition({ biome = "volcanic" }),
                    id .. " is the underworld's")
                if kind == "combat" then assert(e.weight == 3, id .. " is dealt at weight 3") end
            end
            local function count(list, id)
                local n = 0
                for _, x in ipairs(list) do if x == id then n = n + 1 end end
                return n
            end
            local lo = { lower = 99, gate = 99, duke = 99 }
            local hi = { lower = 0, gate = 0, duke = 0 }
            for seed = 1, 40 do
                local ctx = { depth = 15, biome = "underworld", seed = seed * 7919 }
                local lower = Encounter.get("encounter_crown_the_lower_court").composition(ctx)
                local gate = Encounter.get("encounter_crown_the_gatehouse").composition(ctx)
                local duke = Encounter.get("encounter_crown_the_dukes_court").composition(ctx)
                assert(count(lower, "character_greater_archon") == 1 and #lower <= 4, "the Lower Court: one Greater")
                assert(count(gate, "character_archon_warden") == 1 and count(gate, "character_greater_archon") == 1
                    and #gate <= 4, "the Gatehouse: a Warden and a Greater")
                assert(count(duke, "character_archon_duke") == 1 and count(duke, "character_greater_archon") == 1
                    and #duke <= 6, "the Duke's Court: the Duke and a Greater")
                for k, list in pairs({ lower = lower, gate = gate, duke = duke }) do
                    local n = count(list, "character_lesser_archon")
                    lo[k], hi[k] = math.min(lo[k], n), math.max(hi[k], n)
                end
            end
            assert(lo.lower == 2 and hi.lower == 3, "the Lower Court rolls 2-3 Lessers: " .. lo.lower .. "-" .. hi.lower)
            assert(lo.gate == 1 and hi.gate == 2, "the Gatehouse rolls 1-2 Lessers: " .. lo.gate .. "-" .. hi.gate)
            assert(lo.duke == 2 and hi.duke == 3, "the Duke's Court rolls 2-3 Lessers: " .. lo.duke .. "-" .. hi.duke)
        end,
    },

    -- ------------------------------------------------------------------------------ Mana Edge
    {
        name = "Mana Edge: the Lesser Archon's blade lands on Magic Defense, and plate does nothing",
        fn = function()
            local c = Fixture.combat(board(), {
                hero(5, 6, nil, { health = 300, defense = 2, magicDefense = 2 }),
                hero(8, 6, nil, { health = 300, defense = 20, magicDefense = 2 }),
                hero(11, 6, nil, { health = 300, defense = 2, magicDefense = 10 }),
            }, { unit("character_lesser_archon", 5, 5) })
            local a = byId(c, "character_lesser_archon")
            local blade = itemNamed(a.char, "weapon_mana_cut_blade")
            local soft = find(c, function(u) return u.side == "party" and u.x == 5 end)
            local plated = find(c, function(u) return u.side == "party" and u.x == 8 end)
            local warded = find(c, function(u) return u.side == "party" and u.x == 11 end)
            local base = Combat.computeDamage(c, a, soft, blade)
            assert(Combat.computeDamage(c, a, plated, blade) == base, "plate does nothing against it")
            assert(Combat.computeDamage(c, a, warded, blade) < base, "a magic ward does")
            Status.apply(c, soft, "status_magical_barrier", {})
            assert(Combat.computeDamage(c, a, soft, blade) == 0, "and a Magical Barrier eats it")
        end,
    },
    {
        name = "the Mana Edge drop: a blow strikes the lower defense, and bites +3",
        fn = function()
            local c = Fixture.combat(board(), {
                hero(5, 5, { "weapon_iron_sword", "utility_mana_edge" }, { health = 300, damage = 10 }),
                hero(1, 1, { "weapon_iron_sword" }, { health = 300, damage = 10 }),
            }, {
                unit("character_archer", 5, 6, { isolate = "bare", stats = { health = 300, defense = 12, magicDefense = 3 } }),
                unit("character_archer", 1, 2, { isolate = "bare", stats = { health = 300, defense = 12, magicDefense = 3 } }),
            })
            local edged = find(c, function(u) return u.side == "party" and u.x == 5 end)
            local plain = find(c, function(u) return u.side == "party" and u.x == 1 end)
            local foe = find(c, function(u) return u.side == "enemy" and u.x == 5 end)
            local sword1, sword2 = itemNamed(edged.char, "weapon_iron_sword"), itemNamed(plain.char, "weapon_iron_sword")
            local withEdge = Combat.computeDamage(c, edged, foe, sword1)
            local without = Combat.computeDamage(c, plain, foe, sword2)
            -- Defense 12 against Magic Defense 3: nine points of armour skipped, and three of bite.
            assert(withEdge == without + 9 + 3, "lower defense and +3: " .. withEdge .. " vs " .. without)
            -- The live blow agrees with the forecast.
            local before = hp(foe)
            Fixture.openTurn(c, edged)
            Combat.dealDamage(c, edged, foe, sword1, {})
            assert(before - hp(foe) == withEdge, "the blow lands what the hover promised")
        end,
    },

    -- ------------------------------------------------------------------------------ the Greater Archon
    {
        name = "Killing Magic strikes every body in a 5-tile line, its own side too, through barriers",
        fn = function()
            local c = Fixture.combat(board(), {
                hero(5, 6), hero(5, 9), hero(5, 11),
            }, {
                unit("character_greater_archon", 5, 5),
                unit("character_lesser_archon", 5, 8, { stats = { health = 300 } }),
            })
            local g = byId(c, "character_greater_archon")
            local lesser = byId(c, "character_lesser_archon")
            local near = find(c, function(u) return u.side == "party" and u.y == 6 end)
            local far = find(c, function(u) return u.side == "party" and u.y == 9 end)
            local beyond = find(c, function(u) return u.side == "party" and u.y == 11 end)
            Status.apply(c, near, "status_magical_barrier", {})
            local h = { near = hp(near), far = hp(far), beyond = hp(beyond), lesser = hp(lesser) }
            Fixture.openTurn(c, g)
            g.char.stats.mana.current = 99
            local ok = Combat.useItem(c, g, itemNamed(g.char, "ability_killing_magic"), 5, 6)
            assert(ok, "the beam is cast")
            assert(hp(near) < h.near, "through the barrier")
            assert(Status.has(near, "status_magical_barrier"), "and the barrier is not even spent")
            assert(hp(far) < h.far, "every body down the line")
            assert(hp(lesser) < h.lesser, "the court's own included")
            assert(hp(beyond) == h.beyond, "and nothing past five tiles")
        end,
    },
    {
        name = "the Ward: the Greater Archon opens warded, and wards an Archon struck within 3, on a cooldown",
        fn = function()
            local c = Fixture.combat(board(), { hero(1, 1) }, {
                unit("character_greater_archon", 6, 6),
                unit("character_lesser_archon", 6, 8, { stats = { health = 200 } }),
                unit("character_lesser_archon", 8, 6, { stats = { health = 200 } }),
                unit("character_lesser_archon", 12, 12, { stats = { health = 200 } }),
            })
            local g = byId(c, "character_greater_archon")
            local h = find(c, function(u) return u.side == "party" end)
            local a = find(c, function(u) return u.x == 6 and u.y == 8 end)
            local b = find(c, function(u) return u.x == 8 and u.y == 6 end)
            local far = find(c, function(u) return u.x == 12 and u.y == 12 end)
            assert(Status.has(g, "status_magical_barrier"), "it opens every fight under a barrier")
            Combat.dealFlatDamage(c, far, 10, { "physical" }, nil, h)
            Trait.onDamaged(c, far, { attacker = h, amount = 10 })
            assert(not Status.has(far, "status_magical_barrier"), "an Archon beyond 3 is not warded")
            Combat.dealFlatDamage(c, a, 10, { "physical" }, nil, h)
            Trait.onDamaged(c, a, { attacker = h, amount = 10 })
            assert(Status.has(a, "status_magical_barrier"), "a struck Archon within 3 is warded")
            Combat.dealFlatDamage(c, b, 10, { "physical" }, nil, h)
            Trait.onDamaged(c, b, { attacker = h, amount = 10 })
            assert(not Status.has(b, "status_magical_barrier"), "the ward is on a cooldown")
            g.cooldowns = {}
            Trait.onDamaged(c, b, { attacker = h, amount = 10 })
            assert(Status.has(b, "status_magical_barrier"), "and comes back off it")
        end,
    },

    -- ------------------------------------------------------------------------------ the Warden
    {
        name = "Hold the Gate: a holding Warden halves blows struck from beyond 2 on Archons within 2, not melee",
        fn = function()
            local c = Fixture.combat(board(), { hero(5, 3), hero(5, 8) }, {
                unit("character_archon_warden", 5, 6),
                unit("character_lesser_archon", 6, 6, { stats = { health = 300 } }),
                unit("character_lesser_archon", 11, 11, { stats = { health = 300 } }),
                unit("character_archer", 4, 6, { isolate = "bare", stats = { health = 300 } }),
            })
            local w = byId(c, "character_archon_warden")
            local covered = find(c, function(u) return u.x == 6 and u.y == 6 end)
            local open = find(c, function(u) return u.x == 11 and u.y == 11 end)
            local stranger = find(c, function(u) return u.side == "enemy" and u.x == 4 end)
            local archer = find(c, function(u) return u.side == "party" and u.y == 3 end)
            local melee = find(c, function(u) return u.side == "party" and u.y == 8 end)
            Combat.teleportUnit(c, melee, 6, 7)
            assert(Court.isHolding(w), "it holds from the bell")
            assert(Court.holdingWardenNear(c, covered, 2) == w, "and the helper finds it")
            local tags = { "pierce", "physical", "ranged" }
            local full = Combat.mitigatedDamage(open, 40, tags, nil, archer)
            assert(Combat.mitigatedDamage(covered, 40, tags, nil, archer) == math.floor(full * 0.5 + 0.5),
                "a blow from range lands at half on the court behind it")
            assert(Combat.mitigatedDamage(covered, 40, tags, nil, melee) == full, "a blow from 1 lands in full")
            assert(Combat.mitigatedDamage(stranger, 40, tags, nil, archer) ==
                Combat.mitigatedDamage(stranger, 40, tags, nil, melee), "it covers Archons only")
            -- Shoved off the post: the cover is gone until a still turn plants it again.
            Combat.teleportUnit(c, w, 5, 5)
            assert(not Court.isHolding(w), "knocked off its post, it holds nothing")
            assert(Combat.mitigatedDamage(covered, 40, tags, nil, archer) == full, "and the court takes it all")
            w.turnStartX, w.turnStartY = w.x, w.y
            Trait.onAnyTurnEnd(c, w)
            assert(Court.isHolding(w), "a still turn plants it again")
            w.turnStartX, w.turnStartY = 5, 4
            Trait.onAnyTurnEnd(c, w)
            assert(not Court.isHolding(w), "a turn it walked does not")
        end,
    },
    {
        name = "the Warden's glaive shoves the struck body 1 tile back out",
        fn = function()
            local c = Fixture.combat(board(), { hero(5, 6) }, { unit("character_archon_warden", 5, 5) })
            local w = byId(c, "character_archon_warden")
            local h = find(c, function(u) return u.side == "party" end)
            local ok = Fixture.strike(c, w, h, "weapon_gatekeepers_glaive")
            assert(ok, "it swings")
            assert(h.x == 5 and h.y == 7, "one tile back out: " .. h.x .. "," .. h.y)
        end,
    },
    {
        name = "the Warden's Post drop covers every ally, on a still turn",
        fn = function()
            local c = Fixture.combat(board(), {
                hero(5, 5, { "utility_wardens_post" }), hero(6, 5),
            }, { unit("character_archer", 5, 11, { isolate = "bare", stats = { health = 300 } }),
                 unit("character_archer", 6, 6, { isolate = "bare", stats = { health = 300 } }) })
            local post = find(c, function(u) return u.side == "party" and u.x == 5 end)
            local ally = find(c, function(u) return u.side == "party" and u.x == 6 end)
            local shooter = find(c, function(u) return u.side == "enemy" and u.y == 11 end)
            local brawler = find(c, function(u) return u.side == "enemy" and u.y == 6 end)
            assert(Court.isHolding(post), "the bearer holds from the bell")
            local tags = { "pierce", "physical", "ranged" }
            local ranged = Combat.mitigatedDamage(ally, 40, tags, nil, shooter)
            local close = Combat.mitigatedDamage(ally, 40, tags, nil, brawler)
            assert(ranged < close, "a foe from range lands at half on an ally within 2: " .. ranged .. " vs " .. close)
        end,
    },

    -- ------------------------------------------------------------------------------ the Duke
    {
        name = "Ascension: a wisp within 3 goes to the Duke, the body stays down, and at three the Duke Ascends",
        fn = function()
            local c = Fixture.combat(board(), { hero(1, 12) }, {
                unit("character_archon_duke", 6, 6),
                unit("character_lesser_archon", 6, 7), unit("character_lesser_archon", 7, 6),
                unit("character_lesser_archon", 5, 6), unit("character_lesser_archon", 12, 1),
            })
            local duke = byId(c, "character_archon_duke")
            local killer = find(c, function(u) return u.side == "party" end)
            -- The far Lesser's wisp is thrown nowhere near the Duke: it walks home.
            local far = find(c, function(u) return u.x == 12 and u.y == 1 end)
            fell(c, far, killer)
            local farWisp = wispOf(c, far)
            assert(farWisp and Spirit.goal(c, farWisp) == far, "a wisp beyond 3 still walks home")
            duke.char.stats.health.current = 40
            local taken = 0
            for _, pos in ipairs({ { 6, 7 }, { 7, 6 }, { 5, 6 } }) do
                local body = find(c, function(u) return u.x == pos[1] and u.y == pos[2] and u.char.id == "character_lesser_archon" end)
                fell(c, body, killer)
                local w = wispOf(c, body)
                assert(w, "a wisp is thrown")
                -- Brought beside the Duke and claimed at the next turn's edge, then its own turn ends there.
                local placed = false
                for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { -1, 0 }, { 0, 1 } }) do
                    if not placed and Combat.footprintFree(c, 1, 1, duke.x + d[1], duke.y + d[2]) then
                        placed = Combat.teleportUnit(c, w, duke.x + d[1], duke.y + d[2]) and true
                    end
                end
                assert(placed and Combat.unitGap(w, duke) == 1, "a tile beside the Duke")
                Trait.onAnyTurnStart(c, w)
                assert(Spirit.goal(c, w) == duke, "a wisp within 3 goes to the Duke")
                Spirit.tryArrive(c, w)
                taken = taken + 1
                assert(not w.alive, "the Duke takes it in")
                assert(not body.alive, "and that Archon stays down")
                if taken < 3 then assert(not duke.ascended, "not yet: " .. taken) end
            end
            assert(duke.ascended and duke.char.id == Court.ASCENDED, "at three, the Duke Ascends")
            assert(hp(duke) == Combat.unreservedMax(duke.char, "health"), "healed to full")
            assert(itemNamed(duke.char, "ability_sentence_of_the_court"), "with a new spell")
            assert(itemNamed(duke.char, "utility_ducal_command"), "and still Commanding")
        end,
    },
    {
        name = "Command: at the end of the Duke's turn, Archons within 3 are pulled ahead of the company",
        fn = function()
            local c = Fixture.combat(board(), { hero(1, 12) }, {
                unit("character_archon_duke", 6, 6),
                unit("character_lesser_archon", 6, 8), unit("character_lesser_archon", 12, 1),
            })
            local duke = byId(c, "character_archon_duke")
            local h = find(c, function(u) return u.side == "party" end)
            local near = find(c, function(u) return u.x == 6 and u.y == 8 end)
            local far = find(c, function(u) return u.x == 12 and u.y == 1 end)
            duke.initiative, h.initiative, near.initiative, far.initiative = 0, 4, 9, 9
            Trait.onAnyTurnEnd(c, duke)
            assert(near.initiative < h.initiative, "the court near the Duke acts first: " .. near.initiative)
            assert(far.initiative == 9, "the court beyond 3 is not commanded")
            local order = Combat.turnOrder(c)
            local iNear, iHero
            for i, u in ipairs(order) do
                if u == near then iNear = i elseif u == h then iHero = i end
            end
            assert(iNear < iHero, "and the timeline agrees")
        end,
    },
    {
        name = "the Ascension drop: three foes downed by the bearer, and it Ascends for the fight",
        fn = function()
            local c = Fixture.combat(board(), { hero(1, 1, { "utility_ascension" }, { health = 300, damage = 10, movement = 4 }) }, {
                unit("character_archer", 10, 10, { isolate = "bare" }), unit("character_archer", 11, 10, { isolate = "bare" }),
                unit("character_archer", 12, 10, { isolate = "bare" }), unit("character_archer", 12, 12, { isolate = "bare" }),
            })
            local b = find(c, function(u) return u.side == "party" end)
            local foes = {}
            for _, u in ipairs(c.units) do if u.side == "enemy" then foes[#foes + 1] = u end end
            local dmg, mv = Combat.flatStat(b, "damage"), Combat.flatStat(b, "movement")
            fell(c, foes[1], b)
            fell(c, foes[2], b)
            assert(Combat.flatStat(b, "damage") == dmg, "two is not yet three")
            fell(c, foes[3], b)
            assert(Combat.flatStat(b, "damage") == dmg + 6, "+6 Damage at three")
            assert(Combat.flatStat(b, "movement") == mv + 2, "+2 Movement at three")
            fell(c, foes[4], b)
            assert(Combat.flatStat(b, "damage") == dmg + 6, "and it Ascends once")
        end,
    },
}
