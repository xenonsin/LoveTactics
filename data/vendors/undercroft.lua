-- Rogue vendor. Its quest line is theft and quiet murder, and ends facing Greed.
--
-- THE FIRST HOUSE WITH A SERVICE, which is the city's answer to a town that stops changing. Every door
-- in the city does Buy and Sell and nothing else, so the twelfth building to open is the eleventh
-- shelf; what a house needs in order to be worth walking to is a verb of its own (models/vendor.lua's
-- Services block).
--
-- The fence is greed's verb exactly: nothing is made and nothing is destroyed, a thing becomes another
-- thing of the same worth, and the house takes its cut of the difference. It is also the service this
-- game most needed -- a run pays out in gear, gear repeats, and until now a second Iron Sword was worth
-- half an Iron Sword in coin and nothing else.
return {
    name = "The Undercroft",
    class = "rogue",
    description = "No sign, no door you'd notice. Everything inside belonged to someone else.",
    sin = "greed",
    -- The companion this house's line earns; see data/vendors/bastion.lua for why it is authored here.
    companion = "character_clem",
    service = {
        id = "fence",
        label = "Fence",
        -- Shown on the tab's detail pane. Says what the verb DOES and what it costs, because a third
        -- tab nobody understands is a third tab nobody presses.
        blurb = "Hand over a piece and name what you want back. Same worth, a fee for the trouble, "
             .. "and no questions about where the first one came from.",
    },
}
