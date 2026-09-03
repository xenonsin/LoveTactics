-- Reviving Salts: the party's own answer to a fallen body, without a priest on the field. A pinch of
-- alchemical salts burned under the nose of the downed jolts them back to their feet where they lie --
-- the SAME character, its kit intact -- at a sliver of health. It is the accessible half of the downed
-- window (data/status/status_downed.lua): the Revive spell and its scroll are the priest's craft and
-- the priest's price, and this is what an ordinary company carries so a fall is answerable from the
-- very first fight.
--
-- Aim at the body's tile (a felled ally lies incapacitated on the field; you cannot target it as a
-- unit). It works only on an ALLY's body, only while no one stands on the tile, and only while the
-- downed window is still open -- a body that has already gone cold (turned to a corpse) is past salts
-- and past miracles alike (Combat.reanimate refuses it). A support cast, so its cursor previews green.
--
-- 25% health, deliberately low: this is a scramble to get a body back on the board before the count
-- runs out, not a heal. What you revive is fragile, and a second blow will put it right back down --
-- so a save still has to be followed by a rescue. The Alchemist's shelf, one rep rank above the
-- healing potion it sits beside (docs/classes.md).
local Curve = require("models.curve")

return {
    name = "Reviving Salts",
    description = "Revives an adjacent fallen ally at low health, while its body can still be saved.",
    flavor = "The Alchemist swears they wake the dead. The Alchemist is, as ever, exaggerating, but only just.",
    sprite = "assets/items/reviving_salts.png",
    type = "consumable",
    tags = { "salts", "restorative" },
    class = "alchemist",
    price = 265,
    unlockQuests = 7,
    activeAbility = {
        target = "tile",
        support = true, -- friendly cast: preview green
        range = 1,      -- must stand beside the body
        reviveHealth = Curve.ramp(25, 45), -- percent of health restored (a sliver, on purpose)
        speed = 3,
        consumesItem = true,
        effect = function(fx)
            local body = fx.downedAt(fx.tx, fx.ty)
            -- Only an ally's INCAPACITATED body, and only if nobody stands on it (fx.downedAt already
            -- refuses an occupied tile). fx.amount is a percent; reanimate takes it as a fraction of max
            -- HP, and itself refuses a body gone cold or one that never comes back.
            if body and body.side == fx.user.side then
                fx.reanimate(body, (fx.amount or 25) / 100)
            end
        end,
    },
}
