Config = {}


Config.Password = "Password" -- Panic system password (players must use /duresslogin <password>)
Config.Cooldown = 30 -- Cooldown between /panic uses (in seconds)
Config.DepartmentOrder = {"police", "fire", "ems"} -- Department display order

-- Blip appearance for panic alerts
Config.Blip = {
    Sprite = 161, -- Red radius
    Color = 1,    -- Red
    Scale = 1.3,
    Duration = 180 -- Seconds before blip disappears
}

-- Departments
Config.Departments = {
    police = {
        name = "WAPOL", -- Replace with your leo name (eg. WAPOL, NSWPF, ect.)
        color = { r = 59, g = 130, b = 246 },
        logo = "https://i.imgur.com/image.png"  -- Replace with your LEO logo URL
    },
    fire = {
        name = "DFES", -- Replace with your fire name (eg. DFES, FRNSW, ect.)
        color = { r = 239, g = 68, b = 68 },
        logo = "https://i.imgur.com/image.png"  -- Replace with your FIRE logo URL
    },
    ems = {
        name = "SJA", -- Replace with your ems name (eg. SJA, NSWA, ect.)
        color = { r = 34, g = 197, b = 94 },
        logo = "https://i.imgur.com/image.png"  -- Replace with your EMS logo URL
    }
}