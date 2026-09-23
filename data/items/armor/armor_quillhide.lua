-- QUILLHIDE: a coat sewn with the barbs off a manticore's hide, rebuilt as something a person can wear
-- (trait_quillhide). A foe that strikes the wearer in melee comes away Quilled -- and every pierce blow
-- the company throws at that foe afterwards lands two points harder a quill. The knight in front sets
-- the archers behind her up without spending a turn on it. Off the Manticore; a trophy, the common one.
--
-- HUNTER STOCK, because every hide on the Lodge's rack is (Bristlehide, Winterhide) -- it was pitched on
-- the Trapper's shelf and moved there on review. A hide turns an edge, so it resists slash, as the
-- animal does; and one square of pace, as every coat costs.
local Curve = require("models.curve")

return {
    name = "Quillhide",
    description = "A foe that strikes you in melee is inflicted with Quilled.",
    flavor = "Nobody at the Lodge will say who sewed the barbs in. Nobody at the Lodge would wear it inside out.",
    sprite = "assets/items/armor_quillhide.png",
    type = "armor",
    tags = { "hide" },
    class = "hunter",
    unlockLevel = 2,
    unstocked = true,
    traits = { "trait_quillhide" },
    bonus = { defense = Curve.ramp(1, 11), movement = -1 },
    resist = { slash = Curve.ramp(1, 11) },
}
