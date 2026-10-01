-- Tests for SUPERBIA, THE MORNING STAR, Pride's general (reviewed over three rounds, "Pride's Generals"): the
-- body, her four rules, her two stages and the five pieces she pays.
--
--   Non Serviam     a foe's debuff laid on her rebounds onto whoever laid it, at full length, and never touches
--                   her; her relic (the Morning Star) does it once per turn
--   Light-Bearer    a foe whose turn opens able to see her is Blinded until it ends; out of sight, it is not
--   Flawless Form   no single blow takes more than a tenth of her max health (a quarter through Perfect Plate)
--   the Host        at two-thirds, two Reflections of the Morning, and two more at each of her turns' ends
--   the Fall        at one-third the Reflections shatter, she cannot fly, Black Ice spreads a ring a turn (+2
--                   Damage a ring), and a body that ends two turns running on the ice is Frozen
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local MorningStar = require("models.morning_star")
local Fixture = require("tests.support.fixture")

local unit, itemNamed, hp = Fixture.unit, Fixture.itemNamed, Fixture.hp

local GENERAL = "character_general_pride"
local ORGANS = {
    "utility_non_serviam", "utility_light_bearer", "utility_flawless_form", "utility_the_host_and_the_fall",
    "weapon_spear_of_the_morning",
}
-- In the order the stair pays them: her relic first.
local DROPS = {
    { "utility_the_morning_star", "mage" },
    { "armor_halo_of_the_morning", "crusader" },
    { "armor_perfect_plate", "knight" },
    { "utility_mirror_of_the_morning", "summoner" },
    { "ability_cocytus_wing", "elementalist" },
}

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id and u.alive then return u end end
end

