-- THE BUILD ENGINES (docs/engines.md, models/engine.lua). One case per promise each engine's pieces make:
-- the build-up banks, the multiplier multiplies, the payoff spends, and the grid piece reads its
-- neighbours. Every new or reworked piece is named here by id, which is also what keeps
-- tests/item_coverage_spec.lua from calling any of them untested.

local Combat = require("models.combat")
local Character = require("models.character")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Engine = require("models.engine")
local Fixture = require("tests.support.fixture")

local openTurn = Fixture.openTurn

-- A bare body at (x, y) whose grid is exactly `grid` ({ [cell] = id }), with deep pools so no case is
-- refused for want of stamina or mana it is not about.
local function body(id, x, y, grid, stats)
    local spawn = Fixture.unit(id or "character_rowan", x, y, { isolate = "bare", stats = stats })
    spawn.char.inventory = {}
    for cell, itemId in pairs(grid or {}) do spawn.char.inventory[cell] = Item.instantiate(itemId) end
    return spawn
end

local function fight(party, enemies, w, h)
    return Combat.new(Fixture.new(w or 10, h or 10), party, enemies)
end

local function deep(u)
    for _, k in ipairs({ "stamina", "mana" }) do
        local s = u.char.stats[k]
        if type(s) == "table" then s.max, s.current = 200, 200 end
    end
    local hp = u.char.stats.health
    hp.max, hp.current = math.max(hp.max, 200), math.max(hp.max, 200)
end

local function cell(u, i) return u.char.inventory[i] end

