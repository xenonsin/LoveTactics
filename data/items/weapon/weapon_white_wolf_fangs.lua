-- THE WHITE WOLF'S TEETH: the pack's bite, with the pack counted into it.
--
-- HER WHOLE FIGHT IS THIS NUMBER. She strikes once, and then once more for every wolf standing within
-- two tiles of her -- so a lone god bites once and a god at the head of five bites six times. Her howl
-- (ability_howl.lua) calls alphas, which means a turn she spends summoning is a turn she spends raising
-- her own attack, and a party that ignores the pack to focus her is choosing to be bitten five times a
-- round. The Unseeing's clan is a wall you have to get through (character_the_unseeing.lua); hers is a
-- multiplier on her blow. Kill order is not advice in this fight, it is arithmetic.
--
-- UNCAPPED, AND THE CEILING LIVES SOMEWHERE ELSE. Nothing here bounds the count; what bounds it is the
-- stamina her howl reserves per standing alpha, which stops her at two of them (ability_howl.lua). If
-- this fight ever measures as unwinnable, that reserve is the dial -- never a cap written here, which
-- would make the pack stop mattering the moment it was reached and quietly delete the whole read.
--
-- WHY IT IS HER OWN FILE AND NOT weapon_wolf_fangs. There is no "on your own strike" hook in
-- models/trait.lua (the hooks are onAllyStrike, onCast, onDamaged, onDeath and four more), so "her blow
-- repeats" is either a new engine seam or a second weapon. It is a second weapon, identical to the
-- pack's in damage shape, tags, cost, tempo and step-back -- she bites and gives ground exactly like her
-- children, which was the point of putting the pack's teeth in her grid in the first place.
--
-- VOLUME REPLACES THE OTHER TWO RULES, deliberately. The pack's teeth bite twice against a much slower
-- body (Fire Emblem's doubling, re-scaled -- see weapon_wolf_fangs.lua) and hit heavier against wounded
-- prey. Hers do neither: she already repeats, and stacking a doubling and a flat bonus on top of a
-- per-wolf count multiplies three numbers nobody authored together -- six bites at doubled damage plus a
-- finisher bonus kills a soft body outright from half health, from across the board, with no answer.
-- What she keeps is the WOUND: prey at or below half still bleeds, because that rule is about what a
-- pack does to the failing rather than about how hard any one animal bites.
--
-- AND IT IS WORSE AGAINST ARMOUR, which is the honest half of the mechanic. Defense is subtracted from
-- each instance (Combat.mitigatedDamage runs per hit), so six small bites lose almost everything to a
-- plate coat and almost nothing to a robe. She shreds your line's soft bodies and can barely mark your
-- bulwark -- so the fight has a shape: put the armour in front of her, and spend the turns clearing her
-- pack rather than trading with her.
--
-- `noSteal` and `class = "creature"`: her fight can never be handed to the player as-is
-- (docs/bestiary.md). What comes off her body is an authored rebuild, not this.
local Curve = require("models.curve")

local GIVE_GROUND = 1 -- one step, however many times the teeth landed
local REACH = 2       -- how near a wolf must stand to be counted into the blow
local WOUNDED = 0.5   -- "the wounded": at or below half health

-- How many wolves are with her. Counted by the trait every wolf's teeth carry
-- (trait_runs_with_the_pack), not by "ally", so a charmed party member or a summoned anything standing
-- beside her adds nothing -- it is the PACK that makes the blow, and the pack is a specific thing.
local function packWith(combat, user)
    if not (combat and combat.units and user) then return 0 end
    local Combat = require("models.combat") -- inside the call: a data file must not close a load cycle
    local Trait = require("models.trait")
    local n = 0
    for _, other in ipairs(combat.units) do
        if other ~= user and other.alive and other.side == user.side
            and Trait.has(other, "trait_runs_with_the_pack")
            and Combat.unitGap(user, other) <= REACH then
            n = n + 1
        end
    end
    return n
end

return {
    name = "The White Wolf's Teeth",
    description = "Bites an adjacent foe once, and once more for every wolf beside her, then gives ground.",
    flavor = "The pack does not help her fight. The pack is how many times she does it.",
    sprite = "assets/items/fangs.png", -- the pack's own icon: they are the same teeth, and there are more of them
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "physical", "melee" },
    noSteal = true,
    hitAndRun = GIVE_GROUND,
    traits = { "trait_runs_with_the_pack" }, -- she runs with it too: her own relic is the lead it reads
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            local target = fx.target
            if not target then return end

            local hp = target.char and target.char.stats and target.char.stats.health
            local wounded = hp and hp.max and hp.max > 0 and (hp.current / hp.max) <= WOUNDED
            local opts = wounded and { inflicts = "status_bleed" } or {}

            -- One bite, and one more for each wolf with her. The loop re-checks `alive`, so a pack of
            -- six does not go on chewing a corpse -- the surplus is simply lost, which is the right
            -- reading and the reason overkill is not a way to farm anything.
            local bites = 1 + packWith(fx.combat, fx.user)
            for _ = 1, bites do
                if not target.alive then break end
                fx.damage(target, opts)
            end

            -- ONE step, at the end. Stepping off between bites would walk her out of her own attack.
            fx.retreat(target, GIVE_GROUND)
        end,
    },
}
