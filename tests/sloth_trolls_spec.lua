-- Tests for SLOTH'S TROLLS AND ITS OGRE (slice B of "Sloth's Bestiary", reviewed 2026-10-03..04): the bodies under
-- the meltwater bridges, their rules, their drops and their two fights.
--
--   the Troll           a heavy club, hard and slow; Indifferent (the race, pinned in sloth_foundation_spec)
--   the Toll-Troll      THE TOLL: whatever of yours USES something in its reach is struck first; walking and
--                       waiting are left alone. It holds its bridge
--   the Troll Scarlord  SCARRING BLOWS: a body its club strikes cannot be healed or regrow until its next turn
--   the Ogre            CAN'T BE BOTHERED: it never walks; it throws the nearest body beside it, either side, at the
--                       company's farthest within 4 -- both take impact, the body lands beside its target -- or a
--                       slab of ice for half with nobody beside it
--   the drops           Troll Blood, the Grafted Troll Arm, Bridge Tax, the Scarring Club, Ogre's Heave
--
-- Each case pins one approved rule on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local AI = require("models.ai")
local Trolls = require("models.sloth_trolls")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = { "character_troll", "character_toll_troll", "character_troll_scarlord", "character_sloth_ogre" }
local DROPS = {
    character_troll = { "consumable_troll_blood", "utility_grafted_troll_arm" },
    character_toll_troll = { "utility_bridge_tax" },
    character_troll_scarlord = { "weapon_scarring_club" },
    character_sloth_ogre = { "ability_ogres_heave" },
}
local TROPHY_CLASS = {
    consumable_troll_blood = "apothecary", utility_grafted_troll_arm = "plague_knight",
    utility_bridge_tax = "mammonite", weapon_scarring_club = "fighter", ability_ogres_heave = "barbarian",
}
local KIT = { "weapon_troll_club", "weapon_bridge_maul", "utility_the_toll", "weapon_scarlords_club",
    "utility_scarring_blows", "ability_cant_be_bothered" }

local function board(n) return Fixture.new(n or 9, n or 9) end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

-- A plain body of the company, bare, with `items` and a deep pool.
local function body(x, y, items, health)
    return unit("character_archer", x, y, { isolate = "bare", items = items or {},
        stats = { health = health or 200, stamina = 200, mana = 200 } })
end

local function maxHp(u) return Combat.unreservedMax(u.char, "health") end

