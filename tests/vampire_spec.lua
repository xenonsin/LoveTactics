-- Tests for THE VAMPIRES OF WRATH (reviewed over three rounds, 2026-09-26/27, "The Vampires of Wrath"): the tag,
-- the Thirst and its rules (models/thirst.lua), the chaff, the vampires, the Sire, the fights and the drops.
--
--   the tag          `vampire = true` implies undead (Grave-Cold) and seeds the Thirst; race and class kept
--   the Thirst       a dry turn climbs it; Bloodlust at 3 (2 for the newly turned); drawing blood resets it
--   feeding          a vampire's drink heals it, and Grave-Cold does not invert a feeding heal
--   the bite         a vampire's weapon strike opens a vein; a Bleed tick feeds whoever opened the wound
--   the Sire         Blood Bond holds Thirst at 2 and breaks into Bloodlust when it falls; Tithe; Call the Blood
--   the drops        Vitae, the Whistle, the Hungering Fang, Bloodhound's Scent, the Mistcloak, Open Veins,
--                    Boiling Blood, the Communion Chalice, the Sire's Signet, the Box of Grave-Earth
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Arena = require("models.arena")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local AI = require("models.ai")
local Thirst = require("models.thirst")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local VAMPIRES = {
    "character_fledgling", "character_goblin_fledgling", "character_vampire_duelist",
    "character_hemomancer", "character_communicant", "character_the_sire",
}
local LINE = {
    "character_blood_ghoul", "character_familiar", "character_fledgling", "character_goblin_fledgling",
    "character_vampire_duelist", "character_hemomancer", "character_communicant", "character_the_sire",
}
local TROPHIES = {
    "consumable_vitae", "ability_familiars_whistle", "weapon_hungering_fang", "utility_bloodhounds_scent",
    "armor_mistcloak", "ability_open_veins", "ability_boiling_blood", "utility_communion_chalice",
    "utility_sires_signet", "utility_box_of_grave_earth",
}
local ORGANS = {
    "utility_the_thirst", "utility_thrall", "utility_blood_courier", "utility_mist_step", "utility_blood_bond",
    "ability_feed", "ability_wing_swap", "ability_blood_communion", "ability_call_the_blood", "weapon_bat_fangs",
}
local FIGHTS = {
    encounter_wrath_the_night_flight = 1, encounter_wrath_the_kept = 1, encounter_wrath_the_duel_at_dusk = 1,
    encounter_wrath_the_sires_brood = 1,
    encounter_wrath_the_blood_mass = 2, encounter_wrath_the_masque = 2, encounter_wrath_bad_blood = 2,
}

local function board(n) return Fixture.new(n or 11, n or 11) end

