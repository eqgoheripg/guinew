-- Modern UI Engine
-- Modern dark rewrite with compatibility for the old ui-engine-v2 API.
-- API: Library:AddWindow(), Window:AddTab(), Tab:AddButton(), etc.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local UIParent = (gethui and gethui()) or CoreGui

local old = UIParent:FindFirstChild("ModernUIEngine")
if old then old:Destroy() end

local Screen = Instance.new("ScreenGui")
Screen.Name = "ModernUIEngine"
Screen.IgnoreGuiInset = false
Screen.ResetOnSpawn = false
Screen.ZIndexBehavior = Enum.ZIndexBehavior.Global
Screen.DisplayOrder = 20
Screen.Parent = UIParent

local Theme = {
    Background = Color3.fromRGB(13, 14, 18),
    Surface = Color3.fromRGB(20, 22, 28),
    Surface2 = Color3.fromRGB(27, 30, 38),
    Surface3 = Color3.fromRGB(34, 38, 48),
    Text = Color3.fromRGB(240, 242, 247),
    Muted = Color3.fromRGB(146, 151, 165),
    Stroke = Color3.fromRGB(48, 53, 66),
    Accent = Color3.fromRGB(75, 132, 255),
    Accent2 = Color3.fromRGB(128, 86, 255),
    Success = Color3.fromRGB(72, 205, 137),
    Danger = Color3.fromRGB(245, 91, 106)
}

local Library = {
    Flags = {},
    Windows = {},
    Theme = Theme,
    ScreenGui = Screen,
    Connections = {},
    ToggleKey = Enum.KeyCode.RightShift
}

local function New(className, properties)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        if property ~= "Parent" then
            object[property] = value
        end
    end
    if properties and properties.Parent then
        object.Parent = properties.Parent
    end
    return object
end

local function Corner(parent, radius)
    return New("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(0, radius or 8)
    })
end

local function Stroke(parent, color, transparency, thickness)
    return New("UIStroke", {
        Parent = parent,
        Color = color or Theme.Stroke,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    })
end

local function Padding(parent, left, right, top, bottom)
    return New("UIPadding", {
        Parent = parent,
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or left or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0)
    })
end

local function Tween(object, goal, duration, style)
    local tween = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        goal
    )
    tween:Play()
    return tween
end

local function Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Library.Connections, connection)
    return connection
end

local function SetCanvasFromLayout(scroller, layout, extra)
    local function update()
        scroller.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + (extra or 0))
    end
    update()
    Connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), update)
end

local function AddHover(object, normalColor, hoverColor)
    Connect(object.MouseEnter, function()
        Tween(object, {BackgroundColor3 = hoverColor}, 0.15)
    end)
    Connect(object.MouseLeave, function()
        Tween(object, {BackgroundColor3 = normalColor}, 0.15)
    end)
end

local function MakeDraggable(handle, target)
    local dragging = false
    local dragInput
    local dragStart
    local startPosition

    Connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPosition = target.Position
        end
    end)

    Connect(UserInputService.InputChanged, function(input)
        if not dragging then return end
        local valid = input.UserInputType == Enum.UserInputType.MouseMovement or input == dragInput
        if not valid then return end
        local delta = input.Position - dragStart
        target.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)

    Connect(UserInputService.InputEnded, function(input)
        if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            dragInput = nil
        end
    end)
end

local function MakeResizable(handle, target, minimum)
    local resizing = false
    local resizeInput
    local startMouse
    local startSize

    Connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            resizeInput = input
            startMouse = input.Position
            startSize = target.AbsoluteSize
        end
    end)

    Connect(UserInputService.InputChanged, function(input)
        if not resizing or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = input.Position - startMouse
        target.Size = UDim2.fromOffset(
            math.max(minimum.X, startSize.X + delta.X),
            math.max(minimum.Y, startSize.Y + delta.Y)
        )
    end)

    Connect(UserInputService.InputEnded, function(input)
        if input == resizeInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = false
            resizeInput = nil
        end
    end)
end

local function MakeGradient(parent, colorA, colorB, rotation)
    return New("UIGradient", {
        Parent = parent,
        Color = ColorSequence.new(colorA, colorB),
        Rotation = rotation or 0
    })
