-- THE CREATURE IDENTITY PASS, GREED (2026-11-19). An audit asked of every body the rift fields whether
-- meeting it changes what you BRING, where you STAND, or who you kill FIRST, and the author approved a fix
-- for each Greed body that failed. Each case here puts the body in a combat and acts, so what is pinned
-- is the behaviour rather than a field:
--
--   * the Skeleton Knight Shields its company's archers while it stands (order: knights first)
--   * the Skeleton Archer Marks the foe holding an impact weapon, and the company presses the Marked
--   * the Barrow Lord cannot rise while Silenced (bring a Silence)
--   * the Gilded King takes a heap beside him back on as a plate at his turn start (loot, or move him)
--   * the bone bodies stopped all asking for a mace: Bare Bones lost the lattice, and each family's line
--     is its own
--   * the targeting pass: kobolds press the hemmed-in foe, the Coin-Eaters go for the Gilded
--
-- Headless.

local AI = require("models.ai")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit, openTurn = Fixture.unit, Fixture.openTurn

local function kill(c, u) Combat.dealFlatDamage(c, u, 9999, {}, "test") end

-- A plain company body: a knight with nothing on it but what the case hands it, a deep pool, and no
-- magic defense, so a status the case lays is never shortened by the resistance curve.
local function body(x, y, items, stats)
    local s = { health = 200, magicDefense = 0 }
    for k, v in pairs(stats or {}) do s[k] = v end
    return unit("character_knight", x, y, { isolate = "bare", items = items or {}, stats = s })
end

local function heaps(c)
    local n = 0
    for _, h in ipairs(c.hazards or {}) do if h.alive and h.id == "hazard_coin_heap" then n = n + 1 end end
    return n
end

