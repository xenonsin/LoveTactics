-- The forecast tells the truth about three things the live blow already did:
--
--   * a REFUSED cast (Combat.castRefusal: the Sealed Ward, Already Known, the Sealed Hand) previews as refused --
--     nothing on the body but the refusal's name -- and the planner prices popping a foe's cast ward;
--   * a POOLED Physical Barrier (the Bulwark of the Fallen) reads, badges and forecasts as the amount it has left;
--   * a blow that HOLDS its target at 1 (Combat.heldAtOne: Torment, Seek Death, the Lioness) never forecasts a kill.
--
-- Pure logic, headless. FORCE_HIT is pinned by the runner, so preview and live agree on whether a blow lands.

local Character = require("models.character")
local Combat = require("models.combat")
local Status = require("models.status")
local Trait = require("models.trait")
local Item = require("models.item")
local AI = require("models.ai")
local Crown = require("models.crown_demons")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local function board(n) return Fixture.new(n or 8, n or 8) end

local function bare(id, health)
    local char = Character.instantiate(id)
    char.inventory = {}
    if health then char.stats.health.max, char.stats.health.current = health, health end
    return char
end

local function equip(char, ids)
    for _, id in ipairs(ids) do Character.addItem(char, Item.instantiate(id)) end
    return char
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function entryOn(preview, u)
    return preview and preview.entries and preview.entries[u]
end

-- A mage with a Fire Bolt and a Fireball, two squares from a tough bandit wearing a Sealed Ward.
local function wardedDuel()
    local caster = equip(bare("character_mage"), { "ability_fire_bolt", "ability_fireball" })
    local c = Fixture.combat(board(), unit(caster, 3, 3), unit(bare("character_bandit", 600), 3, 5))
    local mage, foe = c.units[1], c.units[2]
    Status.apply(c, foe, "status_sealed_ward")
    openTurn(c, mage)
    return c, mage, foe, itemNamed(caster, "ability_fire_bolt"), itemNamed(caster, "ability_fireball")
end

