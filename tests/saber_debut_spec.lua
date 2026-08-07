-- The debut bout's tuning (data/quests/colosseum/quest_colosseum_slot_01.lua), and the two seams built for it.
--
-- The complaint this answers: Saber telegraphed for four ticks, swung a two-tile line at ground the
-- target had already left, and then spent six more recovering. Three things changed, and each of them
-- is a claim worth pinning rather than a number worth eyeballing:
--
--   * `channelAfflict` -- a Cowering debuff stamped on whoever stands in the wind-up's footprint, ON
--     COMMIT. The commit timing is the whole point (a telegraph that only bites after the blow lands is
--     not a telegraph), so it is asserted directly rather than inferred from the end state.
--   * an AI rule's `windup` -- how deep to hold a chargeable wind-up. Before this, every enemy cast
--     opened at the ability's floor because states/battle.lua passed no depth at all, so a boss
--     carrying a chargeable signature could only ever snap it.
--   * Saber's own rules reading both, so the fight escalates off what she already did: a snap swing
--     cows whoever is under it, the flinch cuts their movement, and only THEN does she hold the edge.
--
-- Companion spec to tests/charge_spec.lua, which pins the wind-up depth from the player's side.

local Combat = require("models.combat")
local Status = require("models.status")
local Item = require("models.item")
local Character = require("models.character")
local Arena = require("models.arena")
local Quest = require("models.quest")
local Fixture = require("tests.support.fixture")

