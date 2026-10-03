-- Tests for THE FACELESS OF ENVY'S SEAT, PART TWO (2026-10-03, "Envy's Bestiary", rounds 1-3; slice B): the
-- Faceless who choose a face some other way than Reshape, the pool they come out of, their fights and their drops.
--
--   the Doppelganger    at the opening bell, an exact copy of the nearest of the company -- stats, grid, tactics --
--                       kept until it dies
--   the Mirror-Knight   Mirrored at the top of each of its turns; the first single-target attack a round rebounds,
--                       then the mirror is down until its next turn
--   the Colossus        2x2, two faces at once: the one Reshape picks, and the runner-up's kit beside it
--   the Mask-Maker      hands every Faceless within 3 a face from its hand, all different: shield, healer,
--                       archer, caster; its death hands them back to Reshape
--   the Water Mirror    copies every body in the company; untouchable while a copy stands; a copy takes nothing
--                       from its own original and goes for it first (the Frieren test). The Second Self stays.
-- Each case pins a rule on a bare, seeded board.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Transform = require("models.transform")
local AI = require("models.ai")
local Faces = require("models.faces")
local Masks = require("models.masks")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = {
    character_doppelganger = "ability_doppel_step",
    character_mirror_knight = "armor_polished_shield",
    character_faceless_colossus = "armor_twofold_hauberk",
    character_mask_maker = "ability_faceless_retinue",
    character_the_water_mirror = "ability_still_water",
}
local SHELF = {
    ability_doppel_step = { "ninja", "ability" },
    armor_polished_shield = { "sentinel", "armor" },
    armor_twofold_hauberk = { "bulwark", "armor" },
    ability_faceless_retinue = { "summoner", "ability" },
    ability_still_water = { "summoner", "ability" },
}
local ORGANS = {
    "utility_exact_copy", "utility_mirrored", "utility_two_faces", "utility_mask_makers_hand", "utility_still_pool",
}
local FIGHTS = {
    encounter_envy_the_water_mirror = "elite",
    encounter_envy_the_masked_company = "combat",
    encounter_envy_two_faces = "combat",
}

local function board() return Fixture.new(11, 11, { seed = 11 }) end

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 300, health or 300
    return spawn
end

local function one(c, id)
    for _, u in ipairs(c.units) do
        if u.char and Faces.originalChar(u).id == id then return u end
    end
end

