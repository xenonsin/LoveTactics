-- MEALS: one supper, bought before the road, felt by the whole company for the whole quest.
--
-- This is the Cafe's entire offer (data/vendors/cafe.lua). It used to be the general store; it sells
-- food now, and food is deliberately NOT an item -- nobody carries it, nobody equips it, no slot is
-- spent on it and the Forge never touches it. A meal is a standing rule about the party, held on the
-- player between the hub and the end of the quest.
--
-- THE ONE-RATION RULE. You may hold exactly one meal at a time (`player.meal`). Buying is refused
-- while one is held (Meal.canEat), and the held meal is eaten up by the quest it was bought for --
-- cleared by Quest.complete, at the objective. So the decision is once per quest, made before you know
-- the ground: it is a wager on what the run will ask for, not a knob you retune between fights.
--
-- A run that ENDS ANY OTHER WAY -- a wipe, a walk-out -- keeps it, because states/game.lua's rollback
-- puts the company back exactly as it marched in and the supper is part of that company. The gold is
-- refunded by the same rollback, so this is not generosity, it is the extraction rule already written:
-- a run only banks (and only spends) through the objective.
--
-- Borrowed, openly, from Monster Hunter's canteen. Three things came across and one deliberately did
-- not:
--   * A PLATTER IS TWO HALVES -- a `bonus` (the courses: flat stats every member eats) and a `skill`
--     (the Felyne skill: one named rule, and the reason to pick this dish over a bigger number).
--   * IT IS A PRE-HUNT DECISION, spent on the way out and not re-rollable in the field.
--   * THE MENU GROWS, gated on `unlockPrestige` the way the city's own buildings are -- a kitchen that
--     offered its best platter on day one would only ever be ordered from once.
--   * WHAT DID NOT COME ACROSS is the ingredient minigame and the activation chance. A buff that
--     sometimes does not happen is unreadable on a board where every other number is exact, and MH can
--     afford it because a hunt is fifty minutes of continuous feedback. A quest is four fights of
--     arithmetic. Ours always fires.
--
-- HOW IT REACHES THE BOARD. Battle setup stamps the held meal's blueprint onto every party unit as
-- `unit.meal` (states/battle.lua), exactly as it stamps a relic's traits, and two places read it:
--   * models/combat.lua's applyUnitPassives folds `bonus` / `maxBonus` / `resist` in beside the grid's
--     -- so a meal's defense is the same quantity a coat's is, and the tooltips need no new case;
--   * models/trait.lua's Trait.attach instantiates `traits` (the kitchen skill) item-less, exactly as
--     it does a relic's.
-- Nothing about a meal survives the battle: `unit.bonus` is rebuilt from scratch every setup, so the
-- supper is re-eaten at each bell of the quest and never compounds.
--
-- Headless-safe (a plain registry load, no love.graphics), like every other model here.

local Registry = require("models.registry")

local Meal = {}

Meal.defs = Registry.load("data/meals", "data.meals")

function Meal.get(id)
    return id and Meal.defs[id]
end