-- A living company body with a sword, on a fixed health pool.
local function swordsman(x, y, health)
    return unit("character_archer", x, y,
        { isolate = "bare", items = { "weapon_iron_sword" }, stats = { health = health or 300 } })
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function brood(spec, party)
    local enemies = {}
    for _, s in ipairs(spec) do enemies[#enemies + 1] = unit(s[1], s[2], s[3], s[4]) end
    return Fixture.combat(board(), party or swordsman(1, 1), enemies)
end

local function kill(c, victim, killer)
    Combat.dealFlatDamage(c, victim, 9999, { "physical" }, "test", killer, { raw = true })
end

-- Top a striker's stamina back up, so a case that swings several times measures the rule and not the purse.
local function rested(u)
    local st = u.char.stats.stamina
    if type(st) == "table" then st.max, st.current = 99, 99 end
end

local function thirst(c, u, n)
    for _ = 1, n do Status.apply(c, u, "status_thirst") end
end

return {
    -- ------------------------------------------------------------------------------ the tag and the content
    {
        name = "the vampire tag implies undead, seeds Grave-Cold and the Thirst, and keeps race and class",
        fn = function()
            local def = Character.defs["character_fledgling"]
            assert(Character.isVampire(def) and Character.isUndead(def), "a vampire blueprint reads as undead")
            local c = Character.instantiate("character_fledgling")
            assert(c.vampire and c.undead, "the runtime character carries both tags")
            assert(itemNamed(c, Character.UNDEAD_GRANT), "Grave-Cold is seeded")
            assert(itemNamed(c, Character.VAMPIRE_GRANT) and Character.VAMPIRE_GRANT == "utility_the_thirst",
                "and the Thirst beside it")
            assert(c.race == "human" and c.class == "fighter" and c.kind == "humanoid", "race and class are kept")
            local g = Character.instantiate("character_goblin_fledgling")
            assert(g.race == "goblin" and g.vampire and itemNamed(g, "utility_blood_feud"),
                "a goblin Fledgling is still a goblin, with Blood Feud")
            local ghoul = Character.instantiate("character_blood_ghoul")
            assert(not ghoul.undead and not ghoul.vampire, "the Blood-Ghoul is a LIVING thrall")
            for _, id in ipairs(VAMPIRES) do
                assert(Character.isVampire(Character.defs[id]), id .. " is a vampire")
                assert(Character.defs[id].class, id .. " grows on a class")
            end
            assert(Character.defs["character_the_sire"].tier == 3 and Character.defs["character_the_sire"].stats.health == 110,
                "the Sire is the tier-3 alpha")
            assert(Character.defs["character_familiar"].race == "beast", "the Familiar is a bat, a beast")
        end,
    },
    {
        name = "every vampire trophy is an unstocked find on a line body's drop list; the organs are a body's own",
        fn = function()
            local dropped = {}
            for _, id in ipairs(LINE) do
                for _, d in ipairs(Character.defs[id].drops or {}) do dropped[d] = true end
            end
            for _, id in ipairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.unstocked, id .. " is a trophy: seen on the rack, never sold")
                assert(dropped[id], id .. " is on a line body's drop list")
                assert(def.class ~= "creature", id .. " sits on a real shelf")
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal, id .. " is a body's own and cannot be taken")
                if def.type == "utility" then assert(def.bound, id .. " is an organ, bound to the body") end
            end
            assert(Item.defs["weapon_hungering_fang"].activeAbility.speed <= 2, "the Fang keeps the dagger's speed")
        end,
    },
    {
        name = "the seven fights stand on the flows, split across Wrath's floors; the Sire's Brood is a spare elite",
        fn = function()
            for id, rung in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e, id .. " exists")
                assert(e.rung == rung, id .. " stands on rung " .. rung)
                assert(e.condition({ biome = "volcanic" }) and not e.condition({ biome = "cave" }),
                    id .. " is locked to the flows")
            end
            assert(Encounter.get("encounter_wrath_the_sires_brood").kind == "elite", "the Sire's Brood is an elite")
            local wrath
            for _, s in ipairs(Descent.SINS) do if s.id == "wrath" then wrath = s end end
            local spares = {}
            for _, id in ipairs(wrath.elites.spares) do spares[id] = true end
            assert(spares.encounter_wrath_the_sires_brood and spares.encounter_wrath_the_night_flight,
                "both are Wrath's spare elites")
        end,
    },
    {
        name = "the Night Flight is a swarm the elite tier seats whole; the Sire's Brood names its own ceiling of eight",
        fn = function()
            local e = Encounter.get("encounter_wrath_the_night_flight")
            -- Approved as an ordinary fight; it measured past the skirmish budget, so it is an elite, kept whole.
            assert(e.kind == "elite", "the Night Flight is an elite")
            local ids = Arena.resolveComposition(e.composition, { depth = 7 })
            local bats = 0
            for _, id in ipairs(ids) do if id == "character_familiar" then bats = bats + 1 end end
            assert(bats >= 3 and bats <= 5, "a Fledgling and three to five bats")
            assert(#ids <= Arena.ELITE_CAP, "which the elite tier seats whole")
            local brood = Encounter.get("encounter_wrath_the_sires_brood")
            assert(brood.enemyCap == 8, "the Brood names its own ceiling")
            assert(Encounter.capOf({ id = "encounter_wrath_the_sires_brood", kind = "elite" }) == 8,
                "a rolled cell resolves the cap off the blueprint")
            assert(Arena.enemyCap({ encounterKind = "elite", encounterCap = 8 }) == 8, "the encounter's own cap wins")
            assert(Arena.enemyCap({ encounterKind = "elite" }) == Arena.ELITE_CAP, "and nobody else's moves")
            assert(Arena.enemyCap({ encounterKind = "combat", encounterCap = 8, quest = { enemyCap = 2 } }) == 2,
                "a floor's own ceiling still cuts an ordinary fight")
            local seated = Arena.clampComposition(Arena.resolveComposition(brood.composition, { depth = 7 }),
                Arena.enemyCap({ encounterKind = "elite", encounterCap = brood.enemyCap }))
            assert(#seated == 7, "on its floor, four named bodies and three bats all stand, past the elite tier's six")
        end,
    },
    -- ------------------------------------------------------------------------------ the Thirst
    {
        name = "the Thirst: a dry turn climbs it, and at 3 a vampire is in Bloodlust (a Fledgling at 2)",
        fn = function()
            local c = brood({ { "character_vampire_duelist", 5, 5 }, { "character_fledgling", 9, 9 } })
            local duelist, fledgling = one(c, "character_vampire_duelist"), one(c, "character_fledgling")
            Trait.onAnyTurnEnd(c, duelist)
            Trait.onAnyTurnEnd(c, duelist)
            assert(Thirst.level(duelist) == 2 and not Status.has(duelist, "status_bloodlust"), "two dry turns, Thirst 2")
            Trait.onAnyTurnEnd(c, duelist)
            assert(Thirst.level(duelist) == 3 and Status.has(duelist, "status_bloodlust"), "the third: Bloodlust")
            Trait.onAnyTurnEnd(c, fledgling)
            assert(not Status.has(fledgling, "status_bloodlust"), "a Fledgling at 1 is not yet")
            Trait.onAnyTurnEnd(c, fledgling)
            assert(Status.has(fledgling, "status_bloodlust"), "newly turned: Bloodlust at 2")
        end,
    },
    {
        name = "Bloodlust: only a weapon, more damage and a step more, and it bites the nearest body, its own included",
        fn = function()
            local c = brood({ { "character_fledgling", 5, 5 }, { "character_blood_ghoul", 5, 6 } }, swordsman(11, 11))
            local v, ghoul = one(c, "character_fledgling"), one(c, "character_blood_ghoul")
            local dmg, move = Combat.flatStat(v, "damage"), Combat.flatStat(v, "movement")
            Thirst.enterBloodlust(c, v)
            assert(Combat.flatStat(v, "damage") > dmg and Combat.flatStat(v, "movement") == move + 1,
                "+30% of its Damage and +1 Movement")
            local block = Combat.itemBlockReason(v, itemNamed(v.char, "ability_wing_swap"))
            assert(block and block.kind == "bloodlust", "Wing-Swap is refused in Bloodlust")
            assert(not Combat.itemBlockReason(v, itemNamed(v.char, "weapon_iron_dagger")), "the bite is not")
            openTurn(c, v)
            local plan = AI.plan(c, v)
            assert(plan and plan.reason == "bloodlust", "the Thirst decides the turn")
            assert(plan.tx == ghoul.x and plan.ty == ghoul.y, "and it bites the ghoul beside it, not the far foe")
            local before = hp(ghoul)
            assert(Combat.useItem(c, v, plan.item, plan.tx, plan.ty), "the side check is waived")
            assert(hp(ghoul) < before, "the thrall is bitten")
        end,
    },
    -- ------------------------------------------------------------------------------ feeding and the bite
    {
        name = "feeding: Grave-Cold turns every heal into a wound except the one a vampire drinks",
        fn = function()
            local c = brood({ { "character_fledgling", 5, 5 } })
            local v = one(c, "character_fledgling")
            v.char.stats.health.current = 20
            Combat.applyHeal(c, v, 10)
            assert(hp(v) == 10, "an ordinary heal wounds the dead")
            Combat.applyHeal(c, v, 10, { feeding = true })
            assert(hp(v) == 20, "a feeding heal is a heal")
        end,
    },
    {
        name = "the bite opens a vein, and drawing blood resets the Thirst and heals 30% of the drink",
        fn = function()
            local c = brood({ { "character_vampire_duelist", 5, 5 } }, swordsman(5, 6))
            local v, foe = one(c, "character_vampire_duelist"), c.units[1]
            thirst(c, v, 2)
            v.char.stats.health.current = 10
            local before = hp(foe)
            Fixture.strike(c, v, foe, "weapon_main_gauche")
            local drawn = before - hp(foe)
            assert(drawn > 0, "the blade lands")
            local bleed = Status.get(foe, "status_bleed")
            assert(bleed and bleed.opener == v, "the bite opened a vein, and the wound knows who cut it")
            assert(Thirst.level(v) == 0, "drawing blood resets the Thirst")
            assert(hp(v) == 10 + math.max(1, math.floor(drawn * Thirst.FEED_SHARE + 0.5)),
                "and heals 30% of the drink, through Grave-Cold")
        end,
    },
    {
        name = "running feeds it: a Bleed tick is blood drawn by the vampire that opened the wound",
        fn = function()
            local c = brood({ { "character_fledgling", 9, 9 } }, swordsman(3, 3))
            local v, foe = one(c, "character_fledgling"), c.units[1]
            Status.apply(c, foe, "status_bleed", { applier = v })
            thirst(c, v, 1)
            v.char.stats.health.current = 10
            Status.onEnterTile(c, foe, "walk", 3, 2)
            assert(hp(foe) == 297, "the wound ticks for 3")
            assert(Thirst.level(v) == 0 and hp(v) == 11, "and the Fledgling across the board drinks it")
        end,
    },
    {
        name = "the Familiar's bite carries the drink to the nearest vampire; Feed drinks from a thrall",
        fn = function()
            local c = brood({ { "character_familiar", 5, 5 }, { "character_fledgling", 8, 8 },
                { "character_blood_ghoul", 8, 9 } }, swordsman(5, 6))
            local bat, v, ghoul = one(c, "character_familiar"), one(c, "character_fledgling"), one(c, "character_blood_ghoul")
            thirst(c, v, 1)
            Fixture.strike(c, bat, c.units[1], "weapon_bat_fangs")
            assert(Status.has(c.units[1], "status_bleed"), "the bat's bite opens a vein")
            assert(Thirst.level(v) == 0, "and the Fledgling drinks what the bat drew")
            thirst(c, v, 2)
            openTurn(c, v)
            local plan = Thirst.plan(c, v)
            assert(plan and plan.reason == "feeding" and plan.tx == ghoul.x, "at Thirst 2 it drinks from its thrall")
            local before = hp(ghoul)
            assert(Combat.useItem(c, v, plan.item, plan.tx, plan.ty), "Feed lands")
            assert(before - hp(ghoul) == math.floor(26 * 0.4 + 0.5), "the thrall takes the wound")
            assert(Thirst.level(v) == 0, "and the vampire's Thirst resets")
            assert(not Combat.useItem(c, v, itemNamed(v.char, "ability_feed"), c.units[1].x, c.units[1].y),
                "Feed is aimed at a thrall and nothing else")
        end,
    },
    {
        name = "a Blood-Ghoul's death bleeds every living body beside it, and not the dead",
        fn = function()
            local c = brood({ { "character_blood_ghoul", 5, 5 }, { "character_fledgling", 5, 4 } }, swordsman(5, 6))
            local ghoul, v, foe = one(c, "character_blood_ghoul"), one(c, "character_fledgling"), c.units[1]
            kill(c, ghoul, foe)
            assert(Status.has(foe, "status_bleed"), "the company body beside it bleeds")
            assert(not Status.has(v, "status_bleed"), "the vampire beside it has no blood to lose")
        end,
    },
    -- ------------------------------------------------------------------------------ the Sire
    {
        name = "Blood Bond: while the Sire stands Thirst stops at 2; when it falls the brood is in Bloodlust",
        fn = function()
            local c = brood({ { "character_the_sire", 2, 2 }, { "character_vampire_duelist", 9, 9 },
                { "character_fledgling", 9, 2 } })
            local sire, duelist, fledgling = one(c, "character_the_sire"), one(c, "character_vampire_duelist"),
                one(c, "character_fledgling")
            for _ = 1, 4 do Trait.onAnyTurnEnd(c, duelist); Trait.onAnyTurnEnd(c, fledgling) end
            assert(Thirst.level(duelist) == 2 and not Status.has(duelist, "status_bloodlust"), "the bond holds at 2")
            assert(not Status.has(fledgling, "status_bloodlust"), "even the newly turned")
            kill(c, sire, c.units[1])
            assert(not sire.alive, "the Sire falls")
            assert(Status.has(duelist, "status_bloodlust") and Status.has(fledgling, "status_bloodlust"),
                "and every vampire it bonded is in Bloodlust at once")
        end,
    },
    {
        name = "Tithe: the Sire heals 10% of every drink its brood takes",
        fn = function()
            local c = brood({ { "character_the_sire", 2, 2 }, { "character_fledgling", 5, 5 } }, swordsman(5, 6))
            local sire, v = one(c, "character_the_sire"), one(c, "character_fledgling")
            sire.char.stats.health.current = 50
            Thirst.feed(c, v, 40)
            assert(hp(sire) == 54, "a drink of 40 tithes the Sire 4")
        end,
    },
    {
        name = "Call the Blood: every bleeding foe within 5 is hauled 2 tiles toward the Sire, bleeding as it goes",
        fn = function()
            local c = brood({ { "character_the_sire", 5, 2 } }, { swordsman(5, 6), swordsman(9, 9) })
            local sire, near, clean = one(c, "character_the_sire"), c.units[1], c.units[2]
            Status.apply(c, near, "status_bleed")
            openTurn(c, sire)
            assert(Combat.useItem(c, sire, itemNamed(sire.char, "ability_call_the_blood"), sire.x, sire.y))
            assert(near.y == 4 and near.x == 5, "hauled two tiles")
            assert(hp(near) == 294, "bleeding 3 a tile")
            assert(clean.x == 9 and clean.y == 9, "a foe that is not bleeding stays put")
        end,
    },
    -- ------------------------------------------------------------------------------ the line bodies
    {
        name = "Mist Step: the first blow a round does nothing, the Duelist re-forms 2 away, and the striker Bleeds",
        fn = function()
            local c = brood({ { "character_vampire_duelist", 5, 5 } }, swordsman(5, 6))
            local d, foe = one(c, "character_vampire_duelist"), c.units[1]
            local before = hp(d)
            rested(foe); Fixture.strike(c, foe, d, "weapon_iron_sword")
            assert(hp(d) == before, "the blow went through mist")
            assert(math.abs(d.x - 5) + math.abs(d.y - 5) == 2, "it re-formed two tiles off")
            local bleed = Status.get(foe, "status_bleed")
            assert(bleed and bleed.opener == d, "and the striker bleeds, a wound the Duelist opened")
            foe.x, foe.y = d.x, d.y + 1
            if Combat.unitAt(c, foe.x, foe.y) ~= foe then foe.x, foe.y = d.x + 1, d.y end
            rested(foe); Fixture.strike(c, foe, d, "weapon_iron_sword")
            assert(hp(d) < before, "the second blow of the round lands")
            Trait.onAnyTurnEnd(c, d)
            local pos = { x = d.x, y = d.y }
            local hurt = hp(d)
            foe.x, foe.y = d.x, d.y + 1
            if Combat.unitAt(c, foe.x, foe.y) ~= foe then foe.x, foe.y = d.x + 1, d.y end
            rested(foe); Fixture.strike(c, foe, d, "weapon_iron_sword")
            assert(hp(d) == hurt and (d.x ~= pos.x or d.y ~= pos.y), "a new round, and the mist is back")
        end,
    },
    {
        name = "Open Veins bleeds every foe in the square; Boiling Blood bursts the wound for 5 x its magnitude",
        fn = function()
            local c = brood({ { "character_hemomancer", 5, 3 } }, { swordsman(5, 6), swordsman(6, 6), swordsman(1, 11) })
            local h = one(c, "character_hemomancer")
            h.char.stats.health.max, h.char.stats.health.current = 300, 300
            openTurn(c, h)
            assert(Combat.useItem(c, h, itemNamed(h.char, "ability_open_veins"), 5, 6))
            local a, b, far = c.units[1], c.units[2], c.units[3]
            assert(Status.has(a, "status_bleed") and Status.has(b, "status_bleed"), "both foes in the square bleed")
            assert(Status.get(a, "status_bleed").opener == h, "and the wounds are the Hemomancer's")
            assert(not Status.has(far, "status_bleed"), "a foe outside it does not")
            local before = hp(a)
            openTurn(c, h)
            assert(Combat.useItem(c, h, itemNamed(h.char, "ability_boiling_blood"), a.x, a.y))
            assert(before - hp(a) == 15 and not Status.has(a, "status_bleed"), "an ordinary wound boils for 15")
            Status.apply(c, b, "status_bleed", { magnitude = 5 })
            before = hp(b)
            openTurn(c, h)
            assert(Combat.useItem(c, h, itemNamed(h.char, "ability_boiling_blood"), b.x, b.y))
            assert(before - hp(b) == 25, "a Kingsblood wound (magnitude 5) boils for 25")
            openTurn(c, h)
            assert(not Combat.useItem(c, h, itemNamed(h.char, "ability_boiling_blood"), far.x, far.y),
                "a foe with no wound is no target")
        end,
    },
    {
        name = "Blood Communion: the Communicant pays 15% and every vampire within 2 drinks it",
        fn = function()
            local c = brood({ { "character_communicant", 5, 5 }, { "character_fledgling", 5, 7 },
                { "character_vampire_duelist", 9, 9 } })
            local com, near, far = one(c, "character_communicant"), one(c, "character_fledgling"),
                one(c, "character_vampire_duelist")
            thirst(c, near, 1); thirst(c, far, 1)
            local before = hp(com)
            openTurn(c, com)
            assert(Combat.useItem(c, com, itemNamed(com.char, "ability_blood_communion"), com.x, com.y))
            assert(before - hp(com) == math.floor(46 * 0.15 + 0.5), "it pays 15% of its max health")
            assert(Thirst.level(near) == 0 and Thirst.level(far) == 1, "the vampire within 2 drinks; the far one does not")
        end,
    },
    {
        name = "Wing-Swap trades places with a Familiar anywhere on the board, and with nothing else",
        fn = function()
            local c = brood({ { "character_fledgling", 2, 2 }, { "character_familiar", 9, 9 },
                { "character_blood_ghoul", 3, 3 } })
            local v, bat, ghoul = one(c, "character_fledgling"), one(c, "character_familiar"), one(c, "character_blood_ghoul")
            openTurn(c, v)
            assert(not Combat.useItem(c, v, itemNamed(v.char, "ability_wing_swap"), ghoul.x, ghoul.y), "not a ghoul")
            openTurn(c, v)
            assert(Combat.useItem(c, v, itemNamed(v.char, "ability_wing_swap"), bat.x, bat.y))
            assert(v.x == 9 and v.y == 9 and bat.x == 2 and bat.y == 2, "they trade tiles")
        end,
    },
    {
        name = "Scent of Blood: +2 movement on a move toward a bleeding foe, and more damage against it",
        fn = function()
            local c = Fixture.combat(board(15), swordsman(14, 8), { unit("character_fledgling", 2, 8) })
            local v, foe = c.units[2], c.units[1]
            local function reach(x, y) return Combat.reachable(c, v)[x .. "," .. y] ~= nil end
            assert(not reach(8, 8), "six tiles is past a Fledgling's four")
            local plain = Combat.computeDamage(c, v, foe, itemNamed(v.char, "weapon_iron_dagger"))
            Status.apply(c, foe, "status_bleed")
            assert(reach(8, 8), "toward a bleeding foe it runs six")
            assert(not reach(2, 14) and not reach(2, 2), "but not away")
            assert(Combat.computeDamage(c, v, foe, itemNamed(v.char, "weapon_iron_dagger")) > plain,
                "and it bites a bleeding foe harder")
        end,
    },
    {
        name = "a goblin Fledgling in Bloodlust that bites a goblin becomes the warband's Feud",
        fn = function()
            local c = brood({ { "character_goblin_fledgling", 5, 5 }, { "character_goblin_cutter", 5, 6 } },
                swordsman(11, 11))
            local v, cutter = one(c, "character_goblin_fledgling"), one(c, "character_goblin_cutter")
            Thirst.enterBloodlust(c, v)
            Fixture.strike(c, v, cutter, "weapon_iron_dagger")
            assert(require("models.feud").of(c, cutter.side) == v, "its own kin marks it the Feud")
        end,
    },
    -- ------------------------------------------------------------------------------ the drops
    {
        name = "Vitae: heal 60% and +3 Damage; then the Thirst -- slake it with blood, or spend a turn in Bloodlust",
        fn = function()
            local c = Fixture.combat(board(), unit("character_archer", 5, 5,
                { isolate = "bare", items = { "consumable_vitae", "weapon_iron_sword" }, stats = { health = 100 } }),
                { unit("character_bandit", 5, 6, { stats = { health = 200 } }) })
            local me, foe = c.units[1], c.units[2]
            me.char.stats.health.current = 10
            local dmg = Combat.flatStat(me, "damage")
            openTurn(c, me)
            assert(Combat.useItem(c, me, itemNamed(me.char, "consumable_vitae"), me.x, me.y))
            assert(hp(me) == 70 and Combat.flatStat(me, "damage") == dmg + 3, "60% back and +3 Damage")
            Status.remove(c, me, "status_vitae")
            assert(Status.has(me, "status_borrowed_thirst"), "and then the borrowed Thirst")
            Fixture.strike(c, me, foe, "weapon_iron_sword")
            assert(not Status.has(me, "status_borrowed_thirst") and not Status.has(me, "status_bloodlust"),
                "blood drawn from a living body pays it")
            Status.apply(c, me, "status_borrowed_thirst")
            Status.remove(c, me, "status_borrowed_thirst")
            assert(Status.has(me, "status_bloodlust") and me.control == "ai", "run dry, and a turn of Bloodlust")
        end,
    },
    {
        name = "the Familiar's Whistle: one bat, its bite heals you, and it comes back next turn when it falls",
        fn = function()
            local c = Fixture.combat(board(), unit("character_archer", 5, 5,
                { isolate = "bare", items = { "ability_familiars_whistle" }, stats = { health = 100, mana = 50 } }),
                { unit("character_bandit", 7, 5, { stats = { health = 200 } }) })
            local me, foe = c.units[1], c.units[2]
            local whistle = itemNamed(me.char, "ability_familiars_whistle")
            openTurn(c, me)
            assert(Combat.useItem(c, me, whistle, 6, 5), "the whistle calls")
            local bat = Combat.activeSummon(whistle)
            assert(bat and bat.char.id == "character_familiar" and bat.side == me.side, "a bat on your side")
            assert(Combat.unreservedMax(me.char, "mana") == 40, "reserving a fifth of your mana")
            me.char.stats.health.current = 50
            local before = hp(foe)
            Fixture.strike(c, bat, foe, "weapon_bat_fangs")
            assert(Status.has(foe, "status_bleed"), "its bite bleeds the target")
            assert(hp(me) == 50 + (before - hp(foe)), "and heals you by the damage")
            kill(c, bat, foe)
            assert(Status.has(me, "status_familiar_returning"), "it falls, and is on its way back")
            Status.onTurnStart(c, me)
            local back = Combat.activeSummon(whistle)
            assert(back and back ~= bat and back.alive, "it comes back beside you at your next turn")
            assert(Combat.unreservedMax(me.char, "mana") == 40, "reserving the fifth again")
        end,
    },
    {
        name = "the Hungering Fang: +3 a dry turn to three, all of it spent on the next hit",
        fn = function()
            local c = Fixture.combat(board(), unit("character_archer", 5, 5,
                { isolate = "bare", items = { "weapon_hungering_fang" } }),
                { unit("character_bandit", 5, 6, { stats = { health = 300 } }) })
            local me, foe = c.units[1], c.units[2]
            local dmg = Combat.flatStat(me, "damage")
            for _ = 1, 4 do Trait.onAnyTurnEnd(c, me) end
            assert(Status.stacksOf(me, "status_hungering") == 3 and Combat.flatStat(me, "damage") == dmg + 9,
                "three dry turns, +9, and no more")
            Fixture.strike(c, me, foe, "weapon_hungering_fang")
            assert(not Status.has(me, "status_hungering") and Status.has(foe, "status_bleed"),
                "the hit spends it, and a dagger's hit bleeds")
        end,
    },
    {
        name = "Bloodhound's Scent: +2 movement on a move that ends beside a bleeding foe",
        fn = function()
            local c = Fixture.combat(board(15), unit("character_archer", 2, 8,
                { isolate = "bare", items = { "utility_bloodhounds_scent" } }), { unit("character_bandit", 9, 8) })
            local me, foe = c.units[1], c.units[2]
            local budget = Combat.flatStat(me, "movement")
            local function reach(x, y) return Combat.reachable(c, me)[x .. "," .. y] ~= nil end
            local besideX = 2 + budget + 2
            foe.x = besideX + 1
            assert(not reach(besideX, 8), "no bleeding foe, no scent")
            Status.apply(c, foe, "status_bleed")
            assert(reach(besideX, 8), "two further, to stand beside the bleeding foe")
            assert(not reach(2, 8 + budget + 1) and not reach(besideX - 1, 8), "and nowhere else")
        end,
    },
    {
        name = "the Mistcloak: the first blow a fight does nothing, and you re-form as far from the striker as you can",
        fn = function()
            local c = Fixture.combat(board(), unit("character_archer", 5, 5,
                { isolate = "bare", items = { "armor_mistcloak" }, stats = { health = 100 } }),
                { unit("character_bandit", 5, 6) })
            local me, foe = c.units[1], c.units[2]
            rested(foe); Fixture.strike(c, foe, me, "weapon_iron_sword")
            assert(hp(me) == 100 and me.x == 5 and me.y == 3, "untouched, and two tiles straight away")
            assert(not Status.has(foe, "status_bleed"), "the cloak bleeds nobody")
            foe.x, foe.y = me.x, me.y + 1
            Trait.onAnyTurnEnd(c, me)
            rested(foe); Fixture.strike(c, foe, me, "weapon_iron_sword")
            assert(hp(me) < 100, "once a fight")
        end,
    },
    {
        name = "the Communion Chalice: 5% of you to each ally beside you, and the undead take it as a heal",
        fn = function()
            local c = Fixture.combat(board(), { unit("character_archer", 5, 5,
                { isolate = "bare", items = { "utility_communion_chalice" }, stats = { health = 100 } }),
                unit("character_dwarf_skeleton", 5, 6) }, { unit("character_bandit", 11, 11) })
            local me, dead = c.units[1], c.units[2]
            dead.char.stats.health.current = 5
            Trait.onAnyTurnEnd(c, me)
            assert(hp(me) == 95 and hp(dead) == 10, "five from you, five into the dead dwarf")
        end,
    },
    {
        name = "the Sire's Signet: allies warded while you stand; when you fall, two turns of Bloodlust",
        fn = function()
            local c = Fixture.combat(board(), { unit("character_archer", 5, 5,
                { isolate = "bare", items = { "utility_sires_signet" } }), swordsman(6, 5) },
                { unit("character_bandit", 11, 11) })
            local me, ally, foe = c.units[1], c.units[2], c.units[3]
            assert(not Status.apply(c, ally, "status_charm"), "no Charm while the Signet stands")
            assert(not Status.apply(c, ally, "status_seeing_red"), "no Seeing Red")
            assert(not Thirst.enterBloodlust(c, ally) and not Status.has(ally, "status_bloodlust"), "no Bloodlust")
            kill(c, me, foe)
            local lust = Status.get(ally, "status_bloodlust")
            assert(lust and lust.remaining == 10 and ally.control == "ai", "it falls, and the ally is in Bloodlust")
        end,
    },
    {
        name = "the Box of Grave-Earth: the first downing is mist, home, and 30% at the next turn",
        fn = function()
            local c = Fixture.combat(board(), unit("character_archer", 2, 2,
                { isolate = "bare", items = { "utility_box_of_grave_earth" }, stats = { health = 100 } }),
                { unit("character_bandit", 9, 9) })
            local me, foe = c.units[1], c.units[2]
            me.x, me.y = 8, 9
            kill(c, me, foe)
            assert(me.alive and hp(me) == 1, "not downed")
            assert(me.x == 2 and me.y == 2, "drifted back to where the fight began")
            assert(Status.untargetable(me, c), "and nothing can aim at the mist")
            Status.onTurnStart(c, me)
            assert(hp(me) == 30 and not Status.has(me, "status_grave_mist"), "it re-forms at 30%")
            kill(c, me, foe)
            assert(not me.alive or me.incapacitated, "once a fight")
        end,
    },
}