end

local function CreateElementHost(parent, height)
    local host = New("Frame", {
        Parent = parent,
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or 42),
        ClipsDescendants = true
    })
    Corner(host, 8)
    Stroke(host, Theme.Stroke, 0.35)
    return host
end

local function CreateTabAPI(container, windowData)
    local tabData = {}

    local function AddLabelTo(parent, text)
        local label = New("TextLabel", {
            Parent = parent,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 24),
            Font = Enum.Font.GothamMedium,
            Text = tostring(text or "Label"),
            TextColor3 = Theme.Muted,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        Padding(label, 4, 4, 0, 0)
        return label
    end

    local function AddButtonTo(parent, text, callback)
        callback = type(callback) == "function" and callback or function() end
        local button = New("TextButton", {
            Parent = parent,
            AutoButtonColor = false,
            BackgroundColor3 = Theme.Surface2,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 40),
            Font = Enum.Font.GothamSemibold,
            Text = tostring(text or "Button"),
            TextColor3 = Theme.Text,
            TextSize = 13
        })
        Corner(button, 8)
        Stroke(button, Theme.Stroke, 0.3)
        AddHover(button, Theme.Surface2, Theme.Surface3)
        Connect(button.MouseButton1Click, function()
            Tween(button, {BackgroundColor3 = windowData.Accent}, 0.08)
            task.delay(0.12, function()
                if button and button.Parent then Tween(button, {BackgroundColor3 = Theme.Surface2}, 0.18) end
            end)
            local ok, err = pcall(callback)
            if not ok then warn("ModernUI button callback:", err) end
        end)
        return button
    end

    function tabData:AddLabel(text)
        return AddLabelTo(container, text)
    end

    function tabData:AddButton(text, callback)
        return AddButtonTo(container, text, callback)
    end

    function tabData:AddSwitch(text, callback)
        callback = type(callback) == "function" and callback or function() end
        local data = {Value = false}
        local row = CreateElementHost(container, 42)

        local title = New("TextLabel", {
            Parent = row,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -68, 1, 0),
            Font = Enum.Font.GothamMedium,
            Text = tostring(text or "Switch"),
            TextColor3 = Theme.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left
        })

        local track = New("Frame", {
            Parent = row,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(38, 20),
            BackgroundColor3 = Theme.Surface3,
            BorderSizePixel = 0
        })
        Corner(track, 20)

        local knob = New("Frame", {
            Parent = track,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 3, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BackgroundColor3 = Theme.Muted,
            BorderSizePixel = 0
        })
        Corner(knob, 20)

        local click = New("TextButton", {
            Parent = row,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 4
        })

        function data:Set(value)
            data.Value = value == true
            Tween(track, {BackgroundColor3 = data.Value and windowData.Accent or Theme.Surface3}, 0.2)
            Tween(knob, {
                Position = data.Value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                BackgroundColor3 = data.Value and Color3.new(1, 1, 1) or Theme.Muted
            }, 0.2)
            local ok, err = pcall(callback, data.Value)
            if not ok then warn("ModernUI switch callback:", err) end
        end

        function data:Get()
            return data.Value
        end

        Connect(click.MouseButton1Click, function()
            data:Set(not data.Value)
        end)

        return data, row
    end

    function tabData:AddTextBox(placeholder, callback, options)
        callback = type(callback) == "function" and callback or function() end
        options = type(options) == "table" and options or {}
        local box = New("TextBox", {
            Parent = container,
            BackgroundColor3 = Theme.Surface2,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 40),
            ClearTextOnFocus = false,
            Font = Enum.Font.GothamMedium,
            PlaceholderText = tostring(placeholder or "Enter text..."),
            PlaceholderColor3 = Theme.Muted,
            Text = "",
            TextColor3 = Theme.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        Corner(box, 8)
        Stroke(box, Theme.Stroke, 0.3)
        Padding(box, 12, 12, 0, 0)

        Connect(box.Focused, function()
            Tween(box, {BackgroundColor3 = Theme.Surface3}, 0.15)
        end)
        Connect(box.FocusLost, function(enterPressed)
            Tween(box, {BackgroundColor3 = Theme.Surface2}, 0.15)
            if enterPressed and box.Text ~= "" then
                local value = box.Text
                local ok, err = pcall(callback, value)
                if not ok then warn("ModernUI textbox callback:", err) end
                if options.clear ~= false then box.Text = "" end
            end
        end)
        return box
    end

    function tabData:AddSlider(text, callback, options)
        callback = type(callback) == "function" and callback or function() end
        options = type(options) == "table" and options or {}
        local minimum = tonumber(options.min) or 0
        local maximum = tonumber(options.max) or 100
        local data = {Value = minimum}
        local row = CreateElementHost(container, 58)

        local title = New("TextLabel", {
            Parent = row,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 5),
            Size = UDim2.new(1, -80, 0, 22),
            Font = Enum.Font.GothamMedium,
            Text = tostring(text or "Slider"),
            TextColor3 = Theme.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left
        })

        local valueLabel = New("TextLabel", {
            Parent = row,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -12, 0, 5),
            Size = UDim2.fromOffset(65, 22),
            Font = Enum.Font.GothamSemibold,
            Text = tostring(minimum),
            TextColor3 = windowData.Accent,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right
        })

        local track = New("TextButton", {
            Parent = row,
            AutoButtonColor = false,
            BackgroundColor3 = Theme.Surface3,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 12, 1, -18),
            Size = UDim2.new(1, -24, 0, 6),
            Text = ""
        })
        Corner(track, 10)

        local fill = New("Frame", {
            Parent = track,
            BackgroundColor3 = windowData.Accent,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(0, 1)
        })
        Corner(fill, 10)
        MakeGradient(fill, windowData.Accent, windowData.Accent2, 0)

        local knob = New("Frame", {
            Parent = fill,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0
        })
        Corner(knob, 20)
        Stroke(knob, windowData.Accent, 0, 2)

        local dragging = false

        function data:Set(value)
            value = math.clamp(tonumber(value) or minimum, minimum, maximum)
            data.Value = value
            local alpha = maximum == minimum and 0 or (value - minimum) / (maximum - minimum)
            Tween(fill, {Size = UDim2.fromScale(alpha, 1)}, 0.12)
            valueLabel.Text = tostring(math.floor(value * 100 + 0.5) / 100)
            local ok, err = pcall(callback, value)
            if not ok then warn("ModernUI slider callback:", err) end
        end

        function data:Get()
            return data.Value
        end

        local function update(input)
            local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            data:Set(minimum + (maximum - minimum) * alpha)
        end

        Connect(track.InputBegan, function(input)
            if options.readonly then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                update(input)
            end
        end)
        Connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end)
        Connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        data:Set(minimum)
        return data, row
    end

    function tabData:AddKeybind(name, callback, options)
        callback = type(callback) == "function" and callback or function() end
        options = type(options) == "table" and options or {}
        local data = {}
        local current = options.standard or Enum.KeyCode.RightShift
        local binding = false
        local row = CreateElementHost(container, 42)

        New("TextLabel", {
            Parent = row,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -110, 1, 0),
            Font = Enum.Font.GothamMedium,
            Text = tostring(name or "Keybind"),
            TextColor3 = Theme.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left
        })

        local inputButton = New("TextButton", {
            Parent = row,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(84, 26),
            BackgroundColor3 = Theme.Surface3,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.GothamSemibold,
            Text = current.Name,
            TextColor3 = Theme.Muted,
            TextSize = 11
        })
        Corner(inputButton, 6)

        function data:SetKeybind(key)
            if typeof(key) == "EnumItem" then
                current = key
                inputButton.Text = key.Name
            end
        end

        function data:Get()
            return current
        end

        Connect(inputButton.MouseButton1Click, function()
            if binding then return end
            binding = true
            inputButton.Text = "..."
            local input = UserInputService.InputBegan:Wait()
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                data:SetKeybind(input.KeyCode)
            else
                data:SetKeybind(input.UserInputType)
            end
            task.wait()
            binding = false
        end)

        Connect(UserInputService.InputBegan, function(input, processed)
            if binding or processed then return end
            if input.KeyCode == current or input.UserInputType == current then
                local ok, err = pcall(callback, current)
                if not ok then warn("ModernUI keybind callback:", err) end
            end
        end)

        return data, row
    end

    function tabData:AddDropdown(name, callback)
        callback = type(callback) == "function" and callback or function() end
        local data = {Options = {}, Value = nil, Open = false}
        local host = CreateElementHost(container, 42)

        local button = New("TextButton", {
            Parent = host,
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 42),
            Font = Enum.Font.GothamMedium,
            Text = tostring(name or "Dropdown"),
            TextColor3 = Theme.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        Padding(button, 12, 44, 0, 0)

        local selected = New("TextLabel", {
            Parent = button,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -30, 0.5, 0),
            Size = UDim2.new(0.48, 0, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            Text = "Select",
            TextColor3 = Theme.Muted,
            TextSize = 12,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Right
        })

        local arrow = New("TextLabel", {
            Parent = button,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Text = "⌄",
            TextColor3 = windowData.Accent,
            TextSize = 15
        })

        local optionsFrame = New("Frame", {
            Parent = host,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(8, 42),
            Size = UDim2.new(1, -16, 0, 0),
            ClipsDescendants = true
        })
        local optionsLayout = New("UIListLayout", {
            Parent = optionsFrame,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder
        })

        local function refreshHeight()
            local contentHeight = optionsLayout.AbsoluteContentSize.Y
            Tween(host, {Size = UDim2.new(1, 0, 0, data.Open and 50 + contentHeight or 42)}, 0.22)
            Tween(optionsFrame, {Size = UDim2.new(1, -16, 0, data.Open and contentHeight or 0)}, 0.22)
            Tween(arrow, {Rotation = data.Open and 180 or 0}, 0.22)
        end

        function data:Set(value)
            if not data.Options[value] then return end
            data.Value = value
            selected.Text = tostring(value)
            data.Open = false
            refreshHeight()
            local ok, err = pcall(callback, value)
            if not ok then warn("ModernUI dropdown callback:", err) end
        end

        function data:Get()
            return data.Value
        end

        function data:Add(option)
            option = tostring(option or "Option")
            local optionData = {}
            local optionButton = New("TextButton", {
                Parent = optionsFrame,
                AutoButtonColor = false,
                BackgroundColor3 = Theme.Surface3,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 30),
                Font = Enum.Font.GothamMedium,
                Text = option,
                TextColor3 = Theme.Muted,
                TextSize = 12
            })
            Corner(optionButton, 6)
            AddHover(optionButton, Theme.Surface3, windowData.Accent)
            data.Options[option] = optionButton

            Connect(optionButton.MouseButton1Click, function()
                data:Set(option)
            end)

            function optionData:Remove()
                data.Options[option] = nil
                optionButton:Destroy()
                task.defer(refreshHeight)
            end

            task.defer(refreshHeight)
            return optionButton, optionData
        end

        Connect(button.MouseButton1Click, function()
            data.Open = not data.Open
            refreshHeight()
        end)

        return data, host
    end

    function tabData:AddColorPicker(callback)
        callback = type(callback) == "function" and callback or function() end
        local data = {Color = Color3.fromRGB(255, 80, 100), Open = false}
        local host = CreateElementHost(container, 42)

        New("TextLabel", {
            Parent = host,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -70, 0, 42),
            Font = Enum.Font.GothamMedium,
            Text = "Color picker",
            TextColor3 = Theme.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left
        })

        local sample = New("TextButton", {
            Parent = host,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0, 21),
            Size = UDim2.fromOffset(36, 22),
            BackgroundColor3 = data.Color,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false
        })
        Corner(sample, 6)
        Stroke(sample, Color3.new(1, 1, 1), 0.75)

        local picker = New("Frame", {
            Parent = host,
            Position = UDim2.fromOffset(10, 48),
            Size = UDim2.new(1, -20, 0, 112),
            BackgroundTransparency = 1,
            Visible = false
        })

        local palette = New("TextButton", {
            Parent = picker,
            AutoButtonColor = false,
            BackgroundColor3 = Color3.fromHSV(0, 1, 1),
            BorderSizePixel = 0,
            Size = UDim2.new(1, -30, 1, 0),
            Text = ""
        })
        Corner(palette, 6)
        New("UIGradient", {
            Parent = palette,
            Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 0, 0)),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1)
            })
        })
        local dark = New("Frame", {
            Parent = palette,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 0
        })
        Corner(dark, 6)
        New("UIGradient", {
            Parent = dark,
            Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0)
            })
        })

        local hue = New("TextButton", {
            Parent = picker,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(18, 112),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false
        })
        Corner(hue, 6)
        New("UIGradient", {
            Parent = hue,
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
            })
        })

        local h, s, v = 0, 1, 1
        local draggingPalette = false
        local draggingHue = false

        local function updateColor()
            data.Color = Color3.fromHSV(h, s, v)
            sample.BackgroundColor3 = data.Color
            palette.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            local ok, err = pcall(callback, data.Color)
            if not ok then warn("ModernUI color callback:", err) end
        end

        local function updatePalette(input)
            s = math.clamp((input.Position.X - palette.AbsolutePosition.X) / palette.AbsoluteSize.X, 0, 1)
            v = 1 - math.clamp((input.Position.Y - palette.AbsolutePosition.Y) / palette.AbsoluteSize.Y, 0, 1)
            updateColor()
        end

        local function updateHue(input)
            h = math.clamp((input.Position.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 1)
            updateColor()
        end

        Connect(sample.MouseButton1Click, function()
            data.Open = not data.Open
            picker.Visible = data.Open
            Tween(host, {Size = UDim2.new(1, 0, 0, data.Open and 170 or 42)}, 0.22)
        end)
        Connect(palette.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingPalette = true updatePalette(input) end
        end)
        Connect(hue.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue = true updateHue(input) end
        end)
        Connect(UserInputService.InputChanged, function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                if draggingPalette then updatePalette(input) end
                if draggingHue then updateHue(input) end
            end
        end)
        Connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingPalette = false
                draggingHue = false
            end
        end)

        function data:Set(color)
            if typeof(color) ~= "Color3" then return end
            h, s, v = color:ToHSV()
            updateColor()
        end

        function data:Get()
            return data.Color
        end

        updateColor()
        return data, host
    end

    function tabData:AddConsole(options)
        options = type(options) == "table" and options or {}
        local height = tonumber(options.y) or 180
        local data = {}
        local host = CreateElementHost(container, height)

        local editor = New("TextBox", {
            Parent = host,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 10),
            Size = UDim2.new(1, -24, 1, -20),
            ClearTextOnFocus = false,
            MultiLine = true,
            TextEditable = options.readonly ~= true,
            Font = Enum.Font.Code,
            Text = "",
            TextColor3 = Theme.Text,
            PlaceholderText = "Console output...",
            PlaceholderColor3 = Theme.Muted,
            TextSize = 14,
            TextWrapped = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top
        })

        function data:Set(value) editor.Text = tostring(value or "") end
        function data:Get() return editor.Text end
        function data:Log(value)
            editor.Text = editor.Text .. (editor.Text == "" and "" or "\n") .. "[*] " .. tostring(value)
            editor.CursorPosition = #editor.Text + 1
        end

        return data, host
    end

    function tabData:AddHorizontalAlignment()
        local horizontal = New("Frame", {
            Parent = container,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 40)
        })
        local layout = New("UIListLayout", {
            Parent = horizontal,
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalFlex = Enum.UIFlexAlignment.Fill
        })
        local horizontalData = {}
        function horizontalData:AddButton(text, callback)
            return AddButtonTo(horizontal, text, callback)
        end
        return horizontalData, horizontal
    end

    function tabData:AddFolder(name)
        local folderData
        local host = CreateElementHost(container, 42)
        local open = false

        local header = New("TextButton", {
            Parent = host,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 42),
            AutoButtonColor = false,
            Font = Enum.Font.GothamSemibold,
            Text = tostring(name or "Folder"),
            TextColor3 = Theme.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        Padding(header, 12, 40, 0, 0)

        local arrow = New("TextLabel", {
            Parent = header,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Text = "⌄",
            TextColor3 = windowData.Accent,
            TextSize = 15
        })

        local content = New("Frame", {
            Parent = host,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(8, 46),
            Size = UDim2.new(1, -16, 0, 0),
            ClipsDescendants = true
        })
        local layout = New("UIListLayout", {
            Parent = content,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder
        })
        folderData = CreateTabAPI(content, windowData)

        local function resizeFolder()
            local contentHeight = layout.AbsoluteContentSize.Y
            Tween(content, {Size = UDim2.new(1, -16, 0, open and contentHeight or 0)}, 0.22)
            Tween(host, {Size = UDim2.new(1, 0, 0, open and contentHeight + 54 or 42)}, 0.22)
            Tween(arrow, {Rotation = open and 180 or 0}, 0.22)
        end

        Connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), resizeFolder)
        Connect(header.MouseButton1Click, function()
            open = not open
            resizeFolder()
        end)

        return folderData, host
    end

    return tabData
