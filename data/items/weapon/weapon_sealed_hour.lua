-- A greatsword, so it winds up (docs/weapons.md). Its extra is that the wound does not arrive when the
-- blade does: the blow seals the target's hour (status_sealed_hour), and every point of damage and
-- healing that lands on that body is HELD until the seal runs out, then settles all at once.
--
-- So the greatsword's usual bargain -- a turn spent for a number nothing else matches -- is paid on a
-- delay, and the delay is the weapon. Three things fall out of it, and all three are the reason to carry
-- it rather than an iron greatsword:
--
--   * The enemy healer wastes their turn. Mending a sealed body puts nothing back; it only adds to a
--     pile that is still going to land.
--   * The kill is scheduled rather than rolled. A sealed foe that the party keeps hitting dies when the
--     hour comes due, and the player can count the ticks on the timeline before committing anything.
--   * It is the worst weapon in the game for finishing something NOW. A boss at a sliver of health does
--     not fall to this; it falls to it in four ticks, which is four ticks of the boss still acting.
--
-- That last one is the honest cost, and it is why this sits at rank 4 rather than 5: it is a stronger
-- weapon than the iron greatsword in a long fight and a strictly worse one in a short one.
return {
    name = "The Sealed Hour",
    description = "Winds up, then falls on one tile and seals the wound: all damage and healing on that foe is held, then settles at once.",
    flavor = "The blow lands on time. The consequences are filed for later.",
    sprite = "assets/items/sealed_hour.png",
    type = "weapon",
    tags = { "greatsword", "slash", "physical", "melee" },
    hands = 2,
    class = "fighter",
    price = 700,
    repRank = 4,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 7,
        channel = 2,
        cost = { stat = "stamina", amount = 16 },
        damage = { 24, 27, 29, 32, 34, 37, 39, 42, 44, 47, 50 }, -- an iron greatsword's: the seal is the extra
        effect = function(fx)
            local t = fx.target
            if not t then return end
            -- Seal FIRST, then strike: the swing's own damage should be the first thing the seal
            -- swallows, or the weapon would be an ordinary greatsword that happens to leave a debuff.
            fx.applyStatus(t, "status_sealed_hour")
            fx.damage(t)
        end,
    },
}
