-- Tests for THE ONI OF WRATH (2026-09-26/27, reviewed over two rounds on "The Oni of Wrath" artifact, from the oni
-- of Reincarnated as a Slime and Re:Zero -- the premises, never the cast): the race, its rules, the clan's own
-- mechanics, the fights and the drops.
--
--   The Horn            below half health, or when an oni of its side falls, Horn Out: +3 Damage, +1 Speed, 10%
--                       healed a turn, and it goes for the killer. A critical hit snaps the horn: no Horn Out, no
--                       mana casts, and -1 against every physical blow and weaker to spells
--   The Witch's Taint   a foe carrying a hex is struck for 25% more and hunted first
--   the clan            the Student, the Oni, the Greatblade (Unmoved, the Odachi), the Shadow (Root and Mark), the
--                       Priestess (the bell, the keeper), the Swordmaster (Instant Draw, the Lesson), the Twins
--                       (one horn between them) and the General (the Dome, the Call, Bestow, the Clan Stands)
-- Each case pins a rule the review approved, on a bare board. The Ogre-Kin were cut in round 1 and must not return.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local ONI = {
    "character_oni_student", "character_oni", "character_oni_greatblade", "character_oni_shadow",
    "character_oni_priestess", "character_oni_swordmaster", "character_oni_horned_twin",
    "character_oni_hornless_twin", "character_oni_general",
}
local TROPHIES = {
    "utility_oni_horn", "weapon_odachi", "consumable_questionable_stew", "ability_steel_thread",
    "ability_purifying_bell", "weapon_instant_draw_katana", "weapon_morning_star", "utility_borrowed_eyes",
    "ability_black_flame_dome",
}
local ORGANS = {
    "utility_oni_blood", "utility_unmoved", "utility_keeper_of_horns", "utility_the_lesson",
    "utility_the_clan_stands", "utility_the_horned_sister", "utility_the_hornless_sister",
    "ability_unblessing", "ability_call_to_vengeance", "ability_bestow", "ability_the_sweep", "ability_wind_blades",
}
local FIGHTS = {
    encounter_wrath_two_swords = 1, encounter_wrath_the_greatblade = 1, encounter_wrath_the_shadow = 1,
    encounter_wrath_the_shrine = 1, encounter_wrath_the_oni_twins = 1,
    encounter_wrath_the_lesson = 2, encounter_wrath_blade_and_shadow = 2, encounter_wrath_the_ward = 2,
    encounter_wrath_the_masters_shadow = 2, encounter_wrath_the_black_flame_court = 2,
}

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 300, health or 300
    return spawn
end

local function board(n) return Fixture.new(n or 11, n or 11) end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

