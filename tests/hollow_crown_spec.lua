-- Tests for THE HOLLOW CROWN (2026-10-09, "The Crown's Bestiary", slice D): the last fight of the game, its four
-- phases, its court, and its drops. Every rule approved over rounds 3-4 of the review page.
--
--   identity          an Archon (no holy line, no demonic essence), a 3x3 throne at the far edge, Enthroned
--   1 the court       no damage while a Warden holds within 2 of the throne; wisps walk to the throne, each heals 10%
--   2 the wants       an omen badge a turn ahead, then the want: Swallowed, Charm, Gilded, Enraged, the Fairest's own
--                     ability, Drowsy, Magic Denied -- seven, each once, dealt off the fight's own seed
--   3 the pit         at half: off the throne, a ring marked and falling a turn later, Downed bodies, Pit Locusts
--   4 the last hour   at a quarter: a count of 6, a Seal a turn, then the board is swallowed
--   the escort        its own court of Archons, a Warden first
--   the drops         the Hollow Crown, Omen, The Floor Gives Way, Usurper, Crown of Thorns
--
-- The headless autobattler never resolves a wind-up, so every phase is pinned here on a bare board, driving the
-- Crown's own hooks (HollowCrown.turnStart / turnEnd) where a played fight would.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Spirit = require("models.spirit")
local Court = require("models.archon_court")
local HollowCrown = require("models.hollow_crown")
local Descent = require("models.descent")
local Fixture = require("tests.support.fixture")

local unit, itemNamed, hp = Fixture.unit, Fixture.itemNamed, Fixture.hp
local CROWN = "character_demon_lord"
local T = Status.TICKS_PER_TURN

-- The Crown's five pieces, the relic first, with the shelf and type the review approved for each.
local DROPS = {
    { "armor_hollow_crown", "warlord", "armor" },
    { "utility_omen", "theurge", "utility" },
    { "ability_the_floor_gives_way", "bombardier", "ability" },
    { "utility_usurper", "warlord", "utility" },
    { "utility_crown_of_thorns", "inquisitor", "utility" },
}

local function board(opts) return Fixture.new(13, 13, opts) end

local function find(c, pred)
    for _, u in ipairs(c.units) do if pred(u) then return u end end
end
local function byId(c, id) return find(c, function(u) return u.char and u.char.id == id end) end
local function crownOf(c) return byId(c, CROWN) end

local function hero(x, y, stats, items)
    return unit("character_archer", x, y, { isolate = "bare", items = items, stats = stats or { health = 300 } })
end

local function maxHp(u) return Combat.unreservedMax(u.char, "health") end

-- A raw blow, so a case reads its threshold and not a defense the balance pass keeps moving.
local function wound(c, target, n, attacker)
    return Combat.dealFlatDamage(c, target, n, {}, "test", attacker, { raw = true })
end

local function fell(c, target, attacker)
    target.lastAttacker = attacker
    Combat.dealFlatDamage(c, target, 9999, { "physical" }, nil, attacker)
end

-- A Crown on a bare board: no court, so it opens in its wants.
local function bare(party, opts)
    local c = Fixture.combat(board(opts), party or { hero(7, 7) }, { unit(CROWN, 6, 1) })
    return c, crownOf(c)
end

-- Take the Crown to just above `share` of its health, then one blow across it.
local function crossTo(c, crown, share)
    local h = crown.char.stats.health
    h.current = math.floor(h.max * share) + 2
    wound(c, crown, 4)
end

