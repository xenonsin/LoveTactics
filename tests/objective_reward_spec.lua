-- What a cleared objective PAYS, as the victory screen reads it (Descent.objectiveReward).
--
-- The screen and the payout are two different pieces of code running one beat apart -- the panel is built
-- when the fight is decided, the grant runs when Continue is pressed -- so every case here is really the
-- same assertion twice: that the preview names exactly what the grant then hands over, and that asking
-- costs nothing. A preview that drifted from its grant would be a screen that lies about a reward, and a
-- preview that granted would be a reward paid twice.
--
-- Written against the model rather than the state on purpose: states/game.lua pulls ui/theme.lua and
-- cannot be required without a window, which is why this arithmetic was moved out of it.

local Descent = require("models.descent")
local Voucher = require("models.voucher")
local Player = require("models.player")
local Quest = require("models.quest")
local Item = require("models.item")
local Material = require("models.material")
local Vendor = require("models.vendor")

-- A run parked on `floor`, which is the only thing the reward reads off it besides the seed.
local function runAt(floor, seed)
    local run = Descent.new(Player.new(), seed or 4242)
    run.floor = floor
    return run
end

-- The first floor whose objective is a GENERAL's -- the one that pays tokens as well as a body.
local function generalFloor()
    for f = 1, Descent.FLOORS do
        if Descent.isGeneralFloor(f) and not Descent.isBottom(f) then return f end
    end
end

-- ...and one that is a lieutenant's: a body, and no tokens.
local function minorFloor()
    for f = 1, Descent.FLOORS do
        if not Descent.isGeneralFloor(f) and not Descent.isBottom(f) then return f end
    end
end

return {
    { name = "a floor's token count can be asked without being paid", fn = function()
        local player = Player.new()
        local floor = generalFloor()
        local n = Voucher.forFloor(floor)
        assert(n > 0, "a general's floor pays tokens")
        assert(Voucher.count(player) == 0, "asking must not grant")
        -- The preview and the grant are the same number by construction, not by coincidence: this is the
        -- assertion that keeps them that way if either constant moves.
        assert(Voucher.grantForFloor(player, floor) == n,
            "the grant pays exactly what the preview named")
        assert(Voucher.count(player) == n, "...and the purse holds it")
        assert(Voucher.forFloor(minorFloor()) == 0, "a lieutenant's floor pays none")
    end },

    { name = "a guardian's reward names her own piece, and takes nothing", fn = function()
        local player = Player.new()
        local floor = generalFloor()
        local run = runAt(floor)
        local sin = Descent.sinAt(run, floor)
        assert(sin, "a floor above the bottom stands in a circle")

        local out = Descent.objectiveReward(player, run, nil)
        assert(out, "a stair guardian pays something")
        assert(#out.items == 1, "one body, one piece")
        assert(out.items[1] == Descent.dropFor(player, sin, true),
            "and it is the piece the grant would have handed over")
        assert(Item.defs[out.items[1]], "which is a real item")
        assert(out.vouchers == Voucher.forFloor(floor), "the circle's tokens ride along")

        -- THE WHOLE POINT OF THE SPLIT: previewing is not taking. Nothing above may have moved the player.
        assert(#(player.stash or {}) == 0, "the piece is not in the stash yet")
        assert(Voucher.count(player) == 0, "and no token has been paid")
        assert((player.gold or 0) == Player.new().gold, "and the purse is untouched")
    end },

    { name = "a stripped circle falls back to the house's stock, exactly as the landing does", fn = function()
        local player = Player.new()
        local floor = generalFloor()
        local run = runAt(floor)
        local sin = Descent.sinAt(run, floor)

        -- Hand the player everything that circle's general has to give, which is the second-playthrough
        -- case Descent.DROPS is written to survive.
        for _, id in ipairs((Descent.DROPS[sin.id] or {}).general or {}) do
            Player.addToStash(player, Item.instantiate(id))
        end
        assert(Descent.dropFor(player, sin, true) == nil, "nothing of hers is left")

        local out = Descent.objectiveReward(player, run, nil)
        assert(out and #out.items == 0, "so no piece is named")
        local houseMat = Material.houseFor((Vendor.get(sin.vendor) or {}).class)
        if houseMat then
            assert(out.materials[houseMat] == Descent.SPENT_SET_STOCK,
                "the house pays its own stock instead")
        else
            assert(out.gold > 0, "...or gold, when the house bills in no material")
        end
    end },

    { name = "an errand names its purse and its goods, and only while it is unfinished", fn = function()
        local player = Player.new()
        local run = runAt(minorFloor())

        -- Any errand-shaped quest def with something to pay. Found rather than hardcoded: the errand pool
        -- is the parked board's seventy blueprints and naming one here would rot the moment it is retired.
        local id, def
        for qid, d in pairs(Quest.defs) do
            if (d.rewardGold or 0) > 0 or #(d.rewardItems or {}) > 0 then id, def = qid, d break end
        end
        assert(id, "the board has at least one quest that pays")

        local out = Descent.objectiveReward(player, run, { questId = id })
        assert(out, "an unfinished errand pays")
        assert(out.gold == (def.rewardGold or 0), "its purse is the def's, not a roll")
        assert(#out.items == #(def.rewardItems or {}), "and every authored good is named")
        assert(out.vouchers == 0, "an errand is not a circle and pays no tokens")

        -- The same guard Errand.complete keeps as its first line: a cleared tile is worth nothing twice.
        player.completedQuests = { [id] = true }
        assert(Descent.objectiveReward(player, run, { questId = id }) == nil,
            "a finished errand names nothing, so a re-cleared end cannot advertise a second payout")
    end },

    { name = "the awarded half is never the granted half", fn = function()
        -- states/battle.lua hangs this table off `spoils.awarded`, and states/game.lua's grantSideSpoils
        -- iterates `spoils.loot`. They must not be the same list: everything here has already been paid by
        -- the branch that runs after the panel closes, so an id appearing in both is an item handed over
        -- twice. This pins the shape the two sides agreed on.
        -- EncounterBattle.spoils is the seam that makes an objective pay salvage and nothing else -- NOT
        -- Spoils.roll, which knows only combat and elite and would happily roll a purse for either.
        local EB = require("models.encounter_battle")
        local paid = EB.spoils({
            encounter = { kind = "objective", tier = 1 }, enemyUnits = {}, day = 4,
        })
        assert(paid, "an objective fight still pays")
        assert(#(paid.loot or {}) == 0, "an objective rolls no loot of its own")
        assert((paid.gold or 0) == 0, "and no gold -- both are the objective's to pay, not the roll's")
        assert(paid.awarded == nil, "the roll never invents this field; the battle state attaches it")
        assert(next(paid.materials or {}) ~= nil, "but the salvage floor still stands under it")
    end },
}
