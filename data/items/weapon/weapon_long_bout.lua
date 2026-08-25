-- Elio's bound relic (Duelist), and THE ONE WEAPON on the hall's roster.
--
-- IT NEVER GATES, and that is not a favour -- it is the rule. A greyed armour slot costs its bearer an
-- option; a greyed weapon slot costs them the thing a weapon is FOR, and a repeatable gate would leave
-- the blade dead at the open of every fight and again after every use. So the count here is a READOUT
-- (`counter` with `counterGates = false`, the pair weapon_borrowed_time and weapon_long_count wear):
-- the slot draws the tally, the blade always swings, and the number only decides how hard.
--
-- THE TALLY IS `repeatStrike` -- the same body hit twice running, banked by the engine on every
-- damaging blow. That is the duel stated mechanically: it climbs while he stays on one person and it
-- is worth nothing the moment he does not. En Garde and Reading the Blade bank the same streak,
-- Main-Gauche banks on parries, and Duelist's Poise pays the whole time he is locked one-to-one.
--
-- Coup Droit competes for the same Tempo, and that competition is the build's actual decision: spend
-- the streak on the shelf's burst, or keep it here and let the blade get heavier.
local Curve = require("models.curve")

return {
    name = "The Long Bout",
    description = "A duelling blade whose blow grows with every turn spent on the same body.",
    flavor = "Everybody else on the field is weather. He has been having one conversation all day.",
    sprite = "assets/items/sig_long_bout.png",
    type = "weapon",
    tags = { "signature", "sword", "slash", "physical" },
    class = "fighter",
    discipline = "duelist",
    -- Swords parry (docs/weapons.md), and a duellist's above all: the family contract is that a blade
    -- answers a melee blow, and Main-Gauche on the same shelf banks Tempo off exactly those parries.
    -- A duelling sword that could not answer would be the one sword in the game that does not duel.
    traits = { "trait_parry" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 7 },
        --        level:  0  1  2  3  4  5  6  7   8   9  10
        damage = Curve.ramp(14, 28),
        description = "Damage climbs 15% per consecutive strike on the same body.",
        -- The streak made visible, so he can watch the bout get heavier rather than doing the
        -- arithmetic. Same tally the effect reads, so badge and blade can never disagree.
        counter = function(unit)
            return unit and require("models.combat").tallyCount(unit, "repeatStrike") or 0
        end,
        -- A count of 0 is the first exchange, not a spent purse: the blade is a full duelling sword on
        -- turn one and simply has nothing banked yet.
        counterGates = false,
        counterLabel = "Streak",
        effect = function(fx)
            local Combat = require("models.combat")
            local streak = Combat.tallyCount(fx.user, "repeatStrike")
            fx.damage(fx.target, { amount = math.floor(fx.amount * (1 + 0.15 * streak)) })
        end,
    },
}