return {
    -- THE CHANNEL AFFLICT (COWERING) ----------------------------------------------------------------
    {
        name = "she cows whoever is caught the moment she COMMITS, not when the blow lands",
        fn = function()
            local map = Fixture.new(8, 8)
            local her = Fixture.unit("character_saber", 4, 4)
            local foe = Fixture.unit("character_bandit", 4, 5)
            local combat = Fixture.combat(map, her, foe)
            local s, f = combat.units[1], combat.units[2]
            local blade = Fixture.itemNamed(s.char, "weapon_first_motion")

            assert(not Status.has(f, "status_cowering"), "nobody flinches before she swings")

            Fixture.openTurn(combat, s)
            assert(Combat.useItem(combat, s, blade, 4, 5), "she begins the wind-up")
            assert(s.channel, "and it is a channel, not an instant swing")

            -- The claim: the flinch is on the body NOW, during the tell, while the target still has
            -- turns in which to decide what to do about it -- not a consequence delivered when the
            -- blow lands. This is the difference between a telegraph the player can answer and one
            -- they can only regret.
            assert(Status.has(f, "status_cowering"),
                "the body under the blade is already cowering while she is still winding up")
        end,
    },
    {
        name = "every body in the telegraphed footprint cowers, and one already clear does not",
        fn = function()
            -- The First Motion drives THROUGH the tiles in front (aoe line, length 2 at level 0: the
            -- aimed cell and the one beyond it). The affliction lands over Combat.aoeCells -- the same
            -- footprint the red preview draws -- so it must catch every body inside it, and being a
            -- status on the occupants rather than terrain, it must NOT reach a body standing outside it.
            local map = Fixture.new(8, 8)
            local her = Fixture.unit("character_saber", 4, 4)
            local combat = Fixture.combat(map, her, {
                Fixture.unit("character_bandit", 4, 5), -- the aimed tile
                Fixture.unit("character_bandit", 4, 6), -- the tile the swing drives through beyond it
                Fixture.unit("character_bandit", 4, 7), -- one step past the footprint
            })
            local s = combat.units[1]
            local blade = Fixture.itemNamed(s.char, "weapon_first_motion")

            local cells = Combat.aoeCells(combat, blade.activeAbility, 4, 5, s)
            assert(#cells >= 2, "the swing really does reach past the first tile")

            Fixture.openTurn(combat, s)
            assert(Combat.useItem(combat, s, blade, 4, 5), "she begins the wind-up")

            assert(Status.has(Combat.unitAt(combat, 4, 5), "status_cowering"), "the aimed body cowers")
            assert(Status.has(Combat.unitAt(combat, 4, 6), "status_cowering"),
                "and so does the one the swing drives through beyond it")
            assert(not Status.has(Combat.unitAt(combat, 4, 7), "status_cowering"),
                "but a body already clear of the footprint is never touched -- it is not terrain")
        end,
    },
    {
        name = "cowering shortens the escape but does not forbid it -- the dodge is priced, not banned",
        fn = function()
            -- Cowering's own contract (data/status/cowering.lua), asserted here because it is the
            -- entire reason the swing lays it: the dodge is not forbidden, its reach is SHORTENED.
            local map = Fixture.new(8, 8)
            local her = Fixture.unit("character_saber", 4, 4)
            local foe = Fixture.unit("character_bandit", 4, 5)
            local combat = Fixture.combat(map, her, foe)
            local s, f = combat.units[1], combat.units[2]
            local blade = Fixture.itemNamed(s.char, "weapon_first_motion")

            local before = Combat.moveBudget(f)
            Fixture.openTurn(combat, s)
            assert(Combat.useItem(combat, s, blade, 4, 5), "she begins the wind-up")
            assert(Status.has(f, "status_cowering"), "the body in the strike zone is cowering")

            local after = Combat.moveBudget(f)
            assert(after < before, "its reach is cut while the blow hangs over it: " .. before .. " -> " .. after)
            assert(after > 0, "but it can still move -- the swing is dodgeable, only not for free")
        end,
    },
    {
        name = "the flinch rides the body, not the ground -- it outlives the swordswoman who caused it",
        fn = function()
            -- A hazard would have been terrain answering to its own life; this is a status on the foe,
            -- so cutting Saber down mid-wind-up does not lift the flinch from the body she stamped it on.
            local map = Fixture.new(8, 8)
            local her = Fixture.unit("character_saber", 4, 4)
            local foe = Fixture.unit("character_bandit", 4, 5)
            local combat = Fixture.combat(map, her, foe)
            local s, f = combat.units[1], combat.units[2]
            local blade = Fixture.itemNamed(s.char, "weapon_first_motion")

            Fixture.openTurn(combat, s)
            assert(Combat.useItem(combat, s, blade, 4, 5), "she begins the wind-up")
            assert(Status.has(f, "status_cowering"), "the foe is cowering")

            Combat.dealFlatDamage(combat, s, 9999, {}, "test")
            assert(not s.alive, "she is down")
            assert(Status.has(f, "status_cowering"), "and the body she made flinch is flinching still")
        end,
    },
    {
        name = "the flinch lifts when she stops channeling -- the blow lands and there is nothing left to cower from",
        fn = function()
            -- The counterpart to the interrupt case above: on a clean RESOLVE the swing has fallen, so
            -- the grip it kept on the bodies under it is released rather than left to punish them a
            -- second time. The cowering rode the wind-up, not a flat window that outlives the blow.
            local map = Fixture.new(8, 8)
            local her = Fixture.unit("character_saber", 4, 4)
            local foe = Fixture.unit("character_bandit", 4, 5)
            local combat = Fixture.combat(map, her, foe)
            local s, f = combat.units[1], combat.units[2]
            local blade = Fixture.itemNamed(s.char, "weapon_first_motion")

            Fixture.openTurn(combat, s)
            assert(Combat.useItem(combat, s, blade, 4, 5), "she begins the wind-up")
            assert(Status.has(f, "status_cowering"), "the foe cowers while the swing hangs over it")

            Combat.resolveChannel(combat, s)
            assert(not Status.has(f, "status_cowering"),
                "and once the blow lands and she stops channeling, the flinch is gone")
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
    {
        name = "haste runs her wind-up shorter without softening the blow",
        fn = function()
            -- Haste discounts the TELL (Combat.useItem's timeTicks) but not the COMMITMENT the bonus is
            -- scored on, so a hasted deep hold lands the SAME damage as an un-hasted one -- in a shorter
            -- wind-up. Half the time to walk clear, and the blow at the end is no smaller.
            local function swing(hasted)
                local map = Fixture.new(8, 8)
                local her = Fixture.unit("character_saber", 4, 4)
                local foe = Fixture.unit("character_bandit", 4, 5, { stats = { health = 400 } })
                local combat = Fixture.combat(map, her, foe)
                local s, f = combat.units[1], combat.units[2]
                local blade = Fixture.itemNamed(s.char, "weapon_first_motion")
                local _, hi = Item.windupRange(blade.activeAbility)
                if hasted then Status.apply(combat, s, "status_hasted") end
                local before = Fixture.hp(f)
                Fixture.openTurn(combat, s)
                assert(Combat.useItem(combat, s, blade, 4, 5, hi), "she holds the edge to the cap")
                -- The actual tell she hangs for is the channeling badge's life (timeTicks + 1); the
                -- stored channel.windup is the undiscounted commitment the bonus is scored on.
                local tell = Status.get(s, "status_channeling").remaining
                Combat.resolveChannel(combat, s)
                return before - Fixture.hp(f), tell
            end
            local plainDmg, plainTell = swing(false)
            local hasteDmg, hasteTell = swing(true)
            assert(hasteTell < plainTell,
                "the hasted tell is shorter: " .. hasteTell .. " vs " .. plainTell)
            assert(hasteDmg == plainDmg,
                "but the blow is identical: hasted " .. hasteDmg .. " vs un-hasted " .. plainDmg)
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
            local foe = Fixture.unit("character_bandit", 4, 6, { stats = { health = 400 } })
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
        name = "the relic commits her at a third -- and no longer whistles in a second wave",
        fn = function()
            -- utility_gatekeepers_measure's script, driven the way the Champion's Sigil is driven: a
            -- survived blow crosses a threshold. Fielded through the twin, which is the only thing that
            -- carries it. The 66% summon was retired -- both trappers now open on the sand -- so the
            -- relic's one remaining stage is the 33% commit, and nothing is called in before it.
            local map = Fixture.new(10, 10)
            local her = Fixture.unit("character_saber_bout", 5, 5)
            local foe = Fixture.unit("character_bandit", 2, 2)
            local combat = Fixture.combat(map, her, foe)
            local s = combat.units[1]

            local phase
            for _, t in ipairs(s.traits or {}) do if t.id == "trait_boss_phases" then phase = t end end
            assert(phase and phase.item and phase.item.phases,
                "the twin answers a deep wound with the next stage, scripted on the relic")

            local function trappersOnSand()
                local n = 0
                for _, u in ipairs(combat.units) do
                    if u.alive and u.char.id == "character_trapper" then n = n + 1 end
                end
                return n
            end
            assert(trappersOnSand() == 0, "no trapper is fielded in this isolated fixture")

            local hp = s.char.stats.health

            -- Just under two-thirds: the OLD summon threshold. Nothing crosses now -- the only stage is
            -- at a third -- so no body is called in and she has not committed.
            hp.current = math.floor(hp.max * 0.65) + 1
            Combat.dealFlatDamage(combat, s, 1, nil, "test")
            assert(s.alive and phase.stacks == 0, "two-thirds crosses nothing: the second wave is gone")
            assert(trappersOnSand() == 0, "and no trapper is whistled onto the sand")
            assert(not Status.get(s, "status_hasted"), "she has not committed at two-thirds")

            -- Just under a third: she stops toying -- fast and hitting harder.
            local dmgBefore = s.bonus.damage or 0
            hp.current = math.floor(hp.max * 0.32) + 1
            Combat.dealFlatDamage(combat, s, 1, nil, "test")
            assert(phase.stacks == 1, "the one remaining stage crosses at a third")
            assert(Status.get(s, "status_hasted"), "she turns fast (status_hasted)")
            assert((s.bonus.damage or 0) > dmgBefore, "and her swing hits harder")
            assert(trappersOnSand() == 0, "still no reinforcement -- the crowd was all there at the bell")
        end,
    },
    {
        name = "a trapper nets an unpinned foe -- the setup Saber's swing was missing",
        fn = function()
            local map = Fixture.new(8, 8)
            local trapper = Fixture.unit("character_trapper", 4, 4)
            local foe = Fixture.unit("character_avatar", 4, 6)
            local combat = Fixture.combat(map, trapper, foe)
            local h, f = combat.units[1], combat.units[2]
            local bolas = Fixture.itemNamed(h.char, "ability_bolas")
            assert(bolas, "the trapper carries the net")

            Fixture.openTurn(combat, h)
            assert(Combat.useItem(combat, h, bolas, 4, 6), "it throws the net")
            assert(Status.has(f, "status_root"), "and the target is pinned for Saber's swing")
        end,
    },
    {
        name = "the opener fields Saber and one trapper, with a gate spawn for each",
        fn = function()
            -- The bell opens on the whole team -- the boss twin and one trapper -- rather than holding a
            -- body back for a summon. The composition names two, and the board must seat every one.
            local comp = Quest.defs["quest_colosseum_slot_01"].map.objective.composition()
            assert(#comp == 2, "two bodies open the bout, got " .. #comp)
            assert(comp[1] == "character_saber_bout", "Saber's twin leads the line")
            local trappers = 0
            for _, id in ipairs(comp) do if id == "character_trapper" then trappers = trappers + 1 end end
            assert(trappers == 1, "one trapper on the sand at the bell, got " .. trappers)

            local sand = require("data.arenas.colosseum_sand")
            assert(#sand.enemySpawns >= 2,
                "the board seats both, got " .. #sand.enemySpawns .. " enemy spawns")
        end,
    },

    -- THE ROOT COUNTERPLAY ------------------------------------------------------------------------
    -- The bout roots the player nearly every turn (two Trappers, a 2-unit party). These two stops on
    -- the approach make that fair: the undercard teaches the net where it cannot lose the fight, and
    -- the kit scene hands the cleanse that lifts it. A re-roll or rename that stripped either would
    -- leave the bout balanced around a lesson never taught and a tool never found.
    {
        name = "the approach fields the netter before the boss -- the trapper undercard",
        fn = function()
            local Encounter = require("models.encounter")
            local always = Quest.defs["quest_colosseum_slot_01"].map.encounters.always
            local listed = false
            for _, e in ipairs(always) do if e.id == "encounter_arena_undercard" then listed = true end end
            assert(listed, "the approach lists the trapper undercard among its always-stops")

            local def = Encounter.defs["encounter_arena_undercard"]
            assert(def and def.kind == "combat", "the undercard is a combat stop")
            local trappers = 0
            for _, id in ipairs(def.composition()) do
                if id == "character_trapper" then trappers = trappers + 1 end
            end
            assert(trappers >= 1, "it fields the same Trapper, so Root is met before the bout")
        end,
    },
    {
        name = "the found kit hands a self-cleanse -- the rooted unit's own way out",
        fn = function()
            -- A rooted body can still drink (Root blocks the step, not the hand -- status_root sets
            -- blocksMove, not disablesActions), so a self-cleanse buys the move back. The scene must
            -- actually grant one; the fight is balanced on the player having it.
            local always = Quest.defs["quest_colosseum_slot_01"].map.encounters.always
            local convId
            for _, e in ipairs(always) do
                if e.id == "encounter_event" and e.conversation == "conversation_colosseum_slot_01_kit" then convId = e.conversation end
            end
            assert(convId, "the approach lists the kit scene among its always-stops")

            local conv = require("models.conversation").defs[convId]
            local grantsVial = false
            for _, node in ipairs(conv.script) do
                for _, c in ipairs(node.choices or {}) do
                    local grant = c.effect and c.effect.grant
                    if type(grant) == "table" then
                        for _, id in ipairs(grant) do
                            if id == "consumable_clearwater_vial" then grantsVial = true end
                        end
                    elseif grant == "consumable_clearwater_vial" then
                        grantsVial = true
                    end
                end
            end
            assert(grantsVial, "the kit scene grants a Clearwater Vial, the rooted unit's own out")
        end,
    },

    -- THE ARENA -------------------------------------------------------------------------------------
    {
        name = "the debut names its board, and the board's rigging survives the build",
        fn = function()
            -- The bout no longer rolls a random castle field: it names data/arenas/colosseum_sand.lua,
            -- and the authored funnel walls, hidden snares and soft-ground patches have to reach the
            -- built combat -- carried by Arena.build (models/arena.lua's traps/hazards seam).
            assert(Quest.defs["quest_colosseum_slot_01"].map.objective.layout == "colosseum_sand",
                "the objective names the authored board")

            local built = Arena.build({}, {
                layout = "colosseum_sand", biome = "castle",
                party = { "character_avatar", "character_rowan" },
                composition = Quest.defs["quest_colosseum_slot_01"].map.objective.composition,
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
