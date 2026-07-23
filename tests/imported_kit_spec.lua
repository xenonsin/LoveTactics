-- Tests for the four new engine mechanics -- Sunder, the Unclosing Wound, the Sealed Ward and
-- Witchlight -- and for the items and statuses built on top of them that could not be verified by the
-- catalog sweeps alone.
--
-- The sweeps in tests/item_schema_spec.lua and tests/class_spec.lua prove every new blueprint is
-- WELL-FORMED. Nothing there proves any of it WORKS, and most of this kit turns on rules that live in
-- models/combat.lua rather than in the data file -- a status flag read at one chokepoint, a hook fired
-- from one place. Those are exactly the things a data-only test cannot see, so they are all here.
--
-- Pure logic, headless. Fixture style borrowed from tests/new_items_spec.lua.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")
local Trait = require("models.trait")

local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0, startX = u.x, startY = u.y }
end

local function equip(char, ids)
    char.inventory = {}
    for _, id in ipairs(ids) do Character.addItem(char, Item.instantiate(id)) end
    return char
end

-- A character stripped of its blueprint kit, so the body under test answers for itself rather than
-- having a knight's stock reflexes intercept what is being measured.
local function bare(id)
    local char = Character.instantiate(id)
    char.inventory = {}
    return char
end

local function itemNamed(char, id)
    for i = 1, Character.MAX_INVENTORY do
        local it = char.inventory[i]
        if it and it.id == id then return it end
    end
    return nil
end

local function hp(u) return u.char.stats.health.current end

