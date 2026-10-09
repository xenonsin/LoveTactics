-- SABOTEUR, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A race-free
-- body fielded as `character_adv_saboteur@<race>`; `race` names the first leaning race only so the
-- blueprint loads. Built on the generic rogue (the root the exemplar walks): 8 / 3 magic.
--
-- WHAT IT DOES ON THE BOARD (The Fuse, Into the Fire): it buries charges where you are about to step and
-- fires them on a body. Set Charge leaves a hidden blast charge on the square beside a foe, which goes off
-- under whoever crosses it; the Sapper's Line buries three fused charges across the approach, and the
-- Detonator sets those off the moment one of yours stands in a blast -- and ONLY then, which is why that
-- rule is a scripted test rather than a dropdown one: a dry run of the plunger reports nobody hit, so the
-- planner cannot tell a live line from an empty one by itself. Kill it before it picks its moment.
local function aFoeOnACharge(ctx)
    for _, c in ipairs(ctx.combat.charges or {}) do
        if not c.spent and c.owner == ctx.unit.index then
            for _, u in ipairs(ctx.combat.units or {}) do
                if u.alive and u.side ~= ctx.unit.side
                    and math.max(math.abs(u.x - c.x), math.abs(u.y - c.y)) <= (c.radius or 1) then
                    return true
                end
            end
        end
    end
    return false
end

return {
    name = "Saboteur",
    race = "goblin",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/saboteur.png",
    class = "rogue",
    discipline = "saboteur",
    archetype = "skirmish",
    stats = {
        health = 54, mana = 8, stamina = 22,
        staminaRegen = 2,
        damage = 14, magicDamage = 3,
        defense = 5, magicDefense = 5,
        movement = 4,
        speed = 5,
        skill = 8, luck = 7,
    },
    startingItems = {
        "weapon_iron_dagger", "ability_set_charge", "ability_detonator",
        "consumable_sappers_line", "armor_leather_armor",
    },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon  = "weapon_iron_dagger",
    signatureAbility = "ability_set_charge",
    -- 1. Fire the line when it will catch somebody. 2. Bury the line across the approach.
    -- 3. A charge beside a foe. 4. Otherwise cut the wounded.
    ai = {
        { priority = "urgent", act = "cast", item = "ability_detonator", label = "a foe stands in a blast",
          whenFn = aFoeOnACharge },
        { priority = "high", act = "cast", item = "consumable_sappers_line",
          when = { subject = "nearest_foe", test = "within", value = 4 } },
        { priority = "high", act = "cast", item = "ability_set_charge",
          when = { subject = "any_foe", test = "within", value = 5 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