-- The menu, cheapest first, as the panel wants it: { id, def, locked }. Everything the kitchen can
-- ever cook is listed -- a dish the city has not grown into yet comes back `locked`, greyed rather
-- than hidden, for the same reason a vendor's quest-gated rows are (seeing the rest of the menu is
-- the point). `prestige` is the player's; nil reads as the opening rank.
function Meal.menu(prestige)
    prestige = prestige or 1
    local out = {}
    for id, def in pairs(Meal.defs) do
        out[#out + 1] = { id = id, def = def, locked = prestige < (def.unlockPrestige or 1) }
    end
    table.sort(out, function(a, b)
        local pa, pb = a.def.unlockPrestige or 1, b.def.unlockPrestige or 1
        if pa ~= pb then return pa < pb end
        if a.def.price ~= b.def.price then return a.def.price < b.def.price end
        return a.def.name < b.def.name
    end)
    return out
end

-- ---------------------------------------------------------------------------
-- The one ration
-- ---------------------------------------------------------------------------

-- The meal blueprint the company is currently running on, or nil if nobody has eaten. `player.meal`
-- stores the bare id (that is what the save round-trips), so this is the one place it is resolved --
-- and an id that vanished from data/ reads as "nobody ate" rather than crashing a load.
function Meal.held(player)
    return player and Meal.get(player.meal)
end

-- Why this player cannot order `id` right now, or nil when they can. Returns a REASON rather than a
-- bare false so the panel can say which of the four it is on the row itself, instead of greying a
-- button and leaving the player to guess.
--
-- The held platter gets its own wording. "You have already eaten" is true of it and useless against
-- it: pointed at the very dish on the table it reads as a second refusal rather than as an answer, and
-- the player is left wondering what they ate. Worded here rather than in the panel so every surface
-- says the same thing.
function Meal.blockReason(player, id, prestige)
    local def = Meal.get(id)
    if not (player and def) then return "nothing on the menu" end
    if player.meal == id then return "this is what the company is eating" end
    if player.meal then return "you have already eaten" end
    if (prestige or player.prestige or 1) < (def.unlockPrestige or 1) then return "not on the menu yet" end
    if (player.gold or 0) < (def.price or 0) then return "not enough gold" end
    return nil
end

function Meal.canEat(player, id, prestige)
    return Meal.blockReason(player, id, prestige) == nil
end

-- Buy and eat `id`: charge the gold and hold the meal. Returns true, or false plus the reason it was
-- refused -- callers branch on this rather than pre-checking, the same contract Player.spendGold has.
-- Persistence is the caller's job (the panel saves once, after the whole transaction).
function Meal.eat(player, id, prestige)
    local why = Meal.blockReason(player, id, prestige)
    if why then return false, why end
    local def = Meal.get(id)
    player.gold = (player.gold or 0) - (def.price or 0)
    player.meal = id
    return true
end

-- The meal is eaten up. Called by Quest.complete, and by nothing else: a run that ends without the
-- objective is rolled back whole (states/game.lua), supper and gold together, so there is nothing to
-- clear on that path -- see the one-ration rule in this file's header.
function Meal.clear(player)
    if player then player.meal = nil end
end

-- ---------------------------------------------------------------------------
-- What the board reads
-- ---------------------------------------------------------------------------

-- The one line a UI quotes for a meal: "Courses" (its flat stats, in the model's own words) joined
-- with its skill's name. Kept here rather than in the panel so the hub strip, the Cafe menu and the
-- battle's own readout cannot word the same platter three ways.
--
-- Stat labels are the ones every other surface already uses, so a meal's +2 defense reads as the same
-- quantity as a coat's.
local STAT_LABEL = {
    damage = "Damage", magicDamage = "Magic Damage",
    defense = "Defense", magicDefense = "Magic Defense",
    speed = "Speed", movement = "Movement", accuracy = "Accuracy",
    health = "Max Health", mana = "Max Mana", stamina = "Max Stamina",
}
local STAT_ORDER = {
    "damage", "magicDamage", "defense", "magicDefense",
    "health", "mana", "stamina", "speed", "movement", "accuracy",
}

-- The courses of `def` as display strings ("+2 Defense"), in a fixed order so the same platter reads
-- the same way every time. `maxBonus` entries are named "Max Health" and friends by the table above,
-- which is why the two blocks can share one list without ambiguity.
function Meal.courses(def)
    if not def then return {} end
    local out = {}
    for _, stat in ipairs(STAT_ORDER) do
        local v = (def.bonus and def.bonus[stat]) or (def.maxBonus and def.maxBonus[stat])
        if v and v ~= 0 then
            out[#out + 1] = string.format("%s%d %s", v > 0 and "+" or "", v, STAT_LABEL[stat] or stat)
        end
    end
    for tag, v in pairs(def.resist or {}) do
        out[#out + 1] = string.format("%s%d vs %s", v > 0 and "+" or "", v, tag)
    end
    return out
end

-- The kitchen skill's { name, description } for `def`, or nil for a platter that is only courses.
-- Resolved off the trait registry so the dish and the rule can never describe themselves differently.
function Meal.skill(def)
    local id = def and def.skill
    if not id then return nil end
    local trait = require("models.trait").defs[id]
    if not trait then return nil end
    return { name = trait.name or id, description = trait.description }
end

-- The trait ids a meal grants each member (models/trait.lua attaches them item-less, like a relic's).
-- A list, though today every platter names at most one skill -- so a future dish that stacks two does
-- not have to change the seam that carries them.
function Meal.traits(def)
    if not (def and def.skill) then return {} end
    return { def.skill }
end

return Meal