return {
    -- -------------------------------------------------------------------- the refused cast, forecast
    {
        name = "a single-target cast at a Sealed Ward previews as refused: no damage, no status, the ward named",
        fn = function()
            local c, mage, foe, bolt = wardedDuel()
            local refusal = Combat.castRefusal(c, mage, bolt, bolt.activeAbility, foe)
            assert(refusal and refusal.kind == "cast", "the pure gate names the cast ward")
            local p = Combat.previewAbility(c, mage, bolt, foe.x, foe.y)
            local e = entryOn(p, foe)
            assert(e, "the warded body is still the one entry")
            assert(#p.order == 1, "and the only one")
            assert(e.damage == 0 and #e.statuses == 0 and not e.lethal, "nothing on it")
            assert(e.warded == Status.defs.status_sealed_ward.name, "the ward is named: " .. tostring(e.warded))
            assert(Status.castWardOn(foe), "the forecast did not spend the ward")
            assert(Combat.castDoesSomething(c, mage, bolt, foe.x, foe.y), "and the click is still a cast, not a step")
            -- ...and the live cast agrees, then spends it.
            local before = hp(foe)
            assert(Combat.useItem(c, mage, bolt, foe.x, foe.y), "the cast resolves")
            assert(hp(foe) == before and not Status.castWardOn(foe), "refused live, ward spent")
        end,
    },
    {
        name = "an area cast over the same warded body still forecasts its damage",
        fn = function()
            local c, mage, foe, _, ball = wardedDuel()
            assert(not Combat.castRefusal(c, mage, ball, ball.activeAbility, foe), "a blast aims at nobody")
            local e = entryOn(Combat.previewAbility(c, mage, ball, foe.x, foe.y), foe)
            assert(e and e.damage > 0 and not e.warded, "the blast forecasts its wound")
        end,
    },
    {
        name = "a Sealed Hand refuses a forecast heal the same way, and is not spent by the hover",
        fn = function()
            local priest = equip(bare("character_priest"), { "ability_renewal" })
            local c = Fixture.combat(board(), { unit(priest, 3, 3), unit(bare("character_rowan"), 3, 4) },
                unit(bare("character_bandit", 600), 7, 7))
            local healer, patient = c.units[1], c.units[2]
            patient.char.stats.health.current = 20
            Status.apply(c, patient, "status_sealed_hand")
            openTurn(c, healer)
            local renewal = itemNamed(priest, "ability_renewal")
            local e = entryOn(Combat.previewAbility(c, healer, renewal, patient.x, patient.y), patient)
            assert(e and e.heal == 0 and e.warded, "the heal forecasts as refused")
            assert(Status.aidWardOn(patient), "and the ward stands")
        end,
    },
    {
        name = "Already Known forecasts as refused once she has seen the spell, and the hover logs nothing",
        fn = function()
            local c = Fixture.combat(board(6), { char = Character.instantiate("character_sublimitas"), x = 1, y = 1 },
                { char = Character.instantiate("character_mage"), x = 2, y = 1 })
            local sublimitas, caster = c.units[1], c.units[2]
            local bolt = Item.instantiate("ability_fire_bolt")
            assert(not Trait.wouldUnravelKnown(sublimitas, caster, bolt), "unseen, it is not known")
            local fresh = entryOn(Combat.previewAbility(c, caster, bolt, 1, 1), sublimitas)
            assert(fresh and fresh.damage > 0 and not fresh.warded, "an unseen spell forecasts its wound")
            Trait.onAnyCast(c, caster, { item = bolt, ability = bolt.activeAbility })
            local logged = #(c.log or {})
            local e = entryOn(Combat.previewAbility(c, caster, bolt, 1, 1), sublimitas)
            assert(e and e.damage == 0 and e.warded == "Already Known", "a known spell forecasts as unravelled")
            assert(#(c.log or {}) == logged, "and the forecast wrote nothing to the log")
            assert(Trait.tryUnravelKnown(c, sublimitas, caster, bolt), "the live gate still answers")
        end,
    },
    {
        name = "the planner prices popping a cast ward modestly, and below a real blow",
        fn = function()
            local c, mage, foe, bolt = wardedDuel()
            local w = AI.WEIGHTS
            local warded = { item = bolt, tx = foe.x, ty = foe.y, x = mage.x, y = mage.y, target = foe }
            AI.scoreCandidate(c, mage, warded, w, {})
            assert(warded.outcome == w.WARD_POP and w.WARD_POP > 0, "a pop earns WARD_POP: " .. tostring(warded.outcome))
            -- The same bolt at the same body unwarded is worth more than the pop.
            Status.remove(c, foe, "status_sealed_ward")
            local open = { item = bolt, tx = foe.x, ty = foe.y, x = mage.x, y = mage.y, target = foe }
            AI.scoreCandidate(c, mage, open, w, {})
            assert(open.outcome > warded.outcome, "a real blow outscores the pop: "
                .. tostring(open.outcome) .. " vs " .. tostring(warded.outcome))
        end,
    },

    -- ------------------------------------------------------------- the pooled barrier, read and forecast
    {
        name = "a pooled Physical Barrier badges, reads and forecasts as the amount it has left",
        fn = function()
            local StatusBadge = require("ui.status_badge")
            local striker = unit("character_rowan", 3, 3, { isolate = "mechanics" })
            local c = Fixture.combat(board(), striker, unit(bare("character_bandit", 600), 3, 4))
            local knight, foe = c.units[1], c.units[2]
            local sword = Item.instantiate("weapon_iron_sword")
            local plain = Combat.computeDamage(c, knight, foe, sword)
            assert(plain > 0, "the sword bites the unwarded body")

            local st = Crown.grantBarrier(c, foe, 30)
            assert(st and st.pool == 30, "a pool of 30 closes")
            assert(StatusBadge.label(st):find("30", 1, true), "the badge prints 30: " .. StatusBadge.label(st))
            assert(st.def.describe(st):find("30", 1, true), "the tooltip reads 30: " .. st.def.describe(st))

            Combat.dealFlatDamage(c, foe, 12, { "physical" }, "test", knight, { raw = true })
            assert(st.pool == 18, "a 12 blow leaves 18: " .. tostring(st.pool))
            assert(StatusBadge.label(st):find("18", 1, true), "the badge follows it")
            assert(st.def.describe(st):find("18", 1, true), "and so does the tooltip")

            local e = entryOn(Combat.previewAbility(c, knight, sword, foe.x, foe.y), foe)
            assert(e and e.damage == math.max(0, plain - 18),
                string.format("the forecast pays the pool first: %s vs %d", tostring(e and e.damage), plain - 18))
            assert(Combat.computeDamage(c, knight, foe, sword) == math.max(0, plain - 18), "computeDamage agrees")
            assert(st.pool == 18, "and the forecast spent none of it")
            assert(Crown.barrierPool(foe) == 18, "the pure read")
        end,
    },
    {
        -- The Tribunal ran 22 -> 39 unit-turns the day the forecast learned the pool: every blow into it read 0,
        -- the planner's outcome gate refused them all, and the company held position until the barrier wore off.
        name = "the planner prices a blow the pool eats as a wound, even when the body loses nothing",
        fn = function()
            local striker = unit("character_rowan", 3, 3, { isolate = "mechanics" })
            local c = Fixture.combat(board(), striker, unit(bare("character_bandit", 600), 3, 4))
            local knight, foe = c.units[1], c.units[2]
            local sword = Item.instantiate("weapon_iron_sword")
            local plain = Combat.computeDamage(c, knight, foe, sword)
            Crown.grantBarrier(c, foe, plain + 50)
            local e = entryOn(Combat.previewAbility(c, knight, sword, foe.x, foe.y), foe)
            assert(e and e.damage == 0 and e.absorbed == plain,
                string.format("the body loses 0 and the pool eats %d: %s / %s", plain, tostring(e and e.damage),
                    tostring(e and e.absorbed)))
            local cand = { item = sword, tx = foe.x, ty = foe.y, x = knight.x, y = knight.y, target = foe }
            AI.scoreCandidate(c, knight, cand, AI.WEIGHTS, {})
            assert(cand.outcome and cand.outcome > 0, "chipping the pool is worth a swing: " .. tostring(cand.outcome))
        end,
    },

    -- ------------------------------------------------------------------- held at 1, forecast
    {
        name = "Torment at a body on 5 forecasts 4 and no kill, and the live blow agrees",
        fn = function()
            local plague = unit(bare("character_rowan"), 3, 3, { stats = { damage = 40 }, items = { "ability_torment" } })
            local c = Fixture.combat(board(), plague, unit(bare("character_bandit", 100), 3, 4))
            local me, foe = c.units[1], c.units[2]
            foe.char.stats.health.current = 5
            local torment = itemNamed(me.char, "ability_torment")
            local e = entryOn(Combat.previewAbility(c, me, torment, foe.x, foe.y), foe)
            assert(e and e.damage == 4 and e.lethal == false,
                string.format("held at 1: damage %s lethal %s", tostring(e and e.damage), tostring(e and e.lethal)))
            openTurn(c, me)
            Combat.useItem(c, me, torment, foe.x, foe.y)
            assert(foe.alive and hp(foe) == 1, "live, it holds at 1")
        end,
    },
    {
        name = "a Pit Locust's sting forecasts no kill; a fragile body is not held",
        fn = function()
            local c = Fixture.combat(board(), unit(bare("character_bandit", 100), 3, 4),
                unit("character_pit_locust", 3, 3, { stats = { damage = 40 } }))
            local foe, locust = c.units[1], one(c, "character_pit_locust")
            foe.char.stats.health.current = 5
            local sting = itemNamed(locust.char, "weapon_pit_locust_sting")
            local e = entryOn(Combat.previewAbility(c, locust, sting, foe.x, foe.y), foe)
            assert(e and e.damage == 4 and not e.lethal, "the sting is held: " .. tostring(e and e.damage))
            foe.fragile = true
            e = entryOn(Combat.previewAbility(c, locust, sting, foe.x, foe.y), foe)
            assert(e and e.lethal, "a fragile body is not held")
        end,
    },
    {
        name = "a Lioness forecasts no kill while her Lion stands, and a kill once he falls",
        fn = function()
            local c = Fixture.combat(board(11), unit(bare("character_bandit", 100), 5, 6),
                { unit("character_lioness", 5, 5, { stats = { damage = 60 } }), unit("character_lion", 9, 9) })
            local foe, lioness, lion = c.units[1], one(c, "character_lioness"), one(c, "character_lion")
            foe.char.stats.health.current = 5
            local weapon = Combat.defaultWeapon(lioness.char)
            local e = entryOn(Combat.previewAbility(c, lioness, weapon, foe.x, foe.y), foe)
            assert(e and e.damage == 4 and not e.lethal, "held for the Lion: " .. tostring(e and e.damage))
            Combat.dealFlatDamage(c, lion, 99999, { "physical" }, "test", foe, { raw = true })
            assert(not lion.alive, "the Lion falls")
            e = entryOn(Combat.previewAbility(c, lioness, weapon, foe.x, foe.y), foe)
            assert(e and e.lethal, "and she kills freely")
        end,
    },
}