return {
    -- ------------------------------------------------------------------ Sunder (the trait break)
    {
        name = "Sundered silences every trait a body carries -- including its answer to being sundered",
        fn = function()
            -- Spike Mail carries Thorns: survive a melee blow and the attacker takes a share back.
            local function fight()
                local wearer = equip(bare("character_knight"), { "armor_spike_mail" })
                local c = Combat.new(arena(8, 8), { unit(wearer, 3, 3) }, { unit(bare("character_bandit"), 3, 4) })
                return c, c.units[1], c.units[2]
            end

            -- A big blow on purpose: Thorns reflects a PERCENTAGE of what actually landed, and a knight's
            -- armor takes a small hit down to the floor of 1 -- 40% of which rounds to nothing and the
            -- spikes decline to bite at all (see data/traits/trait_thorns.lua). A test that measured
            -- the reflection of a scratch would be measuring the rounding.
            local c1, guard, foe = fight()
            local before = hp(foe)
            Combat.dealFlatDamage(c1, guard, 40, { "physical" }, nil, foe)
            assert(hp(foe) < before, "unhindered, the spikes bite back")

            local c2, guard2, foe2 = fight()
            Status.apply(c2, guard2, "status_sundered")
            local before2 = hp(foe2)
            Combat.dealFlatDamage(c2, guard2, 40, { "physical" }, nil, foe2)
            assert(hp(foe2) == before2, "a sundered guard's thorns do not answer")
        end,
    },
    {
        name = "Sunder reaches onStatusApplied, which the ordinary reaction gate deliberately does not",
        fn = function()
            -- The distinction the two flags exist to draw (see Status.traitsDisabled): a STUNNED body
            -- still runs onStatusApplied so a cleansing ward can shrug off the stun that landed, and a
            -- SUNDERED one does not.
            local c = Combat.new(arena(8, 8), { unit(bare("character_knight"), 3, 3) },
                { unit(bare("character_bandit"), 6, 6) })
            local u = c.units[1]
            local fired = 0
            u.traits = { { id = "probe", name = "probe", def = {
                onStatusApplied = function() fired = fired + 1 end,
            } } }

            Status.apply(c, u, "status_stun")
            assert(fired > 0, "a rattled body still hears a status land")

            local seen = fired
            Status.apply(c, u, "status_sundered")
            Status.apply(c, u, "status_poison")
            assert(fired == seen, "a sundered body hears nothing at all")
        end,
    },

    -- ------------------------------------------------- the Unclosing Wound (the heal block)
    {
        name = "an Unclosing Wound refuses every mend, whatever the source",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit(bare("character_knight"), 3, 3) },
                { unit(bare("character_bandit"), 6, 6) })
            local u = c.units[1]
            u.char.stats.health.current = 20

            assert(Combat.applyHeal(c, u, 15) == 15, "an ordinary mend lands")
            assert(hp(u) == 35, "and moves the bar")

            Status.apply(c, u, "status_unclosing_wound")
            assert(Combat.applyHeal(c, u, 15) == 0, "the wound refuses the mend")
            assert(hp(u) == 35, "and the bar does not move")

            -- Cleansable like any debuff: this takes a window away, not a healer.
            Combat.cleanse(c, u)
            assert(Combat.applyHeal(c, u, 10) == 10, "cured, the body mends again")
        end,
    },
    {
        name = "Thinblood Rime coats an adjacent blade, and its hits stop the target being healed",
        fn = function()
            -- The coating sits BESIDE the weapon in the 3x3 grid: slot 1 holds the blade, slot 2 the
            -- phial, and Combat.auraApplies is what carries one onto the other.
            local alch = equip(bare("character_knight"), { "weapon_iron_sword", "consumable_thinblood_rime" })
            local c = Combat.new(arena(8, 8), { unit(alch, 3, 3) }, { unit(bare("character_bandit"), 3, 4) })
            local striker, victim = c.units[1], c.units[2]
            openTurn(c, striker)

            assert(Combat.useItem(c, striker, itemNamed(alch, "weapon_iron_sword"), 3, 4), "the blade lands")
            assert(Status.has(victim, "status_unclosing_wound"),
                "the coated blade opens a wound that will not close")
        end,
    },

    -- ------------------------------------------------------ the Sealed Ward (the spell block)
    {
        name = "a Sealed Ward swallows a single-target spell whole, and spends itself doing it",
        fn = function()
            local caster = equip(bare("character_mage"), { "ability_fire_bolt" })
            local warded = bare("character_bandit")
            local c = Combat.new(arena(8, 8), { unit(caster, 3, 3) }, { unit(warded, 3, 5) })
            local mage, foe = c.units[1], c.units[2]
            Status.apply(c, foe, "status_sealed_ward")
            local before = hp(foe)
            openTurn(c, mage)

            assert(Combat.useItem(c, mage, itemNamed(caster, "ability_fire_bolt"), 3, 5), "the cast resolves")
            assert(hp(foe) == before, "the seal refused the working entirely")
            assert(not Status.castWardOn(foe), "and spent itself doing so")
        end,
    },
    {
        name = "an area cast goes straight past a Sealed Ward -- the standing counterplay",
        fn = function()
            local caster = equip(bare("character_mage"), { "ability_fireball" })
            local c = Combat.new(arena(8, 8), { unit(caster, 3, 3) }, { unit(bare("character_bandit"), 3, 5) })
            local mage, foe = c.units[1], c.units[2]
            Status.apply(c, foe, "status_sealed_ward")
            local before = hp(foe)
            openTurn(c, mage)

            -- Fireball channels, so resolve the wind-up rather than reading the cast's return.
            Combat.useItem(c, mage, itemNamed(caster, "ability_fireball"), 3, 5)
            if mage.channel then Combat.resolveChannel(c, mage) end
            assert(hp(foe) < before, "a blast does not aim at anybody, so the seal has nothing to refuse")
            assert(Status.castWardOn(foe), "and the seal is still standing, unspent")
        end,
    },

    -- ---------------------------------------------------------------- Witchlight (true sight)
    {
        name = "Witchlight makes a hidden body targetable without taking its concealment away",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit(bare("character_knight"), 3, 3) },
                { unit(bare("character_bandit"), 5, 5) })
            local hidden = c.units[2]

            Status.apply(c, hidden, "status_invisible")
            assert(Status.untargetable(hidden), "hidden, it cannot be aimed at")

            Status.apply(c, hidden, "status_limned")
            assert(not Status.untargetable(hidden), "lit, it can")
            assert(Status.has(hidden, "status_invisible"),
                "and it is still hiding -- only the untargetability is overruled")
        end,
    },
    {
        name = "a Witchlight Flare lays ground that keeps whoever stands in it lit",
        fn = function()
            local thrower = equip(bare("character_knight"), { "consumable_witchlight_flare" })
            local c = Combat.new(arena(8, 8), { unit(thrower, 2, 2) }, { unit(bare("character_bandit"), 4, 2) })
            local lighter, sneak = c.units[1], c.units[2]
            Status.apply(c, sneak, "status_invisible")
            openTurn(c, lighter)

            assert(Combat.useItem(c, lighter, itemNamed(thrower, "consumable_witchlight_flare"), 4, 2),
                "the flare lands")
            assert(Status.has(sneak, "status_limned"), "the ground lights whoever is standing in it")
            assert(not Status.untargetable(sneak), "and a lit body can be aimed at")
        end,
    },

    -- ------------------------------------------------------------- the deferral (Sealed Hour)
    {
        name = "a Sealed Hour banks damage instead of landing it, and settles the ledger on expiry",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit(bare("character_knight"), 3, 3) },
                { unit(bare("character_bandit"), 6, 6) })
            local u = c.units[1]
            u.char.stats.health.current = 40
            Status.apply(c, u, "status_sealed_hour")

            Combat.dealFlatDamage(c, u, 12, nil, "probe")
            Combat.dealFlatDamage(c, u, 12, nil, "probe")
            assert(hp(u) == 40, "nothing reaches the body while the hour holds")

            local ledger = Status.get(u, "status_sealed_hour").ledger
            assert(ledger and ledger > 0, "but it is all on the ledger, got " .. tostring(ledger))

            Status.remove(c, u, "status_sealed_hour")
            assert(hp(u) == 40 - ledger, "and the whole account settles at once")
        end,
    },
    {
        name = "mending poured into a Sealed Hour is held too, and lands whole when it ends",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit(bare("character_knight"), 3, 3) },
                { unit(bare("character_bandit"), 6, 6) })
            local u = c.units[1]
            u.char.stats.health.current = 30
            Status.apply(c, u, "status_sealed_hour")

            Combat.dealFlatDamage(c, u, 10, nil, "probe")
            Combat.applyHeal(c, u, 25)
            assert(hp(u) == 30, "neither the wound nor the mend has landed yet")

            Status.remove(c, u, "status_sealed_hour")
            assert(hp(u) > 30, "a net-negative ledger mends: the wager was won")
        end,
    },

    -- ------------------------------------------------------------ the wards (Kept, Splitglass)
    {
        name = "a Kept Wound absorbs blows and then bursts for everything it swallowed",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit(bare("character_knight"), 3, 3) },
                { unit(bare("character_bandit"), 3, 4), unit(bare("character_bandit"), 4, 3) })
            local ward, near, alsoNear = c.units[1], c.units[2], c.units[3]
            Status.apply(c, ward, "status_kept_wound", { magnitude = 2 })
            local wardHp = hp(ward)
            local nearHp, alsoHp = hp(near), hp(alsoNear)

            Combat.dealFlatDamage(c, ward, 18, { "physical" }, "probe")
            assert(hp(ward) == wardHp, "the ward swallows the blow")
            Combat.dealFlatDamage(c, ward, 18, { "physical" }, "probe")
            assert(hp(ward) == wardHp, "and the second one")
            assert(not Status.has(ward, "status_kept_wound"), "spending its last charge ends it")

            assert(hp(near) < nearHp and hp(alsoNear) < alsoHp,
                "and everything standing beside the bearer takes what it kept")
        end,
    },
    {
        name = "Splitglass turns aside both schools, where a single-school barrier turns aside one",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit(bare("character_knight"), 3, 3) },
                { unit(bare("character_bandit"), 6, 6) })
            local u = c.units[1]
            Status.apply(c, u, "status_splitglass", { magnitude = 2 })
            local before = hp(u)

            Combat.dealFlatDamage(c, u, 14, { "physical" }, "probe")
            assert(hp(u) == before, "steel is turned aside")
            Combat.dealFlatDamage(c, u, 14, { "magical" }, "probe")
            assert(hp(u) == before, "and so is magic -- the glass does not ask")
            assert(not Status.has(u, "status_splitglass"), "two charges, two hits")

            Combat.dealFlatDamage(c, u, 14, { "magical" }, "probe")
            assert(hp(u) < before, "the third lands")
        end,
    },

    -- ------------------------------------------------------------------- Rimebitten (on-hit)
    {
        name = "Rimebitten bites every time anything lands on its bearer",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit(bare("character_knight"), 3, 3) },
                { unit(bare("character_bandit"), 6, 6) })
            local u = c.units[1]
            u.char.stats.health.current = 60

            Combat.dealFlatDamage(c, u, 10, { "physical" }, "probe")
            local plain = 60 - hp(u)

            u.char.stats.health.current = 60
            Status.apply(c, u, "status_rimebitten", { magnitude = 6 })
            Combat.dealFlatDamage(c, u, 10, { "physical" }, "probe")
            local bitten = 60 - hp(u)

            assert(bitten == plain + 6,
                "the same blow costs six more under the rime, got " .. bitten .. " vs " .. plain)
        end,
    },

    -- ------------------------------------------------------------------- phasing (the greaves)
    {
        name = "Sidelong Greaves walk through an enemy body, but never stop on one",
        fn = function()
            -- A corridor one tile wide, with a foe standing in the middle of it.
            local a = arena(6, 1)
            local walker = equip(bare("character_knight"), { "utility_sidelong_greaves" })
            walker.stats.movement = 4

            local blocked = Combat.new(a, { unit(bare("character_knight"), 1, 1) },
                { unit(bare("character_bandit"), 3, 1) })
            blocked.units[1].char.stats.movement = 4
            local wallOff = Combat.reachable(blocked, blocked.units[1])
            assert(not wallOff["4,1"], "an ordinary walker cannot get past a body in a corridor")

            local through = Combat.new(a, { unit(walker, 1, 1) }, { unit(bare("character_bandit"), 3, 1) })
            local reach = Combat.reachable(through, through.units[1])
            assert(reach["4,1"], "the greaves walk straight through it")
            assert(not reach["3,1"], "but the occupied tile is still no place to stop")
        end,
    },

    -- ---------------------------------------------------------------- recall (Backward Glance)
    {
        name = "the Backward Glance sends a body to where its PREVIOUS turn opened, not this one",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit(bare("character_knight"), 3, 3) },
                { unit(bare("character_bandit"), 6, 6) })
            local u = c.units[2]

            -- First turn opens: there is no "before" yet, so there is nothing to be sent back to.
            u.turnStartX, u.turnStartY = u.x, u.y
            assert(Combat.recall(c, u) == false, "a body in its first turn has no past to be put back to")

            -- It walks, and a second turn opens: now the older of the two remembered tiles is (6,6).
            u.x, u.y = 4, 4
            u.priorX, u.priorY = u.turnStartX, u.turnStartY
            u.turnStartX, u.turnStartY = u.x, u.y
            u.x, u.y = 3, 4

            assert(Combat.recall(c, u), "the glance lands")
            assert(u.x == 6 and u.y == 6, "and it is back where the previous turn opened")
        end,
    },

    -- -------------------------------------------------------------- the bounty (Struck Ledger)
    {
        name = "a Struck Ledger pays the company when its bearer falls, and lights it until then",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit(bare("character_knight"), 3, 3) },
                { unit(bare("character_bandit"), 3, 4) })
            local killer, marked = c.units[1], c.units[2]
            Status.apply(c, marked, "status_struck_ledger", { magnitude = 60 })

            Status.apply(c, marked, "status_invisible")
            assert(not Status.untargetable(marked), "a priced body does not get to hide")

            assert((c.bounty or 0) == 0, "nothing is owed yet")
            Combat.dealFlatDamage(c, marked, 9999, nil, "probe", killer)
            assert(not marked.alive, "the mark falls")
            assert(c.bounty == 60, "and the price is collected, got " .. tostring(c.bounty))
        end,
    },

    -- ------------------------------------------------------- onAnyCast (the Gaunt Vigil, and the rod)
    {
        name = "a Gaunt Vigil bites a caster who works a spell near it, and ignores a swung blade",
        fn = function()
            local caster = equip(bare("character_mage"), { "ability_fire_bolt", "weapon_iron_sword" })
            local vigil = equip(Character.instantiate("character_gaunt_vigil"), { "utility_vigil_ward" })
            local c = Combat.new(arena(8, 8), { unit(caster, 3, 3) }, { unit(vigil, 4, 3) })
            local mage = c.units[1]
            Trait.attach(c.units[2])

            local before = hp(mage)
            openTurn(c, mage)
            Combat.useItem(c, mage, itemNamed(caster, "weapon_iron_sword"), 4, 3)
            assert(hp(mage) == before, "the vigil has no objection to a sword")

            openTurn(c, mage)
            Combat.useItem(c, mage, itemNamed(caster, "ability_fire_bolt"), 4, 3)
            assert(hp(mage) < before, "but it objects to a working")
        end,
    },
    {
        name = "the Gleaning Rod banks a charge off somebody else's spell, and spends the purse at once",
        fn = function()
            local holder = equip(bare("character_knight"), { "utility_gleaning_rod" })
            local caster = equip(bare("character_mage"), { "ability_fire_bolt" })
            local c = Combat.new(arena(8, 8), { unit(holder, 3, 3), unit(caster, 3, 4) },
                { unit(bare("character_bandit"), 3, 6) })
            local bearer, mage = c.units[1], c.units[2]
            local rod = itemNamed(holder, "utility_gleaning_rod")

            assert((rod.charges or 0) == 0, "the rod starts dry")
            openTurn(c, mage)
            Combat.useItem(c, mage, itemNamed(caster, "ability_fire_bolt"), 3, 6)
            assert((rod.charges or 0) == 1, "an ally's working fills it too")

            openTurn(c, bearer)
            Combat.useItem(c, bearer, rod, 3, 6)
            assert((rod.charges or 0) == 0, "and firing empties the purse entirely")
        end,
    },

    -- ------------------------------------------------------ the fighter's two (cull, and the whirl)
    {
        name = "the Culling Stroke executes below its window and hands the turn straight back",
        fn = function()
            local fighter = equip(bare("character_champion"), { "ability_culling_stroke", "weapon_iron_axe" })
            local c = Combat.new(arena(8, 8), { unit(fighter, 3, 3) }, { unit(bare("character_bandit"), 3, 4) })
            local killer, prey = c.units[1], c.units[2]
            prey.char.stats.health.current = math.floor(prey.char.stats.health.max * 0.1)
            openTurn(c, killer)

            local turnsBefore = c.turnCount
            Combat.useItem(c, killer, itemNamed(fighter, "ability_culling_stroke"), 3, 4)
            assert(not prey.alive, "a body inside the window is simply finished")
            -- The grant is SPENT by the endTurn the same cast runs (see the surge branch there), so
            -- what a caller can observe is not a leftover counter -- it is that the turn did not end:
            -- the same unit still holds an open turn, and the turn count has not moved. Asserting on
            -- `extraActions` would be asserting on a number that is correctly always zero by now.
            assert(c.turn and c.turn.unit == killer, "the turn is handed straight back to the killer")
            assert(c.turnCount == turnsBefore, "one turn with two actions in it, not two turns")
            assert(c.turn.moved, "and a surge buys an action, never a second walk")
        end,
    },
    {
        name = "Whirlplate answers a melee blow by cutting everything adjacent, not only the attacker",
        fn = function()
            local wearer = equip(bare("character_champion"), { "armor_whirlplate", "weapon_iron_axe" })
            local c = Combat.new(arena(8, 8), { unit(wearer, 3, 3) },
                { unit(bare("character_bandit"), 3, 4), unit(bare("character_bandit"), 4, 3) })
            local guard, attacker, bystander = c.units[1], c.units[2], c.units[3]
            local attackerHp, bystanderHp = hp(attacker), hp(bystander)

            Combat.dealFlatDamage(c, guard, 8, { "physical" }, nil, attacker)
            assert(hp(attacker) < attackerHp, "the attacker is answered")
            assert(hp(bystander) < bystanderHp, "and so is the one who merely stood too close")
        end,
    },

    -- ----------------------------------------------------------------------- Duelbound (the knight)
    {
        name = "Single Combat roots both, and the survivor keeps something of the other",
        fn = function()
            local knight = equip(bare("character_knight"), { "ability_single_combat", "weapon_iron_sword" })
            local c = Combat.new(arena(8, 8), { unit(knight, 3, 3) }, { unit(bare("character_bandit"), 3, 4) })
            local caller, called = c.units[1], c.units[2]
            openTurn(c, caller)

            assert(Combat.useItem(c, caller, itemNamed(knight, "ability_single_combat"), 3, 4), "the call lands")
            assert(Status.has(caller, "status_duelbound") and Status.has(called, "status_duelbound"),
                "both are bound")
            assert(Status.blocksMove(caller) and Status.blocksMove(called), "and neither may walk away")

            local before = Combat.flatStat(caller, "damage")
            called.alive = false
            Status.remove(c, caller, "status_duelbound")
            assert(Combat.flatStat(caller, "damage") > before,
                "outliving the other is what pays, however they fell")
        end,
    },
}
