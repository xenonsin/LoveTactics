-- A DRYAD: the alpha of the Dryad line, and the druid's GROWING magic -- the half of the druid the
-- wild shapes on the shelf are not.
--
-- SHE KEEPS THE NYMPH'S PLANTING, STEP AND LIGHT, and brings the grove's four spells:
--
--   Thorn Whip  a vine lash to three tiles that hauls its catch to her (weapon_thorn_whip).
--   Briarfloor  thorn ground around a foe that bills every tile crossed, walked OR thrown
--               (hazard_briarfloor -- a forced step enters a tile like any other, so a slide bites
--               once per tile).
--   Quickset    a three-tile hedge across the lane behind a foe (data/walls/hedge.lua).
--   Barkskin    the next physical blow on an ally glances (status_physical_barrier).
--
-- EVERY ONE OF THEM MAKES A SHOVE WORTH MORE, and that is the argument for her half of the circle.
-- Combat.knockback bills the impact of the tiles a shove could not spend, and on an open board most
-- shoves spend all of theirs; she grows the hedge behind you and the thorns under you, and the flock
-- does the throwing. She takes away the circle's own best answer -- stand in open ground -- by growing
-- ground that is not open.
--
-- Tier 2's band is 31-80 health (Balance.HEALTH_BANDS).
return {
    name = "Dryad",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/dryad.png",
    archetype = "skirmish",
    stats = {
        health = 58, mana = 52, stamina = 14,
        staminaRegen = 2,
        damage = 8, magicDamage = 12,
        defense = 6, magicDefense = 9,
        movement = 4,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 7,
    },
    -- Green wood at a tier's budget (docs/bestiary.md): an edge turns, a maul splits it, and it burns.
    resist = { slash = 3, impact = -3, fire = -4, holy = -3 },
    startingItems = { "weapon_thorn_whip", "weapon_briarfloor", "weapon_quickset", "weapon_barkskin",
                      "weapon_mistlight", "weapon_seedfall", "weapon_greenstep" },
    -- WHAT SHE IS KNOWN FOR (docs/drops.md), rarest first: the thorn floor, the lash and the hedge, which
    -- stock the druid shelf's growing half once found; then the Nymph's light, so a company that holds
    -- all three is paid rather than refused.
    drops = {
        "ability_briarfloor",
        "ability_thorn_whip",
        "ability_quickset",
        "ability_mistlight",
    },
    defaultAction = "weapon_thorn_whip",
    ai = {
        { priority = "high", act = "attack", item = "weapon_briarfloor", targetPref = "nearest",
          when = { subject = "any_foe", test = "within", value = 4 } },
        { priority = "normal", act = "attack", item = "weapon_thorn_whip", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "within", value = 3 } },
    },
}