return {
    -- --------------------------------------------------------------------------------------- identity
    {
        name = "the Hollow Crown is an Archon with no holy line, a 3x3 throne, and its phases on a bound organ",
        fn = function()
            local def = Character.defs[CROWN]
            assert(def.race == "archon" and def.tier == 4 and def.boss, "a tier-4 Archon, and the stair's boss")
            assert(def.revivable == false, "no downed window, so it never throws a wisp of its own")
            assert(def.footprint and def.footprint.w == 3 and def.footprint.h == 3, "the throne is nine tiles")
            local char = Character.instantiate(CROWN)
            assert(char.kind == "humanoid", "an Archon is humanoid")
            assert(not itemNamed(char, "utility_demonic_essence"), "the demonic essence came off with the holy weakness")
            assert(itemNamed(char, Spirit.ORGAN), "it wears Spirit Body from its race")
            local organ = char.inventory[5]
            assert(organ and organ.id == "utility_the_first_archon", "its organ is centred")
            assert(organ.bound and organ.noSteal and organ.class == "creature", "bound creature kit, never loot")
            assert(organ.traits[1] == "trait_hollow_crown" and organ.traits[2] == "trait_gullet",
                "carrying the four phases and the Gullet its Gluttony needs")
            local rule = Trait.defs.trait_hollow_crown
            assert(rule.shades == nil and rule.thresholds == nil, "it no longer wears the dead generals")
            local u = { char = char, alive = true, side = "enemy" }
            Combat.refreshPassives(u)
            assert((u.resist.holy or 0) >= 0, "holy lands on it like anybody else")
            assert(Item.defs.weapon_demon_bane.description:find("demons"), "Demon Bane still answers demons")
        end,
    },
    {
        name = "it opens seated at the far edge, Enthroned: it cannot walk and nothing moves it",
        fn = function()
            local c, crown = bare({ hero(7, 12) })
            assert(crown.w == 3 and crown.h == 3, "the throne stands on the board")
            assert(crown.y == 1, "seated on the edge away from the company")
            assert(Status.has(crown, HollowCrown.ENTHRONED), "Enthroned")
            assert(Status.blocksForcedMove(crown), "nothing moves it")
        end,
    },

    -- --------------------------------------------------------------------------------------- phase 1
    {
        name = "phase 1: while an Archon Warden holds still within 2 of the throne, the Crown takes no damage at all",
        fn = function()
            local c = Fixture.combat(board(), { hero(7, 12), hero(1, 12) }, {
                unit(CROWN, 6, 1),
                unit("character_archon_warden", 7, 5),
                unit("character_lesser_archon", 12, 12, { stats = { health = 300 } }),
            })
            local crown, w = crownOf(c), byId(c, "character_archon_warden")
            assert(HollowCrown.phase(crown) == 1, "its court convenes")
            assert(Court.isHolding(w) and Combat.unitGap(w, crown) == 2, "a Warden holds 2 from the throne")
            local throne = Status.get(crown, HollowCrown.ENTHRONED)
            assert(throne.court and throne.def.describe(throne):find("Warden"), "the badge says why")
            local archer = find(c, function(u) return u.side == "party" end)
            local before = hp(crown)
            assert(Combat.dealFlatDamage(c, crown, 60, { "physical", "pierce" }, nil, archer) == 0, "the blow is void")
            assert(Combat.mitigatedDamage(crown, 60, { "physical", "pierce" }, nil, archer) == 0, "and the hover says so")
            assert(hp(crown) == before, "it takes no damage at all")
            -- Shoved off its post, the Warden holds nothing, and the blow lands.
            Combat.teleportUnit(c, w, 7, 6)
            assert(not Court.isHolding(w), "off its post")
            assert(wound(c, crown, 60, archer) > 0 and hp(crown) < before, "now the Crown is hurt")
        end,
    },
    {
        name = "phase 1: a fallen Archon's wisp walks to the throne, not its body, and each one taken heals 10%",
        fn = function()
            local c = Fixture.combat(board(), { hero(7, 12) }, {
                unit(CROWN, 6, 1),
                unit("character_archon_warden", 12, 12),
                unit("character_lesser_archon", 3, 7),
            })
            local crown = crownOf(c)
            local killer = find(c, function(u) return u.side == "party" end)
            local body = byId(c, "character_lesser_archon")
            fell(c, body, killer)
            local wisp = find(c, function(u) return u.alive and u.wispOf == body end)
            assert(wisp, "the Archon throws its wisp")
            assert(wisp.wispGoal == crown and Spirit.goal(c, wisp) == crown, "and it walks to the throne")
            crown.char.stats.health.current = 200
            assert(Combat.teleportUnit(c, wisp, 5, 2) and Combat.unitGap(wisp, crown) == 1, "beside the throne")
            Spirit.tryArrive(c, wisp)
            assert(not wisp.alive, "the throne takes the wisp")
            assert(not body.alive, "and the body it left stays down")
            assert(hp(crown) == 200 + math.floor(maxHp(crown) * 0.1 + 0.5), "the Crown heals a tenth")
        end,
    },
    {
        name = "phase 1 ends when the court is down -- wisps and all -- and the wants begin with an omen",
        fn = function()
            local c = Fixture.combat(board(), { hero(7, 12) }, {
                unit(CROWN, 6, 1),
                unit("character_archon_warden", 2, 7),
                unit("character_lesser_archon", 11, 7),
            })
            local crown = crownOf(c)
            local killer = find(c, function(u) return u.side == "party" end)
            fell(c, byId(c, "character_archon_warden"), killer)
            fell(c, byId(c, "character_lesser_archon"), killer)
            assert(HollowCrown.phase(crown) == 1, "two wisps are still walking: the court is not down")
            for _, u in ipairs(c.units) do
                if u.alive and u.wispOf then fell(c, u, killer) end
            end
            Trait.onAnyTurnEnd(c, killer)
            assert(HollowCrown.phase(crown) == 2, "the court is down")
            local want = HollowCrown.state(crown).omen
            assert(want and Status.has(crown, HollowCrown.omenStatus(want)), "an omen goes up over its head")
            assert(Status.get(crown, HollowCrown.omenStatus(want)).def.name == "Omen: " .. HollowCrown.WANT_NAMES[want],
                "the badge names the want")
            assert(not Status.get(crown, HollowCrown.ENTHRONED).court, "and the throne no longer claims the court")
        end,
    },

    -- --------------------------------------------------------------------------------------- phase 2
    {
        name = "phase 2: the seven wants come in an order dealt off the fight's own seed, each once",
        fn = function()
            local function order(seed)
                local c, crown = bare(nil, { seed = seed })
                local st = HollowCrown.state(crown)
                local out = { st.omen }
                for _, w in ipairs(st.deck) do out[#out + 1] = w end
                return out
            end
            local a, b = order(4242), order(4242)
            assert(#a == 7, "seven wants")
            local seen = {}
            for i, w in ipairs(a) do
                assert(w == b[i], "the same seed deals the same order")
                assert(not seen[w], w .. " comes once")
                seen[w] = true
            end
            for _, w in ipairs(HollowCrown.WANTS) do assert(seen[w], w .. " is dealt") end
            local differs = false
            for seed = 1, 12 do
                local o = order(seed * 7919)
                for i = 1, 7 do if o[i] ~= a[i] then differs = true end end
            end
            assert(differs, "and another seed deals another order")
        end,
    },
    {
        name = "phase 2: the omen shows a turn ahead, and the want is acted the turn after",
        fn = function()
            local c, crown = bare()
            local st = HollowCrown.state(crown)
            Status.remove(c, crown, HollowCrown.omenStatus(st.omen))
            st.omen = "wrath"
            Status.apply(c, crown, HollowCrown.omenStatus("wrath"), { applier = crown })
            assert(not Status.has(crown, "status_enraged"), "shown, not yet acted")
            HollowCrown.turnStart(c, crown)
            assert(Status.has(crown, "status_enraged"), "its turn comes: the want is acted")
            assert(not Status.has(crown, HollowCrown.omenStatus("wrath")), "the omen comes down")
            assert(st.omen and st.omen ~= "wrath" and Status.has(crown, HollowCrown.omenStatus(st.omen)),
                "and the next one goes up")
        end,
    },
    {
        name = "Gluttony: it Swallows the nearest body, and a tenth of its health dealt sets the body free",
        fn = function()
            local c, crown = bare({ hero(7, 5), hero(2, 12) })
            local near = find(c, function(u) return u.side == "party" and u.y == 5 end)
            HollowCrown.act(c, crown, "gluttony")
            assert(near.swallowedBy == crown and Status.has(near, "status_swallowed"), "the nearest body is Swallowed")
            local tenth = math.ceil(maxHp(crown) * 0.1)
            wound(c, crown, math.floor(tenth / 2))
            assert(near.swallowedBy == crown, "half a tenth is not enough")
            wound(c, crown, tenth)
            assert(not near.swallowedBy and not Status.has(near, "status_swallowed"), "a tenth dealt: it spits it out")
        end,
    },
    {
        name = "Lust: it Charms the hardest hitter for a turn",
        fn = function()
            local c, crown = bare({ hero(7, 6), hero(3, 10, { health = 300, damage = 40 }) })
            local brute = find(c, function(u) return u.side == "party" and u.x == 3 end)
            HollowCrown.act(c, crown, "lust")
            local s = Status.get(brute, "status_charm")
            assert(s and s.remaining == Status.defs.status_charm.duration, "the hardest hitter is Charmed, Charm's own turn")
            assert(brute.side == "enemy", "and fights for the Crown")
        end,
    },
    {
        name = "Greed: it Gilds the two nearest bodies, and an impact blow breaks its gilding (not a dwarf's)",
        fn = function()
            local c, crown = bare({ hero(7, 5), hero(8, 6), hero(2, 12) })
            local a = find(c, function(u) return u.side == "party" and u.y == 5 end)
            local b = find(c, function(u) return u.side == "party" and u.y == 6 end)
            local far = find(c, function(u) return u.side == "party" and u.y == 12 end)
            HollowCrown.act(c, crown, "greed")
            assert(Status.has(a, "status_gilded") and Status.has(b, "status_gilded"), "the two nearest are Gilded")
            assert(not Status.has(far, "status_gilded"), "and nobody else")
            Combat.dealFlatDamage(c, a, 3, { "slash", "physical" }, "test")
            assert(Status.has(a, "status_gilded"), "an edge does not break it")
            Combat.dealFlatDamage(c, a, 3, { "impact", "physical" }, "test")
            assert(not Status.has(a, "status_gilded"), "impact does")
            Status.apply(c, far, "status_gilded")
            Combat.dealFlatDamage(c, far, 3, { "impact", "physical" }, "test")
            assert(Status.has(far, "status_gilded"), "a gilding the Crown did not lay is armour, and stays")
        end,
    },
    {
        name = "Wrath: Enraged, every wound sharpens its next blow, and the blow spends it",
        fn = function()
            local c, crown = bare()
            local st = HollowCrown.state(crown)
            -- Nothing pending, so its next turn acts no other want across the reading.
            Status.remove(c, crown, HollowCrown.omenStatus(st.omen))
            st.omen = nil
            local base = Combat.flatStat(crown, "damage")
            HollowCrown.act(c, crown, "wrath")
            assert(Status.has(crown, "status_enraged"), "Enraged")
            wound(c, crown, 5)
            wound(c, crown, 5)
            wound(c, crown, 5)
            assert(Combat.flatStat(crown, "damage") == base + 3 * HollowCrown.WRATH_STEP, "three wounds, three steps")
            assert(Status.get(crown, "status_enraged").magnitude == 3 * HollowCrown.WRATH_STEP, "the badge counts it")
            HollowCrown.turnStart(c, crown)
            assert(Combat.flatStat(crown, "damage") == base + 3 * HollowCrown.WRATH_STEP, "its blow carries it")
            HollowCrown.turnEnd(c, crown)
            assert(Combat.flatStat(crown, "damage") == base, "and the blow spends it")
            assert(not Status.has(crown, "status_enraged") and st.wrath == nil, "the rage is gone")
        end,
    },
    {
        name = "Envy: it names the Fairest and turns the last ability it used back on it",
        fn = function()
            local c, crown = bare({ hero(7, 6, nil, { "weapon_iron_sword" }), hero(2, 12) })
            local fair = find(c, function(u) return u.side == "party" and u.y == 6 end)
            Status.apply(c, fair, "status_hasted")
            HollowCrown.saw(c, crown, fair, itemNamed(fair.char, "weapon_iron_sword"))
            local before = hp(fair)
            assert(HollowCrown.act(c, crown, "envy") == fair, "the body with the most blessings is the Fairest")
            assert(hp(fair) < before, "its own sword is swung at it")
        end,
    },
    {
        name = "Sloth: every body that did not move since the omen grows Drowsy",
        fn = function()
            local c, crown = bare({ hero(7, 6), hero(2, 12) })
            local still = find(c, function(u) return u.side == "party" and u.y == 6 end)
            local mover = find(c, function(u) return u.side == "party" and u.y == 12 end)
            require("models.desidia").snapshot(c, crown)
            Combat.tally(still, "turnTaken", 1)
            Combat.tally(mover, "turnTaken", 1)
            Combat.tally(mover, "tilesMoved", 2)
            HollowCrown.act(c, crown, "sloth")
            assert(Status.has(still, "status_drowsy"), "the body that stood still grows Drowsy")
            assert(not Status.has(mover, "status_drowsy"), "the body that moved does not")
        end,
    },
    {
        name = "Pride: Magic Denied on the last body to cast a spell",
        fn = function()
            local c, crown = bare({ hero(7, 6), hero(2, 12) })
            local mage = find(c, function(u) return u.side == "party" and u.y == 12 end)
            local other = find(c, function(u) return u.side == "party" and u.y == 6 end)
            HollowCrown.saw(c, crown, other, Item.instantiate("weapon_iron_sword"))
            HollowCrown.saw(c, crown, mage, Item.instantiate("ability_fire_bolt"))
            HollowCrown.saw(c, crown, other, Item.instantiate("weapon_iron_sword"))
            HollowCrown.act(c, crown, "pride")
            assert(Status.has(mage, "status_magic_denied"), "the last caster is Magic Denied")
            assert(not Status.has(other, "status_magic_denied"), "a sword is not a spell")
        end,
    },

    -- --------------------------------------------------------------------------------------- phase 3
    {
        name = "phase 3: at half it steps off the throne onto one tile and walks, and the board's edge is marked",
        fn = function()
            local c, crown = bare({ hero(7, 12) })
            crossTo(c, crown, 0.5)
            assert(HollowCrown.phase(crown) == 3, "half health: the Pit opens")
            assert(crown.w == 1 and crown.h == 1 and crown.x == 7 and crown.y == 2, "the throne's centre tile")
            assert(not Status.has(crown, HollowCrown.ENTHRONED), "no longer Enthroned")
            assert(not HollowCrown.state(crown).omen, "the wants are over")
            local Hazard = require("models.hazard")
            assert(Hazard.at(c, 1, 7, HollowCrown.EDGE) and Hazard.at(c, 13, 13, HollowCrown.EDGE),
                "the outer ring is marked")
            assert(not Hazard.at(c, 2, 7, HollowCrown.EDGE), "and only the outer ring")
        end,
    },
    {
        name = "phase 3: the marked ring falls a turn later -- a body on it is Downed in the Pit, and locusts climb out",
        fn = function()
            local c, crown = bare({ hero(1, 7), hero(7, 7) })
            local edge = find(c, function(u) return u.side == "party" and u.x == 1 end)
            local safe = find(c, function(u) return u.side == "party" and u.x == 7 end)
            crossTo(c, crown, 0.5)
            HollowCrown.turnStart(c, crown)
            assert(not edge.alive and edge.incapacitated and Status.has(edge, "status_downed"),
                "the body on the edge drops into the Pit, Downed with its revive window")
            assert(safe.alive, "the body inside it does not")
            local tiles = c.arena.tiles
            assert(tiles[7][1].type == "lava" and not tiles[7][1].walkable, "the edge is the Pit now")
            assert(tiles[7][3].walkable, "the ground inside is not")
            local locusts = {}
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == HollowCrown.LOCUST then locusts[#locusts + 1] = u end
            end
            assert(#locusts == HollowCrown.LOCUSTS_PER_RING, "Pit Locusts climb out: " .. #locusts)
            for _, l in ipairs(locusts) do
                assert(l.summoner == crown, "sustained by the Crown")
                assert(math.min(l.x - 1, l.y - 1, 13 - l.x, 13 - l.y) == 1, "on the inside edge")
            end
            assert(require("models.hazard").at(c, 2, 7, HollowCrown.EDGE), "and the next ring in is marked")
        end,
    },
    {
        name = "phase 3: it hunts the body with the fewest open tiles around it",
        fn = function()
            local c, crown = bare({ hero(1, 13), hero(7, 7) })
            local corner = find(c, function(u) return u.side == "party" and u.x == 1 end)
            local open = find(c, function(u) return u.side == "party" and u.x == 7 end)
            assert(HollowCrown.openAround(c, corner) == 3 and HollowCrown.openAround(c, open) == 8,
                "a corner has three open tiles, the middle eight")
            local listed = false
            for _, p in ipairs(require("models.ai").TARGET_PREF_ORDER) do if p == "hemmed" then listed = true end end
            assert(listed, "the hunt is a preference the planner knows")
            assert(Character.defs[CROWN].ai[1].targetPref == "hemmed", "and the Crown's own rule asks for it")
        end,
    },

    -- --------------------------------------------------------------------------------------- phase 4
    {
        name = "phase 4: a count of 6, a Seal raised each turn in the approved order, then the board is swallowed",
        fn = function()
            local c, crown = bare({ hero(7, 7) })
            local h = find(c, function(u) return u.side == "party" end)
            crossTo(c, crown, 0.5)
            crossTo(c, crown, 0.25)
            local st = HollowCrown.state(crown)
            assert(HollowCrown.phase(crown) == 4 and st.count == 6, "a quarter: the count is 6")
            assert(Status.get(crown, HollowCrown.LAST_HOUR).magnitude == 6, "on the badge")
            assert(Status.has(crown, "status_immune_slash"), "the first Seal goes up as the hour begins")
            assert(Combat.dealFlatDamage(c, crown, 30, { "slash", "physical" }, "test") == 0, "slash is sealed")
            assert(Combat.dealFlatDamage(c, crown, 30, { "pierce", "physical" }, "test") > 0, "pierce is not yet")
            local hHp = hp(h)
            for turn = 1, 6 do
                crown.char.stats.health.current = math.floor(maxHp(crown) * 0.2)
                HollowCrown.turnStart(c, crown)
                assert(st.count == 6 - turn, "the count drops each turn")
                assert(Status.get(crown, HollowCrown.LAST_HOUR).magnitude == st.count, "and the badge with it")
                assert(Status.has(crown, "status_immune_" .. HollowCrown.SEALS[turn + 1]),
                    "turn " .. turn .. " raises the Seal against " .. HollowCrown.SEALS[turn + 1])
                for i = 1, turn do
                    assert(Status.has(crown, "status_immune_" .. HollowCrown.SEALS[i]), "earlier Seals hold")
                end
            end
            assert(h.alive and hp(h) == hHp, "nothing has struck the company yet")
            assert(HollowCrown.SEALS[7] == "holy", "holy is sealed last")
            HollowCrown.turnStart(c, crown)
            assert(not h.alive, "a turn that opens on 0 swallows the board")
            assert(crown.alive, "and the Crown is still on it")
        end,
    },
    {
        name = "the stair stays resolvable: when the Crown falls, its locusts go with it and the fight is won",
        fn = function()
            local c, crown = bare({ hero(7, 7), hero(1, 7) },
                { objective = { type = "assassinate", target = CROWN } })
            crossTo(c, crown, 0.5)
            HollowCrown.turnStart(c, crown)
            local locust = byId(c, HollowCrown.LOCUST)
            assert(locust and locust.alive, "the swarm is up")
            wound(c, crown, 9999)
            assert(not crown.alive, "the Crown falls")
            assert(not locust.alive, "its locusts go with it")
            assert(Combat.evaluate(c) == "win", "and the assassinate is won")
        end,
    },

    -- --------------------------------------------------------------------------------------- the stair
    {
        name = "the stair's escort is its own court of Archons, a Warden first, sized against the step",
        fn = function()
            local run = Descent.new(nil, 77)
            run.floor = Descent.FLOORS
            local obj = Descent.floorQuest(run).map.objective
            assert(obj.win.type == "assassinate" and obj.win.target == CROWN, "it is the Crown that has to die")
            local bodies = obj.composition({})
            assert(bodies[1] == CROWN, "the Crown leads")
            assert(bodies[2] == "character_archon_warden", "a Warden first: phase 1 needs one")
            assert(#bodies - 1 <= Descent.GUARD_MAX, "inside the arena's cap")
            for i = 2, #bodies do
                assert(Character.defs[bodies[i]].race == "archon", bodies[i] .. " is of its court")
            end
            local n, worth, target = Descent.crownCourtSize(Descent.FLOORS, run)
            assert(n == #bodies - 1, "the composition is the solved court")
            assert(worth >= target or n == Descent.GUARD_MAX,
                "the court reaches the step, or stops at the cap and says so: " .. worth .. " of " .. target)
        end,
    },

    -- --------------------------------------------------------------------------------------- the drops
    {
        name = "it drops its five pieces, the relic first, each a trophy on its approved shelf",
        fn = function()
            local def = Character.defs[CROWN]
            local list = Descent.DROPS.crown.general
            for i, d in ipairs(DROPS) do
                assert(def.drops[i] == d[1], "the body drops " .. d[1] .. " at " .. i)
                assert(list[i] == d[1], "and the stair pays it at " .. i)
                local item = Item.defs[d[1]]
                assert(item.class == d[2] and item.type == d[3], d[1] .. " is a " .. d[2] .. " " .. d[3])
                assert(item.unstocked and item.unlockLevel and item.price == nil, d[1] .. " is an unpriced trophy")
            end
            local Player = require("models.player")
            local p = Player.new()
            assert(Descent.crownDropFor(p) == "armor_hollow_crown", "a first win pays the relic")
            p.stash = p.stash or {}
            p.stash[#p.stash + 1] = Item.instantiate("armor_hollow_crown")
            assert(Descent.crownDropFor(p) == "utility_omen", "a second pays the next piece")
        end,
    },
    {
        name = "the Hollow Crown: +3 damage for each different status on you, good or bad",
        fn = function()
            local c = Fixture.combat(board(), { hero(5, 5, nil, { "armor_hollow_crown" }) },
                { hero(9, 9) })
            local w = c.units[1]
            local base = Combat.flatStat(w, "damage")
            Status.apply(c, w, "status_hasted")
            Status.apply(c, w, "status_burn")
            Status.apply(c, w, "status_burn")
            assert(Combat.flatStat(w, "damage") == base + 6, "two different statuses: +6")
        end,
    },
    {
        name = "Omen: a foe winding up Hastes every ally for a turn, once per foe each round",
        fn = function()
            local c = Fixture.combat(board(), { hero(5, 5, nil, { "utility_omen" }), hero(6, 5) }, { hero(9, 9) })
            local bearer, ally, foe = c.units[1], c.units[2], c.units[3]
            Status.apply(c, foe, "status_channeling", { duration = 6 })
            assert(Status.has(bearer, "status_hasted") and Status.has(ally, "status_hasted"), "the line quickens")
            assert(Status.get(ally, "status_hasted").remaining == T, "for a turn")
            Status.remove(c, ally, "status_hasted")
            Status.remove(c, foe, "status_channeling")
            Status.apply(c, foe, "status_channeling", { duration = 6 })
            assert(not Status.has(ally, "status_hasted"), "the same foe again this round does not")
            Trait.onAnyTurnStart(c, bearer)
            Trait.fire(c, bearer, "onTurnStart", {})
            Status.remove(c, foe, "status_channeling")
            Status.apply(c, foe, "status_channeling", { duration = 6 })
            assert(Status.has(ally, "status_hasted"), "a new round, a new tell")
        end,
    },
    {
        name = "Usurper: a foe with boons falling within 3 hands them over; one farther off does not",
        fn = function()
            local c = Fixture.combat(board(), { hero(5, 5, nil, { "utility_usurper" }) },
                { hero(7, 5), hero(12, 12) })
            local bearer, near, far = c.units[1], c.units[2], c.units[3]
            Status.apply(c, near, "status_hasted")
            Status.apply(c, far, "status_regen")
            fell(c, near, bearer)
            assert(Status.has(bearer, "status_hasted"), "the near foe's boon passes over")
            fell(c, far, bearer)
            assert(not Status.has(bearer, "status_regen"), "a fall beyond 3 does not")
        end,
    },
    {
        name = "Crown of Thorns: a foe within 2 loses a tenth of its max health for each ability it uses",
        fn = function()
            local c = Fixture.combat(board(), { hero(5, 5, nil, { "utility_crown_of_thorns" }) },
                { hero(6, 6, { health = 200, mana = 99 }, { "ability_fire_bolt", "weapon_iron_sword" }),
                  hero(12, 12, { health = 200, mana = 99 }, { "ability_fire_bolt" }) })
            local bearer, near, far = c.units[1], c.units[2], c.units[3]
            local before = hp(near)
            assert(Fixture.strike(c, near, bearer, "ability_fire_bolt"), "the near foe casts")
            assert(before - hp(near) == 20, "and loses a tenth of 200")
            local afterSpell = hp(near)
            Fixture.strike(c, near, bearer, "weapon_iron_sword")
            assert(hp(near) == afterSpell, "a sword is not an ability")
            local farBefore = hp(far)
            Combat.teleportUnit(c, far, 9, 5)
            Fixture.strike(c, far, bearer, "ability_fire_bolt")
            assert(hp(far) == farBefore, "beyond 2 the thorns do not reach")
        end,
    },
    {
        name = "The Floor Gives Way: a hidden mine; the first foe across it takes heavy impact damage and is Rooted",
        fn = function()
            local c = Fixture.combat(board(),
                { hero(5, 5, { health = 300, mana = 99 }, { "ability_the_floor_gives_way" }) }, { hero(9, 9) })
            local bomb, foe = c.units[1], c.units[2]
            assert(Fixture.strike(c, bomb, { x = 7, y = 5 }, "ability_the_floor_gives_way"), "the mine is hidden")
            local Trap = require("models.trap")
            local mine = Trap.at(c, 7, 5)
            assert(mine and mine.id == "the_floor_gives_way", "a mine on the tile")
            local before = hp(foe)
            Combat.teleportUnit(c, foe, 7, 5)
            assert(hp(foe) < before, "it falls through")
            assert(Status.has(foe, "status_root"), "and is Rooted")
        end,
    },
}
