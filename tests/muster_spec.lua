-- The muster ruler (models/muster.lua): how much fight a body is worth, and how a company's worth
-- stands against an encounter's. Two readers depend on these numbers meaning one thing -- the colour of
-- an overworld marker's danger pips, and the gate on walking a fight off without playing it -- so what
-- is pinned here is mostly that the ruler is the SAME on both sides of every comparison, and that the
-- bands and the gate agree about where "walkable" starts.

local Muster = require("models.muster")
local Character = require("models.character")
local Item = require("models.item")
local Player = require("models.player")
local Encounter = require("models.encounter")
local Arena = require("models.arena")

local function bare(id)
    local char = Character.instantiate(id)
    char.traits = {}
    char.inventory = {}
    return char
end

return {
    {
        name = "the same body on both sides reads as an even match",
        fn = function()
            local ours = Muster.company({ bare("character_knight") })
            local theirs = Muster.company({ bare("character_knight") })
            assert(ours > 0, "a knight is worth something")
            assert(Muster.margin(ours, theirs) == 100,
                "identical companies read 100%, got " .. tostring(Muster.margin(ours, theirs)))
        end,
    },
    {
        name = "gear in the grid raises a body's worth",
        fn = function()
            local naked = bare("character_knight")
            local kitted = bare("character_knight")
            Character.addItem(kitted, Item.instantiate("armor_chainmail"))

            assert(Muster.rate(kitted) > Muster.rate(naked),
                "chainmail's defense bonus has to reach the rating -- gear is what the ruler is FOR")
        end,
    },
    {
        name = "a resource ceiling raised by gear reaches the rating too",
        fn = function()
            -- The bonus/maxBonus split is silent when read wrong (Character.statSources): an item that
            -- raises a max health ceiling writes `maxBonus`, not `bonus`, and a reader checking only
            -- `bonus` would price the toughest charms in the game at zero.
            local plain = bare("character_knight")
            local tough = bare("character_knight")
            tough.inventory[1] = { name = "Test Charm", maxBonus = { health = 40 } }

            assert(Muster.rate(tough) - Muster.rate(plain) == 40 * Muster.STAT_WEIGHTS.health,
                "a +40 health ceiling is worth exactly 40 health-weights of muster")
        end,
    },
    {
        name = "offense is the better arm, not the sum of both",
        fn = function()
            -- A body swings with one arm at a time. Summing damage and magicDamage would price a
            -- mediocre hybrid above a specialist who actually hits harder, which is backwards.
            local hybrid = bare("character_knight")
            hybrid.stats.damage, hybrid.stats.magicDamage = 10, 10
            local specialist = bare("character_knight")
            specialist.stats.damage, specialist.stats.magicDamage = 16, 0

            assert(Muster.rate(specialist) > Muster.rate(hybrid),
                "16/0 hits harder than 10/10 and must rate higher")
        end,
    },
    {
        name = "the bands switch exactly on their authored percents",
        fn = function()
            assert(Muster.band(39.9) == "above3", "just under 40 is far above you")
            assert(Muster.band(40) == "above2", "40 is the floor of two steps above")
            assert(Muster.band(59.9) == "above2")
            assert(Muster.band(60) == "above1", "60 is the floor of one step above")
            assert(Muster.band(84.9) == "above1")
            assert(Muster.band(85) == "even", "85 is the floor of an even fight")
            assert(Muster.band(199.9) == "even", "and being ahead is still an even fight to plan for")
            assert(Muster.band(200) == "beneath", "200 is the floor of beneath you")
            assert(Muster.band(1000) == "beneath", "and nothing sits above it")
        end,
    },
    {
        name = "pips count the steps a fight stands ABOVE the company, and only those",
        fn = function()
            -- The count used to be the authored tier -- the same three dots whether the company walked
            -- in naked or fully forged, which is a fact about the encounter table and not about the
            -- run. What a marker has to answer is "how far above me is this", so that is what it counts.
            assert(Muster.stepsAbove(250) == 0, "a fight beneath you draws no pips")
            assert(Muster.stepsAbove(100) == 0, "and neither does an even one -- the COLOUR says it")
            assert(Muster.stepsAbove(70) == 1, "one step above draws one")
            assert(Muster.stepsAbove(50) == 2)
            assert(Muster.stepsAbove(20) == 3, "and far above draws the full three")
            assert(Muster.stepsAbove(nil) == 0, "no reading draws nothing rather than raising")

            -- Every band has to have an answer, or a marker silently draws none.
            for _, entry in ipairs(Muster.BANDS) do
                assert(Muster.PIPS[entry.name], entry.name .. " has no pip count")
                assert(Muster.BAND_LABEL[entry.name], entry.name .. " has no label")
            end
        end,
    },
    {
        name = "the walk-over gate is the floor of the top band",
        fn = function()
            -- The marker that goes calm and the option that appears are ONE fact. If these two ever
            -- disagree, a marker promises a walkover the encounter then refuses to offer.
            local top = Muster.BANDS[#Muster.BANDS]
            assert(top.name == "beneath", "the top band is the beneath-you one")
            assert(Muster.WALK_OVER == top.min,
                "WALK_OVER and the top band's floor must be the same number")

            assert(Muster.canWalkOver(Muster.WALK_OVER), "exactly at the gate is a walkover")
            assert(not Muster.canWalkOver(Muster.WALK_OVER - 0.1), "a hair under is not")
            assert(not Muster.canWalkOver(nil), "no reading is not a walkover")
        end,
    },
    {
        name = "a fight worth nothing has no reading rather than an infinite one",
        fn = function()
            assert(Muster.margin(500, 0) == nil, "dividing by an empty far side reads nil")
            assert(Muster.band(Muster.margin(500, 0)) == nil, "and nil margin draws no band")
            assert(Muster.rate(nil) == 0, "no body is worth nothing, not an error")
        end,
    },
    {
        name = "the fielded four are the ones deployed last fight, topped up from the roster",
        fn = function()
            local roster = {
                bare("character_knight"), bare("character_mage"), bare("character_archer"),
                bare("character_priest"), bare("character_bandit"),
            }
            -- Two who fought last time, sitting at the BACK of the roster: the pick must be by
            -- deployment history, not by roster order.
            local player = {
                roster = roster,
                lastDeployed = { "character_bandit", "character_priest" },
            }

            local picked = Muster.fielded(player)
            assert(#picked == Player.MAX_FIELD,
                "the field holds " .. Player.MAX_FIELD .. ", got " .. #picked)
            assert(picked[1].id == "character_priest", "deployed members come first, in roster order")
            assert(picked[2].id == "character_bandit")
            assert(picked[3].id == "character_knight", "then the roster tops the field up")
            assert(picked[4].id == "character_mage")
        end,
    },
    {
        name = "a company smaller than the field rates every body it has",
        fn = function()
            local player = { roster = { bare("character_knight") }, lastDeployed = {} }
            assert(#Muster.fielded(player) == 1, "one body is a company of one, not a crash")
            assert(Muster.company(Muster.fielded(player)) > 0)
            assert(#Muster.fielded(nil) == 0, "and no player fields nobody")
        end,
    },
    {
        name = "an encounter is rated by the bodies it will actually spawn",
        fn = function()
            local def = Encounter.get("encounter_wolf")
            assert(def, "the wolf pack is still an encounter")

            local small = Muster.encounter(def, { prestige = 1 })
            local large = Muster.encounter(def, { prestige = 8 })
            assert(small > 0, "a pack of wolves is worth something")
            assert(large > small, "the pack grows with prestige and the rating grows with it")
        end,
    },
    {
        name = "an encounter's rating is capped where the arena caps its bodies",
        fn = function()
            -- Compositions grow off prestige without bound (Arena.ENEMY_CAP's comment); Arena.build
            -- clamps them before anything spawns. A rating that skipped the clamp would price a fight
            -- at seventy wolves the board will only ever field nine of, and every late-game marker
            -- would read as hopeless.
            local def = Encounter.get("encounter_wolf")
            local ctx = { prestige = 200 }
            local raw = Arena.resolveComposition(def.composition, ctx)
            -- The cap is derived exactly as the real fight derives it, KIND INCLUDED. Reading it any
            -- other way here would let this case pass while the marker and the board disagreed, which
            -- is the one thing it exists to prevent. A wolf pack is an ordinary road stop, so it caps
            -- at the skirmish tier rather than the old flat nine.
            local cap = Arena.enemyCap({ quest = ctx.quest, encounterKind = def.kind })
            local clamped = Arena.clampComposition(raw, cap)
            assert(cap == Arena.SKIRMISH_CAP, "an ordinary road fight is a skirmish, not a set-piece")
            assert(#raw > #clamped, "at prestige 200 the pack is bigger than the board will field")
            assert(#clamped <= cap, "and it clamps to the cap")

            -- Rate the clamped list by hand and demand the same answer: what the pip prices is the
            -- bodies that will stand on the board, not the composition the formula asked for.
            local Growth = require("models.growth")
            local byHand = 0
            for _, id in ipairs(clamped) do
                byHand = byHand + Muster.rate(Growth.spawn(id, Growth.levelForPrestige(200), nil))
            end
            assert(Muster.encounter(def, ctx) == byHand,
                "the rating is the clamped list's, not the raw composition's")
        end,
    },
    {
        name = "a missing encounter rates nothing rather than raising",
        fn = function()
            assert(Muster.encounter(nil, { prestige = 1 }) == 0)
            assert(Muster.encounter({ composition = {} }, { prestige = 1 }) == 0,
                "an empty composition is worth zero")
        end,
    },
}
