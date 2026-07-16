-- Tests for the weapon archetype contract (docs/weapons.md). Two halves:
--
--   1. A SWEEP over every weapon blueprint, asserting each one keeps the mechanics its family owes.
--      This is what makes the doc enforced rather than aspirational: a new axe that forgets to cleave,
--      or a weapon that names no family at all, fails the build rather than quietly drifting.
--   2. Per-family behaviour cases for the mechanics this contract introduced -- Bleed's per-tile
--      damage, the staff's Focus swap, the wand's magical routing, and the sword's Parry / the
--      Riposte Blade's deflect-and-answer.
--
-- Pure logic, headless. Fixture style mirrors tests/combat_spec.lua and tests/knockback_spec.lua.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")
local Trait = require("models.trait")

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

-- A character with an EMPTY grid, so a case controls exactly what its units carry. Every item can
-- carry traits and stats to its holder (a knight's relic, and now every sword's Parry), so an empty
-- grid is the only clean baseline -- mirrors tests/trait_spec.lua's plainChar.
local function plainChar(id)
    local char = Character.instantiate(id)
    for i = 1, Character.MAX_INVENTORY do char.inventory[i] = nil end
    return char
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

-- Put `id` in `char`'s first grid cell and return the instance.
local function give(char, id)
    local item = Item.instantiate(id)
    char.inventory[1] = item
    return item
end

