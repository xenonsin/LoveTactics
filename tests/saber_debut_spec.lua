-- The debut bout's tuning (data/quests/arena_debut.lua), and the two seams built for it.
--
-- The complaint this answers: Saber telegraphed for four ticks, swung a two-tile line at ground the
-- target had already left, and then spent six more recovering. Three things changed, and each of them
-- is a claim worth pinning rather than a number worth eyeballing:
--
--   * `channelHazard` -- ground the wind-up churns up under its own footprint, laid ON COMMIT. The
--     commit timing is the whole point (a telegraph that only bites after the blow lands is not a
--     telegraph), so it is asserted directly rather than inferred from the end state.
--   * an AI rule's `windup` -- how deep to hold a chargeable wind-up. Before this, every enemy cast
--     opened at the ability's floor because states/battle.lua passed no depth at all, so a boss
--     carrying a chargeable signature could only ever snap it.
--   * Saber's own rules reading both, so the fight escalates off what she already did: a snap swing
--     lays the sand, the sand Mires whoever is standing in it, and only THEN does she hold the edge.
--
-- Companion spec to tests/charge_spec.lua, which pins the wind-up depth from the player's side.

local Combat = require("models.combat")
local Status = require("models.status")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Character = require("models.character")
local Arena = require("models.arena")
local Quest = require("models.quest")
local Fixture = require("tests.support.fixture")

-- Every quicksand patch on the board, as a "x,y" set -- what the swing actually churned up.
local function sandCells(combat)
    local out = {}
    for _, h in ipairs(combat.hazards or {}) do
        if h.alive and h.id == "hazard_quicksand" then out[h.x .. "," .. h.y] = true end
    end
    return out
end

local function count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end

