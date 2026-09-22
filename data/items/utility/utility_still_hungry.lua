-- STILL HUNGRY: a mimic's gullet, prised off the hinge and carried in a pack.
--
-- ONE OBJECT, ONE SENTENCE, and the two halves are the same idea rather than a passive bolted to an
-- active: IT HOLDS WHAT YOU TAKE, AND THE FULLER IT IS THE HARDER IT BITES.
--
--   out of a fight -- `haulBonus`, six more finds on the company's carry ceiling (Descent.carryMax,
--   twenty without it). The first item in the game to touch that number, and it answers a refusal the
--   player has certainly already met: "the chest stays shut -- there is no room to carry what is in it".
--
--   in a fight -- a bite whose weight is WHAT THE COMPANY IS CARRYING RIGHT NOW (Descent.carried), the
--   same figure the stair prices its toll against (Descent.tollFor). One number, two readers, so the
--   item and the toll can never come to different answers about what "carrying" means.
--
-- WHAT THAT BUYS IS A DECISION THE DESCENT WAS ALREADY ASKING AND COULD NOT PRICE: go deeper with a
-- full bag -- dangerous, and no room for the next chest -- or hand the haul over at the stair and have
-- room to loot, with the gullet gone quiet. Nothing else in the game makes the haul matter while you
-- are standing on a board. It is also why the bite is gated on the count rather than merely scaled by
-- it (`counter`, no `counterGates = false`): an empty gullet greys out and says so, which is honest --
-- this is a rift trophy, and it is inert in a duel, a draft and the campaign's daylight.
--
-- IT DOES NOT SPEND THE HAUL. The Gleaning Rod empties itself and says a purse is not a rate; this is
-- the other kind and the difference is deliberate. Eating the company's finds would be the game
-- destroying loot in front of the player, which is the exact thing the chest code refuses to do one
-- file over (states/game.lua: a bag with no room leaves the lid SHUT rather than taking two of four).
--
-- ...AND IT IS NOT THE BAG OF HOLDING, which is worth saying out loud because the one-line summary of
-- the two is nearly the same sentence (data/items/utility/utility_bag_of_holding.lua). Pim's signature
-- is a SECOND GRID filled by theft, emptied at the gate, spent as a burst around her; this reads the
-- EXPEDITION and holds nothing of its own. Different resource, different scope, different shape --
-- hers is an area blast off her own tile, this is one mouth on one adjacent body -- and above all a
-- different decision: hers is "steal more this fight", this is "do not bank at the stair".
--
-- FILED TO THE MAMMONITE, whose whole shelf is already "a purse spent and banked as a combat resource"
-- (docs/classes.md). That is this item with gold in it. `class` is the vendor shelf and never an equip
-- gate: anyone may carry it.
--
-- NO COUNTER DEALS ONE (`unstocked`), however many the company carries out, and none will buy one back
-- (docs/drops.md, Vendor.foundPrice). It is STOCKED AND GREYED rather than absent, so a player can
-- learn at a desk that the thing exists and what it does before ever meeting a lid that bites.
--
-- WHAT `unstocked` DOES NOT MEAN, said plainly because the other fifteen trophies' headers gloss over
-- it: this is a rule about SHOPS, not about the drop pool. Carrying a `dropTier` puts a piece in the
-- band's long tail like anything else (Spoils' anyAtRank filters `bound` and `noSteal` and not this),
-- so an ordinary fight at this rank can pay one, and so, pleasingly, can a chest. That backstop is
-- one row out of a whole rank's catalogue and it does not touch the chase: the mimic is the only thing
-- in the game that pays this at a rate anybody would plan around (Mimic.TROPHY, a flat two in five).
-- HOW MUCH OF THE HAUL THE BITE MAY READ. Six, against a ceiling of twenty-six -- so the gullet is at
-- full weight about a floor and a half into a trip and the rest of the haul is simply loot.
--
-- A CAP AND NOT A CURVE, because the two halves of this item must not compound: uncapped, `haulBonus`
-- would be feeding its own damage and a company that had done nothing but not-bank for four floors
-- would be swinging for eighty. The ceiling is for carrying things out. The bite is for a fight.
local CAP = 6

-- Everything the company has found since the stair, capped. Read off Player.active because an item's
-- `counter` is handed a unit and an item and has no run in either -- the same reach models/descent.lua
-- and models/conversation.lua already take for the same reason. Nought off a descent, which is what
-- greys the cast (see `counterEmpty`).
--
-- BOTH REQUIRES ARE INSIDE THE CALL, which is this folder's standing rule rather than a style choice: a
-- data file is loaded BY models/item.lua's registry, so a model required at the top of one closes a
-- load cycle through whatever that model requires -- and in Lua 5.1 a cycle re-executes the module
-- rather than failing cleanly.
local function fullness()
    local Player = require("models.player")
    local player = Player.active
    return math.min(CAP, require("models.descent").carried(player, player and player.descentRun))
end

return {
    name = "Still Hungry",
    description = "Bites an adjacent foe for more the more your company is carrying, and holds six finds more.",
    flavor = "You fed it a company and it swallowed the chest around itself. It is still hungry.",
    sprite = "assets/items/utility_still_hungry.png",
    type = "utility",
    tags = { "charm" },
    class = "mammonite",
    unlockLevel = 1,
    unstocked = true,
    -- The half that works on the road. Six is about a floor and a half of extra trip against a twenty
    -- find ceiling -- felt on the long dive this is meant to extend, invisible on a short one.
    haulBonus = 6,
    activeAbility = {
        description = "Bites an adjacent foe, scaled by what the company is carrying.",
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        -- The purse, surfaced. One function feeds three surfaces -- the grid badge, the tooltip row and
        -- the refusal -- exactly as the Gleaning Rod's does, so what the player is told and what the
        -- blow is worth cannot drift apart.
        counter = function() return fullness() end,
        counterEmpty = "The gullet is empty -- you are carrying nothing to put behind it",
        effect = function(fx)
            local held = fullness()
            if held <= 0 then return end
            -- Per find rather than a flat blow with a bonus, because the sentence the item makes is
            -- "the fuller it is", and a floor under that would be the item hedging its own argument.
            -- `fx.level` is the forge rung, the same shape the Rod's charges are spent through.
            fx.damage(fx.target, {
                amount = held * (3 + fx.level),
                tags = { "pierce", "physical", "melee" },
            })
        end,
    },
}
