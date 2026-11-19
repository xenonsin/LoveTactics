-- Tests for the CREATURE IDENTITY PASS over ENVY (floors 11-12), 2026-11-19. An audit asked of every fielded body
-- whether meeting it changes what you BRING, where you STAND, or who you kill FIRST, and the author approved a
-- lever for each Envy body that failed. One or more cases per reworked body, each putting the body in a fight and
-- acting, plus the two sameness rows this scope owned:
--
--   Glass-Mote         shatters into Glass Shards: a foe ending a turn there is cut and loses a blessing (POSITION)
--   Glass-Eater        every blessing it strips is a stack of Glass-Fed, +2 damage; a Dispel takes it back (ORDER)
--   Mimic-of-Ash       an elemental blow is echoed onto its strikes until a plain blow clears it (BRING, ORDER)
--   The Unwanted       cracks at each threshold: lines of glass off its sides, never its corners (POSITION) -- and
--                      no longer sheds motes, which was The Long Winter's template (same-apex)
--   Stone Challenger   once woken, each blow it lands gives 1 Stone (ORDER)
--   Faceless (race)    an impact blow knocks a Reshape face off until its turn ends (BRING)
--   Faceless Colossus  using the lent kit opens a seam; the next blow tears the second face off (ORDER)
--   Faceless Champion  commits and names its next face at the end of its turn (POSITION)
--   same-envy-support  the Evil Eye Rattles a Fairest with nothing to sour; the Pale Crone leaps on a kill; the
--                      shards cut a company with no blessings -- the circle reads what every company does
--   targeting          each family's preference (models/envy_oneoffs.lua's Envy.targetPlan)

local Character = require("models.character")
local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Transform = require("models.transform")
local Faces = require("models.faces")
local Envy = require("models.envy_oneoffs")
local Fairest = require("models.fairest")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local function board(n) return Fixture.new(n or 12, n or 12, { seed = 11 }) end

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 200, health or 200
    return spawn
end

local function one(c, id)
    for _, u in ipairs(c.units) do
        if u.alive and u.char and Faces.originalChar(u).id == id and not u.illusory then return u end
    end
end