local function hp(u) return u.char.stats.health.current end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- Every weapon blueprint, as { id, def } pairs.
local function eachWeapon()
    local out = {}
    for id, def in pairs(Item.defs) do
        if def.type == "weapon" then out[#out + 1] = { id = id, def = def } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

return {
    -- ---------------------------------------------------------------- the contract sweep
    {
        name = "every weapon declares exactly one archetype (the family it inherits its mechanics from)",
        fn = function()
            local weapons = eachWeapon()
            assert(#weapons > 0, "the registry found some weapons at all")
            for _, w in ipairs(weapons) do
                local family = Item.archetype(w.def)
                assert(family, w.id .. " declares no archetype tag -- see docs/weapons.md")

                -- Exactly one: two family tags would make Item.archetype depend on tag ORDER, which is
                -- the whole fragility the membership-based encoding exists to rule out.
                local found = {}
                for _, tag in ipairs(w.def.tags or {}) do
                    if Item.ARCHETYPES[tag] then found[#found + 1] = tag end
                end
                assert(#found == 1,
                    w.id .. " declares " .. #found .. " archetype tags (" .. table.concat(found, ", ")
                        .. ") -- a weapon belongs to exactly one family")
            end
        end,
    },
    {
        name = "every weapon keeps the base mechanics its archetype owes (docs/weapons.md)",
        fn = function()
            -- One assertion per family, run against every weapon that claims it. Each is the mechanic
            -- that DEFINES the family -- the thing a new weapon of that kind must not quietly drop.
            local contract = {
                axe = function(ab, id)
                    assert(ab.aoe and ab.aoe.shape == "front",
                        id .. ": an axe cleaves a front arc")
                end,
                spear = function(ab, id)
                    assert(ab.aoe and ab.aoe.shape == "line",
                        id .. ": a spear skewers a line")
                end,
                greatsword = function(ab, id)
                    assert((ab.channel or 0) >= 1, id .. ": a greatsword winds up")
                end,
                bow = function(ab, id)
                    assert((ab.range or 1) >= 2, id .. ": a bow shoots at range")
                    assert((ab.minRange or 0) >= 2, id .. ": a bow has no point-blank shot")
                end,
                longbow = function(ab, id)
                    assert((ab.channel or 0) >= 1, id .. ": a longbow is drawn before it looses")
                    assert((ab.range or 1) >= 5, id .. ": a longbow outreaches a bow by two tiles")
                    assert((ab.minRange or 0) >= 2, id .. ": a longbow has no point-blank shot")
                end,
                wand = function(ab, id)
                    assert((ab.range or 1) >= 2, id .. ": a wand strikes at range")
                end,
                dagger = function(ab, id)
                    assert((ab.speed or 99) <= 2, id .. ": a dagger is quick")
                end,
            }
            -- Families whose contract is a whole-item property rather than an ability one.
            local itemContract = {
                staff = function(def, id)
                    assert(def.waitBehavior and def.waitBehavior.kind == "focus",
                        id .. ": a staff swaps Wait for Focus")
                end,
                sword = function(def, id)
                    -- A counter-reaction, either the ordinary Parry or a blade that upgrades it.
                    local answers = false
                    for _, t in ipairs(def.traits or {}) do
                        if t == "parry" or t == "riposte" or t == "melee_counter" then answers = true end
                    end
                    assert(answers, id .. ": a sword answers a melee blow")
                    assert((def.hands or 1) == 1, id .. ": a sword is one-handed")
                end,
                -- Both bow families: one hand holds the stave, the other draws. Checked as an item
                -- property rather than an ability one, since `hands` is a property of the object.
                bow = function(def, id)
                    assert((def.hands or 1) == 2, id .. ": every bow is two-handed")
                end,
                longbow = function(def, id)
                    assert((def.hands or 1) == 2, id .. ": every bow is two-handed")
                end,
            }

            for _, w in ipairs(eachWeapon()) do
                local family = Item.archetype(w.def)
                local ab = w.def.activeAbility
                if contract[family] then
                    assert(ab, w.id .. " has no activeAbility to check")
                    contract[family](ab, w.id)
                end
                if itemContract[family] then itemContract[family](w.def, w.id) end
            end
        end,
    },
    {
        name = "a shield swaps Wait for Defend, and is the only armor that does",
        fn = function()
            -- The shield family lives in data/items/armor, not weapon, so the sweep above misses it.
            for id, def in pairs(Item.defs) do
                local isShield = false
                for _, tag in ipairs(def.tags or {}) do
                    if tag == "shield" then isShield = true end
                end
                if isShield then
                    assert(def.waitBehavior and def.waitBehavior.kind == "defend",
                        id .. ": a shield swaps Wait for Defend")
                end
            end
        end,
    },

    -- ---------------------------------------------------------------- bleed (the dagger's verb)
    {
        name = "bleed costs a tile of blood for every tile WALKED, and nothing for standing still",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit(plainChar("knight"), 1, 1) },
                { unit(plainChar("bandit"), 8, 8) })
            local knight = c.units[1]
            knight.char.stats.staminaRegen = 0
            Status.apply(c, knight, "bleed", { magnitude = 3, duration = 99 })

            -- Standing still costs nothing: a wait is not a step.
            local before = hp(knight)
            openTurn(c, knight)
            Combat.wait(c, knight)
            assert(hp(knight) == before, "a bleeding unit that holds still takes nothing")

            -- Walking three tiles costs three ticks of it.
            openTurn(c, knight)
            local moved = Combat.moveUnit(c, knight, 4, 1) -- 3 tiles along a clear row
            assert(moved, "the walk is legal")
            assert(knight.x == 4, "it walked the full three tiles")
            assert(hp(knight) == before - 9, "three tiles bled three times for 3, got " .. (before - hp(knight)))
        end,
    },
    {
        name = "bleed follows a unit dragged across the ground, but never one that blinks",
        fn = function()
            -- Forced movement: shoved two tiles = two tiles of bleeding. Being dragged is still
            -- crossing the ground, which is the whole rule (Combat.enterTile's `reason`).
            local c = Combat.new(arena(8, 8), { unit(plainChar("knight"), 3, 4) },
                { unit(plainChar("bandit"), 4, 4) })
            local knight, bandit = c.units[1], c.units[2]
            Status.apply(c, bandit, "bleed", { magnitude = 3, duration = 99 })
            local before = hp(bandit)
            Combat.knockback(c, knight, bandit, 2)
            assert(bandit.x == 6, "shoved the full two tiles")
            assert(hp(bandit) == before - 6, "two shoved tiles bled twice, got " .. (before - hp(bandit)))

            -- A teleport crosses no ground at all, so it costs nothing -- the premium a blink buys.
            local c2 = Combat.new(arena(8, 8), { unit(plainChar("knight"), 1, 1) },
                { unit(plainChar("bandit"), 8, 8) })
            local k2 = c2.units[1]
            Status.apply(c2, k2, "bleed", { magnitude = 3, duration = 99 })
            local hp2 = hp(k2)
            Combat.teleportUnit(c2, k2, 5, 5)
            assert(k2.x == 5 and k2.y == 5, "it leapt across the board")
            assert(hp(k2) == hp2, "a bleeding unit that blinks bleeds not at all")
        end,
    },
    {
        name = "a dagger opens the wound it is named for",
        fn = function()
            local rogue = plainChar("bandit")
            local dagger = give(rogue, "iron_dagger")
            local c = Combat.new(arena(8, 8), { unit(rogue, 3, 3) }, { unit(plainChar("bandit"), 3, 4) })
            local attacker, victim = c.units[1], c.units[2]

            openTurn(c, attacker)
            assert(Combat.useItem(c, attacker, dagger, 3, 4), "the stab lands")
            assert(Status.has(victim, "bleed"), "and leaves the target bleeding")
        end,
    },

    -- ---------------------------------------------------------------- staff / wand
    {
        name = "a staff swaps its holder's Wait into Focus, and Focus restores mana",
        fn = function()
            local mage = plainChar("mage")
            give(mage, "staff")
            local c = Combat.new(arena(8, 8), { unit(mage, 1, 1) }, { unit(plainChar("bandit"), 8, 8) })
            local u = c.units[1]

            assert(Combat.waitBehavior(u).kind == "focus", "the staff's holder Focuses instead of waiting")

            u.char.stats.mana.current = 0
            openTurn(c, u)
            assert(Combat.focus(c, u), "Focus resolves")
            assert(u.char.stats.mana.current > 0, "and put mana back in the pool")
        end,
    },
    {
        name = "a wand's bolt is routed by magic, not muscle",
        fn = function()
            local caster = plainChar("mage")
            local wand = give(caster, "wand")
            local c = Combat.new(arena(8, 8), { unit(caster, 2, 2) }, { unit(plainChar("bandit"), 2, 5) })
            local mage, target = c.units[1], c.units[2]

            -- Raising Damage must not move a wand bolt; raising Magic Damage must.
            local base = Combat.computeDamage(c, mage, target, wand)
            mage.char.stats.damage = mage.char.stats.damage + 50
            assert(Combat.computeDamage(c, mage, target, wand) == base,
                "a wand ignores the wielder's Damage stat")
            mage.char.stats.magicDamage = mage.char.stats.magicDamage + 10
            assert(Combat.computeDamage(c, mage, target, wand) == base + 10,
                "a wand scales off Magic Damage")

            -- And it is Magic Defense that turns it, not armor.
            target.char.stats.magicDefense = target.char.stats.magicDefense + 5
            assert(Combat.computeDamage(c, mage, target, wand) == base + 5,
                "a wand is mitigated by Magic Defense")

            openTurn(c, mage)
            assert(Combat.useItem(c, mage, wand, 2, 5), "and it reaches three tiles away")
        end,
    },

    -- ---------------------------------------------------------------- sword: parry / riposte
    {
        name = "a sword answers a melee blow, then must recover its guard",
        fn = function()
            local defender = plainChar("bandit")
            give(defender, "iron_sword")
            local attacker = plainChar("bandit")
            give(attacker, "iron_sword")
            local c = Combat.new(arena(8, 8), { unit(defender, 3, 3) }, { unit(attacker, 3, 4) })
            local d, a = c.units[1], c.units[2]
            assert(Trait.has(d, "parry"), "an iron sword carries Parry to its holder")

            local before = hp(a)
            Combat.dealFlatDamage(c, d, 5, { "physical" }, "test", a)
            assert(hp(a) < before, "the defender answered the blow")

            -- On cooldown now: a second blow inside the window goes unanswered.
            local mid = hp(a)
            Combat.dealFlatDamage(c, d, 5, { "physical" }, "test", a)
            assert(hp(a) == mid, "the guard is still recovering, so no second answer")
        end,
    },
    {
        name = "a parry is paid for in stamina, and an exhausted swordsman simply eats the blow",
        fn = function()
            local defender = plainChar("bandit")
            give(defender, "iron_sword")
            local attacker = plainChar("bandit")
            give(attacker, "iron_sword")
            local c = Combat.new(arena(8, 8), { unit(defender, 3, 3) }, { unit(attacker, 3, 4) })
            local d, a = c.units[1], c.units[2]

            local stamina = Combat.resource(d.char, "stamina")
            Combat.dealFlatDamage(c, d, 5, { "physical" }, "test", a)
            assert(Combat.resource(d.char, "stamina") == stamina - 4, "a parry costs 4 stamina")

            -- Empty the pool and clear the guard: the cooldown is no longer what is stopping them.
            d.char.stats.stamina.current = 3 -- one short
            Combat.tickCooldowns(c, 99) -- the real recharge clock; setCooldown(.., 0) would NOT clear it
            local before = hp(a)
            Combat.dealFlatDamage(c, d, 5, { "physical" }, "test", a)
            assert(hp(a) == before, "no stamina, no parry")
            assert(d.char.stats.stamina.current == 3, "and the answer that never came bills nothing")
        end,
    },
    {
        name = "a riposte too is paid for -- an exhausted duelist's guard drops entirely",
        fn = function()
            local duelist = plainChar("bandit")
            give(duelist, "riposte_blade")
            local attacker = plainChar("bandit")
            give(attacker, "iron_sword")
            local c = Combat.new(arena(8, 8), { unit(duelist, 3, 3) }, { unit(attacker, 3, 4) })
            local d, a = c.units[1], c.units[2]

            local stamina = Combat.resource(d.char, "stamina")
            local before = hp(d)
            Combat.dealFlatDamage(c, d, 8, { "physical" }, "test", a)
            assert(hp(d) == before, "the blow is turned aside entirely")
            assert(Combat.resource(d.char, "stamina") == stamina - 6, "a riposte costs 6 stamina")

            -- Spent and off cooldown: the blade no longer negates anything, which is the whole point
            -- of pricing it -- a duelist in a doorway can now be worn down rather than waited out.
            d.char.stats.stamina.current = 5 -- one short
            Combat.tickCooldowns(c, 99) -- the real recharge clock; setCooldown(.., 0) would NOT clear it
            Combat.dealFlatDamage(c, d, 8, { "physical" }, "test", a)
            assert(hp(d) < before, "an exhausted guard stops nothing")
            assert(d.char.stats.stamina.current == 5, "and bills nothing for the guard it never raised")
        end,
    },
    {
        name = "a parry answers an attack, not another parry -- two swordsmen never volley",
        fn = function()
            -- Both carry swords. The attacker's strike provokes ONE counter; that counter must not
            -- provoke a counter-counter, or every exchange in the game becomes a three-hit trade.
            local defender = plainChar("bandit")
            give(defender, "iron_sword")
            local attacker = plainChar("bandit")
            local sword = give(attacker, "iron_sword")
            local c = Combat.new(arena(8, 8), { unit(defender, 3, 3) }, { unit(attacker, 3, 4) })
            local d, a = c.units[1], c.units[2]

            local oneSwing = Combat.computeDamage(c, a, d, sword) -- what a single sword blow is worth
            local dBefore, aBefore = hp(d), hp(a)
            openTurn(c, a)
            assert(Combat.useItem(c, a, sword, 3, 3), "the attack lands")

            assert(hp(d) < dBefore, "the defender took the hit")
            assert(hp(a) < aBefore, "and answered it once")
            -- The counter arrived as a reaction, so the attacker's own Parry declined to answer back:
            -- the defender is hit exactly once, by the original swing, and never by a counter-counter.
            local dLost = dBefore - hp(d)
            assert(dLost == oneSwing,
                "the defender is hit once (the swing), not twice: expected " .. oneSwing .. ", got " .. dLost)
        end,
    },
    {
        name = "the Riposte Blade turns a melee blow aside entirely and answers it",
        fn = function()
            local duelist = plainChar("bandit")
            give(duelist, "riposte_blade")
            local attacker = plainChar("bandit")
            local sword = give(attacker, "iron_sword")
            local c = Combat.new(arena(8, 8), { unit(duelist, 3, 3) }, { unit(attacker, 3, 4) })
            local d, a = c.units[1], c.units[2]
            assert(Trait.has(d, "riposte"), "the blade carries Riposte, not the ordinary Parry")

            local dBefore, aBefore = hp(d), hp(a)
            openTurn(c, a)
            assert(Combat.useItem(c, a, sword, 3, 3), "the attack resolves")

            assert(hp(d) == dBefore, "the blow was turned aside: the duelist took NOTHING")
            assert(hp(a) < aBefore, "and the attacker was run through for trying")
        end,
    },
    -- ---------------------------------------------------------------- named weapons earn their price
    -- Each rank-4 weapon must do something its plain iron counterpart does not -- not merely hit for a
    -- bigger number. These lock in that extra.
    {
        name = "frenzy: each body past the first in the arc raises what EVERY one of them takes",
        fn = function()
            -- The keyword's reference user. One body is a plain cleave; three is the same swing landing
            -- harder on all three -- the inversion that makes being surrounded the point.
            local hero = plainChar("knight")
            give(hero, "butchers_wedge")
            local c1 = Combat.new(arena(8, 8), { unit(hero, 3, 3) }, { unit(plainChar("bandit"), 3, 4) })
            local a1, lone = c1.units[1], c1.units[2]
            local before1 = hp(lone)
            openTurn(c1, a1)
            assert(Combat.useItem(c1, a1, a1.char.inventory[1], 3, 4), "the lone swing lands")
            local solo = before1 - hp(lone)

            local hero2 = plainChar("knight")
            give(hero2, "butchers_wedge")
            local c2 = Combat.new(arena(8, 8), { unit(hero2, 3, 3) },
                { unit(plainChar("bandit"), 3, 4), unit(plainChar("bandit"), 2, 4),
                  unit(plainChar("bandit"), 4, 4) })
            local a2, mid = c2.units[1], c2.units[2]
            local before2 = hp(mid)
            openTurn(c2, a2)
            assert(Combat.useItem(c2, a2, a2.char.inventory[1], 3, 4), "the crowded swing lands")
            local crowded = before2 - hp(mid)

            assert(crowded > solo,
                "a swing through three bites deeper than a swing through one: " .. crowded .. " vs " .. solo)
        end,
    },
    {
        name = "frenzy is promised by the damage preview, not just delivered by the swing",
        fn = function()
            -- The tooltip must read the crowd before the player commits, or the number it quotes is a
            -- lie. Both the preview and the live cast run through Combat.castAmount for this reason.
            local hero = plainChar("knight")
            local wedge = give(hero, "butchers_wedge")
            local c = Combat.new(arena(8, 8), { unit(hero, 3, 3) },
                { unit(plainChar("bandit"), 3, 4), unit(plainChar("bandit"), 2, 4),
                  unit(plainChar("bandit"), 4, 4) })
            local a, mid = c.units[1], c.units[2]

            local preview = Combat.previewAbility(c, a, wedge, 3, 4)
            local entry = preview and preview.entries[mid]
            local promised = entry and entry.damage
            assert(promised and promised > 0, "the preview quotes a number for the middle target")

            local before = hp(mid)
            openTurn(c, a)
            assert(Combat.useItem(c, a, wedge, 3, 4), "the swing lands")
            assert(before - hp(mid) == promised,
                "the swing delivers exactly what the preview promised: " .. (before - hp(mid))
                    .. " vs " .. promised)
        end,
    },
    {
        name = "lifesteal: the Crimson Greataxe drinks a share of everything its arc opens",
        fn = function()
            local hero = plainChar("knight")
            local axe = give(hero, "crimson_greataxe")
            local c = Combat.new(arena(8, 8), { unit(hero, 3, 3) },
                { unit(plainChar("bandit"), 3, 4), unit(plainChar("bandit"), 2, 4) })
            local a = c.units[1]
            a.char.stats.health.current = 40 -- leave room for the drink to show

            openTurn(c, a)
            local ok, res = Combat.useItem(c, a, axe, 3, 4)
            assert(ok, "the swing lands")
            assert(res.healed > 0, "and the wielder drank from it")
            assert(hp(a) == 40 + res.healed, "the heal reached the wielder's own bar")

            -- It is the whole arc it drinks from, not just the aimed body: two foes feed it more.
            local solo = plainChar("knight")
            local axe2 = give(solo, "crimson_greataxe")
            local c2 = Combat.new(arena(8, 8), { unit(solo, 3, 3) }, { unit(plainChar("bandit"), 3, 4) })
            local s = c2.units[1]
            s.char.stats.health.current = 40
            openTurn(c2, s)
            local _, res2 = Combat.useItem(c2, s, axe2, 3, 4)
            assert(res.healed > res2.healed,
                "a swing through two drinks more than a swing through one: "
                    .. res.healed .. " vs " .. res2.healed)
        end,
    },
    {
        name = "a declared lifesteal ADDS to a Vampiric Strike charm beside it, rather than overriding",
        fn = function()
            -- The keyword folds into the same mods.lifesteal the aura feeds, so a hungry weapon charmed
            -- hungrier drinks deeper. Slot 2 is adjacent to slot 1 in the 3x3 grid.
            local plain = plainChar("knight")
            local axe = give(plain, "crimson_greataxe")
            local c1 = Combat.new(arena(8, 8), { unit(plain, 3, 3) }, { unit(plainChar("bandit"), 3, 4) })
            local u1 = c1.units[1]
            u1.char.stats.health.current = 30
            openTurn(c1, u1)
            local _, bare = Combat.useItem(c1, u1, axe, 3, 4)

            local charmed = plainChar("knight")
            local axe2 = give(charmed, "crimson_greataxe")
            charmed.inventory[2] = Item.instantiate("vampiric_strike")
            local c2 = Combat.new(arena(8, 8), { unit(charmed, 3, 3) }, { unit(plainChar("bandit"), 3, 4) })
            local u2 = c2.units[1]
            u2.char.stats.health.current = 30
            openTurn(c2, u2)
            local _, both = Combat.useItem(c2, u2, axe2, 3, 4)

            assert(both.healed > bare.healed,
                "charmed drinks deeper than bare: " .. both.healed .. " vs " .. bare.healed)
        end,
    },
    {
        name = "the Kingsblood Dagger puts half a swing again through a wound already open",
        fn = function()
            local rogue = plainChar("bandit")
            local blade = give(rogue, "kingsblood_dagger")
            local c = Combat.new(arena(8, 8), { unit(rogue, 3, 3) }, { unit(plainChar("bandit"), 3, 4) })
            local thief, mark = c.units[1], c.units[2]

            -- A clean target: an ordinary strike, and it leaves its own deeper wound behind.
            local before = hp(mark)
            openTurn(c, thief)
            assert(Combat.useItem(c, thief, blade, 3, 4), "the first stab lands")
            local clean = before - hp(mark)
            local wound = Status.get(mark, "bleed")
            assert(wound and wound.magnitude == 5, "the Kingsblood cuts deeper than the ordinary 3")

            -- The same blade into the wound it just opened: half the swing again.
            local mid = hp(mark)
            openTurn(c, thief)
            assert(Combat.useItem(c, thief, blade, 3, 4), "the second stab lands")
            local reopened = mid - hp(mark)
            assert(reopened > clean,
                "a bleeding foe takes more than a clean one: " .. reopened .. " vs " .. clean)
        end,
    },
    {
        name = "the Hornbow of the Hunt hits harder the further the shot is taken",
        fn = function()
            -- Same bow, same target, two ranges. The far shot must land harder than the near one --
            -- the inversion that makes this bow want the whole field between it and the kill.
            local near = plainChar("archer")
            local nearBow = give(near, "hornbow_of_the_hunt")
            local c1 = Combat.new(arena(8, 8), { unit(near, 1, 1) }, { unit(plainChar("bandit"), 3, 1) })
            local n, nt = c1.units[1], c1.units[2]
            local nBefore = hp(nt)
            openTurn(c1, n)
            assert(Combat.useItem(c1, n, nearBow, 3, 1), "the point-blank-band shot lands (2 tiles)")
            local close = nBefore - hp(nt)

            local far = plainChar("archer")
            local farBow = give(far, "hornbow_of_the_hunt")
            local c2 = Combat.new(arena(8, 8), { unit(far, 1, 1) }, { unit(plainChar("bandit"), 6, 1) })
            local f, ft = c2.units[1], c2.units[2]
            local fBefore = hp(ft)
            openTurn(c2, f)
            assert(Combat.useItem(c2, f, farBow, 6, 1), "the long shot lands (5 tiles)")
            local distant = fBefore - hp(ft)

            assert(distant > close,
                "the far shot lands harder: " .. distant .. " vs " .. close)
        end,
    },
    {
        name = "an Oathkeeper Shield braces the whole line, not just the one holding it",
        fn = function()
            local warden = plainChar("knight")
            give(warden, "oathkeeper_shield")
            local c = Combat.new(arena(8, 8),
                { unit(warden, 3, 3), unit(plainChar("knight"), 3, 4), unit(plainChar("knight"), 7, 7) },
                { unit(plainChar("bandit"), 8, 8) })
            local holder, beside, away = c.units[1], c.units[2], c.units[3]

            assert(Combat.waitBehavior(holder).kind == "defend", "the shield swaps Wait for Defend")
            openTurn(c, holder)
            assert(Combat.defend(c, holder), "the wall is planted")

            assert(Status.has(holder, "defending"), "the holder braces")
            local covered = Status.get(beside, "defending")
            assert(covered, "and the ally beside it is covered by the wall")
            assert(covered.magnitude < Status.get(holder, "defending").magnitude,
                "the ally gets a lesser share than the one actually holding the shield")
            assert(not Status.has(away, "defending"), "an ally across the board is not covered")
        end,
    },
    {
        name = "a plain buckler braces only its holder",
        fn = function()
            -- The counterpart to the case above: `covers` is the Oathkeeper's extra, and the base
            -- shield must NOT have quietly gained it.
            local warden = plainChar("knight")
            give(warden, "buckler")
            local c = Combat.new(arena(8, 8),
                { unit(warden, 3, 3), unit(plainChar("knight"), 3, 4) },
                { unit(plainChar("bandit"), 8, 8) })
            local holder, beside = c.units[1], c.units[2]

            openTurn(c, holder)
            assert(Combat.defend(c, holder), "the buckler braces")
            assert(Status.has(holder, "defending"), "its holder is braced")
            assert(not Status.has(beside, "defending"), "but a buckler covers nobody else")
        end,
    },
    {
        name = "a riposte turns aside only what a blade can reach and touch",
        fn = function()
            -- Ranged: the guard is worth nothing to an archer three tiles off.
            local duelist = plainChar("bandit")
            give(duelist, "riposte_blade")
            local archer = plainChar("archer")
            local bow = give(archer, "iron_bow")
            local c = Combat.new(arena(8, 8), { unit(duelist, 3, 3) }, { unit(archer, 3, 6) })
            local d, a = c.units[1], c.units[2]

            local before = hp(d)
            openTurn(c, a)
            assert(Combat.useItem(c, a, bow, 3, 3), "the shot resolves")
            assert(hp(d) < before, "an arrow flies straight past a raised guard")

            -- Magical: a spell is not something a blade can turn, even at point-blank.
            local d2 = plainChar("bandit")
            give(d2, "riposte_blade")
            local c2 = Combat.new(arena(8, 8), { unit(d2, 3, 3) }, { unit(plainChar("mage"), 3, 4) })
            local du, mg = c2.units[1], c2.units[2]
            local hp2 = hp(du)
            Combat.dealFlatDamage(c2, du, 8, { "magical" }, "test", mg)
            assert(hp(du) < hp2, "a spell passes through the guard")
        end,
    },
}
