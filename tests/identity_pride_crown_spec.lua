-- Tests for THE CREATURE IDENTITY PASS on Pride (floors 13-14) and the Crown (floor 15), 2026-11-19. An audit put
-- every fielded body through one test -- does meeting it change what you BRING, where you STAND, or whom you kill
-- FIRST -- and the author approved a fix for each row that failed and each pattern that blurred. Each case here puts
-- the body on a board and acts, rather than reading a field.
--
--   Elf Retainer      THE OATH: beside an Unblemished elf it takes every blow meant for that elf; break it first
--   Elf court         WOUNDED PRIDE: the blow that marks a court elf Taunts it onto the striker (the court's second axis)
--   Lesser Archon     WISP-CARRIER: a wisp nearer to it than to its body comes to it, and the body stands at once;
--                     it yields to a Duke
--   Gilded Page       THE HOOK: the page fetches (pulls a foe in beside it), the sworn holds; a hollow hide, not plate
--   Pride's hides     floors 13-14 no longer all ask for a spear
--   Pit Locust        SWARM TORMENT: Torment keys on a second locust beside the body, not on a body at 1
--   Targeting         the Reaper walks to the body under its line, the Erinys to a caster winding up

local Character = require("models.character")
local Combat = require("models.combat")
local Status = require("models.status")
local Trait = require("models.trait")
local Spirit = require("models.spirit")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local unit, openTurn, hp = Fixture.unit, Fixture.openTurn, Fixture.hp

local function board(n) return Fixture.new(n or 13, n or 13) end

local function one(c, id, nth)
    local seen = 0
    for _, u in ipairs(c.units) do
        if u.char and u.char.id == id then
            seen = seen + 1
            if seen == (nth or 1) then return u end
        end
    end
end

local function party(c, nth)
    local seen = 0
    for _, u in ipairs(c.units) do
        if u.side == "party" then
            seen = seen + 1
            if seen == (nth or 1) then return u end
        end
    end
end

-- A plain company body, health 200 at full.
local function hero(x, y, items)
    return unit("character_archer", x, y, { isolate = "bare", items = items, stats = { health = 200 } })
end

local function blow(c, target, amount, attacker)
    return Combat.dealFlatDamage(c, target, amount, { "physical" }, "test", attacker, { raw = true })
end

local function fell(c, target, attacker)
    target.lastAttacker = attacker
    Combat.dealFlatDamage(c, target, 9999, { "physical" }, nil, attacker)
end

local function wispOf(c, body)
    for _, u in ipairs(c.units) do if u.alive and u.wispOf == body then return u end end
end

local function place(c, u, x, y)
    assert(Combat.teleportUnit(c, u, x, y), string.format("could not place %s at %d,%d", u.char.id, x, y))
end

return {
    {
        name = "the pass's new pieces are natural kit, carried by the bodies they belong to",
        fn = function()
            local OWNERS = {
                ["utility_sworn_retainer"] = { "character_elf_retainer" },
                ["utility_wounded_pride"] = { "character_elf_longbow", "character_elf_bladedancer",
                                          "character_elf_highborn", "character_elf_starcaller" },
                ["utility_wisp_carrier"] = { "character_lesser_archon" },
                ["weapon_gilded_hook"] = { "character_gilded_page" },
            }
            local Item = require("models.item")
            for id, owners in pairs(OWNERS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal and not def.price, id .. " is natural kit")
                for _, owner in ipairs(owners) do
                    assert(Fixture.itemNamed(Character.instantiate(owner), id), owner .. " carries " .. id)
                end
            end
        end,
    },
    -- ------------------------------------------------------------------------------ the Elf Retainer
    {
        name = "the Retainer's Oath: a blow meant for an Unblemished elf beside it lands on the retainer",
        fn = function()
            local c = Fixture.combat(board(), hero(5, 9), {
                unit("character_elf_longbow", 5, 5, { stats = { health = 100 } }),
                unit("character_elf_retainer", 5, 6, { stats = { health = 100 } }),
            })
            local h, bow, ret = party(c), one(c, "character_elf_longbow"), one(c, "character_elf_retainer")
            assert(Status.has(bow, "status_unblemished"), "the longbow opens Unblemished")
            assert(Status.has(bow, "status_retained"), "and wears Retained: a retainer stands sworn beside it")
            assert(not Status.has(ret, "status_retained"), "a retainer is nobody's charge")
            local bowHp, retHp = hp(bow), hp(ret)
            blow(c, bow, 20, h)
            assert(hp(bow) == bowHp, "the blow never reached the longbow")
            assert(Status.has(bow, "status_unblemished"), "so it is still Unblemished")
            assert(hp(ret) < retHp, "the retainer took it")
            assert(not Status.has(ret, "status_unblemished"), "and the retainer is the one marked")
            -- Every blow, not the first each turn: the oath has no cooldown.
            blow(c, bow, 20, h)
            assert(hp(bow) == bowHp, "the second blow is taken too")
        end,
    },
    {
        name = "the Retainer's Oath: break the retainer and the next blow marks the elf",
        fn = function()
            local c = Fixture.combat(board(), hero(5, 9), {
                unit("character_elf_longbow", 5, 5, { stats = { health = 100 } }),
                unit("character_elf_retainer", 5, 6, { stats = { health = 30 } }),
            })
            local h, bow, ret = party(c), one(c, "character_elf_longbow"), one(c, "character_elf_retainer")
            fell(c, ret, h)
            assert(not ret.alive, "the retainer is down")
            assert(not Status.has(bow, "status_retained"), "the badge goes with it")
            local before = hp(bow)
            blow(c, bow, 20, h)
            assert(hp(bow) < before, "the blow lands on the elf now")
            assert(not Status.has(bow, "status_unblemished"), "and marks it")
        end,
    },
    {
        name = "the Retainer's Oath holds only while its charge is Unblemished, and never for another retainer",
        fn = function()
            local c = Fixture.combat(board(), hero(5, 9), {
                unit("character_elf_longbow", 5, 5, { stats = { health = 100 } }),
                unit("character_elf_retainer", 5, 6, { stats = { health = 100 } }),
                unit("character_elf_retainer", 6, 6, { stats = { health = 100 } }),
            })
            local h, bow = party(c), one(c, "character_elf_longbow")
            local r1, r2 = one(c, "character_elf_retainer", 1), one(c, "character_elf_retainer", 2)
            -- r2 stands beside r1 but not beside the longbow: it swears to nobody.
            assert(r2.guard == nil or r2.guard.ward ~= r1, "a retainer is never another retainer's charge")
            local r1Hp = hp(r1)
            blow(c, r1, 10, h)
            assert(hp(r1) < r1Hp, "a blow on a retainer is its own")
            -- Mark the longbow by other means (the oath lapses the instant it is marked, read live).
            Status.remove(c, bow, "status_unblemished")
            local bowHp = hp(bow)
            blow(c, bow, 20, h)
            assert(hp(bow) < bowHp, "a marked elf has nothing left to protect, and the retainer lets the blow through")
            Trait.onAnyTurnStart(c, h)
            assert(not Status.has(bow, "status_retained"), "and the badge lifts at the next turn's edge")
        end,
    },
    -- ------------------------------------------------------------------------------ the elf court: Wounded Pride
    {
        name = "Wounded Pride: the blow that marks a court elf Taunts it onto the striker, and it walks at them",
        fn = function()
            local c = Fixture.combat(board(), { hero(5, 9), hero(1, 5) }, {
                unit("character_elf_highborn", 5, 5, { stats = { health = 200 } }),
            })
            local striker, other, elf = party(c, 1), party(c, 2), one(c, "character_elf_highborn")
            assert(Status.has(elf, "status_unblemished"), "it opens Unblemished")
            blow(c, elf, 10, striker)
            assert(not Status.has(elf, "status_unblemished"), "the blow marked it")
            local taunt = Status.get(elf, "status_taunt")
            assert(taunt and taunt.taunter == striker, "and it is Taunted onto whoever marked it")
            -- A second blow from somebody else marks nothing (already marked), so the grudge stays where it was.
            blow(c, elf, 10, other)
            assert(Status.get(elf, "status_taunt").taunter == striker, "the grudge is the first striker's")
            -- And the compulsion is real: its turn goes at the striker, though the other body is nearer.
            place(c, other, 5, 4)
            openTurn(c, elf)
            local plan = AI.plan(c, elf)
            assert(plan and plan.reason == "taunted", "its turn is the grudge's: " .. tostring(plan and plan.reason))
        end,
    },
    {
        name = "Wounded Pride: a blow with no striker marks the elf and compels nothing; a retainer carries no grudge",
        fn = function()
            local c = Fixture.combat(board(), hero(5, 9), {
                unit("character_elf_bladedancer", 5, 5, { stats = { health = 200 } }),
                unit("character_elf_retainer", 9, 9, { stats = { health = 200 } }),
            })
            local h, elf, ret = party(c), one(c, "character_elf_bladedancer"), one(c, "character_elf_retainer")
            blow(c, elf, 10, nil)
            assert(not Status.has(elf, "status_unblemished"), "a burn marks it like any wound")
            assert(not Status.has(elf, "status_taunt"), "but there is nobody to answer")
            blow(c, ret, 10, h)
            assert(not Status.has(ret, "status_taunt"), "the retainer serves; it does not take offence")
        end,
    },
    -- ------------------------------------------------------------------------------ the Lesser Archon
    {
        name = "Wisp-Carrier: a wisp nearer a Lesser Archon than its body goes to it, and the body stands at once",
        fn = function()
            local c = Fixture.combat(board(), hero(1, 12), {
                unit("character_lesser_archon", 9, 3, { stats = { health = 60 } }),
                unit("character_lesser_archon", 3, 9, { stats = { health = 60 } }),
            })
            local h = party(c)
            local carrier = one(c, "character_lesser_archon", 1)
            local body = one(c, "character_lesser_archon", 2)
            fell(c, body, h)
            local w = wispOf(c, body)
            assert(w, "a wisp is thrown")
            place(c, w, 8, 5) -- within 3 of the carrier, six from its own body
            Trait.onAnyTurnStart(c, h)
            assert(Spirit.goal(c, w) == carrier, "the wisp turns toward the carrier, not home")
            -- The walk is real: the planner moves it toward the carrier.
            local act = AI.plan(c, w)
            assert(act and act.move, "the wisp moves")
            assert(math.abs(act.move.x - carrier.x) + math.abs(act.move.y - carrier.y) < Combat.unitGap(w, carrier)
                or Combat.unitGap(w, carrier) <= 1, "toward the carrier")
            place(c, w, 9, 4)
            Spirit.tryArrive(c, w)
            assert(not w.alive, "the wisp is spent")
            assert(body.alive and hp(body) > 0, "and its body, six tiles off, stands at once")
            assert(hp(body) <= body.char.stats.health.max * Spirit.RAISE_AT + 1, "at the race's raise share, not full")
        end,
    },
    {
        name = "Wisp-Carrier: a wisp nearer its own body walks home, and a body under a company boot stays down",
        fn = function()
            local c = Fixture.combat(board(), { hero(1, 12), hero(12, 12) }, {
                unit("character_lesser_archon", 10, 2, { stats = { health = 60 } }),
                unit("character_lesser_archon", 3, 9, { stats = { health = 60 } }),
            })
            local h, h2 = party(c, 1), party(c, 2)
            local carrier = one(c, "character_lesser_archon", 1)
            local body = one(c, "character_lesser_archon", 2)
            fell(c, body, h)
            local w = wispOf(c, body)
            place(c, w, 4, 7) -- two from home, far from the carrier
            Trait.onAnyTurnStart(c, h)
            assert(Spirit.goal(c, w) == body, "nearer home than the carrier: it walks home")
            -- Now called by the carrier, but a company body stands on the fallen one.
            w.wispGoal = nil
            place(c, w, 9, 3)
            place(c, h2, body.x, body.y)
            Trait.onAnyTurnStart(c, h)
            assert(Spirit.goal(c, w) == carrier, "called by the carrier")
            Spirit.tryArrive(c, w)
            assert(not body.alive, "a body somebody stands on cannot be stood up -- the race's own counter holds")
        end,
    },
    {
        name = "Wisp-Carrier yields to a Duke: a wisp in the Duke's reach is the Duke's",
        fn = function()
            local c = Fixture.combat(board(), hero(1, 12), {
                unit("character_archon_duke", 6, 6),
                unit("character_lesser_archon", 8, 6, { stats = { health = 60 } }),
                unit("character_lesser_archon", 11, 11, { stats = { health = 60 } }),
            })
            local h, duke = party(c), one(c, "character_archon_duke")
            local carrier = one(c, "character_lesser_archon", 1)
            local body = one(c, "character_lesser_archon", 2)
            fell(c, body, h)
            local w = wispOf(c, body)
            -- First called by the carrier, out of the Duke's reach...
            place(c, w, 10, 4)
            w.wispGoal = carrier
            -- ...then it comes within 3 of the Duke (and still beside the carrier): it is handed over.
            place(c, w, 8, 5)
            Trait.onAnyTurnStart(c, h)
            assert(Spirit.goal(c, w) == duke, "the Duke takes precedence over the carrier")
        end,
    },
    -- ------------------------------------------------------------------------------ the gilded page and sworn
    {
        name = "the Gilded Page fetches: its hook drags a foe within 2 in beside it",
        fn = function()
            local c = Fixture.combat(board(), hero(5, 8), { unit("character_gilded_page", 5, 6) })
            local h, page = party(c), one(c, "character_gilded_page")
            local before = hp(h)
            local ok = Fixture.strike(c, page, h, "weapon_gilded_hook")
            assert(ok, "the hook reaches 2")
            assert(hp(h) < before, "it wounds")
            assert(h.x == 5 and h.y == 7, "and drags the foe in beside the page: " .. h.x .. "," .. h.y)
        end,
    },
    {
        name = "the Page and the Sworn are two roles: different weapons, and a hammer is the page's answer, a spear the sworn's",
        fn = function()
            local page, sworn = Character.defs.character_gilded_page, Character.defs.character_gilded_sworn
            assert(page.defaultAction ~= sworn.defaultAction, "different weapons")
            local c = Fixture.combat(board(), hero(1, 1), {
                unit("character_gilded_page", 5, 5), unit("character_gilded_sworn", 9, 9),
            })
            local p, s = one(c, "character_gilded_page"), one(c, "character_gilded_sworn")
            local function take(u, tag) return Combat.mitigatedDamage(u, 40, { tag, "physical" }) end
            assert(take(p, "impact") > take(p, "pierce"), "a hammer stoves a page in; a point is no better than it ever was")
            assert(take(s, "pierce") > take(s, "impact"), "a point through the gap is still the sworn's answer")
        end,
    },
    -- ------------------------------------------------------------------------------ Pride's hides
    {
        name = "Pride's floors no longer all ask for a spear: the heavy bodies want four different answers",
        fn = function()
            local c = Fixture.combat(board(), hero(1, 1), {
                unit("character_gilded_sworn", 3, 3), unit("character_gilded_page", 5, 3),
                unit("character_standard_bearer", 7, 3), unit("character_lion", 3, 7),
                unit("character_titan", 7, 7),
            })
            local TAGS = { "slash", "pierce", "impact", "lightning" }
            local answers = {}
            for _, id in ipairs({ "character_gilded_sworn", "character_gilded_page", "character_standard_bearer",
                                  "character_lion", "character_titan" }) do
                local u = one(c, id)
                local best, bestN
                for _, tag in ipairs(TAGS) do
                    local n = Combat.mitigatedDamage(u, 40, { tag, tag == "lightning" and "magical" or "physical" })
                    if not bestN or n > bestN then best, bestN = tag, n end
                end
                answers[best] = (answers[best] or 0) + 1
            end
            local kinds = 0
            for _ in pairs(answers) do kinds = kinds + 1 end
            assert(kinds >= 3, "at least three different best answers across the five")
            assert((answers.pierce or 0) <= 1, "and the spear is the best answer to one of them at most here")
        end,
    },
    -- ------------------------------------------------------------------------------ the Pit Locust
    {
        name = "Seek Death on the swarm: one locust Torments nobody, a second beside the same body Torments",
        fn = function()
            local c = Fixture.combat(board(), hero(5, 6), {
                unit("character_pit_locust", 5, 5, { stats = { damage = 40 } }),
                unit("character_pit_locust", 10, 10),
            })
            local h = party(c)
            local a, b = one(c, "character_pit_locust", 1), one(c, "character_pit_locust", 2)
            h.char.stats.health.current = 30
            for _ = 1, 3 do Fixture.strike(c, a, h, "weapon_pit_locust_sting") end
            assert(h.alive and hp(h) == 1, "held at 1")
            assert(not Status.has(h, "status_torment"), "alone it Torments nothing -- the health bar is not the key")
            place(c, b, 4, 6)
            Fixture.strike(c, a, h, "weapon_pit_locust_sting")
            assert(Status.stacksOf(h, "status_torment") == 1, "with a second locust beside the body, Torment")
        end,
    },
    -- ------------------------------------------------------------------------------ targeting
    {
        name = "the Reaper walks to the body under its line rather than the nearest",
        fn = function()
            local c = Fixture.combat(board(), { hero(5, 7), hero(9, 5) }, { unit("character_reaper", 5, 5) })
            local near, wounded, reaper = party(c, 1), party(c, 2), one(c, "character_reaper")
            wounded.char.stats.health.current = 20 -- a tenth of 200: under the quarter line
            openTurn(c, reaper)
            local plan = AI.plan(c, reaper)
            assert(plan, "it acts")
            local dest = plan.move or { x = reaper.x, y = reaper.y }
            local dWounded = math.abs(dest.x - wounded.x) + math.abs(dest.y - wounded.y)
            assert(dWounded <= 2, "it ends beside the body under the line: " .. dest.x .. "," .. dest.y
                .. " (near body at " .. near.x .. "," .. near.y .. ")")
        end,
    },
    {
        name = "the Erinys aims at a caster winding up before the nearest body",
        fn = function()
            local c = Fixture.combat(board(), { hero(5, 7), hero(5, 11) }, { unit("character_erinys", 5, 5) })
            local near, caster, fury = party(c, 1), party(c, 2), one(c, "character_erinys")
            Status.apply(c, caster, "status_channeling", {})
            caster.channel = caster.channel or { turns = 1 }
            openTurn(c, fury)
            local plan = AI.plan(c, fury)
            assert(plan and plan.target == caster, "the caster is the crime she answers, not "
                .. tostring(plan and plan.target and plan.target.char.id))
            caster.channel = nil
        end,
    },
}
