-- Tests for THE PACK: the four rules a wolf's teeth carry, the aura that ties a pack to its lead, and
-- the White Wolf's bite, which is a count of her own pack.
--
-- What these pin, in one sentence each:
--   * the teeth bite twice when much faster (Fire Emblem's doubling, at a threshold re-scaled to this
--     game's 0-9 speed stat -- see weapon_wolf_fangs.lua), and once when they are not;
--   * the teeth tear at prey under half health, and leave a healthy body unwounded;
--   * however many times they land, the wolf steps back ONCE;
--   * a wolf standing with a lead hits harder, and stops the instant that lead falls;
--   * two leads do not stack -- the larger applies -- because the White Wolf calls alphas onto a board
--     she is already standing on, so overlapping auras are the ordinary case here;
--   * her bite lands once per wolf within two, which is why her howl is her damage rather than her
--     decoration.
--
-- Pure logic, headless. Fixture style mirrors tests/give_ground_spec.lua.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")

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

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- An item out of a body's own grid, by id: a wolf is armed by being a wolf.
--
-- A NUMERIC LOOP, NEVER ipairs. A blueprint that authors its grid as a 3x3 with `false` holes -- the
-- alpha and the White Wolf both do -- lands those holes in the inventory as nil, and ipairs stops dead
-- at the first one. Searched with ipairs, the alpha's howl (slot 5, behind a hole at slot 3) simply did
-- not exist, and the test handed nil to Combat.useItem and died inside the engine rather than here.
local function itemOf(u, id)
    for i = 1, Character.MAX_INVENTORY do
        local it = u.char.inventory[i]
        if it and it.id == id then return it end
    end
end

-- A prey body with the numbers this file wants to control: speed decides doubling, defense decides how
-- much of a multi-hit survives mitigation, and health decides whether the pack reads it as wounded.
local function prey(speed, defense, health)
    local char = Character.instantiate("character_rowan")
    char.stats.speed = speed
    char.stats.defense = defense
    char.stats.magicDefense = defense
    char.stats.health.max = health
    char.stats.health.current = health
    return char
end

return {
    {
        -- The heavies (knight, fighter, mage, paladin, bulwark) all sit at speed 3 and a wolf at 5, so
        -- this is the case the rule was scaled for: the pack doubles the armoured half of a warband.
        name = "the fangs bite twice when the wolf is 2 speed clear of its prey",
        fn = function()
            local c = Combat.new(arena(9, 5), { unit(prey(3, 0, 200), 4, 3) },
                { unit("character_wolf_grunt", 5, 3) })
            local target, wolf = c.units[1], c.units[2]
            local fangs = itemOf(wolf, "weapon_wolf_fangs")
            assert(fangs, "the wolf bites with its fangs")

            openTurn(c, wolf)
            local doubled = Combat.strikeWith(c, wolf, fangs, target.x, target.y).damageDealt

            -- The same exchange against a body quick enough to deny the second bite.
            local c2 = Combat.new(arena(9, 5), { unit(prey(5, 0, 200), 4, 3) },
                { unit("character_wolf_grunt", 5, 3) })
            local t2, w2 = c2.units[1], c2.units[2]
            openTurn(c2, w2)
            local single = Combat.strikeWith(c2, w2, itemOf(w2, "weapon_wolf_fangs"), t2.x, t2.y).damageDealt

            assert(single > 0, "the wolf bites at all")
            assert(doubled == single * 2,
                string.format("2 clear doubles the blow: %d against %d", doubled, single))
        end,
    },
    {
        -- One point of advantage is not enough, which is what keeps an alpha (6) from doubling the
        -- rogue, archer, duelist, monk and thief (all 5). The threshold is the mechanic.
        name = "one point of speed is not enough to double",
        fn = function()
            local c = Combat.new(arena(9, 5), { unit(prey(4, 0, 200), 4, 3) },
                { unit("character_wolf_grunt", 5, 3) })
            local target, wolf = c.units[1], c.units[2]
            openTurn(c, wolf)
            local dealt = Combat.strikeWith(c, wolf, itemOf(wolf, "weapon_wolf_fangs"), target.x, target.y).damageDealt

            local c2 = Combat.new(arena(9, 5), { unit(prey(5, 0, 200), 4, 3) },
                { unit("character_wolf_grunt", 5, 3) })
            local t2, w2 = c2.units[1], c2.units[2]
            openTurn(c2, w2)
            local even = Combat.strikeWith(c2, w2, itemOf(w2, "weapon_wolf_fangs"), t2.x, t2.y).damageDealt

            assert(dealt == even, "a single point of speed buys the wolf nothing")
        end,
    },
    {
        -- "A pack pulls down the wounded first" has been a comment on every wolf blueprint since the
        -- week they were written, and an AI rule with nothing behind it. This is the teeth agreeing.
        name = "the fangs tear at wounded prey and leave a healthy body unwounded",
        fn = function()
            -- Healthy: full health, no wound opened.
            local c = Combat.new(arena(9, 5), { unit(prey(5, 0, 200), 4, 3) },
                { unit("character_wolf_grunt", 5, 3) })
            local whole, wolf = c.units[1], c.units[2]
            openTurn(c, wolf)
            local light = Combat.strikeWith(c, wolf, itemOf(wolf, "weapon_wolf_fangs"), whole.x, whole.y).damageDealt
            assert(not Status.has(whole, "status_bleed"), "a whole body is not opened")

            -- Wounded: the same body at a third of its health.
            local hurtChar = prey(5, 0, 200)
            hurtChar.stats.health.current = 60
            local c2 = Combat.new(arena(9, 5), { unit(hurtChar, 4, 3) },
                { unit("character_wolf_grunt", 5, 3) })
            local hurt, w2 = c2.units[1], c2.units[2]
            openTurn(c2, w2)
            local heavy = Combat.strikeWith(c2, w2, itemOf(w2, "weapon_wolf_fangs"), hurt.x, hurt.y).damageDealt

            assert(heavy > light, string.format("failing prey is bitten harder: %d against %d", heavy, light))
            assert(Status.has(hurt, "status_bleed"), "and the wound is opened")
        end,
    },
    {
        -- The step belongs to the exchange, not to each bite. Stepping off between them would walk the
        -- wolf out of its own second bite.
        name = "a doubled bite still gives ground exactly once",
        fn = function()
            local c = Combat.new(arena(9, 5), { unit(prey(3, 0, 200), 4, 3) },
                { unit("character_wolf_grunt", 5, 3) })
            local target, wolf = c.units[1], c.units[2]
            openTurn(c, wolf)
            Combat.strikeWith(c, wolf, itemOf(wolf, "weapon_wolf_fangs"), target.x, target.y)
            assert(Combat.unitGap(wolf, target) == 2,
                "one tile of ground given, not two -- it is out of reach and no further")
        end,
    },
    {
        -- encounter_wolf_pack.lua's header has claimed a kill order since it was written. This is the
        -- half of it that lives on the alpha's presence.
        name = "a wolf standing with an alpha hits harder, and stops when the alpha falls",
        fn = function()
            local c = Combat.new(arena(9, 5), { unit(prey(5, 0, 200), 1, 1) },
                { unit("character_wolf_grunt", 5, 3), unit("character_wolf_alpha", 6, 3) })
            local grunt, alpha = c.units[2], c.units[3]

            local led = Combat.flatStat(grunt, "damage")
            alpha.alive = false
            local alone = Combat.flatStat(grunt, "damage")

            assert(led > alone,
                string.format("the lead is worth something: %d against %d", led, alone))
            assert(led - alone == 3, "an alpha's lead is worth exactly what its item authors")
        end,
    },
    {
        -- The ring is the counterplay: you can pull a wolf out of it, which you cannot do with hers.
        name = "an alpha's lead does not reach past two tiles",
        fn = function()
            local c = Combat.new(arena(12, 5), { unit(prey(5, 0, 200), 1, 1) },
                { unit("character_wolf_grunt", 10, 3), unit("character_wolf_alpha", 2, 3) })
            local far, alpha = c.units[2], c.units[3]
            local away = Combat.flatStat(far, "damage")
            alpha.x, alpha.y = 9, 3 -- brought inside the ring
            local near = Combat.flatStat(far, "damage")
            assert(near > away, "inside two tiles it counts, outside it does not")
        end,
    },
    {
        -- She calls alphas onto a board she is already standing on, so a wolf inside both auras is the
        -- ordinary case rather than the corner one. Summed, the fight's damage would come out of
        -- however many leads were alive instead of a figure anybody chose.
        name = "two leads do not stack -- the larger one applies",
        fn = function()
            local c = Combat.new(arena(12, 7), { unit(prey(5, 0, 200), 1, 1) },
                { unit("character_wolf_grunt", 5, 3), unit("character_wolf_alpha", 6, 3),
                  unit("character_white_wolf", 4, 5) })
            local grunt, alpha, she = c.units[2], c.units[3], c.units[4]

            local both = Combat.flatStat(grunt, "damage")
            she.alive = false
            local alphaOnly = Combat.flatStat(grunt, "damage")
            she.alive, alpha.alive = true, false
            local herOnly = Combat.flatStat(grunt, "damage")

            assert(herOnly > alphaOnly, "hers is the better lead")
            assert(both == herOnly, "standing in both is worth exactly the better one, never the sum")
        end,
    },
    {
        -- Her whole fight: the howl is her damage. A turn spent calling is a turn spent raising her
        -- own blow, and a party that ignores the pack is choosing to be bitten more times.
        name = "the White Wolf bites once for each wolf standing with her",
        fn = function()
            local function heronly(packmates)
                local enemies = { unit("character_white_wolf", 5, 3) }
                for i = 1, packmates do
                    enemies[#enemies + 1] = unit("character_wolf_grunt", 5 + i, 5)
                end
                local c = Combat.new(arena(12, 7), { unit(prey(9, 0, 400), 4, 3) }, enemies)
                local target, she = c.units[1], c.units[2]
                openTurn(c, she)
                return Combat.strikeWith(c, she, itemOf(she, "weapon_white_wolf_fangs"),
                    target.x, target.y).damageDealt
            end

            -- Prey at speed 9 so nothing here is a doubling in disguise: her teeth do not double at all.
            local alone, withTwo = heronly(0), heronly(2)
            assert(alone > 0, "a lone god still bites")
            assert(withTwo == alone * 3,
                string.format("one bite, plus one per wolf: %d against %d", withTwo, alone))
        end,
    },
    {
        -- Her howl is the only one that brings anything; the pack's frightens and nothing more.
        name = "both howls frighten the ring, and only hers calls",
        fn = function()
            local c = Combat.new(arena(12, 7),
                { unit(prey(5, 0, 200), 4, 3), unit(prey(5, 0, 200), 9, 7) },
                { unit("character_wolf_alpha", 5, 3) })
            local near, far, alpha = c.units[1], c.units[2], c.units[3]
            local before = #c.units

            openTurn(c, alpha)
            assert(Combat.useItem(c, alpha, itemOf(alpha, "ability_howl_lesser"), alpha.x, alpha.y),
                "the alpha howls")
            assert(Status.has(near, "status_cowering"), "the body in the ring flinches")
            assert(not Status.has(far, "status_cowering"), "the body outside it does not")
            assert(not Status.has(alpha, "status_cowering"), "and the howler does not frighten itself")
            assert(#c.units == before, "the pack's howl brings nothing")
        end,
    },
    {
        name = "her howl frightens the ring AND brings an alpha",
        fn = function()
            local c = Combat.new(arena(12, 9), { unit(prey(5, 0, 200), 4, 3) },
                { unit("character_white_wolf", 6, 3) })
            local target, she = c.units[1], c.units[2]
            local before = #c.units

            openTurn(c, she)
            assert(Combat.useItem(c, she, itemOf(she, "ability_howl"), she.x, she.y), "she howls")
            assert(Status.has(target, "status_cowering"), "the ring flinches")
            assert(#c.units == before + 1, "and something arrives")
            assert(c.units[#c.units].char.id == "character_wolf_alpha", "an alpha, not a grunt")
        end,
    },
    {
        -- The two lead markers, named directly: they are what the aura cases above are actually
        -- measuring, and each carries its own reach and figure through traitParams.
        name = "the two pack leads carry their own reach and their own figure",
        fn = function()
            local presence = Item.instantiate("utility_pack_presence")
            local wood = Item.instantiate("utility_the_wood_behind_her")
            assert(presence.traitParams.packReach == 2, "an alpha's lead is a ring you can leave")
            assert(wood.traitParams.packReach >= 99, "hers is the whole board, which you cannot leave")
            assert(wood.traitParams.packDamage > presence.traitParams.packDamage,
                "and hers is the better lead, which is what makes the no-stacking rule matter")
            assert(wood.bound and wood.noSteal, "her standing cannot be lifted off her")
        end,
    },
    {
        -- The rule that killed this item's first draft: there is no free rung on the armour table.
        name = "Runner's Hide pays its square and buys speed with it",
        fn = function()
            local hide = Item.instantiate("armor_runners_hide")
            assert(hide.bonus.movement <= -1, "every coat is felt (docs/classes.md)")
            assert(hide.bonus.speed == 1, "what it buys is a place in the order, not a free step")
            assert(hide.resist.slash > 0 and hide.resist.impact == nil,
                "a coat a person buys never sells a negative resist")
        end,
    },
    {
        -- Her second drop: the pack, handed over, free of the reservation every other call pays.
        name = "The Wood Remembers fields a wolf at the first bell, free",
        fn = function()
            local hunter = Character.instantiate("character_archer")
            for i = 1, Character.MAX_INVENTORY do hunter.inventory[i] = nil end
            hunter.inventory[1] = Item.instantiate("utility_the_wood_remembers")
            local c = Combat.new(arena(12, 7), { unit(hunter, 4, 3) },
                { unit(prey(5, 0, 200), 9, 3) })

            local wolves = 0
            for _, u in ipairs(c.units) do
                if u.char.id == "character_wolf_grunt" and u.side == c.units[1].side then
                    wolves = wolves + 1
                end
            end
            assert(wolves == 1, "a wolf arrives beside the bearer")

            local mana = hunter.stats.mana
            if type(mana) == "table" then
                assert(Combat.reservedAmount(hunter, "mana") == 0,
                    "and nothing is locked away for it -- free is the whole distinction")
            end
        end,
    },
    {
        -- Her first drop: the same shape as her howl, cut to a size a party can be given.
        name = "Mother's Howl frightens the ring and calls an ordinary wolf, not an alpha",
        fn = function()
            local hunter = Character.instantiate("character_archer")
            for i = 1, Character.MAX_INVENTORY do hunter.inventory[i] = nil end
            local howl = Item.instantiate("ability_mothers_howl")
            hunter.inventory[1] = howl
            local c = Combat.new(arena(14, 9), { unit(hunter, 4, 3) },
                { unit(prey(5, 0, 200), 6, 3), unit(prey(5, 0, 200), 13, 9) })
            local caster, near, far = c.units[1], c.units[2], c.units[3]
            local before = #c.units

            openTurn(c, caster)
            assert(Combat.useItem(c, caster, howl, caster.x, caster.y), "the howl lands")
            assert(Status.has(near, "status_cowering"), "the ring flinches")
            assert(not Status.has(far, "status_cowering"), "and nothing outside it does")
            assert(#c.units == before + 1, "something arrives")
            assert(c.units[#c.units].char.id == "character_wolf_grunt",
                "a wolf -- a boss's own kit is never handed over as-is")
        end,
    },
    {
        -- The alpha's chase piece: the pack's disengage, on a person, with an ordinary weapon.
        name = "In and Out steps its bearer back after a melee blow",
        fn = function()
            local rogue = Character.instantiate("character_rogue")
            for i = 1, Character.MAX_INVENTORY do rogue.inventory[i] = nil end
            local blade = Item.instantiate("weapon_iron_dagger")
            rogue.inventory[1] = blade
            rogue.inventory[2] = Item.instantiate("utility_in_and_out")
            local c = Combat.new(arena(9, 5), { unit(rogue, 4, 3) },
                { unit(prey(5, 0, 200), 5, 3) })
            local striker, foe = c.units[1], c.units[2]

            openTurn(c, striker)
            assert(Combat.useItem(c, striker, blade, foe.x, foe.y), "the blow lands")
            assert(Combat.unitGap(striker, foe) == 2,
                "and the striker is out of reach before the counter is thrown")
        end,
    },
    {
        -- Without the charm the same body stands exactly where it swung -- which is what makes the
        -- case above a test of the charm rather than of the engine.
        name = "the same blow without the charm does not step back",
        fn = function()
            local rogue = Character.instantiate("character_rogue")
            for i = 1, Character.MAX_INVENTORY do rogue.inventory[i] = nil end
            local blade = Item.instantiate("weapon_iron_dagger")
            rogue.inventory[1] = blade
            local c = Combat.new(arena(9, 5), { unit(rogue, 4, 3) },
                { unit(prey(5, 0, 200), 5, 3) })
            local striker, foe = c.units[1], c.units[2]

            openTurn(c, striker)
            Combat.useItem(c, striker, blade, foe.x, foe.y)
            assert(Combat.unitGap(striker, foe) == 1, "it stood and traded, as everything else does")
        end,
    },
    {
        -- The half worth paying for: a counter that starts an exchange and then leaves it.
        name = "In and Out gives ground when its bearer ANSWERS a blow too",
        fn = function()
            local rogue = Character.instantiate("character_rogue")
            for i = 1, Character.MAX_INVENTORY do rogue.inventory[i] = nil end
            local blade = Item.instantiate("weapon_iron_dagger")
            rogue.inventory[1] = blade
            rogue.inventory[2] = Item.instantiate("utility_in_and_out")
            local c = Combat.new(arena(9, 5), { unit(rogue, 4, 3) },
                { unit(prey(5, 0, 200), 5, 3) })
            local striker, foe = c.units[1], c.units[2]

            Combat.answerStrike(c, striker, foe, blade)
            assert(Combat.unitGap(striker, foe) == 2, "it answered and it is gone")
        end,
    },
    {
        -- The guard that keeps the two systems apart: a weapon that already declares hitAndRun takes
        -- its own step inside its effect, so the charm must add nothing on top of it.
        name = "a wolf wearing the charm still gives ground exactly one tile",
        fn = function()
            local wolfChar = Character.instantiate("character_wolf_grunt")
            local slot
            for i = 1, Character.MAX_INVENTORY do
                if wolfChar.inventory[i] == nil then slot = i break end
            end
            wolfChar.inventory[slot or Character.MAX_INVENTORY] = Item.instantiate("utility_in_and_out")
            local c = Combat.new(arena(9, 5), { unit(prey(5, 0, 200), 4, 3) },
                { unit(wolfChar, 5, 3) })
            local target, wolf = c.units[1], c.units[2]

            openTurn(c, wolf)
            Combat.useItem(c, wolf, itemOf(wolf, "weapon_wolf_fangs"), target.x, target.y)
            assert(Combat.unitGap(wolf, target) == 2,
                "one step, not two -- the teeth already stepped and the charm declines to repeat it")
        end,
    },
    {
        -- Melee only, by reach: a bow that backed its archer off a body five tiles away would be
        -- moving them for no reason at all.
        name = "In and Out does not move an archer who shot something",
        fn = function()
            local archer = Character.instantiate("character_archer")
            for i = 1, Character.MAX_INVENTORY do archer.inventory[i] = nil end
            local bow = Item.instantiate("weapon_iron_bow")
            archer.inventory[1] = bow
            archer.inventory[2] = Item.instantiate("utility_in_and_out")
            local c = Combat.new(arena(11, 5), { unit(archer, 3, 3) },
                { unit(prey(5, 0, 200), 6, 3) })
            local shooter, foe = c.units[1], c.units[2]

            openTurn(c, shooter)
            Combat.useItem(c, shooter, bow, foe.x, foe.y)
            assert(shooter.x == 3 and shooter.y == 3, "a shot is not an exchange to disengage from")
        end,
    },
    {
        -- THE BRAVE RULE, on the one weapon that carries it (docs/weapons.md, Item.strikes). This case
        -- is the wolves' doubling case turned inside out on purpose: it used to assert that the blade
        -- struck twice against a slow body and once against a quick one, which was the pack's rule
        -- borrowed. A brave weapon owes NO condition, so the thing to hold it to is that the target's
        -- own speed cannot change the count -- the exact property the old assertion denied.
        name = "The Second Bite strikes twice whatever it is aimed at: a brave weapon asks no question",
        fn = function()
            local function swing(targetSpeed)
                local hunter = Character.instantiate("character_archer")
                for i = 1, Character.MAX_INVENTORY do hunter.inventory[i] = nil end
                local blade = Item.instantiate("weapon_the_second_bite")
                hunter.inventory[1] = blade
                hunter.stats.speed = 6
                local c = Combat.new(arena(9, 5), { unit(hunter, 4, 3) },
                    { unit(prey(targetSpeed, 0, 200), 5, 3) })
                local striker, foe = c.units[1], c.units[2]
                openTurn(c, striker)
                return Combat.strikeWith(c, striker, blade, foe.x, foe.y).damageDealt, foe
            end

            -- 3 is two clear under the striker's 6 and would have doubled under the old rule; 5 is one
            -- under and would not have. Both land the same, because the count is the weapon's.
            local slow = swing(3)
            local quick, foe = swing(5)
            assert(slow == quick,
                string.format("a brave weapon does not read the target's speed: %d against %d", slow, quick))
            assert(Status.has(foe, "status_bleed"), "and daggers bleed, on the family contract")

            -- ...and it really is TWO blows rather than one big one, which is the half a damage total
            -- cannot show on its own. Measured against a plain dagger carrying the same numbers: armour
            -- is subtracted from each strike (Combat.mitigatedDamage runs per hit), so against a body
            -- with defense the brave blade's total is strictly less than twice a single blow of its own
            -- power -- and against a naked one it is exactly twice. A single-strike weapon can satisfy
            -- neither.
            local function armoured(defense)
                local hunter = Character.instantiate("character_archer")
                for i = 1, Character.MAX_INVENTORY do hunter.inventory[i] = nil end
                local blade = Item.instantiate("weapon_the_second_bite")
                hunter.inventory[1] = blade
                hunter.stats.speed = 6
                local body = prey(5, defense, 400)
                local c = Combat.new(arena(9, 5), { unit(hunter, 4, 3) }, { unit(body, 5, 3) })
                local striker, foe = c.units[1], c.units[2]
                openTurn(c, striker)
                local dealt = Combat.strikeWith(c, striker, blade, foe.x, foe.y).damageDealt
                -- What ONE strike of it would have drawn from the same body, asked of the shared
                -- damage core rather than of a second weapon, so nothing but the count differs.
                local one = Combat.computeDamage(c, striker, foe, blade, {})
                return dealt, one
            end

            local naked, nakedOne = armoured(0)
            assert(naked == nakedOne * 2,
                string.format("unarmoured, two strikes are exactly twice one: %d against %d", naked, nakedOne * 2))
            local plated, platedOne = armoured(10)
            assert(plated < nakedOne * 2,
                "armour bites a brave weapon twice: " .. plated .. " is not under " .. (nakedOne * 2))
            assert(plated == platedOne * 2,
                string.format("...and it bites each strike equally: %d against %d", plated, platedOne * 2))
        end,
    },
    {
        -- THE WIRING, NOT THE RULE. The case above proves the brave rule lands; this one proves the
        -- three OTHER paths through fx.damage learned it too. A count honoured only where blood is
        -- drawn is the worst version of this feature: the board panel would quote half the wound the
        -- player is about to deal and the shelf would under-sell the weapon's whole purchase, and
        -- both would be quietly, consistently wrong rather than visibly broken. Each closure is its
        -- own loop in models/combat.lua, so each needs its own assertion.
        name = "a brave weapon's forecast, its shelf hover and its swing all quote the same two strikes",
        fn = function()
            local hunter = Character.instantiate("character_archer")
            for i = 1, Character.MAX_INVENTORY do hunter.inventory[i] = nil end
            local blade = Item.instantiate("weapon_the_second_bite")
            hunter.inventory[1] = blade
            local c = Combat.new(arena(9, 5), { unit(hunter, 4, 3) }, { unit(prey(5, 4, 400), 5, 3) })
            local striker, foe = c.units[1], c.units[2]
            openTurn(c, striker)

            -- One strike's worth, off the shared damage core, so nothing but the count can differ.
            local one = Combat.computeDamage(c, striker, foe, blade, {})

            -- 1. THE BOARD FORECAST (Combat.previewAbility) -- what the panel promises on hover.
            local preview = Combat.previewAbility(c, striker, blade, foe.x, foe.y)
            local quoted = preview and preview.entries[foe] and preview.entries[foe].damage
            assert(quoted == one * 2,
                string.format("the forecast quotes both strikes: %s against %d", tostring(quoted), one * 2))

            -- 2. THE SHELF HOVER (Combat.abilityOutput) -- no board, a zero-defense stand-in, so its
            -- number is the raw pair: twice the ability's damage plus the wielder's attack stat.
            local out = Combat.abilityOutput(striker, blade)
            local raw = (blade.activeAbility.damage or 0) + Combat.flatStat(striker, "damage")
            assert(out and out.damage == raw * 2,
                string.format("the rack quotes both strikes: %s against %d",
                    tostring(out and out.damage), raw * 2))

            -- 3. THE SWING ITSELF (Combat.useItem) -- the real cast path, which is a different closure
            -- again from the sub-strike path the case above swings through.
            local before = foe.char.stats.health.current
            assert(Combat.useItem(c, striker, blade, foe.x, foe.y), "the stab lands")
            assert(before - foe.char.stats.health.current == one * 2,
                string.format("and the swing deals what both of them promised: %d against %d",
                    before - foe.char.stats.health.current, one * 2))
        end,
    },
}
