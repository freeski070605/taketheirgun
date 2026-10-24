local definitions = {
    Pistol = {
        DisplayName = "Pistol", Damage = 24, HeadshotMultiplier = 1.8,
        MagazineSize = 12, ReserveAmmo = 72, FireRate = 3.5,
        ReloadTime = 1.5, Range = 350, Automatic = false,
        PelletCount = 1, Spread = 0.4, Color = Color3.fromRGB(245, 214, 85),
    },
    SMG = {
        DisplayName = "SMG", Damage = 13, HeadshotMultiplier = 1.5,
        MagazineSize = 32, ReserveAmmo = 160, FireRate = 11,
        ReloadTime = 1.9, Range = 250, Automatic = true,
        PelletCount = 1, Spread = 2.1, Color = Color3.fromRGB(94, 220, 238),
    },
    AssaultRifle = {
        DisplayName = "Assault Rifle", Damage = 19, HeadshotMultiplier = 1.65,
        MagazineSize = 30, ReserveAmmo = 150, FireRate = 8,
        ReloadTime = 2.2, Range = 450, Automatic = true,
        PelletCount = 1, Spread = 0.9, Color = Color3.fromRGB(124, 229, 129),
    },
    Shotgun = {
        DisplayName = "Shotgun", Damage = 10, HeadshotMultiplier = 1.35,
        MagazineSize = 6, ReserveAmmo = 42, FireRate = 1.05,
        ReloadTime = 2.7, Range = 130, Automatic = false,
        PelletCount = 8, Spread = 5.5, Color = Color3.fromRGB(241, 137, 102),
    },
}

return table.freeze(definitions)