return {
    -- ------------------------------------------------------------------------------ the dead company
    {
        name = "Skeleton Knight: while a knight of the company stands its archer is Shielded and takes half; the shield falls with the last knight",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10), body(1, 1),
                { unit("character_skeleton_knight", 8, 8), unit("character_skeleton_knight", 9, 9),
                  unit("character_skeleton_archer", 8, 5) })
            local k1, k2, archer = c.units[2], c.units[3], c.units[4]
            assert(Status.has(archer, "status_shielded"), "the archer opens the fight Shielded")
            assert(not Status.has(k1, "status_shielded"), "a knight shields others, not itself")

            local hp = archer.char.stats.health
            local before = hp.current
            Combat.dealFlatDamage(c, archer, 20, {}, "test")
            local guarded = before - hp.current

            kill(c, k1)
            assert(Status.has(archer, "status_shielded"), "one knight still stands, so the guard holds")
            kill(c, k2)
            assert(not Status.has(archer, "status_shielded"), "the last knight down lifts the shield")

            before = hp.current
            Combat.dealFlatDamage(c, archer, 20, {}, "test")
            local open = before - hp.current
            assert(guarded > 0 and open >= guarded * 2 - 1,
                "the same blow lands about twice as hard once the knights are gone: "
                    .. guarded .. " guarded, " .. open .. " open")
        end,
    },
    {
        name = "Skeleton Archer: at its turn start it Marks the nearest foe holding an impact weapon, not the nearest foe",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { body(8, 6, { "weapon_iron_sword" }), body(2, 2, { "weapon_iron_mace" }) },
                { unit("character_skeleton_archer", 8, 8) })
            local sword, mace, archer = c.units[1], c.units[2], c.units[3]
            Trait.onAnyTurnStart(c, archer)
            assert(Status.has(mace, "status_mark"), "the body holding the mace is Marked")
            assert(not Status.has(sword, "status_mark"), "the nearer swordsman is not")
            -- One quarry at a time: with somebody already Marked, it marks nobody else.
            Status.remove(c, mace, "status_mark")
            Status.apply(c, sword, "status_mark")
            Trait.onAnyTurnStart(c, archer)
            assert(not Status.has(mace, "status_mark"), "a foe already hunted means no second Mark")
            -- And with no hammer on the field it marks nothing.
            local bare = Fixture.combat(Fixture.new(10, 10), body(8, 6, { "weapon_iron_sword" }),
                { unit("character_skeleton_archer", 8, 8) })
            Trait.onAnyTurnStart(bare, bare.units[2])
            assert(not Status.has(bare.units[1], "status_mark"), "no impact weapon, no Mark")
        end,
    },
    {
        name = "the dead company presses the Marked: a Skeleton Knight between two even foes swings at the one with the Mark",
        fn = function()
            -- Mark takes 5 defense and 4 luck off its bearer; the marked body is handed exactly that back,
            -- so the two are even to the scorer and only the rule's preference can choose between them.
            -- Both carry the same blade (whoever the archer marked, the knights' rule reads the Mark), and
            -- the Marked one stands where the planner's tie-break would NOT put it.
            local c = Fixture.combat(Fixture.new(9, 9),
                { body(5, 4, { "weapon_iron_sword" }),
                  body(5, 6, { "weapon_iron_sword" }, { defense = 11 + 5, luck = 2 + 4 }) },
                { unit("character_skeleton_knight", 5, 5) })
            local sword, mace, sk = c.units[1], c.units[2], c.units[3]
            sword.char.stats.defense, sword.char.stats.luck = 11, 2
            Status.apply(c, mace, "status_mark", { duration = 20 })
            openTurn(c, sk)
            local plan = AI.plan(c, sk)
            assert(plan and plan.item, "the knight acts")
            assert(plan.target == mace, "it goes for the Marked hammer, got "
                .. tostring(plan.target and plan.target.char.name) .. " at "
                .. tostring(plan.tx) .. "," .. tostring(plan.ty))
            -- The control: the same board with the rule taken away picks the other body, so it is the
            -- rule choosing and not the board.
            sk.char.ai = {}
            local blind = AI.plan(c, sk)
            assert(blind and blind.target == sword, "without the rule it swings at the other body")
        end,
    },
    {
        name = "Company Bones carries the company's lattice and drill, so the knight's and archer's totals did not move",
        fn = function()
            local def = Item.defs["utility_company_bones"]
            assert(def.class == "creature" and def.noSteal and def.price == nil, "creature kit")
            local c = Fixture.combat(Fixture.new(8, 8), body(1, 1),
                { unit("character_skeleton_knight", 6, 6), unit("character_skeleton_archer", 6, 3) })
            for i = 2, 3 do
                local u = c.units[i]
                assert(Trait.has(u, "trait_the_old_company"), u.char.name .. " keeps the drill")
                assert(u.resist.slash == 3 and u.resist.pierce == 3 and u.resist.impact == -6 and u.resist.holy == -6,
                    u.char.name .. " still wears 3/3/-6/-6")
            end
        end,
    },

    -- ------------------------------------------------------------------------------ the Barrow Lord
    {
        name = "Barrow Lord: Silenced, it cannot pay the rite, and the blow that fells it keeps it down",
        fn = function()
            local function lord()
                local c = Fixture.combat(Fixture.new(8, 8), body(1, 1),
                    unit("character_barrow_lord", 5, 5))
                return c, c.units[2]
            end
            local c, l = lord()
            kill(c, l)
            assert(l.alive, "unsilenced, it rises as it always did")

            c, l = lord()
            local mana = l.char.stats.mana.current
            Status.apply(c, l, "status_silenced", { duration = 15 })
            assert(Status.silenced(l), "the Silence landed")
            kill(c, l)
            assert(not l.alive, "Silenced, the blow that would fell it fells it")
            assert(l.char.stats.mana.current == mana, "and the toll was never paid")
        end,
    },
    {
        name = "the seal is the Binding's, not Bone-Knit's: Marrowlight in a company grid still rises through a Silence",
        fn = function()
            local c = Fixture.combat(Fixture.new(6, 6),
                body(2, 2, { "utility_marrowlight" }, { mana = 80 }),
                unit("character_bandit", 5, 5, { isolate = "mechanics" }))
            local u = c.units[1]
            Status.apply(c, u, "status_silenced", { duration = 15 })
            kill(c, u)
            assert(u.alive, "the player's charm names no seal, so a Silence does not stop it")
        end,
    },

    -- ------------------------------------------------------------------------------ the Gilded King
    {
        name = "Gilded King: a heap beside him at his turn start climbs back on as a plate; a looted heap cannot",
        fn = function()
            local c = Fixture.combat(Fixture.new(11, 11), body(6, 5),
                unit("character_the_gilded_king", 6, 6))
            local knight, king = c.units[1], c.units[2]
            local function plates() return Status.stacksOf(king, "status_gold_plate") end
            Combat.dealFlatDamage(c, king, 3, { "slash", "physical" }, nil, knight)
            Combat.dealFlatDamage(c, king, 3, { "slash", "physical" }, nil, knight)
            assert(plates() == 4 and heaps(c) == 2, "two blows, two plates off, two heaps beside him")

            Trait.onAnyTurnStart(c, king)
            assert(plates() == 5, "one heap went back on, got " .. plates())
            assert(heaps(c) == 1, "and it is gone from the floor")

            -- The company loots the last one before his turn comes round.
            for _, h in ipairs(c.hazards) do
                if h.alive and h.id == "hazard_coin_heap" then Combat.teleportUnit(c, knight, h.x, h.y) end
            end
            assert(heaps(c) == 0, "looted")
            Trait.onAnyTurnStart(c, king)
            assert(plates() == 5, "nothing left beside him, nothing goes back on")
        end,
    },
    {
        name = "Gilded King: a heap two tiles off stays on the floor, and he never plates past six",
        fn = function()
            local Golem = require("models.golem")
            local c = Fixture.combat(Fixture.new(11, 11), body(1, 1),
                unit("character_the_gilded_king", 6, 6))
            local king = c.units[2]
            Golem.heap(c, 7, 7)
            Trait.onAnyTurnStart(c, king)
            assert(Status.stacksOf(king, "status_gold_plate") == 6, "full plate takes nothing back")
            assert(heaps(c) == 1, "the heap is left where it lay")
            Status.spendStacks(c, king, "status_gold_plate", 1)
            Combat.teleportUnit(c, king, 4, 4)
            Trait.onAnyTurnStart(c, king)
            assert(Status.stacksOf(king, "status_gold_plate") == 5, "a heap out of reach does not come")
        end,
    },

    -- ------------------------------------------------------------------------------ same-mace
    {
        name = "same-mace: Bare Bones carries no physical lattice any more, only the holy line",
        fn = function()
            local r = Item.defs["utility_bare_bones"].resist
            assert(r.slash == nil and r.pierce == nil and r.impact == nil, "no slash, pierce or impact on the bone")
            assert(r.holy and r.holy < 0, "the dead still break under holy")
        end,
    },
    {
        name = "same-mace: one slash blow and one impact blow sort the bone bodies by what each asks for",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12), body(1, 1),
                { unit("character_kobold_skeleton", 3, 3), unit("character_dwarf_skeleton", 5, 5),
                  unit("character_skeleton_knight", 7, 7), unit("character_bone_wyrm", 9, 9) })
            local kobold, dwarf, sk, wyrm = c.units[2], c.units[3], c.units[4], c.units[5]
            local function taken(u, tags) return Combat.mitigatedDamage(u, 30, tags) end
            local slash, impact, pierce = { "slash", "physical" }, { "impact", "physical" }, { "pierce", "physical" }
            -- The kobold is the one bone body an edge is FOR.
            assert(kobold.resist.slash < 0, "a kobold's thin frame opens to an edge")
            assert(taken(kobold, slash) > taken(kobold, impact), "the kobold takes the sword over the mace")
            -- The dead company still asks for the mace.
            assert(taken(sk, impact) > taken(sk, slash), "the Skeleton Knight takes the mace over the sword")
            -- The dwarf keeps its race's line: fire-proof, and a hammer still rings it, but mildly.
            assert(dwarf.resist.fire > 0 and dwarf.resist.impact < 0 and dwarf.resist.impact > -6,
                "the dwarf's own line, not the lattice")
            -- The Bone Wyrm keeps the wyrm's hide: a point.
            assert(wyrm.resist.pierce < 0, "the Bone Wyrm asks for a point")
            assert(taken(wyrm, pierce) > taken(wyrm, impact), "...and takes the spear over the mace")
        end,
    },

    -- ------------------------------------------------------------------------------ targeting pass
    {
        name = "targeting: a Kobold Skulker with nobody wounded presses the hemmed-in foe",
        fn = function()
            -- Two even foes three steps off; one stands against the board's edge with fewer open tiles.
            -- The edge body sits where the planner's tie-break would NOT put it (a later row).
            local c = Fixture.combat(Fixture.new(9, 10),
                { body(5, 10, { "weapon_iron_sword" }), body(5, 4, { "weapon_iron_sword" }) },
                { unit("character_kobold_skulker", 5, 7) })
            local edge, open, kobold = c.units[1], c.units[2], c.units[3]
            openTurn(c, kobold)
            local plan = AI.plan(c, kobold)
            assert(plan and plan.item, "the kobold acts")
            assert(plan.target == edge, "it goes for the one with nowhere to step, got "
                .. tostring(plan.target and (plan.target.x .. "," .. plan.target.y)))
            assert(plan.target ~= open)
            kobold.char.ai = {}
            local blind = AI.plan(c, kobold)
            assert(blind and blind.target == open, "without the rule it goes the other way")
        end,
    },
    {
        name = "targeting: a Gilded Scarab and a Rust Mite between two even foes go for the Gilded one",
        fn = function()
            for _, id in ipairs({ "character_gilded_scarab", "character_rust_mite" }) do
                -- Gilded adds 3 defense; the other foe is handed the same, so only the preference differs.
                local c = Fixture.combat(Fixture.new(9, 9),
                    { body(5, 4, { "weapon_iron_sword" }, { defense = 14 }), body(5, 6, { "weapon_iron_sword" }) },
                    { unit(id, 5, 5) })
                local plain, gilt, eater = c.units[1], c.units[2], c.units[3]
                gilt.char.stats.defense = 11
                Status.apply(c, gilt, "status_gilded", { duration = 20 })
                openTurn(c, eater)
                local plan = AI.plan(c, eater)
                assert(plan and plan.item, id .. " acts")
                assert(plan.target == gilt, id .. " goes for the gold, got "
                    .. tostring(plan.target and (plan.target.x .. "," .. plan.target.y)))
                assert(plan.target ~= plain)
                eater.char.ai = {}
                local blind = AI.plan(c, eater)
                assert(blind and blind.target == plain, id .. " without the rule goes the other way")
            end
        end,
    },
}