local function wound(c, u, n, tags)
    Combat.dealFlatDamage(c, u, n, tags or { "physical" }, "test", nil, { raw = true })
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "every troll is a troll, a humanoid that carries Indifferent, and the Ogre is a 2x2 beast",
        fn = function()
            for _, id in ipairs({ "character_troll", "character_toll_troll", "character_troll_scarlord" }) do
                local c = Character.instantiate(id)
                assert(c.race == "troll" and c.kind == "humanoid", id .. " is a troll")
                assert(itemNamed(c, "utility_troll_blood"), id .. ": the race put Indifferent in the grid")
            end
            local def = Character.defs["character_sloth_ogre"]
            assert(def.name == "Ogre" and def.race == "beast", "Sloth's Ogre is a beast called Ogre")
            assert(def.footprint and def.footprint.w == 2 and def.footprint.h == 2, "on the 2x2 pattern")
            assert(Character.defs["character_ogre"] and Character.defs["character_war_ogre"],
                "the reference ogre and the War Ogre are untouched")
            assert(Character.defs["character_troll"].tier == 2, "the Troll is the line body")
            assert(Character.defs["character_toll_troll"].tier == 3 and Character.defs["character_troll_scarlord"].tier == 3
                and def.tier == 3, "the Toll-Troll, the Scarlord and the Ogre are tier 3")
        end,
    },
    {
        name = "the bodies' kit is the creature's own, and each drops the approved trophy off the approved shelf",
        fn = function()
            for _, id in ipairs(KIT) do
                local d = Item.defs[id]
                assert(d and d.class == "creature" and d.noSteal, id .. " is a creature's own kit")
            end
            for _, id in ipairs(BODIES) do
                local want = DROPS[id]
                local got = Character.defs[id].drops or {}
                assert(#got == #want, id .. " drops " .. #want)
                for i, d in ipairs(want) do assert(got[i] == d, id .. " drops " .. d) end
            end
            for id, class in pairs(TROPHY_CLASS) do
                local d = Item.defs[id]
                assert(d and d.class == class, id .. " sits on the " .. class .. " shelf")
                assert(d.unstocked, id .. " is a trophy, never sold")
            end
            assert(Item.archetype(Item.defs["weapon_scarring_club"]) == "hammer", "the Scarring Club is a hammer")
            assert(Item.archetype(Item.defs["weapon_troll_club"]) == "hammer"
                and Item.defs["weapon_troll_club"].activeAbility.speed == 7, "the troll's club hits hard and slow")
        end,
    },
    {
        name = "the Toll-Troll and the Ogre never walk",
        fn = function()
            local c = Fixture.combat(board(), body(1, 1), {
                unit("character_toll_troll", 5, 5), unit("character_sloth_ogre", 2, 6) })
            for _, id in ipairs({ "character_toll_troll", "character_sloth_ogre" }) do
                local u = one(c, id)
                Combat.refreshPassives(u)
                assert(Combat.moveBudget(u) == 0, id .. " stays where it stands")
            end
        end,
    },

    -- ------------------------------------------------------------------------------ the Toll
    {
        name = "the Toll: a body that uses something in its reach is struck first, and the use still lands",
        fn = function()
            local c = Fixture.combat(board(), body(4, 4, { "weapon_iron_sword" }), {
                unit("character_toll_troll", 4, 5, { stats = { health = 300 } }) })
            local troll = one(c, "character_toll_troll")
            local user = c.units[1] ~= troll and c.units[1] or c.units[2]
            local before, trollBefore = hp(user), hp(troll)
            local ok = Fixture.strike(c, user, troll, itemNamed(user.char, "weapon_iron_sword"))
            assert(ok, "the use resolved")
            assert(hp(user) < before, "the troll struck first")
            assert(hp(troll) < trollBefore, "and the blow still landed after")
        end,
    },
    {
        name = "the Toll reaches as far as the maul: two tiles, and not three",
        fn = function()
            local c = Fixture.combat(board(), body(4, 3, { "consumable_troll_blood" }), {
                unit("character_toll_troll", 4, 5) })
            local user = c.units[1].side == "party" and c.units[1] or c.units[2]
            local before = hp(user)
            openTurn(c, user)
            assert(Combat.useItem(c, user, itemNamed(user.char, "consumable_troll_blood"), user.x, user.y))
            assert(hp(user) < before, "a draught drunk two tiles off is a use in reach")
            local c2 = Fixture.combat(board(), body(4, 2, { "consumable_troll_blood" }), {
                unit("character_toll_troll", 4, 5) })
            local far = c2.units[1].side == "party" and c2.units[1] or c2.units[2]
            local hp2 = hp(far)
            openTurn(c2, far)
            assert(Combat.useItem(c2, far, itemNamed(far.char, "consumable_troll_blood"), far.x, far.y))
            assert(hp(far) == hp2, "three tiles off, the troll does not reach")
        end,
    },
    {
        name = "the Toll leaves alone a body that only walks through, or waits",
        fn = function()
            local c = Fixture.combat(board(), body(3, 4), { unit("character_toll_troll", 4, 5) })
            local user = c.units[1].side == "party" and c.units[1] or c.units[2]
            local before = hp(user)
            openTurn(c, user)
            assert(Combat.moveUnit(c, user, 5, 4), "it walks past the troll")
            assert(hp(user) == before, "walking is not a use")
            Combat.pass(c, user)
            assert(hp(user) == before, "and nor is waiting")
        end,
    },
    {
        name = "a toll that fells the user takes the action with it",
        fn = function()
            local c = Fixture.combat(board(), body(4, 4, { "weapon_iron_sword" }, 1), {
                unit("character_toll_troll", 4, 5, { stats = { health = 300 } }) })
            local user = c.units[1].side == "party" and c.units[1] or c.units[2]
            local troll = one(c, "character_toll_troll")
            local trollBefore = hp(troll)
            local ok, result = Fixture.strike(c, user, troll, itemNamed(user.char, "weapon_iron_sword"))
            assert(ok and result and result.tolled, "the turn is over, not refused")
            assert(not user.alive, "the toll felled it")
            assert(hp(troll) == trollBefore, "and the blow never arrived")
        end,
    },
    {
        name = "a Stunned troll collects nothing",
        fn = function()
            local c = Fixture.combat(board(), body(4, 3, { "consumable_troll_blood" }), {
                unit("character_toll_troll", 4, 5) })
            local user = c.units[1].side == "party" and c.units[1] or c.units[2]
            Status.apply(c, one(c, "character_toll_troll"), "status_stun", {})
            local before = hp(user)
            openTurn(c, user)
            assert(Combat.useItem(c, user, itemNamed(user.char, "consumable_troll_blood"), user.x, user.y))
            assert(hp(user) == before, "a troll that cannot react does not collect")
        end,
    },

    -- ------------------------------------------------------------------------------ the Scarlord
    {
        name = "Scarring Blows: a body the Scarlord strikes cannot be healed or regrow until its next turn",
        fn = function()
            local c = Fixture.combat(board(), body(4, 4, { "consumable_troll_blood" }), {
                unit("character_troll_scarlord", 4, 5) })
            local victim = c.units[1].side == "party" and c.units[1] or c.units[2]
            local scarlord = one(c, "character_troll_scarlord")
            Status.apply(c, victim, "status_troll_blood", {})
            assert(Fixture.strike(c, scarlord, victim, itemNamed(scarlord.char, "weapon_scarlords_club")))
            assert(Status.has(victim, "status_unclosing_wound"), "the club scars")
            local struck = hp(victim)
            assert(Combat.applyHeal(c, victim, 30) == 0, "no heal lands")
            Trait.onAnyTurnStart(c, victim)
            assert(hp(victim) == struck, "and the troll blood regrows nothing")
            Trait.onAnyTurnStart(c, scarlord)
            assert(not Status.has(victim, "status_unclosing_wound"), "the scar comes off at the Scarlord's next turn")
            assert(Combat.applyHeal(c, victim, 30) > 0, "and the heal lands again")
        end,
    },
    {
        name = "the Scarring Club stops a troll's regrowth until the wielder's next turn",
        fn = function()
            local c = Fixture.combat(board(), body(4, 4, { "weapon_scarring_club" }), {
                unit("character_troll", 4, 5, { stats = { health = 200 } }) })
            local wielder = c.units[1].side == "party" and c.units[1] or c.units[2]
            local troll = one(c, "character_troll")
            assert(Fixture.strike(c, wielder, troll, itemNamed(wielder.char, "weapon_scarring_club")))
            local struck = hp(troll)
            Trait.onAnyTurnStart(c, troll)
            assert(hp(troll) == struck, "Indifferent regrows nothing through the scar")
            Trait.onAnyTurnStart(c, wielder)
            Trait.onAnyTurnStart(c, troll)
            assert(hp(troll) > struck, "and the troll regrows once the wielder's turn has come round")
        end,
    },

    -- ------------------------------------------------------------------------------ the Ogre
    {
        name = "Can't Be Bothered: the Ogre throws the body beside it at the company's farthest, and both take impact",
        fn = function()
            -- Ogre at (2,4)-(3,5); its own troll beside it at (4,4); the company near (4,7) and far (7,4).
            local c = Fixture.combat(board(), { body(4, 7), body(7, 4) }, {
                unit("character_sloth_ogre", 2, 4), unit("character_troll", 4, 4, { stats = { health = 200 } }) })
            local ogre, troll = one(c, "character_sloth_ogre"), one(c, "character_troll")
            local near, far
            for _, u in ipairs(c.units) do
                if u.side == "party" then if u.x == 7 then far = u else near = u end end
            end
            local plan = AI.preempt(c, ogre)
            assert(plan and plan.tx == troll.x and plan.ty == troll.y, "it lifts the body beside it, its own side or not")
            local trollBefore, farBefore = hp(troll), hp(far)
            openTurn(c, ogre)
            assert(Combat.useItem(c, ogre, plan.item, plan.tx, plan.ty))
            assert(Combat.unitGap(troll, far) == 1, "the thrown troll lands beside its target")
            assert(hp(troll) < trollBefore and hp(far) < farBefore, "both take the impact")
            assert(hp(near) == maxHp(near), "the nearer body is not the mark")
        end,
    },
    {
        name = "with nobody beside it, the Ogre throws a slab of ice for half",
        fn = function()
            local c = Fixture.combat(board(), { body(7, 5), body(4, 7) }, { unit("character_sloth_ogre", 2, 4) })
            local ogre = one(c, "character_sloth_ogre")
            local far = c.units[1].x == 7 and c.units[1] or c.units[2]
            local plan = AI.preempt(c, ogre)
            assert(plan and plan.tx == far.x and plan.ty == far.y, "the slab goes at the farthest within 4")
            local before = hp(far)
            openTurn(c, ogre)
            assert(Combat.useItem(c, ogre, plan.item, plan.tx, plan.ty))
            local slab = before - hp(far)
            assert(slab > 0, "the slab lands")
            -- And a thrown body lands the full blow: the same cast, aimed at a body beside it.
            local c2 = Fixture.combat(board(), { body(4, 4), body(6, 5) }, { unit("character_sloth_ogre", 2, 4) })
            local ogre2 = one(c2, "character_sloth_ogre")
            local far2 = c2.units[1].x == 6 and c2.units[1] or c2.units[2]
            local before2 = hp(far2)
            local plan2 = AI.preempt(c2, ogre2)
            openTurn(c2, ogre2)
            assert(Combat.useItem(c2, ogre2, plan2.item, plan2.tx, plan2.ty))
            assert(before2 - hp(far2) > slab, "a slab is half of a thrown body")
        end,
    },
    {
        name = "a body nothing can move is not lifted",
        fn = function()
            local c = Fixture.combat(board(), { body(4, 4), body(7, 4) }, { unit("character_sloth_ogre", 2, 4) })
            local ogre = one(c, "character_sloth_ogre")
            local rooted = c.units[1].x == 4 and c.units[1] or c.units[2]
            Status.apply(c, rooted, "status_root", { duration = 20 })
            assert(Trolls.besideBody(c, ogre) == nil, "a Rooted body beside it is not picked up")
            local plan = AI.preempt(c, ogre)
            assert(plan and plan.reason == "the slab", "so the slab goes instead")
        end,
    },
    {
        name = "Ogre's Heave: lift a body beside you and throw it at a foe; both take impact, it lands beside",
        fn = function()
            local c = Fixture.combat(board(), body(2, 4, { "ability_ogres_heave" }), {
                unit("character_troll", 3, 4, { stats = { health = 200 } }),
                unit("character_troll", 3, 7, { stats = { health = 200 } }) })
            local thrower = c.units[1].side == "party" and c.units[1] or c.units[2]
            local lifted, target
            for _, u in ipairs(c.units) do
                if u.side ~= thrower.side then if u.y == 4 then lifted = u else target = u end end
            end
            local a, b = hp(lifted), hp(target)
            openTurn(c, thrower)
            assert(Combat.useItem(c, thrower, itemNamed(thrower.char, "ability_ogres_heave"), lifted.x, lifted.y, nil,
                { x = target.x, y = target.y }))
            assert(Combat.unitGap(lifted, target) == 1, "it lands beside its target")
            assert(hp(lifted) < a and hp(target) < b, "and both take the impact")
            -- A landing with nobody on it throws nothing.
            local c2 = Fixture.combat(board(), body(2, 4, { "ability_ogres_heave" }), {
                unit("character_troll", 3, 4, { stats = { health = 200 } }) })
            local t2 = c2.units[1].side == "party" and c2.units[1] or c2.units[2]
            local l2 = one(c2, "character_troll")
            openTurn(c2, t2)
            assert(Combat.useItem(c2, t2, itemNamed(t2.char, "ability_ogres_heave"), l2.x, l2.y, nil, { x = 3, y = 7 }))
            assert(l2.x == 3 and l2.y == 4 and hp(l2) == 200, "no foe there: nothing is thrown")
        end,
    },

    -- ------------------------------------------------------------------------------ the drops
    {
        name = "Troll Blood: a fifth of your health each turn, the rest of the fight, unless fire or acid hit you",
        fn = function()
            local c = Fixture.combat(board(), body(2, 2, { "consumable_troll_blood" }), { body(8, 8) })
            local drinker = c.units[1].x == 2 and c.units[1] or c.units[2]
            openTurn(c, drinker)
            assert(Combat.useItem(c, drinker, itemNamed(drinker.char, "consumable_troll_blood"), drinker.x, drinker.y))
            assert(Status.has(drinker, "status_troll_blood"), "the blood is in them")
            wound(c, drinker, 100)
            local before = hp(drinker)
            Status.onTurnStart(c, drinker)
            assert(hp(drinker) == before + math.floor(maxHp(drinker) * 0.2), "a fifth comes back")
            wound(c, drinker, 10, { "fire" })
            local burned = hp(drinker)
            Status.onTurnStart(c, drinker)
            assert(hp(drinker) == burned, "burned: nothing this turn")
            Status.onTurnStart(c, drinker)
            assert(hp(drinker) > burned, "and it comes back the turn after")
            assert(Status.statBonus(drinker, "avoid") > -100, "and the drinker still dodges: that half is a troll's")
        end,
    },
    {
        name = "the Grafted Troll Arm regrows a tenth a turn, and an ally's heal does nothing to its bearer",
        fn = function()
            local c = Fixture.combat(board(), { body(2, 2, { "utility_grafted_troll_arm" }), body(2, 3, { "ability_heal" }) },
                { body(8, 8) })
            local bearer, healer
            for _, u in ipairs(c.units) do
                if u.side == "party" then if u.y == 2 then bearer = u else healer = u end end
            end
            wound(c, bearer, 100)
            local before = hp(bearer)
            Trait.onAnyTurnStart(c, bearer)
            assert(hp(bearer) == before + math.floor(maxHp(bearer) * 0.1), "a tenth comes back")
            local now = hp(bearer)
            openTurn(c, healer)
            assert(Combat.useItem(c, healer, itemNamed(healer.char, "ability_heal"), bearer.x, bearer.y))
            assert(hp(bearer) == now, "an ally's heal does nothing")
            assert(Trait.flag(bearer, "refusesAllyHeals"), "the arm says so")
        end,
    },
    {
        name = "Bridge Tax: a foe's ability within 2 is struck first, for a swing's stamina; a weapon is not",
        fn = function()
            local c = Fixture.combat(board(), body(4, 3, { "utility_bridge_tax", "weapon_iron_sword" }),
                { body(4, 5, { "consumable_troll_blood", "weapon_iron_sword", "ability_fire_bolt" }) })
            local keeper = c.units[1].side == "party" and c.units[1] or c.units[2]
            local foe = keeper == c.units[1] and c.units[2] or c.units[1]
            local stamina = Combat.resource(keeper.char, "stamina")
            local before = hp(foe)
            openTurn(c, foe)
            assert(Combat.useItem(c, foe, itemNamed(foe.char, "consumable_troll_blood"), foe.x, foe.y))
            assert(hp(foe) == before, "a draught is not an ability")
            openTurn(c, foe)
            assert(Combat.useItem(c, foe, itemNamed(foe.char, "ability_fire_bolt"), keeper.x, keeper.y))
            assert(hp(foe) < before, "an ability within 2 is taxed")
            assert(Combat.resource(keeper.char, "stamina") < stamina, "and the tax is a swing's stamina")
        end,
    },

    -- ------------------------------------------------------------------------------ the fights
    {
        name = "the fights: Under the Bridge on the approach, the Heave on the seat, both tundra",
        fn = function()
            local bridge = Encounter.defs["encounter_sloth_under_the_bridge"]
            local heave = Encounter.defs["encounter_sloth_the_heave"]
            assert(bridge.kind == "combat" and bridge.rung == 1 and bridge.weight == 3, "Under the Bridge: rung 1, weight 3")
            assert(heave.kind == "combat" and heave.rung == 2 and heave.weight == 3, "the Heave: rung 2, weight 3")
            assert(bridge.condition({ biome = "tundra" }) and not bridge.condition({ biome = "desert" }), "tundra")
            assert(heave.condition({ biome = "tundra" }) and not heave.condition({ biome = "forest" }), "tundra")
            local Arena = require("models.arena")
            for seed = 1, 20 do
                local ids = Arena.resolveComposition(bridge.composition, { depth = 9, seed = seed })
                local tolls, trolls = 0, 0
                for _, id in ipairs(ids) do
                    if id == "character_toll_troll" then tolls = tolls + 1 end
                    if id == "character_troll" then trolls = trolls + 1 end
                end
                assert(tolls == 1 and trolls >= 1 and trolls <= 2 and #ids == tolls + trolls,
                    "a Toll-Troll and one or two Trolls")
            end
            local ids = Arena.resolveComposition(heave.composition, { depth = 10, seed = 3 })
            table.sort(ids)
            assert(table.concat(ids, ",") == "character_sloth_ogre,character_troll,character_troll,character_troll_scarlord",
                "an Ogre, a Scarlord and two Trolls")
        end,
    },
}
