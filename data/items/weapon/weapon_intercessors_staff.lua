-- The Cathedral's third focus, and the only healer in the game that heals by ATTACKING.
--
-- A staff, so it owes the family's Focus swap (docs/weapons.md) -- end the turn to recover mana instead
-- of striking. What it adds over data/items/weapon/weapon_staff.lua is where its damage GOES: the trait
-- it carries names one ally at the start of battle (data/traits/trait_intercession.lua), and from then
-- on every blow this staff lands mends that one body. Lifesteal pointed at somebody else.
--
-- Read against the shelf's other two and the trio is complete. The Crozier asks a priest WHERE TO STAND
-- so the line behind it recovers (`waitBehavior.covers`). The censers ask where to WALK, and lay their
-- ground as they go. This asks neither: it asks who you are willing to fight FOR, once, at the start,
-- and then never lets you revise the answer. All three spend a priest's positioning; only this one
-- spends a priest's aggression, which is why it is the one that gets to be a real weapon (its damage
-- curve is the shelf's highest) instead of the deliberate afterthought a focus usually is.
--
-- WHY THE HEALING IS A HAND-ROLL AND NOT `lifesteal`. The keyword heals the USER and folds in at
-- Combat's adjacencyAura funnel (docs/weapons.md), which has no notion of a third party; bending it to
-- take a redirect would put a branch in a path three cast routes share, to serve one item. The contract
-- says reach for a keyword first and hand-roll in the `effect` when none fits, and none fits. What that
-- costs is real and worth naming: a Vampiric Strike charm beside this staff still drinks for the
-- WIELDER, so the two stack rather than compete -- the staff feeds the ward, the charm feeds the priest.
return {
    name = "Intercessor's Staff",
    description = "Names one ally at the start of battle. Every blow this staff lands mends them instead of you.",
    flavor = "She was not asked. The Cathedral has never once thought to ask.",
    sprite = "assets/items/intercessors_staff.png",
    type = "weapon",
    tags = { "staff", "magical", "melee" }, -- magical: routes through magicDamage / magicDefense
    class = "priest",
    price = 340,
    repRank = 4,
    traits = { "trait_intercession" }, -- an item's `traits` reach whoever carries it (models/trait.lua)
    -- The family's obligation, and shallower than the Crozier's on purpose: this staff wants to be swung,
    -- so the turn it offers you for NOT swinging has to be the worse of the two.
    waitBehavior = { kind = "focus", mana = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 }, speed = 10 },
    activeAbility = {
        target = "enemy",
        range = 1, -- adjacent only: a staff is not a wand
        speed = 4,
        cost = { stat = "stamina", amount = 6 }, -- stamina, so a cornered priest can always swing it
        -- The shelf's heaviest focus damage, because here the damage IS the healing: a curve tuned as
        -- feebly as the Crozier's would make the intercession itself worthless.
        damage = { 7, 8, 8, 9, 10, 10, 11, 12, 12, 13, 14 },
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            -- The redirect. `intercession` is set once, at combat start, by the trait above; it is nil
            -- when the priest fought alone, and the staff is then simply a staff. The ward is re-checked
            -- for life on every swing because it may have fallen since it was named -- and a dead ward is
            -- NOT re-picked, deliberately: the oath was to a person, not to a slot.
            local ward = fx.user.intercession
            if dealt > 0 and ward and ward.alive then
                -- Three fifths, floored at 1 so a blow that landed always carries something across. Below
                -- a full point-for-point trade because the priest keeps the tempo either way: it struck a
                -- foe AND mended an ally on one turn, and that is worth a discount on both halves.
                fx.heal(ward, math.max(1, math.floor(dealt * 0.6)))
            end
        end,
    },
}