local function reflections(c, side)
    local out = {}
    for _, u in ipairs(c.units) do
        if u.alive and u.char.id == MorningStar.REFLECTION and (not side or u.side == side) then out[#out + 1] = u end
    end
    return out
end

-- A bare company body carrying `items`, at full on `health`.
local function body(x, y, items, health)
    return unit("character_archer", x, y,
        { isolate = "bare", items = items or {}, stats = { health = health or 200, mana = 60 } })
end

-- Superbia on a 10x10 board at (5, 5), and one company body beside her.
local function field(foeX, foeY, opts)
    local c = Fixture.combat(Fixture.new(10, 10, opts), { body(foeX or 1, foeY or 1) }, { unit(GENERAL, 5, 5) })
    return c, one(c, GENERAL), c.units[1]
end

-- Wound her down to just above `fraction` of her max, then land one blow that crosses it.
local function woundTo(c, sup, fraction)
    local max = Combat.unreservedMax(sup.char, "health")
    sup.char.stats.health.current = math.floor(max * fraction) + 5
    Combat.dealFlatDamage(c, sup, 30, { "physical" })
end

return {
    -- ------------------------------------------------------------------------------ the body
    {
        name = "Superbia is a 2x2 angel boss who flies, without Incorruptible, and carries none of Sublimitas's kit",
        fn = function()
            local def = Character.defs[GENERAL]
            assert(def.name == "Superbia, the Morning Star", "the stair's general is the Morning Star")
            assert(def.race == "angel" and def.boss and def.tier == 4, "a fallen archangel, and the circle's boss")
            assert(def.footprint and def.footprint.w == 2 and def.footprint.h == 2, "four tiles: grand")
            local char = Character.instantiate(GENERAL)
            assert(not itemNamed(char, "utility_angel_blood"), "her own rule replaces Incorruptible")
            for _, id in ipairs(ORGANS) do
                assert(itemNamed(char, id), GENERAL .. " carries " .. id)
                local idef = Item.defs[id]
                assert(idef.class == "creature" and idef.noSteal, id .. " is her own and cannot be taken")
            end
            for _, gone in ipairs({ "utility_codex_unanswered", "ability_rain", "ability_raise_dead",
                "ability_doppelganger", "weapon_wand", "ability_fire_bolt" }) do
                assert(not itemNamed(char, gone), gone .. " went with Sublimitas")
            end
            local c, sup = field()
            assert(Combat.isFlying(sup), "she keeps the wings")
            assert(not Status.isImmune(sup, "status_blessing", sup), "a buff is never refused")
            local r = Character.defs[MorningStar.REFLECTION]
            assert(r.tier == 1 and r.race == "angel", "a Reflection is chaff, and an angel")
            assert(itemNamed(Character.instantiate(MorningStar.REFLECTION), "utility_light_bearer"),
                "a Reflection carries Light-Bearer")
            assert(c ~= nil)
        end,
    },
    -- ------------------------------------------------------------------------------ non serviam
    {
        name = "Non Serviam: a foe's debuff rebounds onto whoever laid it, at full length, and never touches her",
        fn = function()
            local c, sup, foe = field(3, 5)
            assert(Status.apply(c, sup, "status_root", { applier = foe, duration = 7 }) == nil,
                "nothing lands on her")
            assert(not Status.has(sup, "status_root"), "the Root never touches her")
            local sent = Status.get(foe, "status_root")
            assert(sent, "the Root rebounds onto the body that laid it")
            assert(sent.remaining == 7, "at the length it was laid, got " .. tostring(sent.remaining))
            -- Nobody to send it to: ground no one of her side laid. She refuses it.
            assert(Status.apply(c, sup, "status_cripple", {}) == nil and not Status.has(sup, "status_cripple"),
                "a debuff with no layer does not touch her either")
            assert(Status.isImmune(sup, "status_cripple", foe), "the hover reads her as proof against a foe's debuff")
            -- Her own side's still lands, as an angel's does.
            assert(Status.apply(c, sup, "status_cripple", { applier = sup }), "what her own side lays still lands")
        end,
    },
    {
        name = "the Morning Star: once per turn a debuff rebounds, the second lands, and her turn's end resets it",
        fn = function()
            local c = Fixture.combat(Fixture.new(6, 6), { body(2, 2, { "utility_the_morning_star" }) },
                { unit("character_archer", 4, 4, { isolate = "bare", stats = { health = 200 } }) })
            local bearer, foe = c.units[1], c.units[2]
            Status.apply(c, bearer, "status_root", { applier = foe })
            assert(Status.has(foe, "status_root") and not Status.has(bearer, "status_root"), "the first rebounds")
            Status.apply(c, bearer, "status_cripple", { applier = foe })
            assert(Status.has(bearer, "status_cripple") and not Status.has(foe, "status_cripple"),
                "the second in the same turn lands")
            Trait.onAnyTurnEnd(c, bearer)
            Status.apply(c, bearer, "status_stun", { applier = foe })
            assert(not Status.has(bearer, "status_stun") and Status.has(foe, "status_stun"),
                "a new turn, a new rebound")
            assert(not Status.isImmune(bearer, "status_burn", foe), "the relic refuses nothing outright")
        end,
    },
    -- ------------------------------------------------------------------------------ light-bearer
    {
        name = "Light-Bearer: a foe that opens its turn in her sight is Blinded until it ends; behind a wall, not",
        fn = function()
            local wall = {}
            for y = 1, 10 do wall[#wall + 1] = { x = 3, y = y, walkable = false, sightCost = 2 } end
            local c = Fixture.combat(Fixture.new(10, 10, { tiles = wall }),
                { body(8, 9), body(1, 5) }, { unit(GENERAL, 5, 5) })
            local seen, hidden = c.units[1], c.units[2]
            Trait.onAnyTurnStart(c, seen)
            assert(Status.has(seen, "status_blind"), "a foe in her sight is Blinded")
            Trait.onAnyTurnStart(c, hidden)
            assert(not Status.has(hidden, "status_blind"), "a foe out of her sight is not")
            Trait.onAnyTurnEnd(c, seen)
            assert(not Status.has(seen, "status_blind"), "the Blind lifts as that turn ends")
        end,
    },
    -- ------------------------------------------------------------------------------ flawless form
    {
        name = "Flawless Form: no blow takes more than a tenth of her health, and the hover quotes the cap",
        fn = function()
            local c, sup, foe = field(3, 5)
            local before = hp(sup)
            local cap = math.floor(Combat.unreservedMax(sup.char, "health") * 0.1)
            Combat.dealFlatDamage(c, sup, 500, { "physical" }, nil, foe)
            assert(before - hp(sup) == cap, string.format("a huge blow takes %d, the cap, got %d", cap, before - hp(sup)))
            Combat.dealFlatDamage(c, sup, 500, { "physical" }, nil, foe, { critical = true })
            assert(before - hp(sup) == 2 * cap, "a crit is capped too")
            local sword = Item.instantiate("weapon_iron_sword")
            foe.char.stats.damage = 400
            assert(Combat.computeDamage(c, foe, sup, sword) == cap, "the hover agrees with the blow")
            -- Perfect Plate is the same rule at a quarter.
            local c2 = Fixture.combat(Fixture.new(6, 6), { body(2, 2, { "armor_perfect_plate" }, 100) },
                { unit("character_archer", 3, 2, { isolate = "bare" }) })
            local knight = c2.units[1]
            Combat.dealFlatDamage(c2, knight, 500, { "physical" })
            assert(hp(knight) == 75, "Perfect Plate holds a blow to a quarter, left " .. hp(knight))
        end,
    },
    -- ------------------------------------------------------------------------------ the host
    {
        name = "the Host descends at two-thirds: two Reflections at once, two more at each of her turns' ends",
        fn = function()
            local c, sup = field(1, 1)
            woundTo(c, sup, 0.8)
            assert(#reflections(c) == 0, "above two-thirds the Host has not come")
            woundTo(c, sup, MorningStar.HOST_AT)
            local host = reflections(c, sup.side)
            assert(#host == 2, "two Reflections on the threshold, got " .. #host)
            assert(host[1].fragile and host[1].summoner == sup, "a Reflection is hers, and any blow fells it")
            Trait.onAnyTurnEnd(c, sup)
            assert(#reflections(c, sup.side) == 4, "two more at the end of her turn")
            Combat.dealFlatDamage(c, host[1], 1, { "physical" })
            assert(not host[1].alive, "one blow kills a Reflection")
        end,
    },
    -- ------------------------------------------------------------------------------ the fall
    {
        name = "the Fall at one-third: the Host shatters, she lands, the ice rings out, and she hits harder per ring",
        fn = function()
            local c, sup = field(1, 1)
            woundTo(c, sup, MorningStar.HOST_AT)
            assert(#reflections(c) == 2, "the Host has come")
            woundTo(c, sup, MorningStar.FALL_AT)
            assert(#reflections(c) == 0, "every Reflection shatters")
            assert(not Combat.isFlying(sup), "she can no longer fly")
            -- Ring 1 round her 2x2 at (5,5)-(6,6): the 4x4 perimeter from (4,4) to (7,7).
            assert(Hazard.at(c, 4, 4, MorningStar.ICE) and Hazard.at(c, 7, 7, MorningStar.ICE), "the first ring freezes")
            assert(not Hazard.at(c, 3, 3, MorningStar.ICE), "and only the first")
            assert(not Hazard.at(c, 5, 5, MorningStar.ICE), "not the ground she stands on")
            assert((sup.bonus.damage or 0) == MorningStar.ICE_DAMAGE, "+2 Damage for the first ring")
            Trait.onAnyTurnEnd(c, sup)
            assert(Hazard.at(c, 3, 3, MorningStar.ICE) and Hazard.at(c, 8, 8, MorningStar.ICE),
                "the ice spreads a ring at her turn's end")
            assert(sup.bonus.damage == 2 * MorningStar.ICE_DAMAGE, "+2 more for the second ring")
            assert(#reflections(c) == 0, "the Host does not come again after the Fall")
        end,
    },
    {
        name = "the Fall over ground nobody stands on lands her on the nearest ground that holds her",
        fn = function()
            local void = {}
            for y = 5, 6 do for x = 5, 6 do void[#void + 1] = { x = x, y = y, walkable = false } end end
            local c, sup = field(1, 1, { tiles = void })
            assert(sup.x == 5 and sup.y == 5, "she hangs over the void on her wings")
            woundTo(c, sup, MorningStar.FALL_AT)
            assert(Combat.footprintFree(c, 2, 2, sup.x, sup.y, sup), "she lands on ground that holds her")
        end,
    },
    {
        name = "the ice: a body that ends two turns running on it is Frozen, and a turn off it starts the count again",
        fn = function()
            local c, sup, foe = field(4, 5)
            woundTo(c, sup, MorningStar.FALL_AT)
            assert(Hazard.at(c, 4, 5, MorningStar.ICE), "the foe is standing on the first ring")
            Trait.onAnyTurnEnd(c, foe)
            assert(not Status.has(foe, "status_freeze"), "one turn on the ice is not enough")
            Trait.onAnyTurnEnd(c, foe)
            assert(Status.has(foe, "status_freeze"), "two in a row, and it is Frozen")
            Status.remove(c, foe, "status_freeze")
            Trait.onAnyTurnEnd(c, foe)
            foe.x = 1
            Trait.onAnyTurnEnd(c, foe)
            foe.x = 4
            Trait.onAnyTurnEnd(c, foe)
            assert(not Status.has(foe, "status_freeze"), "a turn off the ice starts the count again")
        end,
    },
    -- ------------------------------------------------------------------------------ the drops
    {
        name = "her five pieces are real class trophies, never a creature's, relic first",
        fn = function()
            for _, entry in ipairs(DROPS) do
                local id, class = entry[1], entry[2]
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.class == class, id .. " sits on the " .. class .. " shelf, got " .. tostring(def.class))
                assert(def.class ~= "creature", id .. ": there is never a creature-class drop")
                assert(def.unstocked and def.price == nil, id .. " is a trophy: seen on the rack, never sold")
                assert(#(def.description or "") <= 120, id .. "'s description is short")
            end
            assert(DROPS[1][1] == "utility_the_morning_star", "her relic is first")
        end,
    },
    {
        name = "the Mirror of the Morning calls two Reflections once, below two-thirds",
        fn = function()
            local c = Fixture.combat(Fixture.new(6, 6), { body(3, 3, { "utility_mirror_of_the_morning" }, 90) },
                { unit("character_archer", 6, 6, { isolate = "bare" }) })
            local bearer = c.units[1]
            Combat.dealFlatDamage(c, bearer, 10, { "physical" })
            assert(#reflections(c) == 0, "above two-thirds nothing comes")
            Combat.dealFlatDamage(c, bearer, 30, { "physical" })
            assert(#reflections(c, bearer.side) == 2, "two Reflections fight beside the bearer")
            Combat.dealFlatDamage(c, bearer, 5, { "physical" })
            assert(#reflections(c) == 2, "only the first time each fight")
        end,
    },
    {
        name = "the Cocytus Wing freezes the ring around its caster for three turns, and not the caster's tile",
        fn = function()
            local c = Fixture.combat(Fixture.new(6, 6), { body(3, 3, { "ability_cocytus_wing" }) },
                { unit("character_archer", 6, 6, { isolate = "bare" }) })
            local mage = c.units[1]
            Fixture.openTurn(c, mage)
            local ok = Combat.useItem(c, mage, itemNamed(mage.char, "ability_cocytus_wing"), mage.x, mage.y)
            assert(ok, "the wing is cast")
            local n = 0
            for _, h in ipairs(c.hazards or {}) do
                if h.alive and h.id == MorningStar.ICE then n = n + 1 end
            end
            assert(n == 8, "eight tiles of Black Ice round the caster, got " .. n)
            assert(not Hazard.at(c, 3, 3, MorningStar.ICE), "the caster's own tile stays clear")
            -- Three turns (15 ticks), less whatever the cast's own speed has already spent of them.
            local left = Hazard.at(c, 2, 2, MorningStar.ICE).remaining
            assert(left > 10 and left <= 15, "three turns of ice, got " .. tostring(left))
        end,
    },
}
