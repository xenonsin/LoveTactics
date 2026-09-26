-- SUCCESSION: The Strongest Leads has been cast (data/items/ability/ability_the_strongest_leads.lua). If the
-- bearer falls this fight, every boon it holds passes to the living ally with the most health, who heals half
-- its health (models/succession.lua).
return {
    name = "Succession",
    abbr = "Succ",
    description = "If you fall this fight, your boons pass to the ally with the most health, who heals.",
    color = { 0.760, 0.620, 0.260 },
    duration = math.huge,
    hideDuration = true,
}
