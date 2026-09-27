-- Tests for THE THOUSAND-WINGED (Wrath's vampires, round 3; models/swarm.lua): eight familiars and no body. Four
-- standing together at a turn's end fuse into a vampire lord with 12 health per bat; struck to 0 it scatters back
-- into half of them; and its drop, Swarm Form, flies through bodies and Bleeds every foe it passes. On a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Arena = require("models.arena")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Swarm = require("models.swarm")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BAT = "character_swarm_familiar"

local function swordsman(x, y)
    return unit("character_archer", x, y,
        { isolate = "bare", items = { "weapon_iron_sword" }, stats = { health = 300 } })
end

-- A company body at (1, 1) and a bat on every tile in `tiles`, the opening Scattered cleared so the rule is live.
local function swarm(tiles)
    local enemies = {}
    for _, t in ipairs(tiles) do enemies[#enemies + 1] = unit(BAT, t[1], t[2]) end
    local c = Fixture.combat(Fixture.new(11, 11), swordsman(1, 1), enemies)
    local bats = {}
    for _, u in ipairs(c.units) do
        if u.char.id == BAT then
            Status.remove(c, u, Swarm.SCATTERED)
            bats[#bats + 1] = u
        end
    end
    return c, bats
end

local function lordOf(c)
    for _, u in ipairs(c.units) do
        if u.char.id == Swarm.LORD then return u end
    end
end

local function turnEnds(c) Trait.onAnyTurnEnd(c, c.units[1]) end

return {
    {
        name = "the swarm opens Scattered: eight bats and no body, and no fusion on the first beat",
        fn = function()
            local enemies = {}
            for i = 1, 4 do enemies[#enemies + 1] = unit(BAT, 4 + i, 5) end
            local c = Fixture.combat(Fixture.new(11, 11), swordsman(1, 1), enemies)
            for _, u in ipairs(c.units) do
                if u.char.id == BAT then assert(Status.has(u, Swarm.SCATTERED), "every bat opens Scattered") end
            end
            turnEnds(c)
            assert(not lordOf(c), "four in a row do not fuse while they are Scattered")
        end,
    },
    {
        name = "Gathering marks a group of three; a fourth beside them fuses at the turn's end into 12 x 4 health",
        fn = function()
            local c, bats = swarm({ { 5, 5 }, { 6, 5 }, { 7, 5 }, { 10, 10 } })
            turnEnds(c)
            assert(not lordOf(c), "three is not four")
            for i = 1, 3 do
                local g = Status.get(bats[i], Swarm.GATHERING)
                assert(g and g.magnitude == 3, "the three wear Gathering, counting 3")
            end
            assert(not Status.has(bats[4], Swarm.GATHERING), "the far bat does not")
            -- The fourth flies in beside them.
            bats[4].x, bats[4].y = 6, 6
            turnEnds(c)
            local lord = lordOf(c)
            assert(lord and lord.alive, "at the turn's end they fuse")
            assert(lord.char.stats.health.max == 48 and hp(lord) == 48, "12 health for each of the four")
            assert(Character.isVampire(lord.char) and itemNamed(lord.char, Character.VAMPIRE_GRANT),
                "the lord is a vampire, with the Thirst")
            assert(lord.x == 6 and lord.y == 5, "it stands at the group's heart")
            assert(itemNamed(bats[1].char, "utility_the_swarm") and itemNamed(lord.char, "utility_thousand_wings"),
                "the bats' rule rides on the Swarm, the lord's scatter on Thousand Wings")
            for _, b in ipairs(bats) do
                assert(b.alive and Combat.isOffTile(b) and not Combat.inTimeline(b), "every bat is inside it")
                assert(b.x == lord.x and b.y == lord.y, "and goes where it goes")
                assert(not Status.has(b, Swarm.GATHERING), "the telegraph is spent")
            end
            assert(Combat.unitAt(c, 6, 5) == lord and not Combat.unitAt(c, 7, 5), "the bats' tiles are empty")
            assert(Combat.outcomeFor(c, "party") == nil, "and the fight is not won over bats inside a lord")
            turnEnds(c)
            local lords = 0
            for _, u in ipairs(c.units) do if u.char.id == Swarm.LORD then lords = lords + 1 end end
            assert(lords == 1, "a turn end after does not fuse them twice")
        end,
    },
    {
        name = "on a deep floor the 12 a bat grows with the bat: a lord keeps 12 of every 14 of its bats' health",
        fn = function()
            local Growth = require("models.growth")
            local enemies = {}
            for i = 1, 4 do enemies[#enemies + 1] = { char = Growth.spawn(BAT, 22), x = 4 + i, y = 5 } end
            local c = Fixture.combat(Fixture.new(11, 11), swordsman(1, 1), enemies)
            for _, u in ipairs(c.units) do Status.remove(c, u, Swarm.SCATTERED) end
            local batMax = c.units[2].char.stats.health.max
            assert(batMax > 14, "a level-22 bat has grown past its blueprint")
            turnEnds(c)
            local lord = lordOf(c)
            local per = math.floor(12 * batMax / 14 + 0.5)
            assert(lord and lord.char.stats.health.max == 4 * per, "four bats' worth, at 12 of every 14")
            assert(lord.char.level == c.units[2].char.level, "minted at the bats' own level")
        end,
    },
    {
        name = "the lord's bite opens a vein that is its own",
        fn = function()
            local c = swarm({ { 2, 1 }, { 3, 1 }, { 2, 2 }, { 3, 2 } })
            turnEnds(c)
            local lord, foe = lordOf(c), c.units[1]
            assert(lord and Combat.unitGap(lord, foe) == 1, "fused beside the company body")
            Fixture.strike(c, lord, foe, "weapon_bat_fangs")
            local bleed = Status.get(foe, "status_bleed")
            assert(bleed and bleed.opener == lord, "the bite Bleeds, and the wound is the lord's")
        end,
    },
    {
        name = "struck to 0 the lord scatters: the healthier half fly out Scattered, the rest are dead, and no corpse",
        fn = function()
            local c, bats = swarm({ { 5, 5 }, { 6, 5 }, { 7, 5 }, { 6, 6 } })
            local healths = { 3, 14, 5, 10 }
            for i, b in ipairs(bats) do b.char.stats.health.current = healths[i] end
            turnEnds(c)
            local lord = lordOf(c)
            Combat.dealFlatDamage(c, lord, 9999, { "physical" }, "test", c.units[1], { raw = true })
            assert(not lord.alive and not lord.corpse, "the lord is gone, and leaves no body")
            local out = {}
            for _, b in ipairs(bats) do
                if b.alive then out[#out + 1] = b end
            end
            assert(#out == 2, "half of the four fly out")
            for _, b in ipairs(out) do
                assert(hp(b) == 14 or hp(b) == 10, "the healthiest two, with the health they went in with")
                assert(not Combat.isOffTile(b) and Combat.inTimeline(b), "back on the board and in the turn order")
                assert(Combat.unitAt(c, b.x, b.y) == b, "each on a tile of its own")
                assert(Status.has(b, Swarm.SCATTERED), "and Scattered")
            end
            for _, b in ipairs(bats) do
                if not b.alive then assert(not b.corpse, "a bat lost in the scatter leaves no corpse either") end
            end
            assert(Combat.outcomeFor(c, "party") == nil, "two bats still fly")
            for _, b in ipairs(out) do Combat.dealFlatDamage(c, b, 9999, { "physical" }, "test", c.units[1], { raw = true }) end
            assert(Combat.outcomeFor(c, "party") == "win", "every bat dead is the fight won")
        end,
    },
    {
        name = "a Scattered bat does not count toward a fusion until it lapses",
        fn = function()
            local c, bats = swarm({ { 5, 5 }, { 6, 5 }, { 7, 5 }, { 8, 5 } })
            Status.apply(c, bats[4], Swarm.SCATTERED)
            turnEnds(c)
            assert(not lordOf(c), "three ready and one Scattered is not four")
            Status.remove(c, bats[4], Swarm.SCATTERED)
            assert(Status.get(bats[4], Swarm.GATHERING).magnitude == 4, "its lapse redraws the telegraph at once")
            turnEnds(c)
            assert(lordOf(c), "and the next turn's end fuses them")
        end,
    },
    {
        name = "a bat flies to the biggest group of its kin; the group it is coming to holds",
        fn = function()
            local c, bats = swarm({ { 2, 9 }, { 3, 9 }, { 9, 3 } })
            local goal, hold = Swarm.gatherGoal(c, bats[3])
            assert(goal == bats[1] or goal == bats[2], "the lone bat flies to the pair")
            assert(not hold)
            local _, pairHolds = Swarm.gatherGoal(c, bats[1])
            assert(pairHolds, "the pair waits for it")
        end,
    },
    {
        name = "Swarm Form flies through bodies to a free tile and Bleeds every foe it passes, with the caster's wound",
        fn = function()
            local me = unit("character_archer", 2, 5,
                { isolate = "bare", items = { "ability_swarm_form" }, stats = { health = 100, stamina = 60 } })
            local c = Fixture.combat(Fixture.new(11, 11), { me, swordsman(4, 5) },
                { unit("character_bandit", 3, 5), unit("character_bandit", 5, 5), unit("character_bandit", 3, 8) })
            local caster, ally, a, b, off = c.units[1], c.units[2], c.units[3], c.units[4], c.units[5]
            local form = itemNamed(caster.char, "ability_swarm_form")
            openTurn(c, caster)
            assert(not Combat.useItem(c, caster, form, 5, 5), "it comes down on a free tile only")
            openTurn(c, caster)
            assert(Combat.useItem(c, caster, form, 7, 5), "a straight six-tile flight")
            assert(caster.x == 7 and caster.y == 5, "it re-forms where it stops")
            for _, foe in ipairs({ a, b }) do
                local bleed = Status.get(foe, "status_bleed")
                assert(bleed and bleed.opener == caster, "every foe it passed Bleeds, a wound the caster opened")
            end
            assert(not Status.has(ally, "status_bleed"), "an ally it passed does not")
            assert(not Status.has(off, "status_bleed"), "a foe off the route does not")
            assert(a.x == 3 and b.x == 5 and ally.x == 4, "and nobody it passed was moved")
            openTurn(c, caster)
            assert(not Combat.useItem(c, caster, form, 1, 1), "eight tiles is past its six")
        end,
    },
    {
        name = "Swarm Form's route takes the way over the most foes, and that route is what the board paints",
        fn = function()
            local me = unit("character_archer", 2, 2,
                { isolate = "bare", items = { "ability_swarm_form" }, stats = { stamina = 60 } })
            local c = Fixture.combat(Fixture.new(11, 11), me,
                { unit("character_bandit", 2, 4), unit("character_bandit", 3, 4) })
            local caster, a, b = c.units[1], c.units[2], c.units[3]
            local path = Swarm.formPath(c, caster, 4, 4, 6)
            local over = {}
            for _, cell in ipairs(path) do
                local u = Combat.unitAt(c, cell.x, cell.y)
                if u then over[u] = true end
            end
            assert(#path == 4 and over[a] and over[b], "of the four-step routes it takes the one over both")
            local form = itemNamed(caster.char, "ability_swarm_form")
            local painted = form.activeAbility.aoe.cells(c, 4, 4, caster)
            assert(#painted == #path, "the painted area is the route")
        end,
    },
    {
        name = "the Thousand-Winged is a floor-7 elite of eight bats with its own ceiling, and its bats drop Swarm Form",
        fn = function()
            local e = Encounter.get("encounter_wrath_the_thousand_winged")
            assert(e and e.kind == "elite" and e.rung == 1 and e.enemyCap == 8, "an elite on rung 1, ceiling eight")
            assert(e.condition({ biome = "volcanic" }) and not e.condition({ biome = "cave" }), "on the flows")
            local seated = Arena.clampComposition(Arena.resolveComposition(e.composition, { depth = 7 }),
                Arena.enemyCap({ encounterKind = "elite", encounterCap = e.enemyCap }))
            assert(#seated == 8, "all eight bats stand, past the elite tier's six")
            for _, id in ipairs(seated) do assert(id == BAT, "and nothing but bats") end
            local wrath
            for _, s in ipairs(Descent.SINS) do if s.id == "wrath" then wrath = s end end
            local spare = false
            for _, id in ipairs(wrath.elites.spares) do spare = spare or id == "encounter_wrath_the_thousand_winged" end
            assert(spare, "a spare elite of Wrath's")
            local drops = Character.defs[BAT].drops
            assert(drops and drops[1] == "ability_swarm_form", "the swarm's bats carry the trophy")
            local form = Item.defs["ability_swarm_form"]
            assert(form.unstocked and form.price == nil and form.unlockLevel == 7 and form.class == "skirmisher",
                "an unstocked skirmisher's find at rung 7")
            assert(Character.defs[Swarm.LORD].vampire, "the lord is a vampire")
        end,
    },
}
