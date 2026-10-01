-- Tests for THE ELVES OF PRIDE, the approach's line (2026-09-30, "Pride's Bestiary"): the bodies that wear the race's
-- Unblemished (tests/elf_race_spec.lua pins the race), their own rules, their fights and their drops.
--
--   Elf Retainer      the filler: the race rule and a spear, and nothing else           -> Livery of the House
--   Elf Longbow       DRAWN STANCE: drawn unmoved, the shot cannot be avoided and carries through to the body
--                     behind                                                             -> Heartstring Longbow
--   Elf Bladedancer   UNTOUCHABLE: while Unblemished, every attack that rolls to hit is evaded -> Dancer's Veil
--   Elf Starcaller    BORN TO THE HEIGHT: Exposure does nothing to it; on it, +3 Magic Damage and +1 reach
--                                                                                        -> Skywalker's Sandals
--   Elf Highborn      WILL NOT ADMIT THE WOUND: a full round unstruck and it is Unblemished again
--                                                                                        -> Highborn Circlet
--   The Elf-Lord      RENOWN: every elf kill is a stack on him (+2 Damage, +1 Speed), and elves within 3 take +1
--                     Damage a stack                                                     -> Laurel of Renown
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local ELVES = {
    "character_elf_retainer", "character_elf_longbow", "character_elf_bladedancer", "character_elf_starcaller",
    "character_elf_highborn", "character_elf_lord",
}
local TROPHIES = {
    character_elf_retainer = "armor_livery_of_the_house",
    character_elf_longbow = "weapon_heartstring_longbow",
    character_elf_bladedancer = "armor_dancers_veil",
    character_elf_starcaller = "armor_skywalkers_sandals",
    character_elf_highborn = "utility_highborn_circlet",
    character_elf_lord = "utility_laurel_of_renown",
}
local SHELF = {
    armor_livery_of_the_house = "knight", weapon_heartstring_longbow = "hunter", armor_dancers_veil = "duelist",
    armor_skywalkers_sandals = "mage", utility_highborn_circlet = "knight", utility_laurel_of_renown = "warlord",
}
local ORGANS = { "utility_untouchable", "utility_born_to_the_height", "utility_will_not_admit", "utility_renown" }
local FIGHTS = {
    encounter_pride_elf_patrol = "combat", encounter_pride_the_ring = "combat", encounter_pride_on_the_span = "combat",
    encounter_pride_the_court = "combat", encounter_pride_the_elf_lord = "elite",
}

