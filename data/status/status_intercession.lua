-- Intercession: the mark of being prayed AT. A unit carrying this is the one ally an Intercessor's
-- Staff (data/items/weapon/weapon_intercessors_staff.lua) has named, and every blow that staff lands on
-- an enemy mends this body instead of its wielder's.
--
-- Purely a BADGE. It carries no hooks, no stat bonus and no clock of its own: the link itself lives on
-- the wielder (`unit.intercession`, set by data/traits/trait_intercession.lua at combat start) and the
-- healing is done by the staff's own effect. This exists so the bond is legible on the board -- without
-- it the player would watch health appear on a unit nobody targeted and have to infer the cause.
--
-- NOT a debuff, so Cure and Panacea leave it alone: cleansing the badge would not sever the link (which
-- is not stored here), and a status that can be removed without changing anything is a lie told to the
-- player. It runs to the end of the fight because the oath does.
return {
    name = "Intercession",
    abbr = "Int",
    description = "Named by an intercessor: their blows mend you.",
    color = { 0.85, 0.80, 0.55 }, -- badge tint (candle gold, the Cathedral's own)
    duration = 9999, -- answers to the battle, not a clock
}
