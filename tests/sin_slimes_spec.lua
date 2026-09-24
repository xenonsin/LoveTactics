-- Tests for the last four slime lines -- Wrath's Boil Over, Sloth's three (Torpid, Numbed, Drift), Envy's
-- Mimicry + Begrudge, Pride's Rank -- their Kings' splits, and the drops that touch the engine. Each
-- circle's slime carries ONE rule of its own (the per-circle slime law); what is under test is that each
-- rule does what its card says on a real board.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Encounter = require("models.encounter")
local Descent = require("models.descent")

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

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end
local function wearing(id, items, x, y)
    local c = Character.instantiate(id)
    for _, it in ipairs(items) do Character.addItem(c, Item.instantiate(it)) end
    return { char = c, x = x, y = y }
end
local function itemNamed(char, id)
    for _, it in ipairs(Character.eachItem(char)) do if it.id == id then return it end end
end
local function living(c, id)
    local out = {}
    for _, u in ipairs(c.units) do if u.alive and u.char.id == id then out[#out + 1] = u end end
    return out
end
local function spell(el) return { "spell", el, "magical" } end

local RELICS = {
    "utility_cinder_body", "utility_caldera_heart", "utility_rime_body", "utility_frost_body",
    "utility_snowdrift_body", "utility_glacier_heart", "utility_mimic_body", "utility_many_faces",
    "utility_crystal_body", "utility_apex_facet",
}
local DROPS = {
    character_cinder_slime = { "utility_seething_core" },
    character_caldera_king = { "armor_caldera_plate", "utility_flashpoint" },
    character_rime_slime = { "armor_unhurried_coat" },
    character_frost_slime = { "utility_idle_hands" },
    character_snowdrift_slime = { "utility_snowbank" },
    character_glacier_king = { "utility_the_slow_hour", "utility_stillwater", "utility_heavy_lids",
                               "utility_deep_sleep", "utility_snowslide", "utility_patient_blade" },
    character_mimic_slime = { "utility_copycat" },
    character_many_faced_king = { "utility_mirror_mask", "utility_second_self" },
    character_crystal_slime = { "utility_pecking_order" },
    character_apex_crystal = { "utility_station", "armor_above_reproach" },
}

return {
    -- ----- the shared shape -----
    {
        name = "every body is proof against steel, and every drop is its own and never sold",
        fn = function()
            for _, id in ipairs(RELICS) do
                local r = Item.defs[id]
                assert(r and r.bound and r.immune and r.immune.slash, id .. " is a bound, steel-proof body")
            end
            for body, want in pairs(DROPS) do
                local got = Character.defs[body].drops
                assert(#got == #want, body .. " drops " .. #got .. ", wants " .. #want)
                for i, id in ipairs(want) do
                    assert(got[i] == id, body .. " drop " .. i .. " is " .. tostring(got[i]))
                    assert(Item.defs[id] and Item.defs[id].unstocked, id .. " is unstocked")
                end
            end
        end,
    },
    {
        name = "each circle bills its slimes on its approach and its King on its seat",
        fn = function()
            local want = {
                wrath = { "encounter_the_cinder_slimes", "encounter_the_caldera_king", "volcanic" },
                sloth = { "encounter_the_still_slimes", "encounter_the_glacier_king", "tundra" },
                envy = { "encounter_the_mimic_slimes", "encounter_the_many_faced_king", "desert" },
                pride = { "encounter_the_crystal_slimes", "encounter_the_apex_crystal", "spire" },
            }
            for _, sin in ipairs(Descent.SINS) do
                local w = want[sin.id]
                if w then
                    local billed = { [sin.elites.approach or ""] = true, [sin.elites.seat or ""] = true }
                    for _, id in ipairs(sin.elites.spares or {}) do billed[id] = true end
                    for r, id in ipairs({ w[1], w[2] }) do
                        local e = Encounter.defs[id]
                        assert(e and e.kind == "elite" and e.rung == r, id .. " is the rung-" .. r .. " elite")
                        assert(e.condition({ biome = w[3] }), id .. " stands on " .. w[3])
                        assert(billed[id], sin.id .. " bills " .. id)
                    end
                end
            end
        end,
    },

    -- ----- WRATH: Boil Over -----
    {
        name = "Boil Over: five landed hits and it erupts on its neighbours in the element it took",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_knight", 4, 5) },
                { unit("character_cinder_slime", 5, 5) })
            local knight, slime = c.units[1], c.units[2]
            local before = knight.char.stats.health.current
            for i, el in ipairs({ "fire", "ice", "lightning", "water" }) do
                Combat.dealFlatDamage(c, slime, 5, spell(el), "test")
                assert(Status.get(slime, "status_seething").magnitude == 2 * i, "stack " .. i)
            end
            assert(knight.char.stats.health.current == before, "no eruption yet")
            Combat.dealFlatDamage(c, slime, 5, spell("holy"), "test")
            assert(knight.char.stats.health.current < before, "the fifth hit erupts on the knight beside it")
            assert(not Status.has(slime, "status_seething"), "and the count starts again")
        end,
    },
    {
        name = "the Caldera King comes apart into cinder slimes that are already Seething",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_bandit", 1, 1) },
                { unit("character_caldera_king", 6, 6) })
            Combat.dealFlatDamage(c, c.units[2], 99999, spell("fire"), "test")
            local pieces = living(c, "character_cinder_slime")
            assert(#pieces == 3, "three pieces, got " .. #pieces)
            for _, p in ipairs(pieces) do
                assert(Status.get(p, "status_seething") and Status.get(p, "status_seething").magnitude == 2,
                    "each piece arrives with one stack")
            end
        end,
    },
    {
        name = "Wrath's drops: the Core climbs, the Plate burns once, Flashpoint primes every third hit",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { wearing("character_knight", { "utility_seething_core", "armor_caldera_plate", "utility_flashpoint" }, 4, 5) },
                { unit("character_bandit", 5, 5) })
            local me, foe = c.units[1], c.units[2]
            for _ = 1, 7 do Combat.dealFlatDamage(c, me, 1, {}, "test") end
            assert(Status.get(me, "status_simmering").magnitude == 5, "the Core caps at +5")
            assert(Status.has(me, "status_empowered"), "the sixth hit primed Flashpoint")
            -- Defence would soak a measured blow: set the bar under half, then land a scratch.
            me.char.stats.health.current = math.floor(me.char.stats.health.max * 0.4)
            Combat.dealFlatDamage(c, me, 1, {}, "test")
            assert(Status.has(foe, "status_burn"), "the Plate burns the adjacent bandit below half")
        end,
    },

    -- ----- SLOTH: three slimes and their King -----
    {
        name = "Torpid Touch: a rime slime's blow pushes your next turn back and slows you",
        fn = function()
            -- Measured against an untouched second knight, because the timeline moves everyone on as the
            -- slime's own action is spent.
            local c = Combat.new(arena(10, 10), { unit("character_knight", 4, 5), unit("character_knight", 1, 1) },
                { unit("character_rime_slime", 5, 5) })
            local knight, control, slime = c.units[1], c.units[2], c.units[3]
            local gap = knight.initiative - control.initiative
            Combat.useItem(c, slime, itemNamed(slime.char, "weapon_pseudopod"), knight.x, knight.y)
            assert(Status.has(knight, "status_torpid"), "the knight is Torpid")
            assert(knight.initiative - control.initiative >= gap + 3, "and its next turn comes later than it would have")
        end,
    },
    {
        name = "Numb: a frost slime's blow makes every cost the knight pays 1 higher",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_knight", 4, 5) },
                { unit("character_frost_slime", 5, 5) })
            local knight, slime = c.units[1], c.units[2]
            local ab = Item.instantiate("ability_heal").activeAbility
            local base = Combat.abilityCosts(knight, ab)[1].amount
            Combat.useItem(c, slime, itemNamed(slime.char, "weapon_pseudopod"), knight.x, knight.y)
            assert(Status.has(knight, "status_numbed"), "Numbed")
            assert(Combat.abilityCosts(knight, ab)[1].amount == base + 1, "a cast costs one more")
        end,
    },
    {
        name = "Drift: a snowdrift slime grows each turn it ends where it began, and moving sheds it",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_knight", 1, 1) },
                { unit("character_snowdrift_slime", 7, 7) })
            local slime = c.units[2]
            local st = Status.get(slime, "status_drift")
            assert(st, "the drift is open at the bell")
            for _ = 1, 2 do Status.onTurnStart(c, slime); Status.onTurnEnd(c, slime) end
            assert(st.magnitude == 2 and Status.statBonus(slime, "defense") >= 4, "two still turns, two stacks")
            Status.onTurnStart(c, slime); slime.x = 6; Status.onTurnEnd(c, slime)
            assert(st.magnitude == 0, "a turn it moved sheds them all")
        end,
    },
    {
        name = "the Glacier King carries all three rules and comes apart into one of each",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_bandit", 1, 1) },
                { unit("character_glacier_king", 6, 6) })
            local king = c.units[2]
            for _, t in ipairs({ "trait_torpid_touch", "trait_numb", "trait_drift" }) do
                local found = false
                for _, tr in ipairs(king.traits) do found = found or tr.id == t end
                assert(found, "the King carries " .. t)
            end
            Combat.dealFlatDamage(c, king, 99999, spell("fire"), "test")
            for _, id in ipairs({ "character_rime_slime", "character_frost_slime", "character_snowdrift_slime" }) do
                assert(#living(c, id) == 1, "one " .. id)
            end
        end,
    },
    {
        name = "Sloth's drops: the Coat refuses Torpid and Stun, Idle Hands frees one cast, the Snowslide spends the bank",
        fn = function()
            assert(Item.defs.armor_unhurried_coat.statusImmunity[1] == "status_torpid", "the Coat names Torpid")
            local c = Combat.new(arena(10, 10),
                { wearing("character_bandit", { "utility_idle_hands", "utility_snowbank", "utility_snowslide",
                    "utility_heavy_lids", "utility_stillwater", "utility_patient_blade", "utility_deep_sleep",
                    "utility_the_slow_hour" }, 4, 5) },
                { unit("character_bandit", 5, 5) })
            local me = c.units[1]
            local ab = Item.instantiate("ability_heal").activeAbility
            assert(Combat.abilityCosts(me, ab)[1].amount == 0, "Idle: the first cast is free")
            Combat.useItem(c, me, itemNamed(me.char, "utility_deep_sleep"), me.x, me.y)
            assert(not Status.has(me, "status_idle"), "and using anything spends it")
            for _ = 1, 2 do Status.onTurnStart(c, me); Status.onTurnEnd(c, me) end
            assert(Status.get(me, "status_snowbank").magnitude == 2, "two still turns bank two")
            assert(Status.get(me, "status_stillwater").magnitude == 1, "Stillwater is on")
            assert(Status.get(me, "status_patient").magnitude == 1, "and so is the Patient Blade")
            Combat.useItem(c, me, itemNamed(me.char, "utility_snowslide"), me.x, me.y)
            local emp = Status.get(me, "status_empowered")
            assert(emp and emp.magnitude == 8, "the Snowslide spends the bank as +4 a stack")
        end,
    },

    -- ----- ENVY: Mimicry + Begrudge -----
    {
        name = "Mimicry: the first foe to target a mimic slime is the one it becomes",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_knight", 4, 5) },
                { unit("character_mimic_slime", 5, 5) })
            local knight, slime = c.units[1], c.units[2]
            Combat.useItem(c, knight, itemNamed(knight.char, "weapon_iron_sword"), slime.x, slime.y)
            assert(slime.mimicked == knight, "it took the knight's shape")
            assert(itemNamed(slime.char, "weapon_iron_spear") or itemNamed(slime.char, "weapon_iron_sword"),
                "and carries a copy of the knight's weapon")
            assert(slime.char.stats.damage == knight.char.stats.damage, "and swings with its numbers")
            assert(Combat.mitigatedDamage(slime, 40, { "sword", "slash", "physical" }) == 0, "still steel-proof")
        end,
    },
    {
        name = "Begrudge: a blessing the company gains, the mimic slime gains too -- and only once",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_knight", 1, 1) },
                { unit("character_mimic_slime", 8, 8), unit("character_mimic_slime", 9, 9) })
            local knight = c.units[1]
            Status.apply(c, knight, "status_hasted", { duration = 10 })
            for _, s in ipairs(living(c, "character_mimic_slime")) do
                assert(Status.has(s, "status_hasted"), "each slime begrudges the Haste")
            end
            Status.apply(c, knight, "status_burn", {})
            for _, s in ipairs(living(c, "character_mimic_slime")) do
                assert(not Status.has(s, "status_burn"), "a debuff is nothing to envy")
            end
        end,
    },
    {
        name = "the Many-Faced King comes apart into copies of the company, wearing what it begrudged",
        fn = function()
            local c = Combat.new(arena(12, 12),
                { unit("character_knight", 1, 1), unit("character_bandit", 2, 1) },
                { unit("character_many_faced_king", 6, 6) })
            local knight, king = c.units[1], c.units[3]
            Status.apply(c, knight, "status_hasted", { duration = 10 })
            assert(Status.has(king, "status_hasted"), "the King begrudged it")
            Combat.dealFlatDamage(c, king, 99999, spell("fire"), "test")
            local pieces = living(c, "character_mimic_slime")
            assert(#pieces == 3, "three faces")
            local faces = {}
            for _, p in ipairs(pieces) do
                assert(p.mimicked, "each piece wears somebody")
                faces[p.mimicked] = true
                assert(Status.has(p, "status_hasted"), "and the Haste")
            end
            assert(faces[c.units[1]] and faces[c.units[2]], "both company members are copied")
        end,
    },
    {
        name = "Envy's drops: Copycat lends the weapon until used, the Mask opens with a double, Second Self stands up",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { wearing("character_bandit", { "utility_copycat", "utility_mirror_mask", "utility_second_self" }, 4, 5) },
                { unit("character_knight", 5, 5) })
            local me, foe = c.units[1], c.units[2]
            local double = false
            for _, u in ipairs(c.units) do double = double or (u.decoyOf == me) end
            assert(double, "the Mirror Mask opens the fight with a double of the bearer")
            -- The Mask is worn too, so the FIRST blow lands on the double (Substitution) -- which is the
            -- Mask working. The second one reaches the bearer, and that is the one Copycat hears.
            Combat.dealFlatDamage(c, me, 1, { "sword", "slash", "physical" }, "test", foe)
            local stillDouble = false
            for _, u in ipairs(c.units) do stillDouble = stillDouble or (u.alive and u.decoyOf == me) end
            assert(not stillDouble, "the first blow was taken by the double")
            Combat.dealFlatDamage(c, me, 1, { "sword", "slash", "physical" }, "test", foe)
            local loan
            for _, it in ipairs(Character.eachItem(me.char)) do if it.copycat then loan = it end end
            assert(loan and loan.onLoan, "Copycat: the knight's weapon is copied into the bearer's grid, on loan")
            Combat.returnStripped(c)
            for _, it in ipairs(Character.eachItem(me.char)) do assert(not it.onLoan, "and the fight's end takes it back") end
            me.char.stats.health.current = 1
            Combat.dealFlatDamage(c, me, 99999, {}, "test")
            local selves = 0
            for _, u in ipairs(c.units) do
                if u.alive and u ~= me and u.side == me.side and u.char.id == me.char.id and not u.decoyOf then selves = selves + 1 end
            end
            assert(selves >= 1, "Second Self: a copy stands up when the bearer falls")
        end,
    },

    -- ----- PRIDE: Rank -----
    {
        name = "Rank: only the lowest crystal can be hurt, and the Apex only once the rest are gone",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_bandit", 1, 1) },
                { unit("character_crystal_slime", 6, 6), unit("character_crystal_slime", 8, 8),
                  unit("character_apex_crystal", 10, 10) })
            local a, b, apex = c.units[2], c.units[3], c.units[4]
            a.char.stats.health.current = 10
            assert(Combat.mitigatedDamage(a, 30, spell("fire")) > 0, "the lowest crystal can be hurt")
            assert(Combat.mitigatedDamage(b, 30, spell("fire")) == 0, "the one above it is Outranked")
            assert(Combat.mitigatedDamage(apex, 30, spell("fire")) == 0, "and so is the Apex")
            Combat.dealFlatDamage(c, a, 99999, spell("fire"), "test")
            assert(Combat.mitigatedDamage(b, 30, spell("ice")) > 0, "with it gone, the next is exposed")
            Combat.dealFlatDamage(c, b, 99999, spell("ice"), "test")
            assert(Combat.mitigatedDamage(apex, 30, spell("ice")) > 0, "and last of all the Apex")
        end,
    },
    {
        name = "Pride's drops: the Order hits the weaker harder, Station stands firm, Above Reproach turns the first hit",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { wearing("character_knight", { "utility_pecking_order", "utility_station", "armor_above_reproach" }, 4, 5),
                  unit("character_bandit", 3, 5) },
                { unit("character_bandit", 5, 5) })
            local me, ally, foe = c.units[1], c.units[2], c.units[3]
            foe.char.stats.health.current = 1
            assert(Trait.outgoingDamageBonus(c, me, foe, nil, {}) == 3, "+3 against a foe with less health")
            me.char.level, ally.char.level = 5, 1
            assert(Trait.liveBonus(me, "defense") == 3, "Station: +3 with a lower-level ally beside")
            -- The battle screen applies an opening boon (states/battle.lua, Curse.openingBoons); do what it does.
            assert(Item.defs.armor_above_reproach.openingBoon.id == "status_above_reproach", "the boon is declared")
            Status.apply(c, me, "status_above_reproach")
            assert(Combat.dealFlatDamage(c, me, 20, {}, "test") == 0, "the first hit is turned aside")
            assert(Combat.dealFlatDamage(c, me, 20, {}, "test") > 0, "and only the first")
        end,
    },
}