-- A board of oni (enemy side) and a company.
local function clan(spec, party)
    local enemies = {}
    for _, s in ipairs(spec) do enemies[#enemies + 1] = unit(s[1], s[2], s[3], s[4]) end
    return Fixture.combat(board(), party or walker(1, 1), enemies)
end

local function maxHp(u) return Combat.unreservedMax(u.char, "health") end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the oni is a precise race whose horn carries its resist, and it grants the Horn and the Taint",
        fn = function()
            local blueprint = Character.defs["character_oni"]
            local c = Character.instantiate("character_oni")
            assert(c.race == "oni" and c.kind == "humanoid", "an oni is a humanoid race")
            assert(c.stats.damage == blueprint.stats.damage + 1, "it hits hard")
            assert(c.stats.skill == blueprint.stats.skill + 1, "and exactly (+1: a race line is held to a budget of 2)")
            assert(itemNamed(c, "utility_oni_blood"), "the race put the Horn in the grid")
            local grant = Item.defs["utility_oni_blood"]
            assert(grant.bound and grant.noSteal, "the Horn is an organ, never kit")
            assert(grant.resist.slash == 1 and grant.resist.impact == 1 and grant.resist.pierce == 1,
                "the whole horn turns every physical blow a little")
            assert(require("models.race").get("oni").resist == nil,
                "and the race line stays empty: a racial resist must sum to zero")
            for _, id in ipairs(ONI) do
                local def = Character.defs[id]
                assert(def and def.race == "oni", id .. " is an oni")
                assert(def.class ~= "knight", id .. " is not on the knight table (it walls a line body at depth)")
            end
            for id in pairs(Character.defs) do
                assert(not id:find("ogre_kin"), "the Ogre-Kin were cut in round 1: " .. id)
            end
        end,
    },
    {
        name = "every oni trophy is an unstocked find on an oni's drop list, on a real shelf",
        fn = function()
            local dropped = {}
            for _, id in ipairs(ONI) do
                for _, d in ipairs(Character.defs[id].drops or {}) do dropped[d] = true end
            end
            for _, id in ipairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.unstocked, id .. " is a trophy: seen on the rack, never sold")
                assert(dropped[id], id .. " is on an oni's drop list")
                assert(def.class ~= "creature", id .. " sits on a real shelf")
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.class == "creature" and def.noSteal, id .. " is a body's own and cannot be taken")
                if def.type == "utility" then assert(def.bound, id .. " is an organ, bound to the body") end
            end
        end,
    },
    {
        name = "ten fights stand on the flows, split across Wrath's two floors, and the two elites are spares",
        fn = function()
            for id, rung in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e, id .. " exists")
                assert(e.rung == rung, id .. " stands on rung " .. rung)
                assert(e.condition({ biome = "volcanic" }) and not e.condition({ biome = "cave" }),
                    id .. " is locked to the flows")
            end
            local wrath
            for _, s in ipairs(Descent.SINS) do if s.id == "wrath" then wrath = s end end
            local spares = {}
            for _, id in ipairs(wrath.elites.spares) do spares[id] = true end
            assert(spares.encounter_wrath_the_oni_twins and spares.encounter_wrath_the_black_flame_court,
                "the Oni Twins and the Black-Flame Court are Wrath's spare elites")
            assert(Encounter.get("encounter_wrath_the_oni_twins").kind == "elite", "the Twins are an elite (round 2)")
        end,
    },
    -- ------------------------------------------------------------------------------ the Horn
    {
        name = "the Horn: wounded to half, the horn comes out, and it heals a tenth each turn",
        fn = function()
            local c = clan({ { "character_oni", 5, 5 } }, walker(5, 6))
            local foe, oni = c.units[1], one(c, "character_oni")
            Combat.dealFlatDamage(c, oni, 5, { "physical" }, "test", foe, { raw = true })
            assert(not Status.has(oni, "status_horn_out"), "a scratch does nothing")
            local cur = hp(oni)
            Combat.dealFlatDamage(c, oni, cur - math.floor(maxHp(oni) / 2), { "physical" }, "test", foe, { raw = true })
            assert(Status.has(oni, "status_horn_out"), "at half, the horn comes out")
            assert(oni.hornTarget == foe, "aimed at whoever did it")
            local before = hp(oni)
            Status.onTurnStart(c, oni)
            assert(hp(oni) > before, "and it heals at the top of its turn")
        end,
    },
    {
        name = "the Horn: an oni felled sends its kin Horn Out at the killer, and the AI goes for them",
        fn = function()
            local c = clan({ { "character_oni", 5, 5 }, { "character_oni", 8, 5 } }, { walker(5, 6), walker(8, 9) })
            local killer, bystander = c.units[1], c.units[2]
            local a, b = c.units[3], c.units[4]
            Combat.dealFlatDamage(c, a, 9999, { "physical" }, "test", killer, { raw = true })
            assert(not a.alive, "the first oni falls")
            assert(Status.has(b, "status_horn_out"), "the second one's horn comes out")
            assert(b.hornTarget == killer, "at the one who killed its kin")
            openTurn(c, b)
            local plan = AI.plan(c, b)
            assert(plan and plan.reason == "horn out", "and its turn goes to them, not to the nearer foe "
                .. tostring(bystander and bystander.x))
        end,
    },
    {
        name = "a critical hit snaps the horn: no Horn Out, no mana, and open to every weapon",
        fn = function()
            local c = clan({ { "character_oni", 5, 5 } }, walker(5, 6))
            local foe, oni = c.units[1], one(c, "character_oni")
            Combat.dealFlatDamage(c, oni, 1, { "physical" }, "test", foe, { critical = true })
            assert(Status.has(oni, "status_horn_snapped"), "the crit snaps the horn")
            assert(Status.vulnerability(oni, { "slash" }) == 2, "whole it turned 1 of a blade; snapped it takes 1 more")
            assert(Status.get(oni, "status_horn_snapped").def.silencesMana, "the magic lived in the horn")
            assert(not Status.get(oni, "status_horn_snapped").def.debuff, "and no Cure grows a horn back")
            Combat.dealFlatDamage(c, oni, hp(oni) - 2, { "physical" }, "test", foe, { raw = true })
            assert(not Status.has(oni, "status_horn_out"), "a snapped oni never goes Horn Out")
        end,
    },
    {
        name = "the horn is kept whole beside the Priestess, and while the General who Bestowed it stands",
        fn = function()
            local c = clan({ { "character_oni", 5, 5 }, { "character_oni_priestess", 5, 4 } }, walker(5, 6))
            local foe, oni = c.units[1], one(c, "character_oni")
            Combat.dealFlatDamage(c, oni, 1, { "physical" }, "test", foe, { critical = true })
            assert(not Status.has(oni, "status_horn_snapped"), "beside the Priestess, a crit does not snap it")

            local c2 = clan({ { "character_oni", 5, 5 }, { "character_oni_general", 5, 3 } }, walker(5, 6))
            local foe2, oni2, gen = c2.units[1], one(c2, "character_oni"), one(c2, "character_oni_general")
            openTurn(c2, gen)
            assert(Combat.useItem(c2, gen, itemNamed(gen.char, "ability_bestow"), oni2.x, oni2.y), "the General bestows")
            assert(Status.has(oni2, "status_bestowed"), "the oni wears the gift")
            assert(Status.has(gen, "status_spent"), "and the giving costs the giver")
            Combat.dealFlatDamage(c2, oni2, 1, { "physical" }, "test", foe2, { critical = true })
            assert(not Status.has(oni2, "status_horn_snapped"), "a gifted horn holds while the General stands")
            Combat.dealFlatDamage(c2, gen, 9999, { "physical" }, "test", foe2, { raw = true })
            Combat.dealFlatDamage(c2, oni2, 1, { "physical" }, "test", foe2, { critical = true })
            assert(Status.has(oni2, "status_horn_snapped"), "with the General gone, it snaps")
        end,
    },
    -- ------------------------------------------------------------------------------ the Taint
    {
        name = "the Witch's Taint: a hexed foe is struck for 25% more, and hunted first",
        fn = function()
            local c = clan({ { "character_oni", 5, 5 } }, { walker(5, 6), walker(7, 5) })
            local near, hexed = c.units[1], c.units[2]
            local oni = one(c, "character_oni")
            Status.apply(c, hexed, "status_cursed", {})
            local sword = itemNamed(oni.char, "weapon_iron_sword")
            local vsHex = Trait.outgoingDamageBonus(c, oni, hexed, sword, sword.tags)
            local vsClean = Trait.outgoingDamageBonus(c, oni, near, sword, sword.tags)
            assert(vsHex > vsClean, "the hex is smelled and struck the harder")
            openTurn(c, oni)
            local plan = AI.plan(c, oni)
            assert(plan and plan.reason == "the witch's taint", "and the hexed one decides the turn")
        end,
    },
    -- ------------------------------------------------------------------------------ the clan
    {
        name = "the Greatblade is Unmoved, and her Odachi rolls a miss again",
        fn = function()
            local c = clan({ { "character_oni_greatblade", 5, 5 } }, walker(5, 6))
            local g = one(c, "character_oni_greatblade")
            assert(Status.blocksForcedMove(g), "nothing shoves her")
            Status.apply(c, g, "status_stun", {})
            assert(not Status.has(g, "status_stun"), "and nothing stuns her")
            local odachi = Item.defs["weapon_odachi"]
            assert(odachi.rerollMiss and Item.windupRange(odachi.activeAbility) >= 1,
                "a greatsword that winds up and rolls twice")
            assert(odachi.activeAbility.aoe.shape == "line" and odachi.activeAbility.aoe.length == 3, "down a line of 3")
        end,
    },
    {
        name = "Steel Thread roots and marks",
        fn = function()
            local c = clan({ { "character_oni_shadow", 5, 2 } }, walker(5, 5))
            local foe, s = c.units[1], one(c, "character_oni_shadow")
            openTurn(c, s)
            assert(Combat.useItem(c, s, itemNamed(s.char, "ability_steel_thread"), foe.x, foe.y), "the thread is cast")
            assert(Status.has(foe, "status_root") and Status.has(foe, "status_mark"), "Root and Mark, as the author asked")
        end,
    },
    {
        name = "the Purifying Bell cleanses the Priestess's side; Unblessing strips a foe",
        fn = function()
            local c = clan({ { "character_oni_priestess", 5, 5 }, { "character_oni", 5, 4 } }, walker(5, 7))
            local foe, p, oni = c.units[1], one(c, "character_oni_priestess"), one(c, "character_oni")
            Status.apply(c, oni, "status_poison", {})
            Status.apply(c, foe, "status_poison", {})
            openTurn(c, p)
            assert(Combat.useItem(c, p, itemNamed(p.char, "ability_purifying_bell"), p.x, p.y), "the bell rings")
            assert(not Status.has(oni, "status_poison"), "her side is cleansed")
            assert(Status.has(foe, "status_poison"), "the company is not")
        end,
    },
    {
        name = "the Lesson: an oni beside the Swordmaster crits the more",
        fn = function()
            -- The suite pins every blow to land (Combat.FORCE_HIT), and a board that rolls nothing crits nothing;
            -- the dice are let back in for the reading and pinned again after.
            local pinned = Combat.FORCE_HIT
            Combat.FORCE_HIT = false
            local c = clan({ { "character_oni", 5, 5 } }, walker(5, 6))
            local foe, oni = c.units[1], one(c, "character_oni")
            local sword = itemNamed(oni.char, "weapon_iron_sword")
            local alone = Combat.critChance(c, oni, foe, sword)
            local c2 = clan({ { "character_oni", 5, 5 }, { "character_oni_swordmaster", 4, 5 } }, walker(5, 6))
            local foe2, oni2 = c2.units[1], one(c2, "character_oni")
            local taught = Combat.critChance(c2, oni2, foe2, itemNamed(oni2.char, "weapon_iron_sword"))
            Combat.FORCE_HIT = pinned
            assert(taught == alone + 10 or taught == 100, "the lesson is +10% crit: " .. alone .. " -> " .. taught)
            assert(Item.defs["weapon_instant_draw_katana"].waitBehavior.kind == "overwatch", "and its sword waits to draw")
        end,
    },
    {
        name = "the Twins: strike the hornless one and the horned one's horn comes out; fell her and it comes all the way out",
        fn = function()
            local c = clan({ { "character_oni_horned_twin", 5, 5 }, { "character_oni_hornless_twin", 8, 5 } },
                walker(8, 6))
            local foe = c.units[1]
            local horned, hornless = one(c, "character_oni_horned_twin"), one(c, "character_oni_hornless_twin")
            assert(Status.has(hornless, "status_borrowed_horn"), "the hornless twin draws on her sister from the opening")
            Combat.dealFlatDamage(c, hornless, 3, { "physical" }, "test", foe)
            assert(Status.has(horned, "status_horn_out"), "her sister is struck, and the horn comes out")
            Combat.dealFlatDamage(c, hornless, 9999, { "physical" }, "test", foe, { raw = true })
            assert(Status.has(horned, "status_full_horn_out"), "her sister falls, and it comes all the way out")
            assert(not Combat.itemBlockReason(horned, itemNamed(horned.char, "ability_the_sweep")),
                "and the Sweep is hers to use")
        end,
    },
    {
        name = "the Twins: with her sister down, the hornless twin draws nothing and is Silenced",
        fn = function()
            local c = clan({ { "character_oni_horned_twin", 5, 5 }, { "character_oni_hornless_twin", 8, 5 } },
                walker(1, 1))
            local foe = c.units[1]
            local horned, hornless = one(c, "character_oni_horned_twin"), one(c, "character_oni_hornless_twin")
            Combat.dealFlatDamage(c, horned, 9999, { "physical" }, "test", foe, { raw = true })
            Status.onTurnStart(c, hornless)
            assert(Status.has(hornless, "status_silenced"), "no sister, no mana")
        end,
    },
    {
        name = "the General: the Call sends the clan Horn Out at a foe, the Clan Stands holds a felled oni up once",
        fn = function()
            local c = clan({ { "character_oni_general", 5, 3 }, { "character_oni", 5, 5 } }, walker(5, 6))
            local foe, gen, oni = c.units[1], one(c, "character_oni_general"), one(c, "character_oni")
            openTurn(c, gen)
            assert(Combat.useItem(c, gen, itemNamed(gen.char, "ability_call_to_vengeance"), foe.x, foe.y), "it points")
            assert(Status.has(oni, "status_horn_out") and oni.hornTarget == foe, "the clan's horns come out at that foe")
            Combat.dealFlatDamage(c, oni, 9999, { "physical" }, "test", foe, { raw = true })
            assert(oni.alive and hp(oni) == 1, "while the General stands, the felled oni stays up")
            assert(Status.has(oni, "status_not_yet"), "for one more action")
            assert(Item.defs["ability_black_flame_dome"].activeAbility.windup, "and its Dome is telegraphed a turn ahead")
        end,
    },
}
