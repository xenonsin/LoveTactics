-- Tests for THE FACELESS RACE (2026-10-03, "Envy's Bestiary", rounds 1-3): A Thousand Faces, the rule every
-- Faceless of Envy's seat is built on, and the Fairest, the word the circle's readers share.
--
--   A Thousand Faces   a hand of faces dealt from the whole bestiary; at the top of every turn it wears the one
--                      that answers the nearest foe (Reshape: Bulwark / Hunter / Blade), keeping its own pools
--   The Fairest        the body on a side holding the most blessings, ties to the most current health
--
-- The bodies that wear the race, and their own rules, are pinned in their line specs.

local Combat = require("models.combat")
local Race = require("models.race")
local Item = require("models.item")
local Status = require("models.status")
local Character = require("models.character")
local Transform = require("models.transform")
local Summon = require("models.summon")
local Faces = require("models.faces")
local Fairest = require("models.fairest")
local Fixture = require("tests.support.fixture")

local unit = Fixture.unit

local function board() return Fixture.new(9, 9) end

-- A Faceless-blooded body on the enemy side and a plain foe beside it.
local function field(foeId)
    local f = unit("character_archer", 4, 4, { isolate = "bare", items = { Faces.ORGAN }, stats = { health = 100 } })
    local foe = unit(foeId or "character_archer", 4, 5, { isolate = "bare", stats = { health = 100 } })
    local c = Fixture.combat(board(), foe, { f })
    local e, p
    for _, u in ipairs(c.units) do if u.side == "enemy" then e = u else p = u end end
    return c, e, p
end

local function hasItem(char, id)
    for _, item in ipairs(Character.eachItem(char)) do if item.id == id then return true end end
    return false
end

return {
    {
        name = "the faceless are an unplayable humanoid race that sums its physical resists to zero and grants A Thousand Faces",
        fn = function()
            local def = Race.defs[Faces.RACE]
            assert(def and def.kind == "humanoid", "a Faceless is a humanoid race")
            assert(def.playable == false, "the company does not hire a face-thief")
            local r = def.resist
            assert(r.slash + r.pierce + r.impact == 0, "the physical three sum to zero")
            assert(Faces.ORGAN == "utility_faceless_blood", "the grant is the race's organ")
            local grant = Item.defs[Faces.ORGAN]
            assert(grant and grant.bound and grant.noSteal and grant.class == "creature", "A Thousand Faces is an organ")
        end,
    },
    {
        name = "a face is any fighter in the bestiary, never a general, a boss, a wide body, an object, a human or a Faceless",
        fn = function()
            local pool = Faces.eligible()
            assert(#pool >= 40, "the hand draws from the whole bestiary, got " .. #pool)
            for i = 2, #pool do assert(pool[i - 1] < pool[i], "the deck is sorted, so a seeded deal is stable") end
            assert(not Faces.isEligible("character_general_gluttony"), "a general is a fight, not a face")
            assert(not Faces.isEligible("character_the_unwanted"), "a 2x2 boss is neither")
            assert(not Faces.isEligible("character_archer"), "humans are off the rift's rolls")
            for _, id in ipairs(pool) do
                local d = Character.defs[id]
                assert(d.race ~= Faces.RACE and d.race ~= "object" and not d.boss, id .. " may not be a face")
            end
        end,
    },
    {
        name = "a Faceless opens the fight wearing a face from its own hand",
        fn = function()
            local _, f = field()
            assert(f.faceHand and #f.faceHand == Faces.HAND, "it is dealt a hand of three")
            assert(Transform.isTransformed(f), "and is already wearing one")
            local worn = false
            for _, id in ipairs(f.faceHand) do if id == f.faceWorn then worn = true end end
            assert(worn, "the face it wears is one it holds")
            assert(f.char.id == f.faceWorn, "it IS that body now: its kit and its stats")
        end,
    },
    {
        name = "the body's own organ and its badge survive every face, and the badge is not a blessing",
        fn = function()
            local c, f = field()
            assert(hasItem(f.char, Faces.ORGAN), "A Thousand Faces rides into the shape")
            assert(Status.has(f, Faces.STATUS), "the turn-top read sits on the unit")
            Combat.dispelUnit(c, f, 99)
            assert(Status.has(f, Faces.STATUS), "no strip takes what a body is")
            assert(Fairest.blessings(f) == 0, "and the Fairest does not count it")
        end,
    },
    {
        name = "Reshape reads the nearest foe: a harder hitter makes a Bulwark, a ranged body a Hunter, anything else a Blade",
        fn = function()
            local c, f, p = field()
            local own = Faces.originalChar(f).stats
            p.char.stats.damage = math.max(own.damage or 0, own.magicDamage or 0) + 10
            assert(Faces.read(c, f, p) == "bulwark", "it out-hits the Faceless: stand up to it")
            p.char.stats.damage, p.char.stats.magicDamage = 0, 0
            local reach = (Combat.defaultAction(p.char, p).activeAbility or {}).range or 1
            assert(Faces.read(c, f, p) == (reach >= 3 and "hunter" or "blade"), "an archer is read by its reach")
        end,
    },
    {
        name = "the face it picks is the best of its hand at the form asked",
        fn = function()
            local u = { faceHand = { "character_wolf_grunt", "character_bear", "character_hawk" } }
            for _, form in ipairs({ "bulwark", "hunter", "blade" }) do
                local pick = Faces.pick(u, form)
                for _, id in ipairs(u.faceHand) do
                    assert(Faces.score(pick, form) >= Faces.score(id, form), form .. ": " .. pick .. " beats " .. id)
                end
            end
        end,
    },
    {
        name = "a face changes what it does, never how much killing it takes",
        fn = function()
            local c, f = field()
            local pool = f.char.stats.health
            Faces.wear(c, f, f.faceHand[1] == f.faceWorn and f.faceHand[2] or f.faceHand[1])
            assert(f.char.stats.health == pool, "the same health pool travels into every face")
        end,
    },
    {
        name = "a Faceless can wear a companion's face: a built body, not a blueprint",
        fn = function()
            local c, f, p = field()
            p.char.name = "Saber's Double"
            local copy = Summon.copyChar(p.char)
            Faces.wear(c, f, copy)
            assert(f.char.name == "Saber's Double", "it wears the copy it was handed")
            assert(hasItem(f.char, Faces.ORGAN), "and is still Faceless underneath")
        end,
    },
    {
        name = "the Fairest is the body holding the most blessings, and a tie goes to the most current health",
        fn = function()
            local a = unit("character_archer", 2, 2, { isolate = "bare", stats = { health = 50 } })
            local b = unit("character_archer", 2, 4, { isolate = "bare", stats = { health = 80 } })
            local foe = unit("character_archer", 6, 6, { isolate = "bare", stats = { health = 50 } })
            local c = Fixture.combat(board(), { a, b }, { foe })
            local pa, pb
            for _, u in ipairs(c.units) do
                if u.side ~= "enemy" then if u.char.stats.health.max == 50 then pa = u else pb = u end end
            end
            assert(Fairest.of(c, pb.side) == pb, "nothing blessed: the healthiest is the Fairest")
            Status.apply(c, pa, "status_blessing", { duration = 3 })
            local e
            for _, u in ipairs(c.units) do if u.side == "enemy" then e = u end end
            assert(Fairest.across(c, e) == pa, "one blessing outranks thirty health")
        end,
    },
}
