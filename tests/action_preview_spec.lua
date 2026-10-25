-- The line under a cast's name on the battle's forecast card (ui/action_preview.lua): who it lands on.
-- A blow reads "vs <target>"; a piece used on yourself reads "on <you>", because "Smoke / vs Rowan"
-- read as Rowan fighting himself.

local Character = require("models.character")
local Item = require("models.item")
local ActionPreview = require("ui.action_preview")

local function body(id, side)
    return { char = Character.instantiate(id), side = side, alive = true, x = 1, y = 1 }
end

return {
    {
        name = "a self-target item reads 'on' its user, not 'vs'",
        fn = function()
            local rowan = body("character_rowan", "party")
            local smoke = Item.instantiate("consumable_smoke")
            assert(smoke.activeAbility and smoke.activeAbility.target == "self",
                "the spec's subject is a self-target item")
            local line = ActionPreview.subjectLine({ item = smoke, actor = rowan, target = rowan })
            assert(line == "on " .. rowan.char.name, "got '" .. line .. "'")
        end,
    },
    {
        name = "any cast whose target is its own actor reads 'on', and a blow still reads 'vs'",
        fn = function()
            local rowan = body("character_rowan", "party")
            local bandit = body("character_bandit", "enemy")
            local item = { name = "Mend", activeAbility = { target = "ally" } }
            local self = ActionPreview.subjectLine({ item = item, actor = rowan, target = rowan })
            assert(self == "on " .. rowan.char.name, "got '" .. self .. "'")
            local blow = ActionPreview.subjectLine({ item = { name = "Sword", activeAbility = {} },
                actor = rowan, target = bandit })
            assert(blow == "vs " .. bandit.char.name, "got '" .. blow .. "'")
        end,
    },
}
