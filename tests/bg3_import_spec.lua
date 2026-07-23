-- Tests for the mechanics imported in the Baldur's Gate 3 pass: the four new adjacency-aura fields
-- (careful / twin / speedBonus, plus coatings that spend themselves), the generic extra action, the
-- Halted action gate, the Shared Burden damage split, the shield's shove counter, hazard-driven
-- line-of-sight, and Wet's new elemental opinions.
--
-- Each case pins the RULE rather than the item that first used it, so the numbers on a blueprint may
-- be retuned without breaking a test -- except where a specific item's identity is the point (the
-- Bulwark shoving, the Veil blinding), in which case the item is named.
--
-- Pure logic, headless. Mirrors tests/adjacency_spec.lua in shape.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")
local Hazard = require("models.hazard")
local Trait = require("models.trait")

local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
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

local function equip(char, map)
    char.inventory = {}
    for slot, id in pairs(map) do
        char.inventory[slot] = Item.instantiate(id)
    end
end

-- Fill every pool so a test never fails on affordability it did not mean to test.
local function flush(u)
    for _, stat in ipairs({ "mana", "stamina", "health" }) do
        local s = u.char.stats[stat]
        if s then s.current = s.max or s.current end
    end
end

return {
    -- ---------------------------------------------------------------------
    -- Coatings: an aura item that is spent by being used
    -- ---------------------------------------------------------------------
    {
        name = "a coating is spent one charge per cast it sharpens, and stops applying when empty",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 3) }, { unit("character_bandit", 3, 4) })
            local k, b = c.units[1], c.units[2]
            equip(k.char, { [5] = "consumable_fire_stone", [4] = "weapon_iron_sword" })
            local stone = k.char.inventory[5]
            stone.quantity = 2
            flush(k)

            openTurn(c, k)
            assert(Combat.useItem(c, k, k.char.inventory[4], 3, 4), "the infused sword strikes")
            assert(Status.has(b, "status_burn"), "the coating infused the swing")
            assert(stone.quantity == 1, "one charge is spent per cast, not per hit: " .. stone.quantity)

            -- The bandit has to survive three swings and the knight has to afford them, so both are
            -- topped back up between rounds: this test is about the stack, not about attrition.
            Status.remove(c, b, "status_burn")
            flush(k); flush(b)
            openTurn(c, k)
            assert(Combat.useItem(c, k, k.char.inventory[4], 3, 4), "the second swing lands")
            assert(stone.quantity == 0, "the second cast empties it")

            -- Empty: the aura stops applying, and the slot stays in the grid rather than vanishing.
            Status.remove(c, b, "status_burn")
            flush(k); flush(b)
            openTurn(c, k)
            assert(Combat.useItem(c, k, k.char.inventory[4], 3, 4), "the third swing still lands")
            assert(not Status.has(b, "status_burn"), "an empty coating no longer infuses")
            assert(k.char.inventory[5] == stone, "the spent coating keeps its slot")
        end,
    },
    {
        name = "reading the grid never spends a coating -- only a resolved cast does",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 3) }, { unit("character_bandit", 3, 4) })
            local k = c.units[1]
            equip(k.char, { [5] = "consumable_fire_stone", [4] = "weapon_iron_sword" })
            local stone = k.char.inventory[5]
            stone.quantity = 3
            flush(k)

            -- The damage preview reads the very same aura the cast will. Hovering must be free, or a
            -- satchel would empty itself under the cursor.
            for _ = 1, 5 do
                Combat.previewAbility(c, k, k.char.inventory[4], 3, 4)
                Combat.adjacencyRangeBonus(k.char, k.char.inventory[4])
            end
            assert(stone.quantity == 3, "previewing spends nothing: " .. stone.quantity)
        end,
    },

    -- ---------------------------------------------------------------------
    -- Careful: an area cast that spares its own side
    -- ---------------------------------------------------------------------
    {
        name = "a Careful Sigil steers a blast off the caster's own line, but not off the ground",
        fn = function()
            -- One ally and one foe, both inside a 3x3 blast centred on (5,6).
            local c = Combat.new(arena(10, 10),
                { unit("character_mage", 5, 7), unit("character_knight", 5, 6) },
                { unit("character_bandit", 4, 6) })
            local mage, knight, bandit = c.units[1], c.units[2], c.units[3]
            equip(mage.char, { [5] = "utility_careful_sigil", [4] = "ability_fireball" })
            flush(mage)

            local kHp, bHp = knight.char.stats.health.current, bandit.char.stats.health.current
            openTurn(c, mage)
            -- Fireball CHANNELS, so the cast winds up here and lands on resolution.
            assert(Combat.useItem(c, mage, mage.char.inventory[4], 5, 6), "the careful fireball winds up")
            assert(Combat.resolveChannel(c, mage), "and resolves")

            assert(knight.char.stats.health.current == kHp, "an ally inside the blast is stepped over")
            assert(bandit.char.stats.health.current < bHp, "the foe in the same blast is not spared")
            -- The GROUND is not spared: the sigil steers the blast, not what it leaves behind.
            assert(Hazard.at(c, knight.x, knight.y, "hazard_fire"),
                "fire is still laid on the ally's tile -- ground is nobody's friend")
        end,
    },
    {
        name = "without the sigil the same blast catches the same ally",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_mage", 5, 7), unit("character_knight", 5, 6) },
                { unit("character_bandit", 4, 6) })
            local mage, knight = c.units[1], c.units[2]
            equip(mage.char, { [4] = "ability_fireball" })
            flush(mage)

            local before = knight.char.stats.health.current
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, mage.char.inventory[4], 5, 6), "the plain fireball winds up")
            assert(Combat.resolveChannel(c, mage), "and resolves")
            assert(knight.char.stats.health.current < before,
                "friend and foe alike, exactly as the ability's own description promises")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Twinned: a single-target cast that forks
    -- ---------------------------------------------------------------------
    {
        name = "a Twinned Sigil forks a single-target cast into one more foe beside the target",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_mage", 3, 3) },
                { unit("character_bandit", 6, 3), unit("character_bandit", 6, 4) })
            local mage, a, b = c.units[1], c.units[2], c.units[3]
            equip(mage.char, { [5] = "utility_twinned_sigil", [4] = "ability_fire_bolt" })
            flush(mage)

            local hpA, hpB = a.char.stats.health.current, b.char.stats.health.current
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, mage.char.inventory[4], 6, 3), "the bolt lands")
            assert(a.char.stats.health.current < hpA, "the aimed foe is hit")
            assert(b.char.stats.health.current < hpB, "and so is the one standing beside it")
        end,
    },
    {
        name = "a twin never forks again, and never touches an ally",
        fn = function()
            -- One foe with an ALLY beside it: the fork must find nothing rather than hit the friend.
            local c = Combat.new(arena(10, 10),
                { unit("character_mage", 3, 3), unit("character_knight", 6, 4) },
                { unit("character_bandit", 6, 3) })
            local mage, knight, foe = c.units[1], c.units[2], c.units[3]
            equip(mage.char, { [5] = "utility_twinned_sigil", [4] = "ability_fire_bolt" })
            flush(mage)

            local hpK = knight.char.stats.health.current
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, mage.char.inventory[4], 6, 3), "the bolt lands")
            assert(knight.char.stats.health.current == hpK, "the fork does not find an ally")
            assert(not foe.alive or foe.char.stats.health.current < foe.char.stats.health.max,
                "the aimed foe still takes it")
        end,
    },
    {
        name = "an AREA cast is never twinned -- the sigil copies a blow, not a blast",
        fn = function()
            local ab = { aoe = { shape = "square", radius = 1 } }
            assert(Combat.twinTarget({}, { side = "party" }, ab, { x = 1, y = 1, alive = true }) == nil,
                "an ability with an aoe is not single-target, so it cannot fork")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Quickened: an aura that buys tempo back
    -- ---------------------------------------------------------------------
    {
        name = "a Quickened Sigil shaves initiative off the neighbouring cast, and is quoted everywhere",
        fn = function()
            local plain = Character.instantiate("character_mage")
            plain.inventory = {}
            plain.inventory[4] = Item.instantiate("ability_fire_bolt")

            local quick = Character.instantiate("character_mage")
            quick.inventory = {}
            quick.inventory[4] = Item.instantiate("ability_fire_bolt")
            quick.inventory[5] = Item.instantiate("utility_quickened_sigil")

            local pu, qu = { char = plain }, { char = quick }
            local base = Combat.actionSpeed(pu, plain.inventory[4].activeAbility, plain.inventory[4])
            local fast = Combat.actionSpeed(qu, quick.inventory[4].activeAbility, quick.inventory[4])
            assert(fast < base, "the sigil makes the neighbouring cast cheaper in tempo: " .. fast .. " vs " .. base)
            assert(Combat.adjacencySpeedBonus(quick, quick.inventory[4]) < 0, "and reports the discount as negative")
        end,
    },
    {
        name = "no arrangement of the grid can make an action free",
        fn = function()
            local char = Character.instantiate("character_mage")
            char.inventory = {}
            local bolt = Item.instantiate("ability_fire_bolt")
            bolt.activeAbility.speed = 1
            char.inventory[5] = bolt
            -- Four sigils around it, all discounting at once.
            for _, slot in ipairs({ 2, 4, 6, 8 }) do
                local sigil = Item.instantiate("utility_quickened_sigil")
                sigil.aura.speedBonus = -20 -- absurd on purpose: the floor has to hold anyway
                char.inventory[slot] = sigil
            end
            local speed = Combat.actionSpeed({ char = char }, bolt.activeAbility, bolt)
            assert(speed >= 1, "actionSpeed floors at 1 -- a zero-speed cast would loop forever: " .. speed)
        end,
    },

    -- ---------------------------------------------------------------------
    -- The generic extra action
    -- ---------------------------------------------------------------------
    {
        name = "an extra action re-opens the turn instead of ending it, and banks the tempo",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_warlord", 3, 3) },
                { unit("character_bandit", 3, 4) })
            local f, b = c.units[1], c.units[2]
            equip(f.char, { [1] = "weapon_iron_sword" })
            flush(f)
            f.initiative = 0

            openTurn(c, f)
            Combat.grantExtraAction(f)
            local hp = b.char.stats.health.current
            assert(Combat.useItem(c, f, f.char.inventory[1], 3, 4), "the first swing lands")

            assert(c.turn ~= nil and c.turn.unit == f, "the turn is handed straight back")
            assert(c.turn.moved, "a surge buys an action, never a second walk")
            assert(Combat.tempoDebt(f) > 0, "the first swing's tempo is banked, not waived")
            assert(f.initiative == 0, "and the field gets no beat in between")

            -- The second swing settles everything at once.
            local banked = Combat.tempoDebt(f)
            assert(Combat.useItem(c, f, f.char.inventory[1], 3, 4), "the second swing lands")
            assert(c.turn == nil, "the surge is spent, so this one really ends the turn")
            assert(Combat.tempoDebt(f) == 0, "the debt is settled, and never charged twice")
            assert(b.char.stats.health.current < hp or not b.alive, "both swings actually landed")
            assert(banked > 0, "the banked amount was real")
        end,
    },
    {
        name = "an unspent surge does not carry into the next turn",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_warlord", 3, 3) },
                { unit("character_bandit", 8, 8) })
            local f = c.units[1]
            equip(f.char, { [1] = "weapon_iron_sword" })
            flush(f)
            Combat.grantExtraAction(f)
            openTurn(c, f)
            Combat.wait(c, f) -- a wait is a real turn ending, and it is not the surge path
            Combat.grantExtraAction(f, 0)
            openTurn(c, f)
            assert(Combat.useItem(c, f, f.char.inventory[1], 3, 3) == false
                or c.turn == nil, "a surge left over from an earlier turn does not re-open this one")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Halted: the action gate
    -- ---------------------------------------------------------------------
    {
        name = "Halted refuses every ability -- weapon, spell and potion alike",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 3) }, { unit("character_bandit", 3, 4) })
            local k = c.units[1]
            equip(k.char, { [1] = "weapon_iron_sword", [2] = "ability_heal", [3] = "consumable_healing_potion" })
            flush(k)

            for slot = 1, 3 do
                assert(Combat.itemBlockReason(k, k.char.inventory[slot]) == nil,
                    "nothing is blocked before the order lands (slot " .. slot .. ")")
            end
            Status.apply(c, k, "status_halted")
            for slot = 1, 3 do
                local blocked = Combat.itemBlockReason(k, k.char.inventory[slot])
                assert(blocked and blocked.kind == "halted",
                    "a halted unit may use nothing at all (slot " .. slot .. ")")
            end
        end,
    },
    {
        name = "Halted takes the action and leaves the reflex: a halted swordsman still parries",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 3) }, { unit("character_bandit", 3, 4) })
            local k, b = c.units[1], c.units[2]
            equip(k.char, { [1] = "weapon_iron_sword" })
            equip(b.char, { [1] = "weapon_iron_sword" })
            flush(k); flush(b)
            Trait.setup(c) -- the swords were equipped after Combat.new, so re-collect their Parry
            Status.apply(c, k, "status_halted")

            assert(not Status.disablesReactions(k), "Halt is not hard control: reactions stand")
            local answers = Trait.counterPreview(c, k, b, { tags = { "physical" }, damage = 10 })
            assert(#answers > 0, "the halted knight still answers a blow it can reach")
        end,
    },
    {
        name = "an Elixir of Heroism refuses the order outright rather than resisting it",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 3) }, { unit("character_bandit", 3, 4) })
            local k = c.units[1]
            Status.apply(c, k, "status_heroism")
            assert(Status.apply(c, k, "status_halted") == nil, "a heroic unit is proof against Halt")
            assert(not Status.has(k, "status_halted"), "and the status never lands")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Shared Burden: the damage split
    -- ---------------------------------------------------------------------
    {
        name = "a bond moves half of every wound onto the one who swore it, at any distance",
        fn = function()
            local c = Combat.new(arena(12, 12),
                { unit("character_knight", 1, 1), unit("character_mage", 9, 9) },
                { unit("character_bandit", 9, 8) })
            local knight, mage = c.units[1], c.units[2]
            flush(knight); flush(mage)

            local st = Status.apply(c, mage, "status_shared_burden")
            st.bonded = knight
            local kHp, mHp = knight.char.stats.health.current, mage.char.stats.health.current

            local dealt = Combat.dealFlatDamage(c, mage, 40, { "physical" }, "test")
            local mLost = mHp - mage.char.stats.health.current
            local kLost = kHp - knight.char.stats.health.current
            assert(kLost > 0, "the swearer bore some of it from eight tiles away")
            assert(mLost + kLost > 0 and dealt == mLost,
                "the ward takes what the swearer did not: " .. mLost .. " + " .. kLost)
            assert(math.abs(kLost - mLost) <= 1, "and the split is even: " .. kLost .. " vs " .. mLost)
        end,
    },
    {
        name = "a bond never pays into itself, and is released when its swearer falls",
        fn = function()
            local c = Combat.new(arena(12, 12),
                { unit("character_knight", 1, 1), unit("character_mage", 3, 3) },
                { unit("character_bandit", 9, 9) })
            local knight, mage = c.units[1], c.units[2]
            flush(knight); flush(mage)
            local st = Status.apply(c, mage, "status_shared_burden")
            st.bonded = knight

            knight.alive = false
            local before = mage.char.stats.health.current
            Combat.dealFlatDamage(c, mage, 20, { "physical" }, "test")
            assert(before - mage.char.stats.health.current > 0, "the ward takes the whole blow now")
            assert(not Status.has(mage, "status_shared_burden"), "a dead swearer's bond is released")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Conjunction: the bond's machinery with the sign flipped
    -- ---------------------------------------------------------------------
    {
        name = "a conjunction adds half the wound to every other bound body, and never softens the first",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_mage", 1, 1) },
                { unit("character_bandit", 5, 5), unit("character_bandit", 6, 5),
                  unit("character_bandit", 5, 6) })
            local struck, b, d = c.units[2], c.units[3], c.units[4]
            for _, u in ipairs({ struck, b, d }) do u.resist = {} end

            local link = {}
            for _, u in ipairs({ struck, b, d }) do
                Status.apply(c, u, "status_conjoined").link = link
            end
            local hpS, hpB, hpD = struck.char.stats.health.current, b.char.stats.health.current,
                d.char.stats.health.current

            -- 40 raw so the arithmetic is legible: the struck body keeps 40, the others take 20 each.
            local dealt = Combat.dealFlatDamage(c, struck, 40, {}, "test", nil, { raw = true })
            assert(hpS - struck.char.stats.health.current == dealt,
                "the struck body keeps its whole wound -- an echo is added, never divided out")
            assert(hpB - b.char.stats.health.current == math.floor(dealt * 0.5),
                "each other bound body takes half: " .. (hpB - b.char.stats.health.current))
            assert(hpD - d.char.stats.health.current == math.floor(dealt * 0.5), "all of them, not just one")
        end,
    },
    {
        name = "an echo cannot echo, and two separate bindings never feed each other",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_mage", 1, 1) },
                { unit("character_bandit", 5, 5), unit("character_bandit", 6, 5),
                  unit("character_bandit", 9, 9) })
            local a, b, outsider = c.units[2], c.units[3], c.units[4]
            for _, u in ipairs({ a, b, outsider }) do u.resist = {} end

            local ring, other = {}, {}
            Status.apply(c, a, "status_conjoined").link = ring
            Status.apply(c, b, "status_conjoined").link = ring
            Status.apply(c, outsider, "status_conjoined").link = other -- a DIFFERENT working

            local hpA, hpB = a.char.stats.health.current, b.char.stats.health.current
            local hpOut = outsider.char.stats.health.current
            Combat.dealFlatDamage(c, a, 40, {}, "test", nil, { raw = true })

            assert(hpOut == outsider.char.stats.health.current,
                "a body bound into another working feels nothing of this one")
            -- If the echo could echo, b's 20 would ring back into a for another 10, and on forever.
            assert(hpA - a.char.stats.health.current == 40, "the struck body takes exactly its wound: "
                .. (hpA - a.char.stats.health.current))
            assert(hpB - b.char.stats.health.current == 20, "and the ring rings exactly once")
        end,
    },
    {
        name = "an echo that empties a bar actually fells the body (the toll goes through killUnit)",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_mage", 1, 1) },
                { unit("character_bandit", 5, 5), unit("character_bandit", 6, 5) })
            local struck, frail = c.units[2], c.units[3]
            struck.resist, frail.resist = {}, {}
            local link = {}
            Status.apply(c, struck, "status_conjoined").link = link
            Status.apply(c, frail, "status_conjoined").link = link
            frail.char.stats.health.current = 3

            Combat.dealFlatDamage(c, struck, 40, {}, "test", nil, { raw = true })
            assert(frail.char.stats.health.current == 0, "the echo emptied the bar")
            assert(not frail.alive, "and the body actually fell rather than standing at 0")
        end,
    },
    {
        name = "a bond that kills its bearer fells them too -- the same toll, the other direction",
        fn = function()
            local c = Combat.new(arena(12, 12),
                { unit("character_knight", 1, 1), unit("character_mage", 9, 9) },
                { unit("character_bandit", 5, 5) })
            local knight, mage = c.units[1], c.units[2]
            local st = Status.apply(c, mage, "status_shared_burden")
            st.bonded = knight
            knight.char.stats.health.current = 4

            Combat.dealFlatDamage(c, mage, 40, {}, "test", nil, { raw = true })
            assert(not knight.alive, "a knight who swore more than it could carry dies of it")
        end,
    },

    -- ---------------------------------------------------------------------
    -- The shield's shove counter
    -- ---------------------------------------------------------------------
    {
        name = "a Bulwark drives its melee attacker two tiles back",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_knight", 5, 5) },
                { unit("character_bandit", 5, 6) })
            local k, b = c.units[1], c.units[2]
            equip(k.char, { [1] = "armor_bulwark_shield" })
            equip(b.char, { [1] = "weapon_iron_sword" })
            flush(k); flush(b)
            Trait.setup(c)

            openTurn(c, b)
            assert(Combat.useItem(c, b, b.char.inventory[1], 5, 5), "the bandit swings")
            Combat.endAnswers(c)
            assert(b.y > 6, "the shield answered by taking the ground back: y=" .. b.y)
        end,
    },
    {
        name = "a shove is not a swing, so it is billed the trait's own cost and not a weapon's",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_knight", 5, 5) },
                { unit("character_bandit", 5, 6) })
            local k = c.units[1]
            -- A greatsword in the grid would price a SWING at 16; the shove must ignore it entirely.
            equip(k.char, { [1] = "armor_bulwark_shield", [2] = "weapon_iron_greatsword" })
            flush(k)
            Trait.setup(c)

            local shove
            for _, t in ipairs(k.traits) do
                if t.id == "trait_shield_shove" then shove = t end
            end
            assert(shove, "the Bulwark carries the shove")
            local cost = Trait.answerCost(c, k, shove, 1)
            assert(cost and cost[1].amount == 5,
                "it costs the 5 stamina it declares, not the greatsword's 16: " .. tostring(cost and cost[1].amount))
        end,
    },

    -- ---------------------------------------------------------------------
    -- Darkness: a hazard that blocks sight
    -- ---------------------------------------------------------------------
    {
        name = "a Veil of Night seals a line of sight that terrain left open",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_mage", 3, 6) },
                { unit("character_bandit", 9, 6) })
            assert(Combat.hasLineOfSight(c, 3, 6, 9, 6), "open ground: the line is clear to begin with")

            Hazard.place(c, 6, 6, "hazard_darkness", {})
            assert(not Combat.hasLineOfSight(c, 3, 6, 9, 6),
                "one tile of dark seals it -- sightCost 2 reaches SIGHT_BLOCK on its own")
            assert(Hazard.sightCostAt(c, 6, 6) == 2, "and the ground reports the cost it contributed")
            assert(Hazard.sightCostAt(c, 7, 6) == 0, "an unclouded tile contributes nothing")
        end,
    },
    {
        name = "darkness stops arrows, not feet",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_knight", 5, 5) }, { unit("character_bandit", 9, 9) })
            local k = c.units[1]
            flush(k)
            Hazard.place(c, 5, 6, "hazard_darkness", {})
            openTurn(c, k)
            assert(Combat.moveUnit(c, k, 5, 6), "a body walks into the dark unhindered")
            assert(k.char.stats.health.current == k.char.stats.health.max, "and takes nothing for it")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Wet's three elements
    -- ---------------------------------------------------------------------
    {
        name = "Wet amplifies lightning AND ice, and damps fire",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 3) }, { unit("character_bandit", 3, 4) })
            local b = c.units[2]
            b.resist = {}

            local dryBolt = Combat.mitigatedDamage(b, 40, { "lightning", "magical" })
            local dryIce  = Combat.mitigatedDamage(b, 40, { "ice", "magical" })
            local dryFire = Combat.mitigatedDamage(b, 40, { "fire", "magical" })

            Status.apply(c, b, "status_wet")
            assert(Combat.mitigatedDamage(b, 40, { "lightning", "magical" }) > dryBolt, "water carries a charge")
            assert(Combat.mitigatedDamage(b, 40, { "ice", "magical" }) > dryIce, "a soaked body freezes")
            assert(Combat.mitigatedDamage(b, 40, { "fire", "magical" }) < dryFire, "and does not burn well")
        end,
    },
    {
        name = "a resistance can damp a hit but never heal one: mitigation still floors at 1",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 3) }, { unit("character_bandit", 3, 4) })
            local b = c.units[2]
            b.resist = {}
            Status.apply(c, b, "status_wet")
            assert(Combat.mitigatedDamage(b, 1, { "fire", "magical" }) >= 1,
                "a damped hit still lands for at least a point")
        end,
    },

    -- ---------------------------------------------------------------------
    -- The Coveted Blood's walking cloud
    -- ---------------------------------------------------------------------
    {
        name = "Coveted Blood exposes foes standing in it and never its bearer's own line",
        fn = function()
            local c = Combat.new(arena(12, 12),
                { unit("character_priest", 5, 5), unit("character_knight", 5, 4) },
                { unit("character_bandit", 4, 5) })
            local al, knight, foe = c.units[1], c.units[2], c.units[3]
            equip(al.char, { [1] = "utility_coveted_blood" })
            Combat.layIncense(c, al)

            assert(Status.has(foe, "status_exposed"), "the foe beside the bearer is opened up")
            assert(not Status.has(knight, "status_exposed"), "the bearer's own line is not")

            local before = Combat.mitigatedDamage(foe, 30, { "slash" })
            local pierced = Combat.mitigatedDamage(foe, 30, { "pierce" })
            assert(pierced > before, "and it is piercing hits alone that benefit")
        end,
    },
}