return {
    -- THE CHANNEL HAZARD ----------------------------------------------------------------------------
    {
        name = "the ground goes soft when she COMMITS, not when the blow lands",
        fn = function()
            local map = Fixture.new(8, 8)
            local her = Fixture.unit("character_saber", 4, 4)
            local foe = Fixture.unit("character_bandit", 4, 5)
            local combat = Fixture.combat(map, her, foe)
            local s = combat.units[1]
            local blade = Fixture.itemNamed(s.char, "weapon_first_motion")

            assert(count(sandCells(combat)) == 0, "the sand is clean before she swings")

            Fixture.openTurn(combat, s)
            assert(Combat.useItem(combat, s, blade, 4, 5), "she begins the wind-up")
            assert(s.channel, "and it is a channel, not an instant swing")

            -- The claim: the sand is down NOW, during the tell, while the target still has turns in
            -- which to decide what to do about it. This is the difference between a telegraph the
            -- player can answer and a consequence they can only regret.
            local mid = sandCells(combat)
            assert(count(mid) > 0, "the strike zone is already churned while she is still winding up")
            assert(mid["4,5"], "including the tile she aimed at, got: " .. table.concat((function()
                local t = {} for k in pairs(mid) do t[#t + 1] = k end table.sort(t) return t
            end)(), " "))
        end,
    },
    {
        name = "the sand covers the whole telegraphed footprint, not just the aimed tile",
        fn = function()
            -- The First Motion drives THROUGH the tiles in front (aoe line, length 2 at level 0), and
            -- the hazard is laid over Combat.aoeCells -- the same footprint the red preview draws. A
            -- swing whose sand did not match its own telegraph would be lying to the player.
            local map = Fixture.new(8, 8)
            local her = Fixture.unit("character_saber", 4, 4)
            local foe = Fixture.unit("character_bandit", 4, 5)
            local combat = Fixture.combat(map, her, foe)
            local s = combat.units[1]
            local blade = Fixture.itemNamed(s.char, "weapon_first_motion")

            Fixture.openTurn(combat, s)
            assert(Combat.useItem(combat, s, blade, 4, 5), "she begins the wind-up")

            local sand = sandCells(combat)
            local cells = Combat.aoeCells(combat, blade.activeAbility, 4, 5, s)
            assert(#cells >= 2, "the swing really does reach past the first tile")
            for _, c in ipairs(cells) do
                assert(sand[c.x .. "," .. c.y],
                    "every telegraphed tile is churned; " .. c.x .. "," .. c.y .. " was not")
            end
        end,
    },
    {
        name = "standing in the churned ground Mires you, so leaving it costs double",
        fn = function()
            -- Quicksand's own contract (data/hazards/hazard_quicksand.lua), asserted here because it
            -- is the entire reason the swing lays it: the dodge is not forbidden, it is PRICED.
            local map = Fixture.new(8, 8)
            local her = Fixture.unit("character_saber", 4, 4)
            local foe = Fixture.unit("character_bandit", 4, 5)
            local combat = Fixture.combat(map, her, foe)
            local s, f = combat.units[1], combat.units[2]
            local blade = Fixture.itemNamed(s.char, "weapon_first_motion")

            Fixture.openTurn(combat, s)
            assert(Combat.useItem(combat, s, blade, 4, 5), "she begins the wind-up")
            -- The bandit is standing in the strike zone as the sand goes down.
            Hazard.onEnter(combat, f, f.x, f.y)
            assert(Status.has(f, "status_mired"),
                "a body standing in the strike zone is bogged down while the blow is still coming")
        end,
    },
    {
        name = "the sand does not vanish when she does -- it is churned earth, not a summon",
        fn = function()
            local map = Fixture.new(8, 8)
            local her = Fixture.unit("character_saber", 4, 4)
            local foe = Fixture.unit("character_bandit", 4, 6)
            local combat = Fixture.combat(map, her, foe)
            local s = combat.units[1]
            local blade = Fixture.itemNamed(s.char, "weapon_first_motion")

            Fixture.openTurn(combat, s)
            assert(Combat.useItem(combat, s, blade, 4, 5), "she begins the wind-up")
            local before = count(sandCells(combat))
            assert(before > 0, "the sand is down")

            -- Cut her down mid-wind-up. An owned zone would go with its owner (Hazard.dropOwnedBy);
            -- this one is deliberately unowned, so killing the caster does not un-churn the ground.
            Combat.dealFlatDamage(combat, s, 9999, {}, "test")
            assert(not s.alive, "she is down")
            assert(count(sandCells(combat)) == before, "and the ground she tore up is still torn up")
        end,
    },

    -- THE AI'S WIND-UP DEPTH ------------------------------------------------------------------------
    {
        name = "an AI rule's windup reaches the model: a named depth is the depth actually held",
        fn = function()
            -- The bug this closes: states/battle.lua called Combat.useItem with no depth, so every
            -- enemy cast clamped to the ability's floor and the deep end of a chargeable wind-up was
            -- unreachable from the enemy side of the board. Asserted through Combat.useItem directly,
            -- which is the seam the enemy turn now feeds.
            local map = Fixture.new(8, 8)
            local her = Fixture.unit("character_saber", 4, 4)
            local foe = Fixture.unit("character_bandit", 4, 5)
            local combat = Fixture.combat(map, her, foe)
            local s = combat.units[1]
            local blade = Fixture.itemNamed(s.char, "weapon_first_motion")
            local lo, hi = Item.windupRange(blade.activeAbility)

            Fixture.openTurn(combat, s)
            assert(Combat.useItem(combat, s, blade, 4, 5, hi), "she holds the edge to the cap")
            assert(s.channel.windup == hi,
                "the deep hold is what she is holding, got " .. tostring(s.channel.windup))
            assert(s.channel.held == hi - lo,
                "and `held` is the part she CHOSE above her floor, got " .. tostring(s.channel.held))
        end,
    },
    {
        name = "a snap and a deep hold are different tells, and the deep one lands harder",
        fn = function()
            -- Patience made arithmetic: the bonus rides `held`, so a swing loosed at the floor is an
            -- ordinary heavy greatsword blow and a deep hold into a fresh body is devastating.
            local function swing(depth)
                local map = Fixture.new(8, 8)
                local her = Fixture.unit("character_saber", 4, 4)
                local foe = Fixture.unit("character_bandit", 4, 5, { stats = { health = 400 } })
                local combat = Fixture.combat(map, her, foe)
                local s, f = combat.units[1], combat.units[2]
                local blade = Fixture.itemNamed(s.char, "weapon_first_motion")
                local before = Fixture.hp(f)
                Fixture.openTurn(combat, s)
                assert(Combat.useItem(combat, s, blade, 4, 5, depth), "the wind-up starts")
                Combat.resolveChannel(combat, s)
                return before - Fixture.hp(f)
            end
            local lo, hi = Item.windupRange(
                Item.instantiate("weapon_first_motion").activeAbility)
            local snap, held = swing(lo), swing(hi)
            assert(held > snap,
                "holding the edge is worth something: snap " .. snap .. " vs held " .. held)
        end,
    },

    -- HER KIT ---------------------------------------------------------------------------------------
    {
        name = "she carries the bolas she is authored to open with, and it roots",
        fn = function()
            -- Rule 3 of her block throws it, and rules 1-2 are written against what it leaves behind.
            -- A rule naming an item the character does not carry collapses to "this rule cannot act"
            -- (models/ai.lua), which would fail silently and leave her swinging into empty ground.
            local map = Fixture.new(8, 8)
            local her = Fixture.unit("character_saber", 4, 4)
            local foe = Fixture.unit("character_bandit", 4, 6)
            local combat = Fixture.combat(map, her, foe)
            local s, f = combat.units[1], combat.units[2]
            local bolas = Fixture.itemNamed(s.char, "ability_bolas")
            assert(bolas, "the bolas is in her grid")

            Fixture.openTurn(combat, s)
            assert(Combat.useItem(combat, s, bolas, 4, 6), "she throws it")
            assert(Status.has(f, "status_root"), "and the target is pinned")
        end,
    },
    {
        name = "every item her tactics name is an item she actually holds",
        fn = function()
            -- The whole failure mode of an authored rule block: a renamed or moved item leaves a rule
            -- that can never fire, and nothing complains -- the boss just quietly stops doing the
            -- thing it was written to do.
            local def = Character.defs["character_saber"]
            assert(def and def.ai, "Saber carries authored tactics")
            local held = {}
            for _, entry in ipairs(def.startingItems or {}) do
                if type(entry) == "string" then held[entry] = true end
            end
            for i, rule in ipairs(def.ai) do
                if rule.item then
                    assert(held[rule.item],
                        "rule " .. i .. " names " .. rule.item .. ", which she does not carry")
                end
            end
        end,
    },
    {
        name = "a depth named by a rule is one the ability can actually be held at",
        fn = function()
            -- A rule asking for a depth outside the ability's range is not an error anywhere -- it is
            -- silently clamped -- so an authoring slip reads as a boss that swings at a depth nobody
            -- chose. Cheaper to catch here than to notice in a bout.
            local def = Character.defs["character_saber"]
            for i, rule in ipairs(def.ai or {}) do
                if rule.windup and rule.item then
                    local ab = Item.defs[rule.item] and Item.defs[rule.item].activeAbility
                    local lo, hi = Item.windupRange(ab)
                    assert(rule.windup >= lo and rule.windup <= hi,
                        "rule " .. i .. " asks to hold " .. rule.item .. " for " .. rule.windup
                            .. " ticks, outside its " .. lo .. "-" .. hi .. " range")
                end
            end
        end,
    },

    -- THE BOSS TWIN AND ITS PHASES ------------------------------------------------------------------
    {
        name = "the bout twin extends the recruit but adds the boss flag, the pool, and the relic",
        fn = function()
            -- The whole point of the split: everything the bout needs and the companion must not keep
            -- lives on the twin. The recruit is clean.
            local recruit = Character.defs["character_saber"]
            local twin = Character.defs["character_saber_bout"]
            assert(not recruit.boss, "the recruit is an ordinary companion, not a quest objective")
            assert(twin.boss, "the twin is the objective -- immune to execute and Charm")
            assert(twin.stats.health > recruit.stats.health,
                "the twin carries the deeper pool the phases need room to read in")
            -- The kit and tactics are SHARED, so they cannot drift: same table, by reference.
            assert(twin.ai == recruit.ai, "the twin fights with the companion's own tactics, not a copy")

            local function holds(def, id)
                for _, e in ipairs(def.startingItems or {}) do if e == id then return true end end
                return false
            end
            assert(holds(twin, "utility_gatekeepers_measure"), "the twin carries the phase relic")
            assert(not holds(recruit, "utility_gatekeepers_measure"),
                "and the recruit does NOT -- the relic never rides home")
            assert(holds(twin, "weapon_first_motion") and holds(recruit, "weapon_first_motion"),
                "both swing the same signature")
        end,
    },
    {
        name = "the relic summons a hand at two-thirds and commits her at a third",
        fn = function()
            -- utility_gatekeepers_measure's script, driven the way the Champion's Sigil is driven: a
            -- survived blow crosses a threshold. Fielded through the twin, which is the only thing that
            -- carries it.
            local map = Fixture.new(10, 10)
            local her = Fixture.unit("character_saber_bout", 5, 5)
            local foe = Fixture.unit("character_bandit", 2, 2)
            local combat = Fixture.combat(map, her, foe)
            local s = combat.units[1]
            assert(Status ~= nil)

            local phase
            for _, t in ipairs(s.traits or {}) do if t.id == "trait_boss_phases" then phase = t end end
            assert(phase and phase.item and phase.item.phases,
                "the twin answers each wound with the next stage, scripted on the relic")

            local hp = s.char.stats.health
            local handsBefore = 0
            for _, u in ipairs(combat.units) do
                if u.alive and u.char.id == "character_arena_hand" then handsBefore = handsBefore + 1 end
            end

            -- Just under two-thirds: she whistles in a hand.
            hp.current = math.floor(hp.max * 0.65) + 1
            Combat.dealFlatDamage(combat, s, 1, nil, "test")
            assert(s.alive and phase.stacks == 1, "one stage crossed at two-thirds")
            local handsAfter = 0
            for _, u in ipairs(combat.units) do
                if u.alive and u.char.id == "character_arena_hand" then handsAfter = handsAfter + 1 end
            end
            assert(handsAfter == handsBefore + 1, "another house hand is on the sand")
            assert(not Status.get(s, "status_hasted"), "but she has not committed yet")

            -- Just under a third: she stops toying -- fast and hitting harder.
            local dmgBefore = s.bonus.damage or 0
            hp.current = math.floor(hp.max * 0.32) + 1
            Combat.dealFlatDamage(combat, s, 1, nil, "test")
            assert(phase.stacks == 2, "the second stage crossed at a third")
            assert(Status.get(s, "status_hasted"), "she turns fast (status_hasted)")
            assert((s.bonus.damage or 0) > dmgBefore, "and her swing hits harder")
        end,
    },
    {
        name = "the house hand nets an unpinned foe -- the setup Saber's swing was missing",
        fn = function()
            local map = Fixture.new(8, 8)
            local hand = Fixture.unit("character_arena_hand", 4, 4)
            local foe = Fixture.unit("character_avatar", 4, 6)
            local combat = Fixture.combat(map, hand, foe)
            local h, f = combat.units[1], combat.units[2]
            local bolas = Fixture.itemNamed(h.char, "ability_bolas")
            assert(bolas, "the hand carries the net")

            Fixture.openTurn(combat, h)
            assert(Combat.useItem(combat, h, bolas, 4, 6), "it throws the net")
            assert(Status.has(f, "status_root"), "and the target is pinned for Saber's swing")
        end,
    },

    -- THE ARENA -------------------------------------------------------------------------------------
    {
        name = "the debut names its board, and the board's rigging survives the build",
        fn = function()
            -- The bout no longer rolls a random castle field: it names data/arenas/colosseum_sand.lua,
            -- and the authored funnel walls, hidden snares and soft-ground patches have to reach the
            -- built combat -- carried by Arena.build (models/arena.lua's traps/hazards seam).
            assert(Quest.defs["arena_debut"].map.objective.layout == "colosseum_sand",
                "the objective names the authored board")

            local built = Arena.build({}, {
                layout = "colosseum_sand", biome = "castle",
                party = { "character_avatar", "character_knight" },
                composition = function() return { "character_saber_bout", "character_arena_hand" } end,
                objective = { type = "assassinate", target = "character_saber_bout" },
                seed = 1,
            })

            -- The funnel: obstacle walls a rolled board would never place at the flanks.
            assert(built.tiles[4][1].type == "obstacle" and built.tiles[4][8].type == "obstacle",
                "the flank walls that funnel a dodging body are on the board")
            -- The rigged edges: two hidden snares, owned by the enemy so they never bite Saber's team.
            local snares = 0
            for _, t in ipairs(built.traps or {}) do
                if t.id == "snare_stake" then snares = snares + 1 end
            end
            assert(snares == 2, "both hidden snares survived the build, got " .. snares)
            -- The soft ground: the seeable grasping-hollow patches.
            local hollows = 0
            for _, h in ipairs(built.hazards or {}) do
                if h.id == "hazard_grasping_hollow" then hollows = hollows + 1 end
            end
            assert(hollows == 2, "both grasping-hollow patches survived the build, got " .. hollows)
        end,
    },
}
