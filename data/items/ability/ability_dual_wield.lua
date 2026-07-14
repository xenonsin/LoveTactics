-- Dual Wield: swing the weapons sitting beside this ability in the 3x3 item grid, all at one foe. Each
-- adjacent melee weapon strikes with ITS OWN blow -- its damage, its tags, its on-hit effect (a poison,
-- a stun) -- through Combat.strikeWith, and the action bills the SUMMED speed of everything it swung
-- (fx.setSpeed): two fast daggers cost little tempo, a pair of mauls a great deal.
--
-- It needs at least two qualifying weapons beside it to fire (ab.usable gates it, graying the slot
-- until then). Forging widens what counts:
--   * base (+0..4): up to two adjacent ONE-handed melee weapons.
--   * +5: two-handed melee weapons (greataxe / war hammer / spear -- data `hands = 2`) also qualify.
--   * +10: swing up to THREE weapons instead of two.
-- The rogue's arsenal answer: a grid built around this hits like everything in it at once.
local MELEE_TAG = "melee"

-- Is `it` a melee weapon Dual Wield can swing at upgrade `level`? One-handed weapons always count;
-- two-handed ones (data `hands = 2`) only once the item is forged to +5.
local function qualifies(it, level)
    if not it or it.type ~= "weapon" then return false end
    local melee = false
    for _, t in ipairs(it.tags or {}) do
        if t == MELEE_TAG then melee = true break end
    end
    if not melee then return false end
    if (it.hands or 1) >= 2 and (level or 0) < 5 then return false end
    return true
end

-- The weapons a Dual Wield strike will swing: qualifying melee weapons adjacent to `item` in `char`'s
-- grid, in grid order, capped at two (three once forged to +10). Shared by the usability gate and the
-- effect so the greyed slot and the live cast can never disagree on what qualifies.
local function armory(char, item)
    -- Lazy require (not at load time): the item registry loads this data file WHILE models.character is
    -- still loading, so a top-level require would be a cycle. Mirrors the trait files' pattern.
    local Character = require("models.character")
    local level = item and item.level or 0
    local cap = (level >= 10) and 3 or 2
    local out = {}
    local idx = char and Character.slotIndex(char, item)
    if not idx then return out end
    for _, nb in ipairs(Character.adjacentItems(char, idx)) do
        if qualifies(nb, level) then
            out[#out + 1] = nb
            if #out >= cap then break end
        end
    end
    return out
end

-- The initiative a swing of `weapons` bills: their ability speeds added together.
local function swingSpeed(weapons)
    local s = 0
    for _, w in ipairs(weapons) do s = s + ((w.activeAbility and w.activeAbility.speed) or 0) end
    return s
end

return {
    name = "Dual Wield",
    description = "Swing two adjacent melee weapons at one foe -- each its own blow. Speed cost is theirs, summed.",
    sprite = "assets/items/ability_dual_wield.png",
    type = "ability",
    tags = { "guile", "physical" },
    class = "rogue",
    price = 360,
    repRank = 3,
    activeAbility = {
        name = "Dual Wield",
        target = "enemy",
        range = 1,
        speed = 4, -- nominal, for the initiative average only; the real cost is the summed weapon speeds
        cost = { stat = "stamina", amount = 6 },
        -- Gate: at least two qualifying weapons must sit beside it (see armory / qualifies).
        usable = function(unit, item)
            if #armory(unit.char, item) >= 2 then return true end
            return false, "needs two adjacent melee weapons"
        end,
        -- Draw the grid connector lines only to the weapons this cast will actually swing (the capped,
        -- level-qualified set), not to every adjacent weapon (Combat.adjacencyLinks reads this).
        adjacencyUses = function(char, item) return armory(char, item) end,
        -- The live turn cost the timeline previews: the summed speed of the weapons it will swing, so the
        -- ghost slot matches what the effect bills through fx.setSpeed. Falls back to the nominal `speed`
        -- when it isn't armed (fewer than two weapons), which is all the greyed slot can promise anyway.
        speedPreview = function(unit, item)
            local weapons = armory(unit.char, item)
            if #weapons >= 2 then return swingSpeed(weapons) end
            return item.activeAbility.speed
        end,
        effect = function(fx)
            local weapons = armory(fx.user.char, fx.item)
            if #weapons < 2 then return end -- `usable` already gates this; stay safe on a direct call
            for _, w in ipairs(weapons) do fx.strikeWith(w) end
            fx.setSpeed(swingSpeed(weapons)) -- the whole flurry costs the weapons' speeds added together
        end,
    },
}