return {
    -- ------------------------------------------------------------------------------- Bloodletting
    {
        name = "Bloodletting: a whetstone beside a dagger stacks Bleed, Widen the Wound doubles it",
        fn = function()
            local c = fight({ body("character_rowan", 2, 2,
                    { [1] = "weapon_iron_dagger", [2] = "utility_serrated_whetstone", [3] = "ability_widen_the_wound" }) },
                { body("character_bandit", 2, 3, {}) })
            local a, foe = c.units[1], c.units[2]
            deep(a); deep(foe)
            openTurn(c, a)
            assert(Combat.useItem(c, a, cell(a, 1), foe.x, foe.y), "the dagger lands")
            local after = Engine.bleedStacks(foe)
            assert(after >= 2, "the dagger's own wound and the whetstone's stack: 2, got " .. after)
            openTurn(c, a)
            assert(Combat.useItem(c, a, cell(a, 3), foe.x, foe.y), "Widen the Wound lands")
            assert(Engine.bleedStacks(foe) == after * 2, "the stacks double: " .. Engine.bleedStacks(foe))
        end,
    },
    {
        name = "Bloodletting: a Hemophage Charm carries a fallen foe's Bleed to its nearest ally",
        fn = function()
            local c = fight({ body("character_rowan", 1, 1, { [1] = "utility_opportunists_charm" }) },
                { body("character_bandit", 5, 5, {}), body("character_bandit", 5, 6, {}) })
            local a, f1, f2 = c.units[1], c.units[2], c.units[3]
            Engine.addBleed(c, f1, 3, a)
            Combat.dealFlatDamage(c, f1, 9999, { "physical" }, "test", a)
            assert(not f1.alive, "the bleeding foe falls")
            assert(Engine.bleedStacks(f2) == 3, "its three wounds open on the foe beside it, got "
                .. Engine.bleedStacks(f2))
        end,
    },

    -- ------------------------------------------------------------------------------- Tempo
    {
        name = "Tempo: a quick action banks it, a walk forfeits it, and the Skirmisher keeps it on the move",
        fn = function()
            local c = fight({ body("character_rowan", 2, 2, { [1] = "ability_penetrating_strike" }),
                    body("character_rowan", 6, 2, { [1] = "ability_penetrating_strike", [2] = "ability_harrying_strike" }) },
                { body("character_bandit", 2, 3, {}), body("character_bandit", 6, 3, {}) })
            local a, s = c.units[1], c.units[2]
            local fa, fs = c.units[3], c.units[4]
            for _, u in ipairs(c.units) do deep(u) end
            openTurn(c, a)
            assert(Combat.useItem(c, a, cell(a, 1), fa.x, fa.y), "the jab lands")
            assert(Combat.chargePool(a, "tempo") == 1, "one quick action, one Tempo")
            Engine.onWalk(c, a, 2)
            assert(Combat.chargePool(a, "tempo") == 0, "a walk throws it away")
            openTurn(c, s)
            assert(Combat.useItem(c, s, cell(s, 1), fs.x, fs.y), "the skirmisher jabs")
            Engine.onWalk(c, s, 2)
            assert(Combat.chargePool(s, "tempo") == 1, "and keeps it on the move (Harrying Strike)")
        end,
    },
    {
        name = "Tempo: the Afterimage Cloak raises barrier on a quick action; the Whetted Edge sharpens only quick weapons",
        fn = function()
            local c = fight({ body("character_rowan", 2, 2, { [1] = "ability_penetrating_strike", [2] = "utility_afterimage_cloak" }) },
                { body("character_bandit", 2, 3, {}) })
            local a, foe = c.units[1], c.units[2]
            deep(a); deep(foe)
            openTurn(c, a)
            assert(Combat.useItem(c, a, cell(a, 1), foe.x, foe.y), "the jab lands")
            assert(Engine.barrierPool(a) >= 2, "a quick action raises barrier, got " .. Engine.barrierPool(a))
            local edge = Item.instantiate("utility_whetted_edge")
            assert(Combat.auraApplies(edge.aura, Item.instantiate("weapon_iron_dagger")), "a dagger is quick")
            assert(not Combat.auraApplies(edge.aura, Item.instantiate("weapon_iron_sword")), "a sword is not")
        end,
    },

    -- ------------------------------------------------------------------------------- Blood Price
    {
        name = "Blood Price: Red Tithe pays 15% health for full stamina and banks Blood a Sanguine Font spends",
        fn = function()
            local c = fight({ body("character_rowan", 2, 2,
                    { [1] = "ability_red_tithe", [2] = "utility_keen_edge", [3] = "ability_power_strike" }) },
                { body("character_bandit", 2, 3, {}) })
            local a, foe = c.units[1], c.units[2]
            deep(a); deep(foe)
            local hp, st = a.char.stats.health, a.char.stats.stamina
            st.current = 10
            local before = hp.current
            openTurn(c, a)
            assert(Combat.useItem(c, a, cell(a, 1), a.x, a.y), "the tithe is paid")
            assert(hp.current == before - math.floor(hp.max * 0.15), "15% of max health is paid")
            assert(st.current == st.max, "stamina is full")
            assert(Combat.chargePool(a, "blood") == 1, "the self-wound banks one Blood")
            openTurn(c, a)
            local plain = Combat.computeDamage(c, a, foe, cell(a, 3))
            a.chargeSpent = { blood = 1 } -- spent: what the strike lands without the Font
            local bare = Combat.computeDamage(c, a, foe, cell(a, 3))
            assert(plain == bare + 3, "one Blood adds 3 to the next ability: " .. plain .. " vs " .. bare)
        end,
    },
    {
        name = "Blood Price: a Wound Gift pays an unaffordable stamina price in health, and a Scab gives it back on a kill",
        fn = function()
            local c = fight({ body("character_rowan", 2, 2,
                    { [1] = "ability_power_strike", [2] = "utility_wound_gift", [3] = "utility_scab",
                      [4] = "weapon_iron_sword" }) },
                { body("character_bandit", 2, 3, {}) })
            local a, foe = c.units[1], c.units[2]
            deep(a)
            a.char.stats.stamina.current = 0
            local costs = Combat.abilityCosts(a, cell(a, 1).activeAbility)
            assert(costs[1].stat == "health", "the stamina price is quoted in health")
            local hp = a.char.stats.health
            local before = hp.current
            foe.char.stats.health.current = 1
            openTurn(c, a)
            assert(Combat.useItem(c, a, cell(a, 1), foe.x, foe.y), "the strike is paid in blood")
            assert(not foe.alive, "and kills")
            assert(hp.current == before, "the Scab heals back what was paid this turn: " .. hp.current .. " vs " .. before)
        end,
    },
    {
        name = "Blood Price: the Butcher's Tally counts only the bearer's own kills",
        fn = function()
            local c = fight({ body("character_rowan", 1, 1, { [1] = "utility_butchers_tally" }),
                    body("character_rowan", 2, 1, {}) },
                { body("character_bandit", 5, 5, {}), body("character_bandit", 6, 6, {}) })
            local a, ally, f1, f2 = c.units[1], c.units[2], c.units[3], c.units[4]
            Combat.dealFlatDamage(c, f1, 9999, { "physical" }, "test", ally)
            assert(((a.bonus and a.bonus.damage) or 0) == 0, "an ally's kill does not notch the strap")
            Combat.dealFlatDamage(c, f2, 9999, { "physical" }, "test", a)
            assert(a.bonus.damage == Trait.defs.trait_blood_fever.magnitude, "the bearer's own does")
        end,
    },

    -- ------------------------------------------------------------------------------- Reaper
    {
        name = "Reaper: a kill with a weapon beside the Ledger refunds it and grants a stride; a Carrion Mark quickens",
        fn = function()
            local c = fight({ body("character_rowan", 2, 2,
                    { [1] = "weapon_iron_sword", [2] = "utility_reapers_ledger", [3] = "ability_carrion_mark" }) },
                { body("character_bandit", 2, 3, {}), body("character_bandit", 5, 4, {}) })
            local a, f1, f2 = c.units[1], c.units[2], c.units[3]
            deep(a)
            local st = a.char.stats.stamina
            openTurn(c, a)
            assert(Combat.useItem(c, a, cell(a, 3), f2.x, f2.y), "the mark lands")
            assert(Status.has(f2, "status_carrion_mark"), "the foe is marked")
            Combat.dealFlatDamage(c, f2, 9999, { "physical" }, "test")
            assert(Status.has(a, "status_quickened"), "its fall quickens the marker")
            local sword = cell(a, 1)
            local quick = Combat.actionSpeed(a, sword.activeAbility, sword)
            Status.remove(c, a, "status_quickened")
            assert(Combat.actionSpeed(a, sword.activeAbility, sword) == quick + 2, "two ticks sooner")
            f1.char.stats.health.current = 1
            st.current = 100
            openTurn(c, a)
            assert(Combat.useItem(c, a, sword, f1.x, f1.y), "the sword kills")
            -- Regeneration runs on the clock the swing advanced, so the purse can only come back fuller.
            assert(st.current >= 100, "the Ledger refunds the swing: " .. st.current)
            assert(Status.has(a, "status_reapers_stride"), "and grants two free steps")
        end,
    },

    -- ------------------------------------------------------------------------------- Storm Vessel
    {
        name = "Storm Vessel: banked Storm multiplies the spell beside it, the forecast agrees, and the cast spends it",
        fn = function()
            local c = fight({ body("character_mage", 2, 2,
                    { [1] = "ability_fire_bolt", [2] = "utility_resonance_prism", [3] = "utility_focus_stone" }) },
                { body("character_bandit", 2, 4, {}) })
            local a, foe = c.units[1], c.units[2]
            deep(a); deep(foe)
            foe.char.stats.health.max, foe.char.stats.health.current = 999, 999
            openTurn(c, a)
            local base = Combat.previewAbility(c, a, cell(a, 1), foe.x, foe.y).entries[foe].damage
            Combat.tally(a, "turnTaken", 2)
            assert(Combat.chargePool(a, "storm") == 2, "two turns, two Storm")
            local preview = Combat.previewAbility(c, a, cell(a, 1), foe.x, foe.y).entries[foe].damage
            assert(preview > base, "two Storm make the bolt bigger: " .. preview .. " vs " .. base)
            local ok, r = Combat.useItem(c, a, cell(a, 1), foe.x, foe.y)
            assert(ok and r.damageDealt == preview, "the bolt lands what the forecast quoted")
            assert(Combat.chargePool(a, "storm") == 0, "and spends the Storm")
            assert(Combat.tallyCount(a, "stormSpent") == 2, "Static Focus counts two spent")
        end,
    },
    {
        name = "Storm Vessel: a Deep Vessel beside it holds five, and Outpour turns Storm into mana",
        fn = function()
            local c = fight({ body("character_mage", 2, 2,
                    { [1] = "utility_deep_vessel", [2] = "utility_resonance_prism", [9] = "ability_jolt" }) },
                { body("character_bandit", 8, 8, {}) })
            local a = c.units[1]
            deep(a)
            Combat.tally(a, "turnTaken", 7)
            assert(Combat.chargePool(a, "storm") == 5, "beside the vessel the pool holds five")
            a.char.inventory[1], a.char.inventory[7] = nil, a.char.inventory[1]
            assert(Combat.chargePool(a, "storm") == 3, "away from it, three")
            a.char.stats.mana.current = 0
            openTurn(c, a)
            assert(Combat.useItem(c, a, cell(a, 9), a.x, a.y), "Outpour")
            assert(a.char.stats.mana.current == 12, "3 Storm are 12 mana, got " .. a.char.stats.mana.current)
        end,
    },

    -- ------------------------------------------------------------------------------- Overflow
    {
        name = "Overflow: healing past full banks Radiance on the healer, and the Reliquary spends it on a heal",
        fn = function()
            local c = fight({ body("character_priest", 2, 2,
                    { [1] = "ability_heal", [2] = "utility_reliquary_of_tallies" }),
                    body("character_rowan", 2, 3, {}) }, {})
            local p, ally = c.units[1], c.units[2]
            deep(p)
            openTurn(c, p)
            assert(Combat.useItem(c, p, cell(p, 1), ally.x, ally.y), "a heal on a full ally")
            local banked = Combat.chargePool(p, "radiance")
            assert(banked > 0, "the whole heal overflowed into Radiance")
            ally.char.stats.health.current = 1
            openTurn(c, p)
            assert(Combat.useItem(c, p, cell(p, 2), ally.x, ally.y), "the reliquary heals")
            assert(ally.char.stats.health.current == 1 + banked, "for what was banked")
            assert(Combat.chargePool(p, "radiance") == 0, "and its own heal banks nothing back")
        end,
    },
    {
        name = "Overflow: the Brimming Chalice turns overheal into barrier, the Censer Chain splashes a heal",
        fn = function()
            local c = fight({ body("character_priest", 2, 2,
                    { [1] = "ability_heal", [2] = "armor_warding_chasuble", [4] = "armor_censer_cloth_habit" }),
                    body("character_rowan", 2, 4, {}), body("character_rowan", 3, 4, {}) }, {})
            local p, ally, beside = c.units[1], c.units[2], c.units[3]
            deep(p)
            beside.char.stats.health.current = 1
            openTurn(c, p)
            assert(Combat.useItem(c, p, cell(p, 1), ally.x, ally.y), "a heal on a full ally")
            assert(Engine.barrierPool(ally) > 0, "the overflow becomes barrier on the patient")
            assert(beside.char.stats.health.current > 1, "the chain heals the body beside it too")
        end,
    },
    {
        name = "Overflow: Judgement throws Radiance as raw holy damage; Aegis of Plenty lays it as shared barrier",
        fn = function()
            local c = fight({ body("character_priest", 2, 2,
                    { [1] = "ability_judgement", [2] = "ability_aegis_of_plenty", [3] = "utility_reliquary_of_tallies" }),
                    body("character_rowan", 2, 1, {}) },
                { body("character_bandit", 2, 4, {}) })
            local p, ally, foe = c.units[1], c.units[2], c.units[3]
            deep(p); deep(foe)
            foe.char.stats.defense = 50
            Combat.tally(p, "overheal", 10)
            openTurn(c, p)
            local ok, r = Combat.useItem(c, p, cell(p, 1), foe.x, foe.y)
            assert(ok and r.damageDealt == 15, "10 Radiance land 15 raw through 50 defense, got " .. tostring(r and r.damageDealt))
            Combat.tally(p, "overheal", 10)
            openTurn(c, p)
            assert(Combat.useItem(c, p, cell(p, 2), p.x, p.y), "the aegis")
            assert(Engine.barrierPool(ally) >= 10, "the lone ally beside takes all of it")
        end,
    },
    {
        name = "Overflow: the Overflowing Cup banks chi from overheal; the Votive Flame grows a channel",
        fn = function()
            local c = fight({ body("character_priest", 2, 2,
                    { [1] = "ability_heal", [2] = "utility_overflowing_cup", [3] = "utility_votive_flame" }),
                    body("character_rowan", 2, 3, {}) }, {})
            local p, ally = c.units[1], c.units[2]
            deep(p)
            openTurn(c, p)
            assert(Combat.useItem(c, p, cell(p, 1), ally.x, ally.y), "a heal on a full ally")
            assert(Combat.chi(p) == 1, "one overhealing heal, one chi")
            Combat.tally(p, "overheal", 8)
            local pending = { windup = 4, held = 0 }
            Engine.onChannelResolve(c, p, pending)
            assert(pending.windup > 4 and pending.held > 0, "Radiance grew the wind-up")
            assert(Combat.chargePool(p, "radiance") == 0, "and was spent doing it")
        end,
    },

    -- ------------------------------------------------------------------------------- Rampart
    {
        name = "Rampart: barrier pays a blow down, Entrench doubles it, Shield Slam hits for it, Bastion keeps it",
        fn = function()
            local c = fight({ body("character_rowan", 2, 2,
                    { [1] = "ability_entrench", [2] = "utility_forty_one_marks", [3] = "utility_closed_entry" }) },
                { body("character_bandit", 2, 3, {}) })
            local k, foe = c.units[1], c.units[2]
            deep(k); deep(foe)
            k.char.stats.defense = 0
            Engine.grantBarrier(c, k, 6)
            local st = Status.get(k, "status_physical_barrier")
            assert(st and st.remaining > 1000, "the Bastion Plate keeps the pool from timing out")
            openTurn(c, k)
            assert(Combat.useItem(c, k, cell(k, 1), k.x, k.y), "entrench")
            assert(Engine.barrierPool(k) == 12, "doubled, got " .. Engine.barrierPool(k))
            assert(Status.has(k, "status_root"), "and rooted")
            foe.char.stats.defense = 50
            openTurn(c, k)
            local ok, r = Combat.useItem(c, k, cell(k, 2), foe.x, foe.y)
            assert(ok and r.damageDealt == 12, "the slam lands its barrier raw, got " .. tostring(r and r.damageDealt))
            assert(Engine.barrierPool(k) == 12, "and keeps it")
            local hp = k.char.stats.health.current
            Combat.dealFlatDamage(c, k, 5, { "physical" }, "test")
            -- What armour leaves of the blow is what the pool pays (the Bastion Plate is a point of defense).
            assert(k.char.stats.health.current == hp and Engine.barrierPool(k) < 12, "a blow is paid from the pool")
        end,
    },
    {
        name = "Rampart: the Buckle raises barrier per adjacent shield; a guard banks what it took; a Paladin shares",
        fn = function()
            local c = fight({ body("character_rowan", 2, 2,
                    { [1] = "armor_buckler", [2] = "utility_relief_order", [3] = "armor_tower_shield" }),
                    body("character_rowan", 6, 6, { [1] = "ability_aegis_of_plenty" }),
                    body("character_rowan", 6, 7, {}) },
                { body("character_bandit", 2, 3, {}) })
            local k, pal, ward = c.units[1], c.units[2], c.units[3]
            deep(k)
            ward.char.stats.defense = 0
            Combat.dealFlatDamage(c, k, 1, { "physical" }, "test")
            assert(Engine.barrierPool(k) >= 6, "two shields beside the buckle, 3 each, got " .. Engine.barrierPool(k))
            local sentinel = Fixture.unit("character_rowan", 0, 0, { isolate = "bare", items = { "armor_wardens_oath" } })
            assert(Trait.defs.trait_guard_barrier.guardBarrier, "the Warden's Oath banks a guarded blow")
            assert(sentinel.char.inventory[1].traits[2] == "trait_guard_barrier", "and carries it")
            Engine.grantBarrier(c, pal, 8)
            assert(Engine.barrierPool(ward) == 8, "the paladin's pool covers the ally beside it")
            local hp = ward.char.stats.health.current
            Combat.dealFlatDamage(c, ward, 5, { "physical" }, "test")
            assert(ward.char.stats.health.current == hp and Engine.barrierPool(pal) == 3, "paid from the paladin's pool")
        end,
    },

    -- ------------------------------------------------------------------------------- Reactions
    {
        name = "Reactions: fire on an Oiled body explodes; a hammer on a Chilled body shatters its armour",
        fn = function()
            local c = fight({ body("character_rowan", 2, 2, { [1] = "weapon_iron_hammer" }) },
                { body("character_bandit", 2, 3, {}), body("character_bandit", 3, 3, {}) })
            local a, f1, f2 = c.units[1], c.units[2], c.units[3]
            deep(a); deep(f1); deep(f2)
            Status.apply(c, f1, "status_oiled")
            local hp2 = f2.char.stats.health.current
            Combat.dealFlatDamage(c, f1, 3, { "fire" }, "test", a)
            assert(not Status.has(f1, "status_oiled"), "the oil is spent")
            assert(f2.char.stats.health.current < hp2, "the blast catches the body beside it")
            Status.apply(c, f1, "status_chilled")
            f1.char.stats.defense = 30
            openTurn(c, a)
            assert(Combat.useItem(c, a, cell(a, 1), f1.x, f1.y), "the hammer lands")
            assert(Status.has(f1, "status_shattered"), "the chill shatters")
            assert(Combat.flatStat(f1, "defense") == 0, "and its armour reads 0")
        end,
    },
    {
        name = "Reactions: the Arc Rod jumps to Wet foes, the Reagent Vest lengthens, Reactive Salts lay Rime",
        fn = function()
            local c = fight({ body("character_rowan", 2, 2,
                    { [1] = "weapon_arc_rod", [2] = "armor_reagent_vest", [3] = "consumable_elixir_of_the_giant",
                      [4] = "utility_reactive_salts", [5] = "consumable_ice_bomb" }) },
                { body("character_bandit", 2, 4, {}), body("character_bandit", 3, 5, {}), body("character_bandit", 8, 8, {}) })
            local a, f1, f2, far = c.units[1], c.units[2], c.units[3], c.units[4]
            deep(a); deep(f1); deep(f2)
            Status.apply(c, f2, "status_wet")
            local hp2 = f2.char.stats.health.current
            openTurn(c, a)
            assert(Combat.useItem(c, a, cell(a, 1), f1.x, f1.y), "the rod fires")
            assert(f2.char.stats.health.current < hp2, "the bolt jumps to the Wet foe")
            openTurn(c, a)
            assert(Combat.useItem(c, a, cell(a, 3), f1.x, f1.y), "the rime draught lands")
            local chilled = Status.get(f1, "status_chilled")
            assert(chilled and chilled.remaining >= Status.defs.status_chilled.duration + 5,
                "the vest beside it adds a turn")
            openTurn(c, a)
            assert(Combat.useItem(c, a, cell(a, 5), f1.x, f1.y), "the ice bomb")
            assert(Status.has(f2, "status_chilled"), "the salts leave the blast Chilled")
            assert(not Status.has(far, "status_chilled"), "and nobody outside it")
        end,
    },

    -- ------------------------------------------------------------------------------- Grid jokers
    {
        name = "Jokers: the Mirror Shard copies the traits to its right; the Hollow Idol pays for empty cells",
        fn = function()
            local c = fight({ body("character_rowan", 2, 2,
                    { [1] = "utility_mirror_shard", [2] = "utility_scab", [4] = "utility_overreach", [5] = "ability_power_strike" }) },
                { body("character_bandit", 2, 3, {}) })
            local a, foe = c.units[1], c.units[2]
            local n = 0
            for _, t in ipairs(a.traits) do if t.id == "trait_scab" then n = n + 1 end end
            assert(n == 2, "the shard carries a second Scab, got " .. n)
            local strike = cell(a, 5)
            local lean = Combat.computeDamage(c, a, foe, strike)
            a.char.inventory[9] = Item.instantiate("utility_scab")
            local fuller = Combat.computeDamage(c, a, foe, strike)
            assert(lean == fuller + 2, "one more item, one fewer empty cell, 2 less: " .. lean .. " vs " .. fuller)
        end,
    },
    {
        name = "Jokers: the Keystone raises its neighbours a forge level from the centre only",
        fn = function()
            local char = Character.instantiate("character_rowan")
            char.inventory = {}
            char.inventory[4] = Item.instantiate("ability_power_strike")
            char.inventory[5] = Item.instantiate("utility_keystone")
            local u = { char = char }
            local step = Engine.forgeStep(char.inventory[4])
            assert(step > 0, "a forge level is worth something")
            local c = fight({ { char = char, x = 2, y = 2 } }, { body("character_bandit", 2, 3, {}) })
            local a, foe = c.units[1], c.units[2]
            a.char.inventory[6] = Item.instantiate("weapon_iron_sword") -- the strike's melee weapon
            openTurn(c, a)
            local centred = Combat.previewAbility(c, a, cell(a, 4), foe.x, foe.y).entries[foe].damage
            a.char.inventory[1], a.char.inventory[5] = a.char.inventory[5], nil
            local off = Combat.previewAbility(c, a, cell(a, 4), foe.x, foe.y).entries[foe].damage
            assert(centred > off, "the keystone speaks only from the centre: " .. centred .. " vs " .. off)
            assert(u)
        end,
    },
    {
        name = "Jokers: the Relay Sigil fires the far end of its row at the same mark, once a turn",
        fn = function()
            local c = fight({ body("character_mage", 2, 2,
                    { [1] = "ability_fire_bolt", [2] = "utility_quickened_sigil", [3] = "ability_fire_bolt" }) },
                { body("character_bandit", 2, 4, {}) })
            local a, foe = c.units[1], c.units[2]
            deep(a); deep(foe)
            foe.char.stats.health.max, foe.char.stats.health.current = 999, 999
            local mana = a.char.stats.mana.current
            openTurn(c, a)
            local ok, r = Combat.useItem(c, a, cell(a, 1), foe.x, foe.y)
            assert(ok, "the bolt is cast")
            local cost = Item.costs(cell(a, 1).activeAbility)[1].amount
            assert(a.char.stats.mana.current == mana - cost, "only one bolt is paid for")
            assert(999 - foe.char.stats.health.current > r.damageDealt, "but two land")
        end,
    },
    -- ------------------------------------------------------------------------------- the bestiary
    {
        -- THE BESTIARY PASS, MEASURED (docs/engines.md, "What enemies ask for"). Each engine is an answer to
        -- a kind of fight, and this holds the shipped roster to having that kind of fight in it: plate
        -- for the raw payoffs, packs for Tempo and the Reaper, bosses for the slow engines, and wet or
        -- burnable ground for the Reactions. A roster that lost one would leave an engine with nothing to
        -- be right about.
        name = "every engine has foes on the shipped roster that it answers",
        fn = function()
            local plate, bosses = 0, 0
            for _, def in pairs(Character.defs) do
                local st = def.stats or {}
                if type(st.defense) == "number" and st.defense >= 12 then plate = plate + 1 end
                if def.boss then bosses = bosses + 1 end
            end
            assert(plate >= 5, "armour walls for Bloodletting, Shield Slam and the Rime Draught: " .. plate)
            assert(bosses >= 5, "bosses for the Storm Vessel and Blood Price: " .. bosses)
            local packs = 0
            for _, name in ipairs(love.filesystem.getDirectoryItems("data/encounters")) do
                local src = love.filesystem.read("data/encounters/" .. name) or ""
                for base in src:gmatch("base%s*=%s*(%d+)") do
                    if tonumber(base) >= 3 then packs = packs + 1 break end
                end
            end
            assert(packs >= 10, "packs of three or more for Tempo and the Reaper: " .. packs)
            local Terrain = require("models.terrain")
            local wet, burn = 0, 0
            for _, t in pairs(Terrain.TYPES) do
                for _, tag in ipairs(t.tags or {}) do
                    if tag == "conductable" then wet = wet + 1 end
                    if tag == "burnable" then burn = burn + 1 end
                end
            end
            assert(wet > 0 and burn > 0, "wet and burnable ground for the Reactions")
        end,
    },
}