end

function Library:AddWindow(title, options)
    options = type(options) == "table" and options or {}
    local minimum = options.min_size or Vector2.new(500, 360)
    local accent = options.main_color or Theme.Accent
    local accent2 = options.second_color or Theme.Accent2
    Library.ToggleKey = options.toggle_key or Library.ToggleKey

    local windowData = {
        Tabs = {},
        CurrentTab = nil,
        Accent = accent,
        Accent2 = accent2,
        Minimized = false
    }

    local index = #Library.Windows + 1
    local root = New("Frame", {
        Parent = Screen,
        Name = "Window_" .. index,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, (index - 1) * 24, 0.5, (index - 1) * 20),
        Size = UDim2.fromOffset(minimum.X, minimum.Y),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true
    })
    Corner(root, 12)
    Stroke(root, Theme.Stroke, 0.05)

    local topbar = New("Frame", {
        Parent = root,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 54)
    })

    local accentLine = New("Frame", {
        Parent = topbar,
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -2),
        Size = UDim2.new(1, 0, 0, 2)
    })
    MakeGradient(accentLine, accent, accent2, 0)

    New("TextLabel", {
        Parent = topbar,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 0),
        Size = UDim2.new(1, -130, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = tostring(title or "Modern UI"),
        TextColor3 = Theme.Text,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left
    })

    local subtitle = New("TextLabel", {
        Parent = topbar,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -92, 0.5, 0),
        Size = UDim2.fromOffset(70, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = "ONLINE",
        TextColor3 = Theme.Success,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right
    })

    local minimize = New("TextButton", {
        Parent = topbar,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        Text = "—",
        TextColor3 = Theme.Muted,
        TextSize = 14
    })
    Corner(minimize, 7)
    AddHover(minimize, Theme.Surface2, Theme.Surface3)

    local sidebar = New("Frame", {
        Parent = root,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 54),
        Size = UDim2.new(0, 148, 1, -54)
    })

    local tabButtons = New("ScrollingFrame", {
        Parent = sidebar,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(8, 12),
        Size = UDim2.new(1, -16, 1, -24),
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 0
    })
    local tabLayout = New("UIListLayout", {
        Parent = tabButtons,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder
    })
    SetCanvasFromLayout(tabButtons, tabLayout, 8)

    local contentHolder = New("Frame", {
        Parent = root,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(148, 54),
        Size = UDim2.new(1, -148, 1, -54),
        ClipsDescendants = true
    })

    local resizeHandle = New("TextButton", {
        Parent = root,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1,
        Text = "◢",
        Font = Enum.Font.GothamBold,
        TextColor3 = Theme.Muted,
        TextSize = 12,
        AutoButtonColor = false,
        ZIndex = 20
    })

    MakeDraggable(topbar, root)
    if options.can_resize ~= false then
        MakeResizable(resizeHandle, root, minimum)
    else
        resizeHandle.Visible = false
    end

    local expandedSize = root.Size
    Connect(minimize.MouseButton1Click, function()
        windowData.Minimized = not windowData.Minimized
        if windowData.Minimized then
            expandedSize = root.Size
            sidebar.Visible = false
            contentHolder.Visible = false
            resizeHandle.Visible = false
            Tween(root, {Size = UDim2.fromOffset(root.AbsoluteSize.X, 54)}, 0.25)
            minimize.Text = "+"
        else
            Tween(root, {Size = expandedSize}, 0.25)
            task.delay(0.18, function()
                sidebar.Visible = true
                contentHolder.Visible = true
                resizeHandle.Visible = options.can_resize ~= false
            end)
            minimize.Text = "—"
        end
    end)

    function windowData:AddTab(tabName)
        local tab = {
            Name = tostring(tabName or "Tab"),
            Active = false
        }

        local button = New("TextButton", {
            Parent = tabButtons,
            AutoButtonColor = false,
            BackgroundColor3 = Theme.Surface,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 38),
            Font = Enum.Font.GothamMedium,
            Text = "  " .. tab.Name,
            TextColor3 = Theme.Muted,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        Corner(button, 8)

        local marker = New("Frame", {
            Parent = button,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(3, 0),
            BackgroundColor3 = accent,
            BorderSizePixel = 0
        })
        Corner(marker, 5)
        MakeGradient(marker, accent, accent2, 90)

        local page = New("ScrollingFrame", {
            Parent = contentHolder,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(14, 14),
            Size = UDim2.new(1, -28, 1, -28),
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = accent,
            Visible = false
        })
        local layout = New("UIListLayout", {
            Parent = page,
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder
        })
        Padding(page, 0, 5, 0, 4)
        SetCanvasFromLayout(page, layout, 10)

        local api = CreateTabAPI(page, windowData)
        api.Button = button
        api.Page = page

        function api:Show()
            for _, other in ipairs(windowData.Tabs) do
                other.Active = false
                other.Page.Visible = false
                Tween(other.Button, {BackgroundTransparency = 1, TextColor3 = Theme.Muted}, 0.16)
                Tween(other.Marker, {Size = UDim2.fromOffset(3, 0)}, 0.16)
            end
            tab.Active = true
            page.Visible = true
            Tween(button, {BackgroundTransparency = 0, BackgroundColor3 = Theme.Surface2, TextColor3 = Theme.Text}, 0.18)
            Tween(marker, {Size = UDim2.fromOffset(3, 22)}, 0.2)
            windowData.CurrentTab = api
        end

        tab.Button = button
        tab.Page = page
        tab.Marker = marker
        table.insert(windowData.Tabs, tab)

        Connect(button.MouseButton1Click, function()
            api:Show()
        end)

        if #windowData.Tabs == 1 then
            api:Show()
        end

        return api, page
    end

    function windowData:SetVisible(value)
        root.Visible = value == true
    end

    function windowData:Toggle()
        root.Visible = not root.Visible
    end

    function windowData:SetAccent(color, secondColor)
        if typeof(color) == "Color3" then
            windowData.Accent = color
            accentLine.BackgroundColor3 = color
        end
        if typeof(secondColor) == "Color3" then
            windowData.Accent2 = secondColor
        end
    end

    windowData.Instance = root
    table.insert(Library.Windows, windowData)
    return windowData, root
end

function Library:FormatWindows()
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    for index, window in ipairs(self.Windows) do
        if window.Instance and window.Instance.Parent then
            window.Instance.Position = UDim2.fromOffset(
                math.floor(viewport.X / 2 - window.Instance.AbsoluteSize.X / 2 + (index - 1) * 28),
                math.floor(viewport.Y / 2 - window.Instance.AbsoluteSize.Y / 2 + (index - 1) * 24)
            )
            window.Instance.AnchorPoint = Vector2.new(0, 0)
        end
    end
end

function Library:SetVisible(value)
    Screen.Enabled = value == true
end

function Library:Toggle()
    Screen.Enabled = not Screen.Enabled
end

function Library:Unload()
    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    self.Connections = {}
    if Screen then Screen:Destroy() end
end

Connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if input.KeyCode == Library.ToggleKey then
        Library:Toggle()
    end
end)

return Library