local function board() return Fixture.new(11, 11) end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function sided(c, side)
    local out = {}
    for _, u in ipairs(c.units) do if u.side == side then out[#out + 1] = u end end
    return out
end

-- A plain company body, health 100 at full, carrying `items` and nothing else.
local function body(x, y, items)
    return unit("character_archer", x, y, { isolate = "bare", items = items, stats = { health = 100 } })
end

-- The dice let back in for a reading the suite otherwise pins (Combat.FORCE_HIT), and pinned again after.
local function withDice(fn)
    local pinned = Combat.FORCE_HIT
    Combat.FORCE_HIT = false
    local ok, err = pcall(fn)
    Combat.FORCE_HIT = pinned
    if not ok then error(err, 0) end
end

local function wound(c, u, by, amount)
    Combat.dealFlatDamage(c, u, amount or 5, { "physical" }, "test", by, { raw = true })
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "every elf of the approach is an elf, and each drops its own trophy onto a real shelf",
        fn = function()
            for _, id in ipairs(ELVES) do
                local def = Character.defs[id]
                assert(def and def.race == "elf", id .. " is an elf")
                assert(def.class ~= "knight", id .. " is not on the knight table (it walls a line body at depth)")
                local c = Character.instantiate(id)
                assert(itemNamed(c, "utility_elf_blood"), id .. " wears the race's Unblemished")
                local trophy = TROPHIES[id]
                assert(def.drops and def.drops[1] == trophy, id .. " drops " .. trophy)
                local t = Item.defs[trophy]
                assert(t and t.unstocked and not t.price, trophy .. " is a trophy: seen on the rack, never sold")
                assert(t.class == SHELF[trophy], trophy .. " sits on the " .. SHELF[trophy] .. " shelf")
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal and def.bound, id .. " is an organ, never kit")
            end
            assert(Character.defs["character_elf_lord"].boss, "the Elf-Lord is a boss body")
        end,
    },
    {
        name = "five fights stand on the spire's approach, and the Elf-Lord's is the elite",
        fn = function()
            for id, kind in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e, id .. " exists")
                assert(e.rung == 1, id .. " stands on the approach (rung 1)")
                assert(e.kind == kind, id .. " is a " .. kind)
                assert(e.condition({ biome = "spire" }) and not e.condition({ biome = "castle" }),
                    id .. " is locked to the spire")
            end
            local lord = Encounter.get("encounter_pride_the_elf_lord").composition({ depth = 13 })
            local fielded = {}
            for _, id in ipairs(lord) do fielded[id] = true end
            assert(fielded.character_elf_lord and fielded.character_elf_longbow and fielded.character_elf_bladedancer
                and fielded.character_elf_retainer, "the Lord is fielded with a longbow, a bladedancer and retainers")
        end,
    },
    -- ------------------------------------------------------------------------------ the Retainer
    {
        name = "the Retainer carries the race rule and a spear and nothing else; its Livery guards only the unmarked",
        fn = function()
            local c = Character.instantiate("character_elf_retainer")
            local held = {}
            for _, item in ipairs(Character.eachItem(c)) do held[#held + 1] = item.id end
            table.sort(held)
            assert(#held == 2 and held[1] == "utility_elf_blood" and held[2] == "weapon_iron_spear",
                "a spear and Unblemished: " .. table.concat(held, ", "))

            local cb = Fixture.combat(board(), body(5, 5, { "armor_livery_of_the_house" }),
                unit("character_elf_retainer", 5, 6))
            local wearer, foe = sided(cb, "party")[1], sided(cb, "enemy")[1]
            local whole = Combat.flatStat(wearer, "defense")
            wound(cb, wearer, foe)
            assert(Combat.flatStat(wearer, "defense") == whole - 3, "the first wound takes the Livery's 3 Defense")
            Combat.applyHeal(cb, wearer, 50)
            assert(Combat.flatStat(wearer, "defense") == whole, "and a heal back to full returns it")
        end,
    },
    -- ------------------------------------------------------------------------------ the Longbow
    {
        name = "Drawn Stance: drawn unmoved, the Heartstring's shot cannot be avoided; moved, it rolls",
        fn = function()
            withDice(function()
                local c = Fixture.combat(board(), body(5, 5), unit("character_elf_longbow", 5, 1))
                local foe, archer = sided(c, "party")[1], one(c, "character_elf_longbow")
                local bow = itemNamed(archer.char, "weapon_heartstring_longbow")
                openTurn(c, archer)
                assert(not Combat.rollsToHit(c, archer, foe, bow), "an unmoved draw is not asked the dice")
                assert(Combat.hitChance(c, archer, foe, bow) == 100, "and the forecast says so")
                c.turn.moved = true
                assert(Combat.rollsToHit(c, archer, foe, bow), "a moved archer's shot rolls like any other")
            end)
        end,
    },
    {
        name = "Drawn Stance: the shot carries through to the body behind, and only from an unmoved draw",
        fn = function()
            local c = Fixture.combat(board(), { body(5, 4), body(5, 5) }, unit("character_elf_longbow", 5, 1))
            local front, back = sided(c, "party")[1], sided(c, "party")[2]
            local archer = one(c, "character_elf_longbow")
            local bow = itemNamed(archer.char, "weapon_heartstring_longbow")
            openTurn(c, archer)
            assert(Combat.useItem(c, archer, bow, front.x, front.y), "the draw begins")
            assert(archer.channel and archer.channel.drawn, "and it is judged at the draw: unmoved")
            Combat.resolveChannel(c, archer)
            assert(hp(front) < 100, "the arrow strikes its mark")
            assert(hp(back) < 100, "and carries through to the body behind")

            local c2 = Fixture.combat(board(), { body(5, 4), body(5, 5) }, unit("character_elf_longbow", 5, 1))
            local front2, back2 = sided(c2, "party")[1], sided(c2, "party")[2]
            local archer2 = one(c2, "character_elf_longbow")
            openTurn(c2, archer2)
            c2.turn.moved = true
            assert(Combat.useItem(c2, archer2, itemNamed(archer2.char, "weapon_heartstring_longbow"), front2.x, front2.y),
                "a moved archer still draws")
            Combat.resolveChannel(c2, archer2)
            assert(hp(front2) < 100 and hp(back2) == 100, "but its arrow stops in the first body")
            assert(Item.windupRange(Item.defs["weapon_heartstring_longbow"].activeAbility) >= 1,
                "the Heartstring is a longbow: drawn before it looses")
        end,
    },
    -- ------------------------------------------------------------------------------ the Bladedancer
    {
        name = "Untouchable: while Unblemished the Bladedancer evades every attack that rolls; marred, it does not",
        fn = function()
            withDice(function()
                local c = Fixture.combat(board(), body(5, 6), unit("character_elf_bladedancer", 5, 5))
                local foe, dancer = sided(c, "party")[1], one(c, "character_elf_bladedancer")
                local sword = Item.instantiate("weapon_iron_sword")
                assert(Combat.rollsToHit(c, foe, dancer, sword), "a sword asks the dice")
                assert(Combat.hitChance(c, foe, dancer, sword) == 0, "and while it is Unblemished, the answer is none")
                wound(c, dancer, nil) -- a blow that never rolled: a trap, a spell, the ground
                assert(not Status.has(dancer, "status_unblemished"), "something that does not roll can mar it")
                assert(Combat.hitChance(c, foe, dancer, sword) > 0, "and once marred it is an ordinary swordsman")
            end)
        end,
    },
    {
        name = "the Dancer's Veil: at full health, the first rolled attack each round misses; the bearer's turn re-arms it",
        fn = function()
            withDice(function()
                local c = Fixture.combat(board(), body(5, 6, { "armor_dancers_veil" }), unit("character_elf_retainer", 5, 5))
                local wearer, foe = sided(c, "party")[1], one(c, "character_elf_retainer")
                local spear = itemNamed(foe.char, "weapon_iron_spear")
                assert(Combat.veilReady(wearer) and Combat.hitChance(c, foe, wearer, spear) == 0,
                    "the first blow of the round is evaded, and the forecast says so")
                Fixture.strike(c, foe, wearer, spear)
                assert(hp(wearer) == 100, "the swing misses")
                assert(not Combat.veilReady(wearer), "and the veil is spent for the round")
                Trait.onAnyTurnEnd(c, wearer)
                assert(Combat.veilReady(wearer), "the wearer's own turn ending re-arms it")
                wound(c, wearer, foe)
                assert(not Combat.veilReady(wearer), "and a wounded wearer has no veil at all")
            end)
        end,
    },
    -- ------------------------------------------------------------------------------ the Starcaller
    {
        name = "Born to the Height: Exposure does nothing to the Starcaller, and pays it +3 Magic Damage and a tile",
        fn = function()
            local c = Fixture.combat(board(), body(1, 1),
                { unit("character_elf_starcaller", 5, 5), unit("character_elf_retainer", 7, 5) })
            local sc, ret = one(c, "character_elf_starcaller"), one(c, "character_elf_retainer")
            local bolt = itemNamed(sc.char, "ability_ice_bolt").activeAbility
            local magic, reach = Combat.flatStat(sc, "magicDamage"), Combat.abilityRange(c, sc, bolt)
            -- Sided to the company, so to every elf it is a foe's ground.
            Hazard.place(c, 5, 5, "hazard_exposure", { side = "party" })
            Hazard.place(c, 7, 5, "hazard_exposure", { side = "party" })
            assert(Status.has(ret, "status_vulnerable_pierce"), "Exposure opens an ordinary elf to the point")
            assert(not Status.has(sc, "status_vulnerable_pierce"), "and does nothing to the Starcaller")
            assert(Combat.flatStat(sc, "magicDamage") == magic + 3, "on it, +3 Magic Damage")
            assert(Combat.abilityRange(c, sc, bolt) == reach + 1, "and a tile further out")
        end,
    },
    {
        name = "the Skywalker's Sandals: no hostile ground does anything to the wearer, and standing on it pays +2 Magic Damage",
        fn = function()
            local c = Fixture.combat(board(), body(5, 5, { "armor_skywalkers_sandals" }), unit("character_elf_retainer", 9, 9))
            local wearer = sided(c, "party")[1]
            local magic = Combat.flatStat(wearer, "magicDamage")
            Hazard.place(c, 5, 5, "hazard_fire")
            assert(not Status.has(wearer, "status_burn"), "fire underfoot does not burn the wearer")
            assert(Combat.flatStat(wearer, "magicDamage") == magic + 2, "and standing in it pays +2 Magic Damage")
            assert(Hazard.tileBias(c, 5, 5, wearer.side, wearer) == 0, "its planner reads the fire as open floor")
        end,
    },
    -- ------------------------------------------------------------------------------ the Highborn
    {
        name = "Will Not Admit the Wound: a full round unstruck and the Highborn is Unblemished again",
        fn = function()
            local c = Fixture.combat(board(), body(5, 6), unit("character_elf_highborn", 5, 5))
            local foe, hb = sided(c, "party")[1], one(c, "character_elf_highborn")
            wound(c, hb, foe)
            assert(not Status.has(hb, "status_unblemished"), "the wound mars it")
            Trait.onAnyTurnEnd(c, hb) -- the round it was struck in ends; the count begins
            assert(not Status.has(hb, "status_unblemished"), "a round it was struck in gives nothing back")
            Trait.onAnyTurnEnd(c, hb) -- a whole round untouched
            assert(Status.has(hb, "status_unblemished"), "a round untouched, and the badge returns")
            wound(c, hb, foe)
            Trait.onAnyTurnEnd(c, hb)
            wound(c, hb, foe)
            Trait.onAnyTurnEnd(c, hb)
            assert(not Status.has(hb, "status_unblemished"), "kept marked every round, it stays marred")
        end,
    },
    {
        name = "the Highborn Circlet: a full round unstruck heals 15% and makes the wearer Composed until struck",
        fn = function()
            local c = Fixture.combat(board(), body(5, 6, { "utility_highborn_circlet" }), unit("character_elf_retainer", 5, 5))
            local wearer, foe = sided(c, "party")[1], one(c, "character_elf_retainer")
            wound(c, wearer, foe, 40)
            Trait.onAnyTurnEnd(c, wearer)
            assert(hp(wearer) == 60 and not Status.has(wearer, "status_composed"), "the round it was struck in pays nothing")
            Trait.onAnyTurnEnd(c, wearer)
            assert(hp(wearer) == 75, "a round untouched heals 15% of 100")
            assert(Status.has(wearer, "status_composed") and Status.statBonus(wearer, "damage") == 2, "and +2 Damage")
            wound(c, wearer, foe)
            assert(not Status.has(wearer, "status_composed"), "until the next wound")
        end,
    },
    -- ------------------------------------------------------------------------------ the Elf-Lord
    {
        name = "Renown: an elf's kill is a stack on the Lord, and lends +1 Damage to every elf within 3 of him",
        fn = function()
            local c = Fixture.combat(board(), { body(1, 1), body(10, 10) }, {
                unit("character_elf_lord", 5, 5), unit("character_elf_longbow", 5, 7), unit("character_elf_retainer", 5, 10),
            })
            local victim = sided(c, "party")[1]
            local lord, near, far = one(c, "character_elf_lord"), one(c, "character_elf_longbow"),
                one(c, "character_elf_retainer")
            local lordDmg, lordSpd = Combat.flatStat(lord, "damage"), Combat.flatStat(lord, "speed")
            local nearDmg, farDmg = Combat.flatStat(near, "damage"), Combat.flatStat(far, "damage")
            Combat.dealFlatDamage(c, victim, 9999, { "physical" }, "test", near, { raw = true })
            assert(not victim.alive, "the longbow's kill")
            assert(Status.stacksOf(lord, "status_renown") == 1, "is told to the Lord's credit")
            assert(Combat.flatStat(lord, "damage") == lordDmg + 2 and Combat.flatStat(lord, "speed") == lordSpd + 1,
                "+2 Damage and +1 Speed a stack")
            assert(Combat.flatStat(near, "damage") == nearDmg + 1, "an elf within 3 of him fights for +1 a stack")
            assert(Combat.flatStat(far, "damage") == farDmg, "and one out of reach does not")
        end,
    },
    {
        name = "the Laurel of Renown: a kill by the wearer's side lays +1 Damage on the wearer and allies within 3, up to 5",
        fn = function()
            local c = Fixture.combat(board(), { body(2, 2, { "utility_laurel_of_renown" }), body(2, 4), body(10, 10) },
                { unit("character_elf_retainer", 3, 4), unit("character_elf_retainer", 9, 1) })
            local party = sided(c, "party")
            local wearer, beside, away = party[1], party[2], party[3]
            local foes = sided(c, "enemy")
            Combat.dealFlatDamage(c, foes[1], 9999, { "physical" }, "test", beside, { raw = true })
            assert(Status.stacksOf(wearer, "status_laurels") == 1, "an ally's kill crowns the wearer")
            assert(Status.stacksOf(beside, "status_laurels") == 1, "and every ally within 3")
            assert(Status.stacksOf(away, "status_laurels") == 0, "but not one across the board")
            for _ = 1, 6 do Status.apply(c, wearer, "status_laurels", {}) end
            assert(Status.stacksOf(wearer, "status_laurels") == 5, "up to 5")
            assert(Status.get(wearer, "status_laurels").def.statBonus.damage == 1, "+1 Damage each")
        end,
    },
}