local function side(c, s)
    local out = {}
    for _, u in ipairs(c.units) do if u.side == s then out[#out + 1] = u end end
    return out
end

local function ids(char)
    local out = {}
    for _, item in ipairs(Character.eachItem(char)) do out[#out + 1] = item.id end
    table.sort(out)
    return table.concat(out, ",")
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the five are tier-3 Faceless, each with its trophy on a real shelf and its organ bound",
        fn = function()
            for id, drop in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def and def.race == Faces.RACE and def.tier == 3, id .. " is a tier-3 Faceless")
                local dropped = false
                for _, d in ipairs(def.drops or {}) do if d == drop then dropped = true end end
                assert(dropped, id .. " drops " .. drop)
                local item = Item.defs[drop]
                assert(item and item.unstocked, drop .. " is a trophy: seen on the rack, never sold")
                assert(item.class == SHELF[drop][1] and item.type == SHELF[drop][2],
                    drop .. " sits on the " .. SHELF[drop][1] .. " shelf as a " .. SHELF[drop][2])
                assert(item.unlockLevel == 12, drop .. " is a seat find (floor 12)")
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.bound and def.noSteal, id .. " is an organ")
            end
            assert(Character.defs.character_faceless_colossus.footprint.w == 2, "the Colossus is a heap, 2x2")
            assert(Character.defs.character_the_water_mirror.boss, "the pool is the fight")
        end,
    },
    {
        name = "the Water Mirror is the seat's elite, the two fights stand on the seat, and the Second Self stays",
        fn = function()
            for id, kind in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e and e.kind == kind, id .. " is " .. kind)
                assert(e.rung == 2, id .. " stands on the seat (rung 2)")
                assert(e.condition({ biome = "desert" }) and not e.condition({ biome = "cave" }), id .. " is Envy's")
            end
            local seen = {}
            -- Across the band's rolls on the seat's floor: the Mirror-Knight is a rolled body, not a fixed one.
            local Arena = require("models.arena")
            for id in pairs(FIGHTS) do
                for seed = 1, 40 do
                    local ctx = { biome = "desert", depth = 12, seed = seed }
                    for _, body in ipairs(Arena.resolveComposition(Encounter.get(id).composition, ctx)) do
                        seen[body] = true
                    end
                end
            end
            for id in pairs(BODIES) do assert(seen[id], id .. " is fielded by one of the fights") end
            local second = Encounter.get("encounter_envy_second_self")
            assert(second and second.kind == "elite" and second.rung == 2, "the Second Self is not retired")
        end,
    },
    -- ------------------------------------------------------------------------------ the Doppelganger
    {
        name = "the Doppelganger opens as an exact copy of the nearest of the company, tactics included, and keeps it",
        fn = function()
            local near = walker(5, 6)
            near.char.name, near.char.archetype = "Near One", "support"
            near.char.aiRules = { { priority = "high", act = "wait" } }
            local far = unit("character_knight", 5, 10, { isolate = "mechanics" })
            local c = Fixture.combat(board(), { near, far }, { unit("character_doppelganger", 5, 5) })
            local d = one(c, "character_doppelganger")
            local n = c.units[1]
            assert(d.char.name == "Near One", "it is the nearest body: " .. tostring(d.char.name))
            assert(d.faceLocked and d.copyOf == n, "and it is locked into that copy")
            assert(d.char.archetype == "support" and d.char.aiRules == n.char.aiRules, "with the tactics it fights by")
            assert(d.char.stats.damage == n.char.stats.damage, "and its stats")
            local mine, theirs = {}, {}
            for _, item in ipairs(Character.eachItem(n.char)) do theirs[#theirs + 1] = item.id end
            for _, item in ipairs(Character.eachItem(d.char)) do mine[item.id] = true end
            for _, id in ipairs(theirs) do assert(mine[id], "it carries the copy's " .. id) end
            assert(d.char.stats.health == Faces.originalChar(d).stats.health, "its own health pool, never a second bar")
            Status.onTurnStart(c, d)
            assert(d.char.name == "Near One", "no read takes the copy off at the top of a turn")
        end,
    },
    {
        name = "Doppel-Step wears an exact copy of any body until the end of the next turn, on the bearer's own pool",
        fn = function()
            local user = unit("character_archer", 4, 4, { isolate = "bare", items = { "ability_doppel_step" },
                stats = { stamina = 40 } })
            local foe = unit("character_knight", 4, 6, { isolate = "mechanics" })
            local c = Fixture.combat(board(), user, foe)
            local u, f = c.units[1], c.units[2]
            local pool = u.char.stats.health
            local ok = Fixture.strike(c, u, f, "ability_doppel_step")
            assert(ok, "it casts")
            assert(u.char.id == f.char.id and Transform.isTransformed(u), "the bearer wears the foe's body")
            assert(u.char.stats.health == pool, "on its own health")
            assert(Status.has(u, "status_doppel_step"), "the badge owns the shape")
            assert(Item.defs.ability_doppel_step.activeAbility.cooldown, "on a cooldown, not once a fight")
            -- Counted in turn-ends: the cast's own turn may already have closed (useItem ends a spent turn), so
            -- end turns until it lets go and count them all.
            local badge = Status.get(u, "status_doppel_step")
            local ends = badge.ends or 0
            assert(ends <= 1, "the shape outlives the turn it was cast in")
            while Transform.isTransformed(u) and ends < 5 do
                Status.onTurnEnd(c, u)
                ends = ends + 1
            end
            assert(ends == 2, "it ends with the end of the next turn, not later: " .. ends)
            assert(u.char.id == "character_archer", "and the bearer is itself again")
        end,
    },
    -- ------------------------------------------------------------------------------ the Mirror-Knight
    {
        name = "the Mirror-Knight is Mirrored: the first single-target blow a round rebounds, then the mirror is down",
        fn = function()
            -- A dagger, which answers nothing: a sword would parry its own rebound and muddy the count.
            local attacker = unit("character_archer", 5, 6, { isolate = "bare", items = { "weapon_iron_dagger" },
                stats = { health = 300, stamina = 99 } })
            local c = Fixture.combat(board(), attacker, { unit("character_mirror_knight", 5, 5) })
            local a, k = c.units[1], one(c, "character_mirror_knight")
            -- Its own body, so the rule is measured rather than whatever face the hand dealt.
            Transform.revert(c, k)
            k.faceLocked = true
            Trait.attach(k, c)
            Trait.onAnyTurnStart(c, k)
            assert(Status.has(k, "status_reflect_physical") and Status.has(k, "status_reflect_magic"),
                "it starts its turn wearing both mirrors")
            local kBefore, aBefore = hp(k), hp(a)
            Fixture.strike(c, a, k, "weapon_iron_dagger")
            assert(hp(k) == kBefore and hp(a) < aBefore, "the first blow rebounds onto the attacker")
            assert(not Status.has(k, "status_reflect_physical") and not Status.has(k, "status_reflect_magic"),
                "and the mirror is down")
            Fixture.strike(c, a, k, "weapon_iron_dagger")
            assert(hp(k) < kBefore, "so the second blow of the round lands")
            assert(Status.has(a, "status_rattled"), "and the Polished Shield Rattles a melee attacker")
            Trait.onAnyTurnStart(c, k)
            assert(Status.has(k, "status_reflect_physical"), "its next turn puts the mirror back up")
        end,
    },
    {
        name = "the mirror rides every face the Mirror-Knight Reshapes into",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 7), { unit("character_mirror_knight", 5, 5) })
            local k = one(c, "character_mirror_knight")
            assert(Transform.isTransformed(k), "it Reshapes like any Faceless")
            assert(itemNamed(k.char, "utility_mirrored"), "and its mirror goes with it")
            assert(Status.has(k, "status_reflect_physical"), "worn from the opening bell")
        end,
    },
    {
        name = "the Polished Shield Rattles a melee attacker and nothing that shoots",
        fn = function()
            local bearer = unit("character_archer", 5, 5, { isolate = "bare", items = { "armor_polished_shield" },
                stats = { health = 300 } })
            local sword = unit("character_archer", 5, 6, { isolate = "bare", items = { "weapon_iron_sword" } })
            local bow = unit("character_archer", 5, 9, { isolate = "bare", items = { "weapon_iron_bow" } })
            local c = Fixture.combat(board(), bearer, { sword, bow })
            local b, s, w = c.units[1], c.units[2], c.units[3]
            Fixture.strike(c, w, b, "weapon_iron_bow")
            assert(not Status.has(w, "status_rattled"), "an arrow never touched the shield")
            Fixture.strike(c, s, b, "weapon_iron_sword")
            assert(Status.has(s, "status_rattled"), "a sword did")
        end,
    },
    -- ------------------------------------------------------------------------------ the Colossus
    {
        name = "the Colossus wears two faces at once, and keeps its four tiles under both",
        fn = function()
            local c = Fixture.combat(board(), walker(4, 8), { unit("character_faceless_colossus", 4, 4) })
            local col = one(c, "character_faceless_colossus")
            assert(#col.faceHand == 4, "a hand of four, so there is a runner-up")
            assert(Transform.isTransformed(col) and col.char.id == col.faceWorn, "the first face is its body")
            assert(col.secondFace and col.secondFace ~= col.faceWorn, "and it holds a second face")
            local lent = 0
            for _, item in ipairs(Character.eachItem(col.char)) do if item.lentByFace then lent = lent + 1 end end
            assert(lent > 0 or not Character.firstEmptySlot(col.char), "the second face's kit is in its hands")
            assert(itemNamed(col.char, "utility_two_faces"), "Two Faces rides into the shape")
            assert(col.w == 2 and col.h == 2 and col.char.footprint.w == 2, "a heap of four tiles under any face")
            -- A fresh face at the top of a turn: the old loan goes, the new one comes.
            local other
            for _, id in ipairs(col.faceHand) do if id ~= col.faceWorn then other = id; break end end
            Faces.wear(c, col, other)
            Trait.onAnyTurnStart(c, col)
            assert(col.secondFace ~= col.faceWorn, "the runner-up is read again for the new face")
            for _, item in ipairs(Character.eachItem(col.char)) do
                if item.lentByFace then
                    local held = false
                    for _, it in ipairs(Character.eachItem(Character.instantiate(col.secondFace))) do
                        if it.id == item.id then held = true end
                    end
                    assert(held, item.id .. " is the new second face's, not a leftover")
                end
            end
        end,
    },
    {
        name = "the Twofold Hauberk counts the foes within 2 at the top of the turn, +3 defense each, up to 2",
        fn = function()
            local bearer = unit("character_archer", 5, 5, { isolate = "bare", items = { "armor_twofold_hauberk" } })
            local c = Fixture.combat(board(), bearer, {
                unit("character_archer", 5, 6, { isolate = "bare" }),
                unit("character_archer", 6, 5, { isolate = "bare" }),
                unit("character_archer", 4, 5, { isolate = "bare" }),
                unit("character_archer", 5, 10, { isolate = "bare" }),
            })
            local b = c.units[1]
            local before = Combat.flatStat(b, "defense")
            Trait.onAnyTurnStart(c, b)
            assert(Combat.flatStat(b, "defense") == before + 6, "three foes within 2 count as two: +6")
            for i = 2, 4 do c.units[i].alive = false end
            Trait.onAnyTurnStart(c, b)
            assert(Combat.flatStat(b, "defense") == before, "none within 2: nothing")
        end,
    },
    -- ------------------------------------------------------------------------------ the Mask-Maker
    {
        name = "the Mask-Maker's hand is a company: a shield, a healer, an archer and a caster",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1), { unit("character_mask_maker", 5, 5) })
            local m = one(c, "character_mask_maker")
            assert(table.concat(m.maskRoles, ",") == "shield,healer,archer,caster", "one face for each place")
            local seen = {}
            for i, id in ipairs(m.faceHand) do
                assert(not seen[id], "all different")
                seen[id] = true
                assert(Masks.roleOf(id) == m.maskRoles[i], id .. " is read as a " .. m.maskRoles[i])
                assert(Faces.isEligible(id), id .. " is a face the race may wear")
            end
        end,
    },
    {
        name = "the Mask-Maker masks every Faceless within 3, all different, and its death hands them back to Reshape",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1), {
                unit("character_mask_maker", 5, 5),
                unit("character_mirror_knight", 5, 6), unit("character_mirror_knight", 6, 5),
                unit("character_mirror_knight", 4, 5), unit("character_mirror_knight", 5, 9),
            })
            local m = one(c, "character_mask_maker")
            local masked, faces = 0, {}
            for _, u in ipairs(side(c, "enemy")) do
                if u ~= m then
                    if Combat.unitGap(m, u) <= 3 then
                        assert(u.faceLocked and u.maskedBy == m, "a Faceless within 3 wears what it is handed")
                        assert(u.faceWorn == m.faceHand[masked + 1] or faces[u.faceWorn] == nil, "a face from its hand")
                        assert(not faces[u.faceWorn], "no two the same")
                        faces[u.faceWorn] = true
                        assert(Masks.roleOf(u.faceWorn) == u.maskRole, "the face is the place it was handed")
                        masked = masked + 1
                    else
                        assert(not u.faceLocked, "one out of reach reads for itself")
                    end
                end
            end
            assert(masked == 3, "three in reach, three masks")
            -- A masked body skips the read at the top of its own turn.
            local held
            for _, u in ipairs(side(c, "enemy")) do if u.maskedBy == m then held = u end end
            local face = held.faceWorn
            Status.onTurnStart(c, held)
            assert(held.faceWorn == face, "Reshape stands aside while the mask is on")
            Transform.revert(c, m)
            m.faceLocked = true
            Combat.dealFlatDamage(c, m, 99999, { "physical" }, "test", c.units[1], { raw = true })
            assert(not m.alive, "the Mask-Maker falls")
            for _, u in ipairs(side(c, "enemy")) do
                if u ~= m then assert(not u.faceLocked and u.maskedBy == nil, "and every mask comes off") end
            end
        end,
    },
    {
        name = "the Mask-Maker never masks over a Doppelganger's copy",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 8), {
                unit("character_mask_maker", 5, 5), unit("character_doppelganger", 5, 6),
            })
            local m, d = one(c, "character_mask_maker"), one(c, "character_doppelganger")
            assert(d.faceLocked and d.maskedBy == nil, "the copy is the Doppelganger's own lock")
            Masks.handOut(c, m)
            assert(d.maskedBy == nil and d.copyOf, "and the Mask-Maker leaves it be")
        end,
    },
    {
        name = "Faceless Retinue summons the line soldier wearing a foe's face, and nothing without the soldier",
        fn = function()
            -- The line soldier (character_faceless) is built on its own branch. Where this tree lacks it, the cast
            -- must summon nothing; and the rule is still measured, on a Faceless stood in under the soldier's id.
            local real = Character.defs.character_faceless
            local function cast()
                local user = unit("character_archer", 4, 4, { isolate = "bare", items = { "ability_faceless_retinue" },
                    stats = { mana = 100 } })
                local foe = unit("character_knight", 4, 7, { isolate = "mechanics" })
                local c = Fixture.combat(board(), user, foe)
                local u, f = c.units[1], c.units[2]
                local before = #c.units
                openTurn(c, u)
                Combat.useItem(c, u, itemNamed(u.char, "ability_faceless_retinue"), 4, 5)
                return c, u, f, before
            end
            if not real then
                local c, _, _, before = cast()
                assert(#c.units == before, "no line soldier in this tree: nothing is summoned")
                Character.defs.character_faceless = Character.defs.character_mirror_knight
            end
            local ok, err = pcall(function()
                local c, u, f = cast()
                local s = c.units[#c.units]
                assert(s.summoner == u and s.side == u.side, "a soldier of yours")
                assert(s.faceLocked and s.char.id == f.char.id, "wearing the face of the foe in sight")
                assert(s.char.stats.health == Faces.originalChar(s).stats.health, "on the soldier's own health")
            end)
            Character.defs.character_faceless = real
            assert(ok, err)
        end,
    },
    -- ------------------------------------------------------------------------------ the Water Mirror
    {
        name = "the Water Mirror copies every body in the company, and cannot be hurt while a copy stands",
        fn = function()
            local a, b = walker(3, 6), walker(9, 6)
            a.char.name, b.char.name = "Left", "Right"
            local c = Fixture.combat(board(), { a, b }, { unit("character_the_water_mirror", 6, 6) })
            local pa, pb = c.units[1], c.units[2]
            local pool = one(c, "character_the_water_mirror")
            assert(not Transform.isTransformed(pool), "a pool wears no face: it makes them")
            assert(Combat.moveBudget(pool) == 0 and Trait.flag(pool, "unmoved"), "and it never moves")
            assert(#pool.mirrorCopies == 2, "one copy for every body in the company")
            local copyA, copyB
            for _, cp in ipairs(pool.mirrorCopies) do
                assert(cp.side == pool.side and cp.summoned, "the copies fight for the pool")
                assert(ids(cp.char) == ids(cp.mirrorOf.char), "with the original's items")
                assert(cp.char.stats.damage == cp.mirrorOf.char.stats.damage, "and its stats")
                if cp.mirrorOf == pa then copyA = cp else copyB = cp end
            end
            assert(copyA and copyB, "each copy knows its original")
            local before = hp(pool)
            Combat.dealFlatDamage(c, pool, 30, { "physical" }, "test", pa)
            assert(hp(pool) == before, "the pool takes nothing while a copy stands")
            before = hp(copyA)
            Combat.dealFlatDamage(c, copyA, 30, { "physical" }, "test", pa)
            assert(hp(copyA) == before, "a copy takes nothing from its own original")
            Combat.dealFlatDamage(c, copyA, 30, { "physical" }, "test", pb)
            assert(hp(copyA) < before, "and everything from a friend")
            Combat.dealFlatDamage(c, copyA, 99999, { "physical" }, "test", pb, { raw = true })
            Combat.dealFlatDamage(c, copyB, 99999, { "physical" }, "test", pa, { raw = true })
            assert(not copyA.alive and not copyB.alive, "swap opponents and the copies fall")
            before = hp(pool)
            Combat.dealFlatDamage(c, pool, 30, { "physical" }, "test", pa)
            assert(hp(pool) < before, "then the pool can be struck")
        end,
    },
    {
        name = "a Water Mirror copy goes for its own original first",
        fn = function()
            local a, b = walker(3, 6), walker(9, 6)
            local c = Fixture.combat(board(), { a, b }, { unit("character_the_water_mirror", 6, 6) })
            local pool = one(c, "character_the_water_mirror")
            for _, cp in ipairs(pool.mirrorCopies) do
                openTurn(c, cp)
                local plan = AI.plan(c, cp)
                assert(plan and plan.reason == "its original", "a copy's turn goes to its original: "
                    .. tostring(plan and plan.reason))
            end
        end,
    },
    {
        name = "Still Water makes a fragile copy of your body nearest the named foe, and that foe cannot touch it",
        fn = function()
            local user = unit("character_archer", 4, 4, { isolate = "bare", items = { "ability_still_water" },
                stats = { mana = 100 } })
            local ally = unit("character_knight", 5, 5, { isolate = "mechanics", stats = { health = 200 } })
            local named = unit("character_archer", 5, 6, { isolate = "bare", items = { "weapon_iron_sword" } })
            local other = unit("character_archer", 7, 7, { isolate = "bare", items = { "weapon_iron_bow" } })
            local c = Fixture.combat(board(), { user, ally }, { named, other })
            local u, al, n, o = c.units[1], c.units[2], c.units[3], c.units[4]
            local ok = Fixture.strike(c, u, n, "ability_still_water")
            assert(ok, "it casts at the foe it names")
            local copy = c.units[#c.units]
            assert(copy ~= o and copy.side == u.side and copy.fragile, "a fragile copy of yours")
            assert(copy.char.id == al.char.id, "of the body standing nearest the named foe")
            assert(copy.knows == n and copy.summonRemaining, "it knows the named foe, for 2 turns")
            Combat.dealFlatDamage(c, copy, 20, { "physical" }, "test", n)
            assert(copy.alive, "nothing the named foe throws lands")
            Combat.dealFlatDamage(c, copy, 1, { "physical" }, "test", o)
            assert(not copy.alive, "anything else unmakes it")
        end,
    },
}