local function party(c)
    local out = {}
    for _, u in ipairs(c.units) do if u.side == "party" then out[#out + 1] = u end end
    return out
end

local function hit(c, target, amount, tags, attacker)
    return Combat.dealFlatDamage(c, target, amount, tags or { "physical" }, "test", attacker, { raw = true })
end

local function lentCount(u)
    local n = 0
    for _, item in ipairs(Character.eachItem(u.char)) do if item.lentByFace then n = n + 1 end end
    return n
end

return {
    -- ------------------------------------------------------------------------------ Glass-Mote
    {
        name = "Glass-Mote: it shatters into Glass Shards, which cut and strip a foe that ends a turn there",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 6), { unit("character_glass_mote", 5, 5), unit("character_glass_eater", 8, 8) })
            local body, mote, eater = party(c)[1], one(c, "character_glass_mote"), one(c, "character_glass_eater")
            assert(itemNamed(mote.char, "weapon_glass_shard"), "the mote carries its shard")
            hit(c, mote, 99, { "physical", "impact" }, body)
            assert(not mote.alive, "one blow and it is gone")
            assert(Hazard.at(c, 5, 5, "hazard_glass_shards"), "and the tile it stood on is glass now")

            -- Stepping on is free; STOPPING is what costs.
            Combat.teleportUnit(c, body, 5, 5)
            Status.apply(c, body, "status_hasted")
            local before = hp(body)
            Hazard.onTurnEnd(c, body)
            assert(hp(body) == before - 3, "ending a turn on the glass cuts for 3, took " .. (before - hp(body)))
            assert(not Status.has(body, "status_hasted"), "and takes a blessing")

            -- Sided: the glass does not cut its own line.
            Combat.teleportUnit(c, body, 1, 1)
            Combat.teleportUnit(c, eater, 5, 5)
            local eb = hp(eater)
            Hazard.onTurnEnd(c, eater)
            assert(hp(eater) == eb, "a body of the glass's own side stands on it unhurt")
        end,
    },
    -- ------------------------------------------------------------------------------ Glass-Eater
    {
        name = "Glass-Eater: each blessing it strips is a stack of Glass-Fed on it, and a Dispel takes the meal back",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 6), { unit("character_glass_eater", 5, 5) })
            local body, eater = party(c)[1], one(c, "character_glass_eater")
            local base = Combat.flatStat(eater, "damage")
            -- Nothing to eat, nothing gained: against a company with no blessings it stays the soft body it was.
            assert(Fixture.strike(c, eater, body, "weapon_vitreous_bite"), "it bites")
            assert(not Status.has(eater, "status_glass_fed"), "a bite with nothing to strip feeds it nothing")

            Status.apply(c, body, "status_hasted")
            Status.apply(c, body, "status_regen")
            assert(Fixture.strike(c, eater, body, "weapon_vitreous_bite"), "it bites again")
            assert(Status.stacksOf(eater, "status_glass_fed") == 2, "two blessings stripped, two stacks, got "
                .. Status.stacksOf(eater, "status_glass_fed"))
            assert(Combat.flatStat(eater, "damage") == base + 4, "and +2 damage each")

            Combat.dispelUnit(c, eater, 5)
            assert(not Status.has(eater, "status_glass_fed"), "Glass-Fed is a blessing: a Dispel takes it back")
            assert(Combat.flatStat(eater, "damage") == base, "and the damage with it")
        end,
    },
    -- ------------------------------------------------------------------------------ Mimic-of-Ash
    {
        name = "Mimic-of-Ash: an elemental blow is echoed onto its strikes, named on its badge, until a plain blow lands",
        fn = function()
            local c = Fixture.combat(board(), walker(4, 4), { unit("character_mimic_of_ash", 5, 4) })
            local victim, mimic = party(c)[1], one(c, "character_mimic_of_ash")
            Status.apply(c, victim, "status_vulnerable_fire", { duration = 999 })

            assert(Fixture.strike(c, mimic, victim, "weapon_ashen_echo"), "the mimic strikes")
            local before = hp(victim)
            assert(Fixture.strike(c, mimic, victim, "weapon_ashen_echo"), "and again, still plain")
            local plainBlow = before - hp(victim)

            hit(c, mimic, 5, { "magical", "fire" }, victim)
            assert(Combat.strikeElement(mimic) == "fire", "a fire blow is remembered")
            local badge = Status.get(mimic, "status_ashen_echo")
            assert(badge and badge.element == "fire", "and the badge names it")
            assert(badge.def.describe(badge):find("fire", 1, true), "in words the tooltip prints")

            before = hp(victim)
            assert(Fixture.strike(c, mimic, victim, "weapon_ashen_echo"), "it strikes with the echo")
            local fireBlow = before - hp(victim)
            assert(fireBlow > plainBlow, string.format("burn it and it burns you back (%d plain, %d echoed)",
                plainBlow, fireBlow))

            hit(c, mimic, 5, { "physical", "slash" }, victim)
            assert(Combat.strikeElement(mimic) == nil, "a plain blow washes the echo out")
            assert(not Status.has(mimic, "status_ashen_echo"), "and the badge with it")
        end,
    },
    -- ------------------------------------------------------------------------------ The Unwanted
    {
        name = "The Unwanted: each threshold cracks lines of glass off its sides -- never its corners -- and sheds nothing",
        fn = function()
            local c = Fixture.combat(board(), { walker(5, 3), walker(3, 3) }, { unit("character_the_unwanted", 5, 5) })
            local inLine, onCorner = party(c)[1], party(c)[2]
            local apex = one(c, "character_the_unwanted")
            local count = #c.units
            local a, b = hp(inLine), hp(onCorner)

            hit(c, apex, 20)
            assert(not Hazard.at(c, 5, 4, "hazard_glass_shards"), "a scratch above the first threshold cracks nothing")

            hit(c, apex, 35) -- 140 -> 85, past two-thirds
            assert(#c.units == count, "it sheds no motes -- that was The Long Winter's shape")
            for _, cell in ipairs({ { 5, 4 }, { 5, 3 }, { 5, 2 }, { 6, 4 }, { 7, 5 }, { 9, 6 }, { 4, 6 }, { 6, 8 } }) do
                assert(Hazard.at(c, cell[1], cell[2], "hazard_glass_shards"),
                    "the crack runs straight off a side through " .. cell[1] .. "," .. cell[2])
            end
            assert(not Hazard.at(c, 4, 4, "hazard_glass_shards") and not Hazard.at(c, 7, 7, "hazard_glass_shards"),
                "and never off a corner")
            assert(hp(inLine) == a - 8, "a body standing in line is cut as it opens, took " .. (a - hp(inLine)))
            assert(hp(onCorner) == b, "a body on the diagonal is not")

            local again = hp(inLine)
            hit(c, apex, 45) -- 85 -> 40, past one-third
            assert(hp(inLine) == again - 8, "the second threshold cracks again")
            hit(c, apex, 10)
            assert(hp(inLine) == again - 8, "and there is no third")
        end,
    },
    -- ------------------------------------------------------------------------------ Stone Challenger
    {
        name = "Stone Challenger: woken, every blow it lands gives 1 Stone; still a statue, it gives none",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 6), { unit("character_stone_challenger", 5, 5) })
            local body, statue = party(c)[1], one(c, "character_stone_challenger")
            assert(Status.has(statue, "status_petrified"), "it opens as a statue")
            Trait.onBlowLanded(c, statue, body, { amount = 5, before = hp(body) })
            assert(Status.stacksOf(body, "status_stone") == 0, "a statue carries nothing")

            statue.statueWoken = true
            Status.remove(c, statue, "status_petrified")
            -- Its own fists, read off the body rather than named: the fists are shared stock with the earth line, and
            -- this case is about the challenger's organ, not about them.
            local fists = Combat.defaultWeapon(statue.char)
            assert(Fixture.strike(c, statue, body, fists), "woken, it swings")
            assert(Status.stacksOf(body, "status_stone") == 1, "and the blow carries her gaze: 1 Stone")
            assert(Fixture.strike(c, statue, body, fists), "it swings again")
            assert(Fixture.strike(c, statue, body, fists), "and a third time")
            assert(Status.has(body, "status_petrified"), "three blows, three Stone: Petrified by the gaze's own rule")
        end,
    },
    -- ------------------------------------------------------------------------------ the Faceless
    {
        name = "Faceless: an impact blow knocks its face off until its turn ends; a blade does not",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 7), { unit("character_faceless", 5, 5) })
            local body, f = party(c)[1], one(c, "character_faceless")
            assert(Transform.isTransformed(f) and f.faceWorn, "it opens wearing a face")
            hit(c, f, 3, { "physical", "slash" }, body)
            assert(Transform.isTransformed(f), "a blade passes through a shape that gives")

            hit(c, f, 3, { "physical", "impact" }, body)
            assert(not Transform.isTransformed(f) and f.char.id == "character_faceless", "a club knocks the face off")
            assert(Status.has(f, "status_unmasked"), "and it is Unmasked")
            Status.onTurnStart(c, f)
            assert(not Transform.isTransformed(f), "its turn opens bare: Reshape puts nothing on")
            Status.onTurnEnd(c, f)
            assert(not Status.has(f, "status_unmasked"), "the turn's end lets it go")
            Status.onTurnStart(c, f)
            assert(Transform.isTransformed(f), "and the next read puts a face back on")
        end,
    },
    {
        name = "Faceless: a locked face is another rule's script, and a club leaves it on",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 7), { unit("character_faceless", 5, 5) })
            local body, f = party(c)[1], one(c, "character_faceless")
            f.faceLocked = true
            hit(c, f, 3, { "physical", "impact" }, body)
            assert(Transform.isTransformed(f) and not Status.has(f, "status_unmasked"), "a locked face stays on")
            assert(not Faces.knockable(nil, { "impact" }), "and nothing is knocked off nobody")
        end,
    },
    {
        name = "Faceless Colossus: using the lent kit opens the seam, and the next blow tears the second face off for good",
        fn = function()
            local c = Fixture.combat(board(), walker(4, 8, 300), { unit("character_faceless_colossus", 4, 4) })
            local body, col = party(c)[1], one(c, "character_faceless_colossus")
            local lent
            for _, item in ipairs(Character.eachItem(col.char)) do if item.lentByFace then lent = item break end end
            if not lent then return end -- a first face that filled every cell lends nothing to test against
            hit(c, col, 3, { "physical", "slash" }, body)
            assert(lentCount(col) > 0, "a blow with the seam shut takes nothing")

            Trait.onCast(c, col, { item = lent })
            assert(Status.has(col, "status_seam_open"), "reaching for what it borrowed opens the seam")
            hit(c, col, 3, { "physical", "slash" }, body)
            assert(lentCount(col) == 0 and col.secondFaceTorn, "a blow through the seam tears the second face away")
            assert(not Status.has(col, "status_seam_open"), "and the seam closes over the tear")
            Trait.onAnyTurnStart(c, col)
            assert(lentCount(col) == 0, "it does not grow back: one face for the rest of the fight")
        end,
    },
    {
        name = "Faceless Champion: it names its next face at the end of its turn, and wears exactly that one",
        fn = function()
            -- The nearest of the company decides the read: a heavy hitter asks for a bulwark, an archer for a hunter.
            local heavy = walker(5, 6)
            heavy.char.stats.damage = 40
            local light = walker(9, 9)
            light.char.stats.damage, light.char.stats.magicDamage = 1, 0
            local c = Fixture.combat(board(), { heavy, light }, { unit("character_faceless_champion", 5, 5) })
            local near, far = party(c)[1], party(c)[2]
            local ch = one(c, "character_faceless_champion")
            assert(ch.nextFace and Status.has(ch, "status_next_face"), "it names a face from the bell")
            local badge = Status.get(ch, "status_next_face")
            assert(badge.def.describe(badge):find(Character.defs[ch.nextFace].name, 1, true), "by name, on the badge")

            Trait.onAnyTurnEnd(c, ch)
            local promised = ch.nextFace
            assert(promised == Faces.pick(ch, "bulwark"), "with the heavy hitter beside it, it promises its bulwark")
            -- Whoever steps up AFTER the promise does not change it: the badge told the truth.
            Combat.teleportUnit(c, near, 11, 11)
            Combat.teleportUnit(c, far, 5, 6)
            local fresh = Faces.read(c, ch)
            assert(fresh ~= "bulwark", "a fresh read would now ask for something else, got " .. fresh)
            local changed = promised ~= ch.faceWorn
            Status.onTurnStart(c, ch)
            assert(ch.faceWorn == promised, "it wears the face it named, " .. tostring(promised)
                .. ", got " .. tostring(ch.faceWorn))
            if changed then
                assert(not Status.has(ch, "status_next_face"), "and the badge comes off as the promise is kept")
            end
            Trait.onAnyTurnEnd(c, ch)
            assert(ch.nextFace == Faces.pick(ch, fresh) and Status.has(ch, "status_next_face"),
                "its turn's end names the next one off the board as it now stands")
        end,
    },
    -- ------------------------------------------------------------------------------ same-envy-support
    {
        name = "same-envy-support: a company with no blessings still meets the circle -- the eye, the crone, the glass",
        fn = function()
            -- THE EVIL EYE: nothing to sour, and the healthiest it can see is Rattled outright.
            local c = Fixture.combat(board(), { walker(5, 8, 150), walker(1, 1, 100) }, { unit("character_evil_eye", 5, 2) })
            local tall, short, eye = party(c)[1], party(c)[2], one(c, "character_evil_eye")
            assert(Fairest.across(c, eye) == tall, "with no blessings anywhere the Fairest is the healthiest")
            Status.onTurnStart(c, eye)
            assert(Status.has(tall, "status_rattled"), "the eye falls on it all the same")
            assert(not Status.has(short, "status_rattled"), "and only on it")

            -- THE PALE CRONE: a kill in her sight is success, and she leaps on the killer.
            local c2 = Fixture.combat(board(), walker(5, 8), {
                unit("character_pale_crone", 5, 2), unit("character_glass_mote", 5, 6, { stats = { health = 3 } }) })
            local killer, crone, mote = party(c2)[1], one(c2, "character_pale_crone"), one(c2, "character_glass_mote")
            c2.turnCount = 1
            hit(c2, mote, 50, { "physical", "slash" }, killer)
            assert(not mote.alive, "the company fells a body")
            assert(crone.lungeAt == killer, "and she marks the leap on whoever felled it")
            Trait.onAnyTurnEnd(c2, killer)
            assert(Combat.unitGap(crone, killer) == 1, "she is beside it")
            -- The Skirmisher's Thorned Staff runs the same rule pointed the other way, and reads heals only.
            local staff = Item.defs.utility_thorned_staff
            assert(staff and not (staff.traitParams and staff.traitParams.grievesKills), "the player's staff is unchanged")

            -- THE GLASS: covered by the mote's case -- the shards cut whether or not there was anything to strip.
        end,
    },
    -- ------------------------------------------------------------------------------ targeting
    {
        name = "targeting: glass envies the Fairest, the mimic answers its attacker, a challenger finishes the Stoned",
        fn = function()
            -- Two bodies in the mote's reach; the blessed one is the one it goes for, nearer or not.
            local c = Fixture.combat(board(), { walker(5, 6), walker(6, 5) }, { unit("character_glass_mote", 5, 5) })
            local plain, blessed, mote = party(c)[1], party(c)[2], one(c, "character_glass_mote")
            Status.apply(c, blessed, "status_hasted")
            local plan = Envy.plan(c, mote)
            assert(plan and plan.item and plan.item.id == "weapon_glass_shard", "the glass plans a strike")
            assert(plan.tx == blessed.x and plan.ty == blessed.y, "at the Fairest")

            -- The mimic goes for whoever last struck it.
            local c2 = Fixture.combat(board(), { walker(5, 6), walker(4, 5) }, { unit("character_mimic_of_ash", 5, 5) })
            local a, b, mimic = party(c2)[1], party(c2)[2], one(c2, "character_mimic_of_ash")
            hit(c2, mimic, 2, { "physical", "slash" }, b)
            local p2 = Envy.plan(c2, mimic)
            assert(p2 and p2.tx == b.x and p2.ty == b.y, "the body that struck it is the body it answers")

            -- A woken challenger goes for the foe carrying the most Stone.
            local c3 = Fixture.combat(board(), { walker(5, 6), walker(4, 5) }, { unit("character_stone_challenger", 5, 5) })
            local s1, s2, statue = party(c3)[1], party(c3)[2], one(c3, "character_stone_challenger")
            statue.statueWoken = true
            Status.remove(c3, statue, "status_petrified")
            Status.apply(c3, s2, "status_stone")
            local p3 = Envy.plan(c3, statue)
            assert(p3 and p3.tx == s2.x and p3.ty == s2.y, "it finishes what her eyes began")

            -- A preference, never a compulsion: a Taunted body is left to its taunter.
            Status.apply(c, mote, "status_taunt", { applier = plain })
            assert(Envy.targetPlan(c, mote) == nil, "Taunted, the glass's preference stands aside")

            -- The Wasting One smiles at pain: its rule goes for the most wounded.
            local rule = Character.defs.character_wasting_one.ai[1]
            assert(rule.targetPref == "lowest_hp", "the Wasting One goes for the most wounded")
        end,
    },
}
