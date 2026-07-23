-- Tests for the itemized damage breakdown (Combat.damageBreakdown + Status.statBonusParts): the
-- hover receipt behind a "takes N damage" log line must list every buff/debuff that moved the
-- attacker's attack stat or the target's defense as its own signed +/- row, not fold them into one
-- opaque number. Pure logic, runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")

-- A flat, all-walkable arena (mirrors tests/combat_spec.lua's fixture).
local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do tiles[y][x] = { type = "ground", moveCost = 1, walkable = true } end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

-- The row a breakdown produced for a given label, or nil.
local function rowFor(rows, label)
    for _, r in ipairs(rows) do if r.label == label then return r end end
    return nil
end

-- Sum of every non-total row: the working the strong "Damage" total must equal.
local function sumWorking(rows)
    local total = 0
    for _, r in ipairs(rows) do
        if not r.strong and r.value then total = total + r.value end
    end
    return total
end

return {
    {
        name = "statBonusParts itemizes each contributing status and sums to statBonus",
        fn = function()
            local u = { statuses = {
                { def = { name = "Aegis", statBonus = { defense = 5 } } },
                { def = { name = "Acid", statBonus = { defense = -6 } } },
                { def = { name = "Bracing", magnitudeStat = "defense" }, magnitude = 2 },
                { def = { name = "Haste", statBonus = { speed = 3 } } }, -- moves a different stat: ignored
            } }
            local parts = Status.statBonusParts(u, "defense")
            assert(#parts == 3, "three statuses move defense, got " .. #parts)
            assert(rowFor(parts, "Aegis").value == 5, "Aegis +5")
            assert(rowFor(parts, "Acid").value == -6, "Acid -6")
            assert(rowFor(parts, "Bracing").value == 2, "Bracing +2 (from magnitude)")
            -- The parts always sum to the single-number fold used by mitigation.
            local total = 0
            for _, p in ipairs(parts) do total = total + p.value end
            assert(total == Status.statBonus(u, "defense"), "parts sum to statBonus")
        end,
    },
    {
        name = "damageBreakdown splits the target's defense into base + each modifier, signed",
        fn = function()
            -- Hand-built target: base defense 4, +2 from equipment, plus an Acid debuff (-6).
            local target = {
                char = { stats = { defense = 4 } },
                bonus = { defense = 2 },
                resist = {},
                statuses = { { def = { name = "Acid", statBonus = { defense = -6 } } } },
            }
            -- Base power 10, no attacker parts -> a single "Base" row. Net defense = 4 + 2 - 6 = 0,
            -- so mitigated = 10 and the floor never engages.
            local rows = Combat.damageBreakdown(target, 10, {}, nil, nil, 10)

            local def = rowFor(rows, "Defense")
            assert(def and def.value == -4 and def.signed, "base defense is its own signed -4 row")
            local eq = rowFor(rows, "Equipment")
            assert(eq and eq.value == -2 and eq.signed, "equipment is its own signed -2 row")
            local acid = rowFor(rows, "Acid")
            -- A -defense debuff FEEDS the damage: the subtraction flips to a +.
            assert(acid and acid.value == 6 and acid.signed, "Acid debuff shows as a signed +6, got "
                .. tostring(acid and acid.value))

            local dmg = rowFor(rows, "Damage")
            assert(dmg and dmg.strong, "a strong Damage total closes the receipt")
            assert(sumWorking(rows) == dmg.value, "the itemized rows sum to the total")
        end,
    },
    {
        name = "equipment shows the actual item name, not a bare 'Equipment'",
        fn = function()
            -- A bandit (base defense 6) in leather armor (+4 defense at level 1).
            local armored = Character.instantiate("character_bandit")
            assert(Character.addItem(armored, Item.instantiate("armor_leather_armor")), "equip armor")
            local c = Combat.new(arena(6, 6), { unit("character_warlord", 1, 1) }, { { char = armored, x = 1, y = 2 } })
            local attacker, target = c.units[1], c.units[2]

            local sword = Item.instantiate("weapon_iron_sword")
            Combat.dealDamage(c, attacker, target, sword, {})

            local detail
            for i = 1, #c.log do
                if c.log[i].kind == "damage" and c.log[i].detail then detail = c.log[i].detail; break end
            end
            assert(detail, "the damage line carries its breakdown")

            local armor = rowFor(detail, "Leather Armor")
            assert(armor and armor.value == -4 and armor.signed, "the armor is named and worth -4 defense, got "
                .. tostring(armor and armor.value))
            assert(not rowFor(detail, "Equipment"), "no generic 'Equipment' row when the gear is attributed")

            local dmg = rowFor(detail, "Damage")
            assert(dmg and dmg.strong and sumWorking(detail) == dmg.value, "rows sum to the dealt damage")
        end,
    },
    {
        name = "a real hit's log detail lists the buff and debuff that moved the stats",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_warlord", 1, 1) },
                { unit("character_bandit", 1, 2) })
            local attacker, target = c.units[1], c.units[2]
            -- +4 attack on the striker, -6 defense on the struck: one modifier each side, opposite signs.
            Status.apply(c, attacker, "status_inspiration")
            Status.apply(c, target, "status_acid")

            local sword = Item.instantiate("weapon_iron_sword")
            Combat.dealDamage(c, attacker, target, sword, {})

            -- The breakdown rides on the FIRST "takes N damage" line -- the warlord's own blow. A later
            -- damage line could be the bandit's counter, whose attacker carries no Inspiration.
            local detail
            for i = 1, #c.log do
                if c.log[i].kind == "damage" and c.log[i].detail then detail = c.log[i].detail; break end
            end
            assert(detail, "the damage line carries its breakdown")

            local insp = rowFor(detail, "Inspiration")
            assert(insp and insp.value == 4 and insp.signed, "attack buff is a signed +4 row")
            local acid = rowFor(detail, "Acid")
            assert(acid and acid.value == 6 and acid.signed, "defense debuff is a signed +6 row")

            local dmg = rowFor(detail, "Damage")
            assert(dmg and dmg.strong, "strong total present")
            assert(sumWorking(detail) == dmg.value, "rows sum to the dealt damage")
        end,
    },
}
