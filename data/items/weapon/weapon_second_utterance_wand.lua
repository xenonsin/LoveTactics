-- A wand, so it strikes at range and needs only a direction (docs/weapons.md). Its extra is that the shot
-- BUYS ITS CASTER A FREE CHANNEL: the bolt lands, and the mage is left holding status_second_utterance --
-- their next channelled working resolves AT ONCE, with no draw at all.
--
-- Quest-only: `class` with no `price`.
--
-- The third of the Arcanum's quest wands, with data/items/weapon/weapon_sealed_ward_wand.lua and
-- data/items/weapon/weapon_reflecting_wand.lua; the note at the top of the Sealed Ward wand explains why
-- all three pay their own caster. Those two buy defence off an attack. This one buys TEMPO, which makes it
-- the one that changes what the mage does next rather than what survives.
--
-- What it is worth. Every channelled thing in this game is priced the same way and always draws the same
-- objection: you commit a turn, the enemy sees it, and they walk out of the aimed tile or break the channel
-- outright. That objection is what a greatsword, a longbow and half the Arcanum's spell list all pay. This
-- deletes it -- once, for the caster, and only if the caster spent a turn attacking to earn it. The rhythm
-- it wants is bolt, then Meteor Storm with no telegraph at all, which is two turns of work for one
-- unanswerable one.
--
-- It used to be aimed at an ALLY and dealt nothing, which docs/weapons.md carried a ⚠️ against: a weapon
-- pointed at your own side is not a weapon, and its damage has no honest number when the honest number
-- would wound the friend it is aimed at (Balance.gradesOnMagnitude).
--
-- THREE THINGS NOW GRANT THIS AND ALL THREE ARE DIFFERENT PURCHASES, which is worth being precise about
-- because the id says "second utterance" three times over:
--
--   utility_second_utterance   a passive charm. Banks a charge every time a channel of the BEARER'S lands,
--                              so it rewards a mage who already got one through -- the hardest thing the
--                              shelf asks. Nothing is spent to arm it and nothing can be aimed with it.
--   ability_second_utterance   a cast, and it goes to SOMEBODY ELSE. Hands a greatswordsman an
--                              untelegraphed Avalanche. Costs a whole slow turn (speed 8, 22 mana).
--   this wand                  takes it for ITSELF, off an attack, asking nothing first. The only one of
--                              the three that arms the free cast on a turn the mage also spent hurting
--                              somebody -- and the only one that cannot give it away.
local Curve = require("models.curve")

return {
    name = "Wand of the Second Utterance",
    description = "The bolt leaves its caster holding Second Utterance.",
    flavor = "Saying it once was always enough. The Arcanum spent four hundred years finding out who had to say it.",
    sprite = "assets/items/second_utterance_wand.png",
    type = "weapon",
    tags = { "wand", "magical", "arcane", "ranged" },
    class = "mage",
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 11 }, -- the deleted telegraph is the dearest of the three riders
        -- Its slot's number, which at slot 0 is the plain wand's exactly (Balance.slotTarget): same
        -- family, same slot, same magnitude, and the free channel is what tells them apart.
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            fx.damage(fx.target)
            -- On the CASTER. Ten ticks against the status's own twelve -- long enough that the very next
            -- working is the one it pays for, short enough that it cannot be banked across the fight
            -- waiting for the perfect cast. Holding it is not the plan; spending it is.
            fx.applyStatus(fx.user, "status_second_utterance", { duration = 10 })
        end,
    },
}
