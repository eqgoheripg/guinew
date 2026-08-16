local Bulohub = loadstring(game:HttpGet("https://raw.githubusercontent.com/eqgoheripg/guinew/refs/heads/main/gui.luau"))()  
Bulohub.Callbacks.OnVerify = function(key)
    return key == "THIS_IS_KEY"
end
Bulohub.Appearance = { 
    Title = "Ixa & Bulo hub",
    Subtitle = "Verify Key to enjoy",
    Icon = "rbxassetid://95721401302279",
    IconSize = UDim2.new(0, 30, 0, 30)
}
Bulohub.Links = {
    GetKey = "",
    Discord = "https://discord.gg/xxxxxxx"
}
Bulohub.Storage = {
    FileName = "Ixa & Bulo hub",
    Remember = true,
    AutoLoad = false
}
Bulohub.Options = {
    Keyless = false,
    Blur = true,
    Draggable = true
}
Bulohub.Theme = {
    Accent = Color3.fromRGB(220, 20, 60),
    AccentHover = Color3.fromRGB(255, 30, 80),
    Background = Color3.fromRGB(0, 0, 0), 
    Header = Color3.fromRGB(10, 10, 10),
    Input = Color3.fromRGB(20, 20, 20),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(150, 150, 150),
    Success = Color3.fromRGB(50, 255, 50),
    Error = Color3.fromRGB(255, 30, 80),
    Warning = Color3.fromRGB(255, 255, 0),
    StatusIdle = Color3.fromRGB(180, 40, 60),
    Discord = Color3.fromRGB(220, 20, 60),
    DiscordHover = Color3.fromRGB(255, 30, 80),
    Divider = Color3.fromRGB(30, 30, 30),
    Pending = Color3.fromRGB(40, 40, 40)
}

Bulohub.Callbacks.OnSuccess = function()
    print("✅ Verification successful, loading script")
end

Bulohub.Callbacks.OnFail = function(errorMsg)
    print("Failed:", errorMsg)
end

Bulohub.Callbacks.OnClose = function()
    print("User closed the verification window")
end

Bulohub.Changelog = {
    {Version = "v0.0.1", Date = "May 30, 2026", Changes = {"Update Scripts"}},
}
Bulohub.Shop = {
    Enabled = false,
    Icon = "",
    Title = "Get Premium Access",
    Subtitle = "Instant delivery • 24/7 support",
    ButtonText = "Buy",
    Link = ""
}
Bulohub:Launch()
