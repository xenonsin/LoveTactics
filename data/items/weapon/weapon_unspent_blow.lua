-- A hammer, so it stuns (docs/weapons.md) -- except that it does not, most of the time. It BANKS instead:
-- each swing puts a stun by rather than landing one, and the third swing spends all three at once for a
-- blow that lands `raw` (no defense, no resist) with a stun to match.
--
-- Quest-only: `class` with no `price`.
--
-- What it sells is the one thing the family cannot otherwise offer: a hammer blow that armour has nothing
-- to say about. Every other hammer here is a big physical number aimed at the stat heavy infantry stack
-- highest, and the harder the target, the worse the trade. This one saves three turns' worth of tempo and
-- cashes it as a hit that simply ignores the question.
--
-- Three swings is a long time and that is the design. The first two are genuinely weak -- no stun, poor
-- damage -- so carrying this is a bet that the fight will last long enough to collect. Against a warband
-- it never pays. Against the thing at the end of a quest, it is the fighter's answer.
--
-- The count lives on the UNIT (`fx.user.unspentBlows`), not on the item, for the reason
-- data/items/weapon/weapon_marching_standard.lua gives about its standard: an item field would survive
-- into the next battle and the hammer would open a fresh fight already loaded. A battle-scoped fact
-- belongs on the battle-scoped object.
local Curve = require("models.curve")

return {
    name = "The Unspent Blow",
    description = "Holds its stun back. Every third swing spends all three at once. Unblockable, and armour cannot turn it.",
    flavor = "It is not that he is not hitting you. It is that he has not decided to yet.",
    sprite = "assets/items/unspent_blow.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2,
    class = "fighter",
    dropTier = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7,
        cost = { stat = "stamina", amount = 12 },
        -- Read this as the BANKING number: it is what the first two swings land. The third is worth three
        -- of them and ignores armour, which is where the weapon's actual output lives.
        damage = Curve.ramp(12, 22),
        -- How many blows are being held, on the slot badge and in the tooltip. It used to say so only in
        -- the combat log, which meant the one number this weapon is entirely about scrolled away: a
        -- player looking at the hammer could not tell a first swing from the one that lands triple and
        -- unblockable, and had to have been counting. Everything that accrues quotes its count.
        --
        -- `counterGates = false`: a held count of 0 is a fresh hammer, not a spent purse. The first
        -- swing is a real swing, so an empty count must never grey the slot out (cf. the Long Count).
        counter = function(unit) return (unit and unit.unspentBlows) or 0 end,
        counterLabel = "Held",
        counterGates = false,
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local held = (fx.user.unspentBlows or 0) + 1
            if held < 3 then
                fx.bank("unspentBlows", held) -- banked, not assigned: a raw write would tick on every hover
                fx.damage(t) -- an ordinary, unremarkable, un-stunning hit
                fx.log("action", string.format("%s holds the blow (%d/3).",
                    (fx.user.char and fx.user.char.name) or "Unit", held))
                return
            end
            fx.bank("unspentBlows", 0)
            -- Everything at once. `raw` skips defense and every tag resist (docs/weapons.md), which is
            -- what three turns of patience is actually buying -- and the stun is a full one on top.
            fx.damage(t, {
                amount = (fx.amount or 0) * 3,
                raw = true, -- the flag Combat.mitigatedDamage reads, as weapon_mailpiercer's line does
                inflicts = { id = "status_stun", magnitude = 9 },
            })
            fx.log("action", string.format("%s spends all three.",
                (fx.user.char and fx.user.char.name) or "Unit"))
        end,
    },
}
