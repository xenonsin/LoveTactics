-- A BANE (Combat.BANE): a damage tag only one race answers. Wolfsbane Oil is the first, and it is Act 0's
-- aura lesson -- so what this pins is the half a player sees: the oil marks the weapon beside it, a beast
-- takes the bonus, anything else takes exactly what it took before, and the damage receipt names the row
-- so the numbers on the hover still sum.
--
-- Pure logic, headless.

local Item = require("models.item")
local Character = require("models.character")
local Combat = require("models.combat")

local function unitOf(id)
    local unit = { char = Character.instantiate(id), alive = true, x = 1, y = 1, side = "enemy" }
    Combat.refreshPassives(unit)
    return unit
end

return {
    {
        name = "Wolfsbane Oil marks the weapon beside it and nothing else",
        fn = function()
            local oil = Item.instantiate("utility_wolfsbane_oil")
            assert(oil.aura and oil.aura.grantTags[1] == "beastbane", "the oil grants beastbane")
            assert(Combat.auraApplies(oil.aura, Item.instantiate("weapon_iron_sword")), "it reaches a weapon")
            assert(not Combat.auraApplies(oil.aura, Item.instantiate("ability_renewal")), "it does not reach an ability")
            assert(not Combat.auraApplies(oil.aura, Item.instantiate("armor_leather_armor")), "nor a coat")
        end,
    },
    {
        name = "a beastbane blow lands harder on a beast and the same on anything else",
        fn = function()
            local bonus = Combat.BANE.beastbane.amount
            local beast = unitOf("character_wolf_grunt")
            assert(beast.char.race == "beast", "the wolf is a beast")
            local plain = Combat.mitigatedDamage(beast, 30, { "slash" })
            local baned = Combat.mitigatedDamage(beast, 30, { "slash", "beastbane" })
            assert(baned == plain + bonus, ("a beast takes +%d: %d -> %d"):format(bonus, plain, baned))

            local demon = unitOf("character_demon_champion_tutorial")
            assert(demon.char.race ~= "beast", "the Champion is not a beast")
            assert(Combat.mitigatedDamage(demon, 30, { "slash", "beastbane" }) == Combat.mitigatedDamage(demon, 30, { "slash" }),
                "a body of any other race ignores the bane")
        end,
    },
    {
        name = "the damage receipt names the bane and still sums",
        fn = function()
            local beast = unitOf("character_wolf_grunt")
            local tags = { "slash", "beastbane" }
            local dmg = Combat.mitigatedDamage(beast, 30, tags)
            local rows = Combat.damageBreakdown(beast, 30, tags, nil, nil, dmg)
            local named = false
            for _, r in ipairs(rows) do
                if r.label == Combat.BANE.beastbane.label then
                    named = true
                    assert(r.value == Combat.BANE.beastbane.amount, "the row carries the bonus")
                end
            end
            assert(named, "the receipt has a Beastbane row")
            assert(rows[#rows].value == dmg, "the receipt's total is the dealt number")
        end,
    },
}
