-- DiiUi HUB | safe-run wrapper (V3.9 fix)
-- Kalau ada error di executor mana pun, pesan error ditampilkan di layar + console (F9),
-- jadi gampang di-screenshot dan dilaporkan ke owner.
local __DiiUiOk, __DiiUiErr = xpcall(function()
--==================================================
-- DiiUi HUB V2 | REAL EXECUTOR
-- Client-side GUI and visual utilities
--==================================================

--==================================================
-- AUTO SAVE: pengaturan tersimpan otomatis ke file DiiUi_Settings.json (butuh writefile/readfile)
-- Disimpan di `shared` supaya tidak menambah variabel local di level atas.
--==================================================
shared.DiiUiPersist = (function()
    local HttpService = game:GetService("HttpService")
    local FILE = "DiiUi_Settings.json"
    local P = {Reg = {}, Replaying = false}
    local D = {enabled = true, restoreActions = false, toggles = {}, sliders = {}, anim = {}}
    P.Data = D
    -- aksi sesaat: baru dipulihkan kalau "Pulihkan juga aksi" dinyalakan
    local ACTION_KEYS = {"FLY", "Tornado Spin", "Gravity 0"}

    local canIO = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
    P.CanSave = canIO

    if canIO then
        pcall(function()
            if isfile(FILE) then
                local t = HttpService:JSONDecode(readfile(FILE))
                if type(t) == "table" then
                    for k, v in pairs(t) do D[k] = v end
                end
            end
        end)
    end
    if type(D.toggles) ~= "table" then D.toggles = {} end
    if type(D.sliders) ~= "table" then D.sliders = {} end
    if type(D.anim) ~= "table" then D.anim = {} end

    local pending = false
    function P.Save(now)
        if not canIO then return end
        local function write()
            pending = false
            pcall(function() writefile(FILE, HttpService:JSONEncode(D)) end)
        end
        if now then write() return end
        if pending then return end
        pending = true
        task.delay(0.6, write)
    end

    local function on() return D.enabled and not P.Replaying end
    function P.Toggle(key, state)
        if not on() then return end
        D.toggles[key] = state and true or false
        P.Save()
    end
    function P.Slider(key, v)
        if not on() then return end
        D.sliders[key] = v
        P.Save()
    end
    function P.SetPreset(name)
        if not D.enabled then return end
        D.preset = (name ~= "Reset") and name or nil
        P.Save()
    end
    function P.SetPack(name)
        if not on() then return end
        D.pack, D.anim = name, {}
        P.Save()
    end
    function P.SetAnim(cat, id)
        if not on() then return end
        D.anim[cat] = id
        P.Save()
    end
    function P.ClearAnim()
        if not on() then return end
        D.pack, D.anim = nil, {}
        P.Save()
    end
    function P.ClearAll()
        D.toggles, D.sliders, D.anim = {}, {}, {}
        D.preset, D.pack = nil, nil
        P.Save(true)
    end

    -- dipanggil setelah tab-tab pengaturan dirender sekali (supaya semua callback terdaftar)
    function P.Replay()
        if not D.enabled then return end
        P.Replaying = true
        for key, v in pairs(D.sliders) do
            local fn = P.Reg["s:" .. key]
            if fn then pcall(fn, v) end
        end
        for key, want in pairs(D.toggles) do
            local r = P.Reg["t:" .. key]
            if r then
                local isAction = false
                for _, a in ipairs(ACTION_KEYS) do
                    if key:find(a, 1, true) then isAction = true break end
                end
                if (not isAction or D.restoreActions) and want ~= r.get() then
                    pcall(r.set)
                end
            end
        end
        P.Replaying = false
    end
    return P
end)()

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

if not game:IsLoaded() then game.Loaded:Wait() end
local LP = Players.LocalPlayer
if not LP then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LP = Players.LocalPlayer
end

--====================================
-- DiiUi HUB | WHITELIST USERNAME
-- Hanya username di daftar ini yang boleh memakai script.
-- Kalau username TIDAK ada di daftar, pemain langsung di-kick dari map.
--
-- CARA MENAMBAH USER:
--   Tambah satu baris baru berisi username Roblox (huruf besar/kecil bebas),
--   pisahkan dengan koma. Contoh:
--       "UsernameTeman1",
--       "UsernameTeman2",
-- Opsional: tambah UserId di AllowedUserIds (lebih aman kalau username bisa diganti).
--====================================
local AllowedUsernames = {
    "Bapex1708",
    "Celvin_tin",
    "Hantu_belau2",
    "adefabian7",
    "rridho_66",
    "nasss_TH",
    "bbymloo",
    "ell4voraa",
    "budakkaseppp",
    "flesss377",
    "haushh42",
    "AYELxzy978",
    "junvy7",
}

local AllowedUserIds = {
    -- 123456789,
}

local KICK_MESSAGE = "DiiUi HUB: username kamu belum terdaftar. Hubungi owner untuk didaftarkan."

local function hasAccess(player)
    local wanted = string.lower(player.Name)
    for _, name in ipairs(AllowedUsernames) do
        if string.lower((string.gsub(tostring(name), "%s+", ""))) == wanted then
            return true
        end
    end
    for _, id in ipairs(AllowedUserIds) do
        if id == player.UserId then
            return true
        end
    end
    return false
end

if not hasAccess(LP) then
    warn("[DiiUi HUB] ACCESS DENIED: " .. LP.Name .. " tidak terdaftar.")
    LP:Kick(KICK_MESSAGE)
    return
end

print("[DiiUi HUB] ACCESS GRANTED: " .. LP.Name)
local PG = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui", 15)
local Camera = workspace.CurrentCamera or workspace:GetPropertyChangedSignal("CurrentCamera"):Wait() and workspace.CurrentCamera

-- REMOVE OLD GUI
do
    local places = {PG}
    pcall(function() table.insert(places, game:GetService("CoreGui")) end)
    pcall(function() if gethui then table.insert(places, gethui()) end end)
    for _, place in ipairs(places) do
        pcall(function()
            local old = place and place:FindFirstChild("DiiUiHUB")
            if old then old:Destroy() end
        end)
    end
end

-- COLORS
local PURPLE = Color3.fromRGB(145, 70, 255)
local DARK = Color3.fromRGB(17, 14, 27)
local PANEL = Color3.fromRGB(27, 22, 41)
local WHITE = Color3.fromRGB(240, 235, 255)
local GREY = Color3.fromRGB(160, 150, 180)

-- GUI
local Gui = Instance.new("ScreenGui")
Gui.Name = "DiiUiHUB"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- Pasang GUI: coba gethui / CoreGui dulu (aman di banyak executor), kalau gagal pakai PlayerGui
do
    local mounted = false
    pcall(function()
        if gethui then
            Gui.Parent = gethui()
        elseif syn and syn.protect_gui then
            syn.protect_gui(Gui)
            Gui.Parent = game:GetService("CoreGui")
        else
            Gui.Parent = game:GetService("CoreGui")
        end
        mounted = Gui.Parent ~= nil
    end)
    if not mounted and PG then
        Gui.Parent = PG
    end
end

local Main = Instance.new("Frame")
Main.Name = "Main"
local vp = Camera.ViewportSize
local compact = vp.X < 700
local mainW = math.min(650, vp.X - 30)
local mainH = math.min(420, vp.Y - 40)
local sideW = compact and 112 or 145
Main.Size = UDim2.fromOffset(mainW, mainH)
Main.Position = UDim2.new(0.5, -mainW / 2, 0.5, -mainH / 2)
Main.BackgroundColor3 = DARK
Main.BorderSizePixel = 0
Main.Active = true -- sink input: tap di menu TIDAK tembus ke game / tool
Main.Parent = Gui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Color = PURPLE
Stroke.Thickness = 1.5
Stroke.Parent = Main

-- TOP BAR
local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 48)
Top.BackgroundColor3 = PANEL
Top.BorderSizePixel = 0
Top.Active = true
Top.Parent = Main

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 12)
TopCorner.Parent = Top

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -110, 1, 0)
Title.Position = UDim2.fromOffset(15, 0)
Title.BackgroundTransparency = 1
Title.Text = "✨ DiiUi HUB"
Title.TextColor3 = WHITE
Title.Font = Enum.Font.GothamBold
Title.TextSize = 19
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Top

local function topButton(txt, x)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(35, 30)
    b.Position = UDim2.new(1, x, 0, 9)
    b.BackgroundColor3 = PURPLE
    b.Text = txt
    b.TextColor3 = WHITE
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.Parent = Top
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    return b
end

local MinButton = topButton("-", -82)
local CloseButton = topButton("❌", -42)

--====================================
-- DiiUi HUB: DRAG (semua jendela & tombol mini bisa digeser)
--====================================
local function makeDraggable(handle, target, onTap)
    handle.Active = true
    local dragging, dragInput, dragStart, startUI, startAbs, moved = false, nil, nil, nil, nil, false

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragInput = input
            dragStart = input.Position
            startUI = target.Position
            startAbs = target.AbsolutePosition
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if onTap and not moved then onTap() end
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        local isMine = input == dragInput
            or (input.UserInputType == Enum.UserInputType.MouseMovement
                and dragInput.UserInputType == Enum.UserInputType.MouseButton1)
        if not isMine then return end
        local d = input.Position - dragStart
        if d.Magnitude > 6 then moved = true end
        if not moved then return end
        -- jaga agar tidak keluar layar
        local lo = Gui.AbsolutePosition
        local hi = lo + Gui.AbsoluteSize - target.AbsoluteSize
        local want = Vector2.new(startAbs.X + d.X, startAbs.Y + d.Y)
        local clamped = Vector2.new(
            math.clamp(want.X, lo.X, math.max(lo.X, hi.X)),
            math.clamp(want.Y, lo.Y, math.max(lo.Y, hi.Y))
        )
        local fix = clamped - startAbs
        target.Position = UDim2.new(
            startUI.X.Scale, startUI.X.Offset + fix.X,
            startUI.Y.Scale, startUI.Y.Offset + fix.Y
        )
    end)
end

makeDraggable(Top, Main)
makeDraggable(Title, Main)

-- MINIMIZE TO SMALL BUTTON (bisa digeser, ketuk untuk membuka)
-- LOGO (foto DiiHub) untuk tombol mini
-- Opsional: upload fotonya ke Roblox lalu isi LOGO_ASSET_ID dengan angkanya.
local miniButton
do
local LOGO_ASSET_ID = nil
local LOGO_B64 = table.concat({
    "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",
    "2D8249a1Oc5NSUqRyX//2Q=="
})

local B64CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64MAP = {}
for i = 1, #B64CHARS do B64MAP[string.byte(B64CHARS, i)] = i - 1 end
local function b64decode(data)
    local chunk, n, buf, bits = {}, 0, 0, 0
    for i = 1, #data do
        local v = B64MAP[string.byte(data, i)]
        if v then
            buf = buf * 64 + v
            bits = bits + (6)
            if bits >= 8 then
                bits = bits - (8)
                local p = 2 ^ bits
                n = n + (1)
                chunk[n] = string.char(math.floor(buf / p) % 256)
                buf = buf % p
            end
        end
    end
    return table.concat(chunk)
end

local function resolveLogo()
    if LOGO_ASSET_ID then return "rbxassetid://" .. tostring(LOGO_ASSET_ID) end
    local ok, res = pcall(function()
        local wf = writefile
        local gca = getcustomasset or getsynasset
        if not (wf and gca) then return nil end
        local name = "DiiUi_logo_v1.jpg"
        if not (isfile and isfile(name)) then wf(name, b64decode(LOGO_B64)) end
        return gca(name)
    end)
    if ok and res and res ~= "" then return res end
    return nil
end

miniButton = Instance.new("ImageButton")
miniButton.Name = "DiiUiMini"
miniButton.Size = UDim2.fromOffset(42, 42)
miniButton.Position = UDim2.new(0, 12, 0.4, 0)
miniButton.BackgroundColor3 = Color3.fromRGB(30, 10, 25)
miniButton.AutoButtonColor = false
miniButton.ScaleType = Enum.ScaleType.Crop
miniButton.Visible = false
miniButton.ZIndex = 5
local logoImage = resolveLogo()
if logoImage then
    miniButton.Image = logoImage
else
    local fallback = Instance.new("TextLabel")
    fallback.Size = UDim2.fromScale(1, 1)
    fallback.BackgroundTransparency = 1
    fallback.Text = "✨"
    fallback.TextColor3 = Color3.fromRGB(255, 90, 160)
    fallback.Font = Enum.Font.GothamBold
    fallback.TextSize = 20
    fallback.ZIndex = 6
    fallback.Parent = miniButton
end
miniButton.Parent = Gui
Instance.new("UICorner", miniButton).CornerRadius = UDim.new(1, 0)
local miniStroke = Instance.new("UIStroke")
miniStroke.Color = Color3.fromRGB(255, 60, 140)
miniStroke.Thickness = 1.5
miniStroke.Parent = miniButton
end -- do logo

makeDraggable(miniButton, miniButton, function()
    task.defer(function()
        miniButton.Visible = false
        Main.Visible = true
    end)
end)

-- KEYBOARD M: SHOW / HIDE MENU
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or UIS:GetFocusedTextBox() then
        return
    end
    if input.KeyCode == Enum.KeyCode.M then
        if miniButton.Visible then
            miniButton.Visible = false
            Main.Visible = true
        else
            Main.Visible = not Main.Visible
        end
    end
end)

MinButton.MouseButton1Click:Connect(function()
    Main.Visible = false
    miniButton.Visible = true
end)

-- CLOSE GUI
CloseButton.MouseButton1Click:Connect(function()
    Gui:Destroy()
end)

-- SIDEBAR (bisa di-scroll agar muat di HP)
local Side = Instance.new("ScrollingFrame")
Side.Position = UDim2.fromOffset(8, 56)
Side.Size = UDim2.new(0, sideW, 1, -64)
Side.BackgroundColor3 = PANEL
Side.BorderSizePixel = 0
Side.ScrollBarThickness = 3
Side.ScrollBarImageColor3 = PURPLE
Side.CanvasSize = UDim2.new()
Side.Active = true
Side.AutomaticCanvasSize = Enum.AutomaticSize.Y
Side.Parent = Main
Instance.new("UICorner", Side).CornerRadius = UDim.new(0, 9)

local SideList = Instance.new("UIListLayout")
SideList.Padding = UDim.new(0, 6)
SideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
SideList.SortOrder = Enum.SortOrder.LayoutOrder
SideList.Parent = Side

local SidePad = Instance.new("UIPadding")
SidePad.PaddingTop = UDim.new(0, 8)
SidePad.PaddingBottom = UDim.new(0, 8)
SidePad.Parent = Side

-- CONTENT
local Content = Instance.new("ScrollingFrame")
Content.Position = UDim2.fromOffset(sideW + 16, 56)
Content.Size = UDim2.new(1, -(sideW + 24), 1, -64)
Content.BackgroundColor3 = PANEL
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = PURPLE
Content.CanvasSize = UDim2.new()
Content.Active = true
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Main
Instance.new("UICorner", Content).CornerRadius = UDim.new(0, 9)

local ContentList = Instance.new("UIListLayout")
ContentList.Padding = UDim.new(0, 8)
ContentList.SortOrder = Enum.SortOrder.LayoutOrder
ContentList.Parent = Content

local ContentPad = Instance.new("UIPadding")
ContentPad.PaddingTop = UDim.new(0, 10)
ContentPad.PaddingLeft = UDim.new(0, 8)
ContentPad.PaddingRight = UDim.new(0, 8)
ContentPad.PaddingBottom = UDim.new(0, 10)
ContentPad.Parent = Content

-- KLIK AMAN: abaikan klik kalau itu sebenarnya geseran (scroll) / klik beruntun
local function guardedClick(btn, scroller, callback, cooldown)
    local downPos, downCanvas, last = nil, nil, 0
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            downPos = input.Position
            downCanvas = scroller and scroller.CanvasPosition or Vector2.zero
        end
    end)
    btn.Activated:Connect(function(input)
        if downPos and input and input.Position then
            if (input.Position - downPos).Magnitude > 10 then return end
        end
        if scroller and downCanvas and (scroller.CanvasPosition - downCanvas).Magnitude > 6 then return end
        local now = os.clock()
        if now - last < (cooldown or 0.2) then return end
        last = now
        callback()
    end)
end

local function clearContent()
    for _, v in ipairs(Content:GetChildren()) do
        if v:IsA("GuiObject") and v ~= ContentList
        and v ~= ContentPad then
            v:Destroy()
        end
    end
    -- menu gabungan: header pilihan sub-menu dibuat ulang setiap konten dibersihkan
    if shared.DiiMergeHeader then
        local ok, err = pcall(shared.DiiMergeHeader)
        if not ok then warn("[DiiUi HUB] header menu gabungan: " .. tostring(err)) end
    end
end

local function label(txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -5, 0, 28)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = WHITE
    l.Font = Enum.Font.GothamBold
    l.TextSize = compact and 13 or 15
    l.TextWrapped = true
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = Content
    return l
end

local function button(txt, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -5, 0, 36)
    b.BackgroundColor3 = Color3.fromRGB(65, 39, 105)
    b.Text = txt
    b.TextColor3 = WHITE
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 13
    b.TextWrapped = true
    b.AutomaticSize = Enum.AutomaticSize.Y
    b.Parent = Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    local bp = Instance.new("UIPadding")
    bp.PaddingTop = UDim.new(0, 6)
    bp.PaddingBottom = UDim.new(0, 6)
    bp.PaddingLeft = UDim.new(0, 8)
    bp.PaddingRight = UDim.new(0, 8)
    bp.Parent = b

    guardedClick(b, Content, function()
        if callback then
            local ok, err = pcall(callback)
            if not ok then warn("[DiiUi HUB] " .. tostring(err)) end
        end
    end)
    return b
end

local function textbox(placeholder)
    local t = Instance.new("TextBox")
    t.Size = UDim2.new(1, -5, 0, 36)
    t.BackgroundColor3 = DARK
    t.TextColor3 = WHITE
    t.PlaceholderColor3 = GREY
    t.PlaceholderText = placeholder
    t.Text = ""
    t.Font = Enum.Font.Gotham
    t.TextSize = 13
    t.ClearTextOnFocus = false
    t.Parent = Content
    Instance.new("UICorner", t).CornerRadius = UDim.new(0, 7)
    return t
end

-- SLIDER GESER KE SAMPING (mouse & sentuh) + tombol halus ⏪ ⏩
local function slider(titleText, minV, maxV, startV, step, onChange, fmt)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -5, 0, 58)
    holder.BackgroundColor3 = DARK
    holder.BorderSizePixel = 0
    holder.Parent = Content
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -76, 0, 24)
    lbl.Position = UDim2.fromOffset(8, 3)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = WHITE
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = holder

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -28, 0, 8)
    track.Position = UDim2.new(0, 14, 0, 40)
    track.BackgroundColor3 = Color3.fromRGB(60, 48, 90)
    track.BorderSizePixel = 0
    track.Parent = holder
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = PURPLE
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(20, 20)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = WHITE
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, 0, 0, 30)
    hit.Position = UDim2.fromOffset(0, 28)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Parent = holder

    local function mini(txt, x)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(28, 22)
        b.Position = UDim2.new(1, x, 0, 4)
        b.BackgroundColor3 = Color3.fromRGB(65, 39, 105)
        b.Text = txt
        b.TextColor3 = WHITE
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.Parent = holder
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end
    local minus = mini("⏪", -68)
    local plus = mini("⏩", -36)

    do local PS = shared.DiiUiPersist if PS then PS.Reg["s:" .. titleText] = onChange end end
    local value = math.clamp(tonumber(startV) or minV, minV, maxV)
    local function render()
        local a = (value - minV) / (maxV - minV)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        lbl.Text = titleText .. ": " .. (fmt and string.format(fmt, value) or tostring(value))
    end
    local function setValue(v)
        v = math.clamp(math.floor(v / step + 0.5) * step, minV, maxV)
        v = tonumber(string.format("%.4f", v))
        if v ~= value then
            value = v
            render()
            if onChange then
                local ok, err = pcall(onChange, v)
                if not ok then warn("[DiiUi HUB] " .. tostring(err)) end
            end
            local PS = shared.DiiUiPersist
            if PS then PS.Slider(titleText, v) end
        end
    end
    local function setFromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        setValue(minV + a * (maxV - minV))
    end
    minus.MouseButton1Click:Connect(function() setValue(value - step) end)
    plus.MouseButton1Click:Connect(function() setValue(value + step) end)

    local dragging, active = false, nil
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            active = input
            Content.ScrollingEnabled = false
            setFromX(input.Position.X)
        end
    end)
    local c1 = UIS.InputChanged:Connect(function(input)
        if dragging and (input == active
            or (input.UserInputType == Enum.UserInputType.MouseMovement
                and active.UserInputType == Enum.UserInputType.MouseButton1)) then
            setFromX(input.Position.X)
        end
    end)
    local c2 = UIS.InputEnded:Connect(function(input)
        if dragging and (input == active or input.UserInputType == Enum.UserInputType.MouseButton1) then
            dragging = false
            Content.ScrollingEnabled = true
        end
    end)
    holder.Destroying:Connect(function()
        c1:Disconnect()
        c2:Disconnect()
        Content.ScrollingEnabled = true
    end)

    render()
    return holder
end

local function notify(msg)
    label("✨ " .. msg)
end

-- PLAYER CHARACTER
local function getCharacter()
    return LP.Character or LP.CharacterAdded:Wait()
end

local function getHumanoid()
    return getCharacter():WaitForChild("Humanoid")
end

-- GRAPHICS
local preset
do
local LIGHT_PROPS = {"Brightness", "ClockTime", "FogEnd", "FogStart", "FogColor", "GlobalShadows",
    "Ambient", "OutdoorAmbient", "ExposureCompensation", "EnvironmentDiffuseScale",
    "EnvironmentSpecularScale", "ColorShift_Top", "ColorShift_Bottom", "ShadowSoftness"}
local oldLighting = {}
for _, k in ipairs(LIGHT_PROPS) do
    local ok, v = pcall(function() return Lighting[k] end)
    if ok then oldLighting[k] = v end
end

local dlssRestore -- diisi preset DLSS5; mengembalikan Technology/material saat preset diganti
local function clearDiiEffects()
    if dlssRestore then local f = dlssRestore dlssRestore = nil pcall(f) end
    for _, v in ipairs(Lighting:GetChildren()) do
        if v.Name:match("^DiiUi_") then
            v:Destroy()
        end
    end
end

-- Atmosphere milik game disimpan dulu, lalu dikembalikan saat Reset
local atmoSaved
local ATMO_PROPS = {"Density", "Offset", "Color", "Decay", "Glare", "Haze"}
local function getAtmo()
    local a = Lighting:FindFirstChildOfClass("Atmosphere")
    if a and not a.Name:match("^DiiUi_") then
        if not atmoSaved then
            atmoSaved = {inst = a}
            for _, k in ipairs(ATMO_PROPS) do atmoSaved[k] = a[k] end
        end
        return a
    end
    if a then return a end
    a = Instance.new("Atmosphere")
    a.Name = "DiiUi_Atmosphere"
    a.Parent = Lighting
    return a
end

local function setLight(props)
    for k, v in pairs(props) do pcall(function() Lighting[k] = v end) end
end

local function addFx(className, name, props)
    local fx = Instance.new(className)
    fx.Name = "DiiUi_" .. name
    for k, v in pairs(props) do pcall(function() fx[k] = v end) end
    fx.Parent = Lighting
    return fx
end


-- ===== CUACA / PARTIKEL (hanya terlihat di layar sendiri) =====
local weather = {}
local cloudSaved

local function ns(...)
    local pts = {}
    for i, p in ipairs({...}) do pts[i] = NumberSequenceKeypoint.new(p[1], p[2]) end
    return NumberSequence.new(pts)
end

-- ===== SALJU DI TANAH: tanah/rumput diputihkan (hanya terlihat di layarmu) =====
local snowGround = {Parts = {}, Terrain = {}, Conn = nil, Deco = nil, Token = 0}
local SNOW_COLOR = Color3.fromRGB(238, 243, 252)
local SNOW_MATS = {
    [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true, [Enum.Material.Ground] = true,
    [Enum.Material.Mud] = true, [Enum.Material.Sand] = true, [Enum.Material.Sandstone] = true,
}
local SNOW_TERRAIN = {
    Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Ground, Enum.Material.Mud,
    Enum.Material.Sand, Enum.Material.Sandstone, Enum.Material.Rock, Enum.Material.Slate,
}

local function snowifyPart(d)
    if not d:IsA("BasePart") or d:IsA("Terrain") then return end
    if snowGround.Parts[d] or d.Transparency > 0.9 then return end
    if d:FindFirstChildOfClass("SurfaceAppearance") then return end
    -- HANYA lantai/tanah yang besar dan padat. Item, aksesoris, koin, tanaman kecil, dan
    -- benda tanpa tabrakan TIDAK disentuh (dulu ikut jadi putih lalu "hilang" di salju).
    if not d.CanCollide then return end
    local s = d.Size
    if s.X < 8 or s.Z < 8 or s.Y > 10 then return end
    if d:IsA("MeshPart") and s.Y > 6 then return end
    local p = d.Parent
    while p and p ~= workspace do
        if p:IsA("Accessory") or p:IsA("Tool") or p:IsA("Accoutrement")
            or (p:IsA("Model") and p:FindFirstChildOfClass("Humanoid"))
            or p.Name:sub(1, 6) == "DiiUi_" then
            return
        end
        p = p.Parent
    end
    local c = d.Color
    local flatLarge = s.Y <= 6 and s.X >= 30 and s.Z >= 30 and c.G > c.R and c.G > c.B
    if not (SNOW_MATS[d.Material] or flatLarge) then return end
    snowGround.Parts[d] = {d.Color, d.Material}
    d.Color = SNOW_COLOR
    d.Material = Enum.Material.Snow
end

local function applySnowGround()
    snowGround.Token = snowGround.Token + 1
    local token = snowGround.Token
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        pcall(function()
            if snowGround.Deco == nil then snowGround.Deco = terrain.Decoration end
            terrain.Decoration = false   -- rumput tinggi disembunyikan supaya tidak menembus salju
        end)
        for _, mat in ipairs(SNOW_TERRAIN) do
            pcall(function()
                if snowGround.Terrain[mat] == nil then snowGround.Terrain[mat] = terrain:GetMaterialColor(mat) end
                local col = SNOW_COLOR
                if mat == Enum.Material.Rock or mat == Enum.Material.Slate then
                    col = Color3.fromRGB(225, 232, 245)
                end
                terrain:SetMaterialColor(mat, col)
            end)
        end
    end
    if snowGround.Conn then snowGround.Conn:Disconnect() end
    snowGround.Conn = workspace.DescendantAdded:Connect(snowifyPart)
    task.spawn(function()
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if snowGround.Token ~= token then return end
            snowifyPart(d)
            n = n + 1
            if n % 1500 == 0 then task.wait() end
        end
    end)
end

local function restoreSnowGround()
    snowGround.Token = snowGround.Token + 1
    if snowGround.Conn then snowGround.Conn:Disconnect() end
    for part, orig in pairs(snowGround.Parts) do
        if part.Parent then
            pcall(function()
                part.Color = orig[1]
                part.Material = orig[2]
            end)
        end
    end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        for mat, col in pairs(snowGround.Terrain) do
            pcall(function() terrain:SetMaterialColor(mat, col) end)
        end
        if snowGround.Deco ~= nil then
            pcall(function() terrain.Decoration = snowGround.Deco end)
        end
    end
    snowGround = {Parts = {}, Terrain = {}, Conn = nil, Deco = nil, Token = snowGround.Token}
end

-- ===== TANAH BASAH (efek hujan): tanah digelapkan + mengkilap, hanya terlihat di layarmu =====
local wetGround = {Parts = {}, Terrain = {}, Conn = nil, Token = 0, S = 1}
local WET_MATS = {
    [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true, [Enum.Material.Ground] = true,
    [Enum.Material.Mud] = true, [Enum.Material.Sand] = true, [Enum.Material.Sandstone] = true,
    [Enum.Material.Asphalt] = true, [Enum.Material.Pavement] = true, [Enum.Material.Cobblestone] = true,
}
local WET_TERRAIN = {
    Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Ground, Enum.Material.Mud,
    Enum.Material.Sand, Enum.Material.Sandstone, Enum.Material.Rock, Enum.Material.Slate,
    Enum.Material.Asphalt, Enum.Material.Pavement, Enum.Material.Cobblestone,
}

local function wetColor(c, s)
    local k = 1 - 0.38 * s
    return Color3.new(c.R * k * 0.96, c.G * k * 0.98, c.B * k)   -- gelap + sedikit kebiruan
end

local function wetifyPart(d)
    if not d:IsA("BasePart") or d:IsA("Terrain") then return end
    if wetGround.Parts[d] or d.Transparency > 0.9 then return end
    if d:FindFirstChildOfClass("SurfaceAppearance") then return end
    local flatLarge = d.Size.Y <= 6 and d.Size.X >= 20 and d.Size.Z >= 20
    if not (WET_MATS[d.Material] or flatLarge) then return end
    local m = d:FindFirstAncestorOfClass("Model")
    if m and Players:GetPlayerFromCharacter(m) then return end
    wetGround.Parts[d] = {d.Color, d.Reflectance}
    d.Color = wetColor(d.Color, wetGround.S)
    d.Reflectance = math.clamp(math.max(d.Reflectance, 0.06 + 0.16 * wetGround.S), 0, 0.3)
end

local function restoreWetGround()
    wetGround.Token = wetGround.Token + 1
    if wetGround.Conn then wetGround.Conn:Disconnect() end
    for part, orig in pairs(wetGround.Parts) do
        if part.Parent then
            pcall(function()
                part.Color = orig[1]
                part.Reflectance = orig[2]
            end)
        end
    end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        for mat, col in pairs(wetGround.Terrain) do
            pcall(function() terrain:SetMaterialColor(mat, col) end)
        end
    end
    wetGround = {Parts = {}, Terrain = {}, Conn = nil, Token = wetGround.Token, S = 1}
end

local function applyWetGround(strength)
    restoreWetGround()
    wetGround.S = strength or 1
    local token = wetGround.Token
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        for _, mat in ipairs(WET_TERRAIN) do
            pcall(function()
                local orig = terrain:GetMaterialColor(mat)
                wetGround.Terrain[mat] = orig
                terrain:SetMaterialColor(mat, wetColor(orig, wetGround.S))
            end)
        end
    end
    wetGround.Conn = workspace.DescendantAdded:Connect(wetifyPart)
    task.spawn(function()
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if wetGround.Token ~= token then return end
            wetifyPart(d)
            n = n + 1
            if n % 1500 == 0 then task.wait() end
        end
    end)
end

local function stopWeather()
    restoreSnowGround()
    restoreWetGround()
    if weather.Conn then weather.Conn:Disconnect() end
    if weather.Part then pcall(function() weather.Part:Destroy() end) end
    if weather.Bars then pcall(function() weather.Bars:Destroy() end) end
    weather = {}
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
    if clouds then
        if clouds.Name == "DiiUi_Clouds" then
            clouds:Destroy()
        elseif cloudSaved then
            for k, v in pairs(cloudSaved) do pcall(function() clouds[k] = v end) end
        end
    end
    cloudSaved = nil
end

local function setClouds(cover, density, color)
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if not terrain then return end
    local c = terrain:FindFirstChildOfClass("Clouds")
    if not c then
        c = Instance.new("Clouds")
        c.Name = "DiiUi_Clouds"
        c.Parent = terrain
    elseif c.Name ~= "DiiUi_Clouds" and not cloudSaved then
        cloudSaved = {Cover = c.Cover, Density = c.Density, Color = c.Color, Enabled = c.Enabled}
    end
    c.Enabled = true
    c.Cover, c.Density, c.Color = cover, density, color
end

-- Part transparan mengikuti kamera + ParticleEmitter (hujan / salju / debu)
local function startWeather(opts)
    local cam = workspace.CurrentCamera
    if not cam then return end
    local height = opts.Height or 22
    local part = Instance.new("Part")
    part.Name = "DiiUi_Weather"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Transparency = 1
    part.Size = opts.Size or Vector3.new(80, 1, 80)
    part.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, height, 0))
    part.Parent = cam
    -- batas rate per emitter: 400 di PC, 100 di HP
    local maxRate = UIS.TouchEnabled and 100 or 400
    for _ = 1, opts.Count or 1 do
        local e = Instance.new("ParticleEmitter")
        for k, v in pairs(opts.Props) do pcall(function() e[k] = v end) end
        pcall(function() e.Rate = math.min(opts.Props.Rate or 100, maxRate) end)
        e.EmissionDirection = Enum.NormalId.Bottom
        e.Parent = part
    end
    weather.Part = part
    weather.Conn = RunService.RenderStepped:Connect(function()
        local c = workspace.CurrentCamera
        if not c or not part.Parent then return end
        if part.Parent ~= c then part.Parent = c end
        part.CFrame = CFrame.new(c.CFrame.Position + Vector3.new(0, height, 0))
    end)
end

-- Garis hitam atas-bawah ala film (di bawah UI game)
local function startLetterbox(frac)
    local sg = Instance.new("ScreenGui")
    sg.Name = "DiiUi_Letterbox"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.DisplayOrder = -1
    sg.Parent = LP:WaitForChild("PlayerGui")
    for i = 0, 1 do
        local f = Instance.new("Frame")
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        f.BorderSizePixel = 0
        f.Size = UDim2.new(1, 0, frac, 0)
        f.Position = UDim2.new(0, 0, i == 0 and 0 or 1 - frac, 0)
        f.Parent = sg
    end
    weather.Bars = sg
end

local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

-- Properti emitter hujan: partikel dipanjangkan (Squash) jadi garis air
local function rainProps(rate, smin, smax, size, tr)
    return {
        Rate = rate,
        Lifetime = NumberRange.new(0.45, 0.6),
        Speed = NumberRange.new(smin, smax),
        Acceleration = Vector3.new(0, -40, 0),
        SpreadAngle = Vector2.new(3, 3),
        Size = NumberSequence.new(size),
        Squash = NumberSequence.new(3),
        Rotation = NumberRange.new(-6, 6),
        Color = ColorSequence.new(Color3.fromRGB(190, 205, 225)),
        Transparency = ns({0, 1}, {0.1, tr}, {0.85, tr}, {1, 1}),
        LightInfluence = 0.6,
        LightEmission = 0.1,
    }
end


-- Matikan blur / depth-of-field milik game (untuk mode HD anti blur), dipulihkan saat Reset
local blurSaved = {}
local function disableGameBlur()
    local function scan(parent)
        for _, v in ipairs(parent:GetChildren()) do
            if (v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect")) and not v.Name:match("^DiiUi_") then
                if blurSaved[v] == nil then blurSaved[v] = v.Enabled end
                v.Enabled = false
            end
        end
    end
    scan(Lighting)
    if workspace.CurrentCamera then scan(workspace.CurrentCamera) end
end
local function restoreGameBlur()
    for v, was in pairs(blurSaved) do
        if v.Parent then pcall(function() v.Enabled = was end) end
    end
    blurSaved = {}
end

local removeXmasDeco -- diisi di bawah, dekat preset Salju

local function resetLighting()
    stopWeather()
    restoreGameBlur()
    clearDiiEffects()
    if removeXmasDeco then pcall(removeXmasDeco) end
    setLight(oldLighting)
    if atmoSaved and atmoSaved.inst and atmoSaved.inst.Parent then
        for _, k in ipairs(ATMO_PROPS) do pcall(function() atmoSaved.inst[k] = atmoSaved[k] end) end
    end
end

local function setQuality(level)
    pcall(function() settings().Rendering.QualityLevel = level end)
end

local GraphicsPresets = {}

GraphicsPresets.HD = function()
    setLight({Brightness = 3, GlobalShadows = true, FogEnd = 100000})
    addFx("ColorCorrectionEffect", "HD", {Contrast = 0.1, Saturation = 0.15})
end
GraphicsPresets.Low = function()
    setLight({Brightness = 1, GlobalShadows = false, FogEnd = 100000})
    setQuality(1)
end
GraphicsPresets.Horror = function()
    setLight({Brightness = 0.5, ClockTime = 0, FogEnd = 100})
    addFx("ColorCorrectionEffect", "Horror", {TintColor = Color3.fromRGB(180, 190, 210), Contrast = 0.35, Saturation = -0.7})
end
GraphicsPresets.Sunset = function()
    setLight({ClockTime = 18, Brightness = 2})
    addFx("ColorCorrectionEffect", "Sunset", {TintColor = Color3.fromRGB(255, 170, 110)})
end
GraphicsPresets.Night = function()
    setLight({ClockTime = 0, Brightness = 0.5})
end

-- ===== GRAFIK BARU =====
-- 1) Cinematic: warna film, vignette-ish blur halus, bloom, DOF, sun rays
GraphicsPresets.Cinematic = function()
    setLight({Brightness = 2.2, GlobalShadows = true, ExposureCompensation = -0.15,
        ShadowSoftness = 0.3, FogEnd = 100000})
    addFx("ColorCorrectionEffect", "Cinematic", {TintColor = Color3.fromRGB(255, 238, 218),
        Contrast = 0.22, Saturation = -0.08, Brightness = -0.02})
    addFx("BloomEffect", "CinematicBloom", {Intensity = 0.45, Size = 32, Threshold = 1.0})
    addFx("DepthOfFieldEffect", "CinematicDOF", {FarIntensity = 0.18, FocusDistance = 40,
        InFocusRadius = 45, NearIntensity = 0})
    addFx("SunRaysEffect", "CinematicRays", {Intensity = 0.12, Spread = 0.8})
end

-- 2) Kabut: Atmosphere tebal + warna abu kebiruan
GraphicsPresets.Kabut = function()
    setLight({Brightness = 1.6, FogStart = 10, FogEnd = 450, FogColor = Color3.fromRGB(190, 200, 212)})
    local a = getAtmo()
    a.Density = 0.55
    a.Offset = 0.25
    a.Color = Color3.fromRGB(196, 205, 218)
    a.Decay = Color3.fromRGB(150, 160, 175)
    a.Glare = 0
    a.Haze = 2.6
    addFx("ColorCorrectionEffect", "Kabut", {TintColor = Color3.fromRGB(225, 232, 245),
        Saturation = -0.18, Contrast = -0.04})
end

-- 3) Ultra HD: tajam, jernih, bayangan halus, kualitas maks
GraphicsPresets.UltraHD = function()
    setLight({Brightness = 3, GlobalShadows = true, ShadowSoftness = 0.15,
        EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1, FogEnd = 100000})
    addFx("ColorCorrectionEffect", "UltraHD", {Contrast = 0.18, Saturation = 0.22, Brightness = 0.02})
    addFx("BloomEffect", "UltraHDBloom", {Intensity = 0.25, Size = 20, Threshold = 1.4})
    addFx("SunRaysEffect", "UltraHDRays", {Intensity = 0.08, Spread = 0.6})
    setQuality(21)
end

-- DLSS 5 / RTX ULTRA HD (simulasi). Roblox tidak punya DLSS atau ray tracing sungguhan; ini memakai
-- pencahayaan Future (paling mendekati RTX), bayangan halus, tone mapping sinematik, bloom, depth of
-- field halus, material 2022, dan kualitas render maksimal. Berat di HP kentang / laptop lemah.
GraphicsPresets.DLSS5 = function()
    local origTech, origMat
    pcall(function()
        if gethiddenproperty then origTech = gethiddenproperty(Lighting, "Technology") end
        if origTech == nil then origTech = Lighting.Technology end
    end)
    pcall(function()
        if sethiddenproperty then sethiddenproperty(Lighting, "Technology", Enum.Technology.Future)
        else Lighting.Technology = Enum.Technology.Future end
    end)
    local MS = game:GetService("MaterialService")
    pcall(function() origMat = MS.Use2022Materials MS.Use2022Materials = true end)
    dlssRestore = function()
        pcall(function()
            if origTech ~= nil then
                if sethiddenproperty then sethiddenproperty(Lighting, "Technology", origTech)
                else Lighting.Technology = origTech end
            end
        end)
        pcall(function() if origMat ~= nil then MS.Use2022Materials = origMat end end)
    end

    setLight({Brightness = 2.8, GlobalShadows = true, ShadowSoftness = 0.12, ExposureCompensation = 0.25,
        EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1, FogEnd = 100000})
    local a = getAtmo()
    a.Density, a.Offset, a.Glare, a.Haze = 0.22, 0.1, 0.15, 0.7
    a.Color = Color3.fromRGB(198, 214, 236)
    a.Decay = Color3.fromRGB(124, 152, 192)
    addFx("ColorCorrectionEffect", "DLSS5", {Contrast = 0.22, Saturation = 0.26, Brightness = 0.02,
        TintColor = Color3.fromRGB(255, 251, 246)})
    addFx("BloomEffect", "DLSS5Bloom", {Intensity = 0.35, Size = 20, Threshold = 1.0})
    addFx("SunRaysEffect", "DLSS5Rays", {Intensity = 0.1, Spread = 0.8})
    addFx("DepthOfFieldEffect", "DLSS5DOF", {FarIntensity = 0.12, FocusDistance = 45,
        InFocusRadius = 70, NearIntensity = 0})
    setQuality(21)
    pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04 end)
end

-- 4) Anime / Vibrant: warna pekat ceria
GraphicsPresets.Vibrant = function()
    setLight({Brightness = 2.6, GlobalShadows = true, FogEnd = 100000})
    addFx("ColorCorrectionEffect", "Vibrant", {Saturation = 0.55, Contrast = 0.12,
        TintColor = Color3.fromRGB(255, 248, 245)})
    addFx("BloomEffect", "VibrantBloom", {Intensity = 0.3, Size = 24, Threshold = 1.1})
end

-- 5) Cyberpunk Neon: ungu-cyan, gelap, bloom kuat
GraphicsPresets.Cyberpunk = function()
    setLight({Brightness = 1.2, ClockTime = 21, FogEnd = 100000,
        Ambient = Color3.fromRGB(60, 30, 110), OutdoorAmbient = Color3.fromRGB(70, 40, 130)})
    addFx("ColorCorrectionEffect", "Cyberpunk", {TintColor = Color3.fromRGB(220, 170, 255),
        Saturation = 0.35, Contrast = 0.3})
    addFx("BloomEffect", "CyberpunkBloom", {Intensity = 1.0, Size = 40, Threshold = 0.8})
end

-- 6) Vintage: sepia film lama
GraphicsPresets.Vintage = function()
    setLight({Brightness = 1.8, FogEnd = 100000})
    addFx("ColorCorrectionEffect", "Vintage", {TintColor = Color3.fromRGB(255, 224, 180),
        Saturation = -0.45, Contrast = 0.15})
    addFx("BlurEffect", "VintageBlur", {Size = 2})
end


-- ===== GRAFIK SUPER + CUACA =====
GraphicsPresets.SuperHD = function()
    setLight({Brightness = 3.2, GlobalShadows = true, ShadowSoftness = 0.1, ExposureCompensation = 0,
        EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1, FogEnd = 100000})
    local a = getAtmo()
    a.Density, a.Offset, a.Glare, a.Haze = 0.15, 0.1, 0.1, 0.5
    a.Color = Color3.fromRGB(190, 210, 235)
    a.Decay = Color3.fromRGB(120, 150, 190)
    addFx("ColorCorrectionEffect", "SuperHD", {Contrast = 0.25, Saturation = 0.3, Brightness = 0.02,
        TintColor = Color3.fromRGB(255, 250, 245)})
    addFx("BloomEffect", "SuperHDBloom", {Intensity = 0.3, Size = 24, Threshold = 1.2})
    addFx("SunRaysEffect", "SuperHDRays", {Intensity = 0.12, Spread = 0.7})
    setQuality(21)
end

GraphicsPresets.SuperCinematic = function()
    setLight({ClockTime = 17.4, Brightness = 2.1, GlobalShadows = true, ExposureCompensation = -0.2,
        ShadowSoftness = 0.25, FogEnd = 100000})
    local a = getAtmo()
    a.Density, a.Offset, a.Glare, a.Haze = 0.3, 0.2, 0.4, 1.8
    a.Color = Color3.fromRGB(255, 205, 160)
    a.Decay = Color3.fromRGB(230, 130, 80)
    addFx("ColorCorrectionEffect", "SuperCine", {TintColor = Color3.fromRGB(255, 226, 196),
        Contrast = 0.3, Saturation = 0.05, Brightness = -0.03})
    addFx("BloomEffect", "SuperCineBloom", {Intensity = 0.7, Size = 40, Threshold = 0.9})
    addFx("DepthOfFieldEffect", "SuperCineDOF", {FarIntensity = 0.25, FocusDistance = 35,
        InFocusRadius = 40, NearIntensity = 0})
    addFx("SunRaysEffect", "SuperCineRays", {Intensity = 0.25, Spread = 1})
    setQuality(21)
    startLetterbox(0.11)
end

--====================================
-- DEKORASI NATAL untuk preset Salju (hanya terlihat di layarmu)
-- Topi Santa di kepala + rusa kecil yang jalan di sampingmu + lampu kelap-kelip.
--====================================
local XmasDeco = {Hat = nil, Reindeer = nil, Lights = nil, Conn = nil, CharConn = nil}

-- ===== KEBUN SALJU: boneka salju, rusa & beruang kutub yang berjalan sendiri =====
-- Dibuat prosedural (tanpa Asset ID), hanya terlihat di layarmu. Muncul saat preset Salju aktif.
XmasDeco.Zoo = (function()
    local Z = {Folder = nil, Conn = nil, Animals = {}, Snowmen = {}, Params = nil, LastChar = nil}
    local rng = Random.new()
    local TAU = math.pi * 2

    local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

    local function part(parent, name, size, color, mat, shape)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.Color = color
        p.Material = mat or Enum.Material.SmoothPlastic
        if shape then p.Shape = shape end
        p.Anchored = false
        p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Parent = parent
        return p
    end

    local function weld(p0, p1, c0)
        local w = Instance.new("Weld")
        w.Part0, w.Part1, w.C0 = p0, p1, c0 or CFrame.new()
        w.Parent = p0
        return w
    end

    local function setFilter()
        local list = {Z.Folder}
        if LP.Character then list[#list + 1] = LP.Character end
        Z.Params.FilterDescendantsInstances = list
        Z.LastChar = LP.Character
    end

    -- tinggi tanah di (x, z); nil kalau air / tidak ada tanah
    local function groundAt(x, z, refY)
        local res = workspace:Raycast(Vector3.new(x, refY + 8, z), Vector3.new(0, -140, 0), Z.Params)
        if res and res.Material ~= Enum.Material.Water then return res.Position.Y end
        return nil
    end

    local function findSpot(center, rmin, rmax)
        for _ = 1, 12 do
            local ang = rng:NextNumber(0, TAU)
            local r = rng:NextNumber(rmin, rmax)
            local x, z = center.X + math.cos(ang) * r, center.Z + math.sin(ang) * r
            local gy = groundAt(x, z, center.Y)
            if gy and math.abs(gy - center.Y) < 14 then return Vector3.new(x, gy, z) end
        end
        return nil
    end

    ---------------- BONEKA SALJU ----------------
    local function poseArm(a, ang)
        a.W.C0 = CFrame.new(a.Side * 1.05, 2.7, 0) * CFrame.Angles(0, 0, a.Side * ang) * CFrame.new(a.Side * 0.95, 0, 0)
    end

    local function buildSnowman()
        local white, black = rgb(248, 250, 255), rgb(25, 25, 28)
        local m = Instance.new("Model")
        m.Name = "Snowman"
        local base = part(m, "Base", Vector3.new(3.4, 3.4, 3.4), white, Enum.Material.Snow, Enum.PartType.Ball)
        base.Anchored = true
        m.PrimaryPart = base
        local mid = part(m, "Mid", Vector3.new(2.5, 2.5, 2.5), white, Enum.Material.Snow, Enum.PartType.Ball)
        weld(base, mid, CFrame.new(0, 2.3, 0))
        local head = part(m, "Head", Vector3.new(1.8, 1.8, 1.8), white, Enum.Material.Snow, Enum.PartType.Ball)
        weld(base, head, CFrame.new(0, 4.1, 0))
        for _, s in ipairs({-1, 1}) do
            local eye = part(m, "Eye", Vector3.new(0.2, 0.2, 0.2), black, nil, Enum.PartType.Ball)
            weld(head, eye, CFrame.new(s * 0.32, 0.22, -0.8))
        end
        local nose = part(m, "Nose", Vector3.new(0.9, 0.22, 0.22), rgb(255, 140, 30), nil, Enum.PartType.Cylinder)
        weld(head, nose, CFrame.new(0, -0.05, -1.0) * CFrame.Angles(0, math.rad(90), 0))
        for i, y in ipairs({2.7, 2.3, 1.9}) do
            local b = part(m, "Button", Vector3.new(0.3, 0.3, 0.3), black, nil, Enum.PartType.Ball)
            weld(base, b, CFrame.new(0, y, i == 2 and -1.2 or -1.15))
        end
        local scarf = part(m, "Scarf", Vector3.new(0.4, 2.0, 2.0), rgb(200, 30, 40), Enum.Material.Fabric, Enum.PartType.Cylinder)
        weld(base, scarf, CFrame.new(0, 3.45, 0) * CFrame.Angles(0, 0, math.rad(90)))
        local brim = part(m, "Brim", Vector3.new(0.15, 1.9, 1.9), black, nil, Enum.PartType.Cylinder)
        weld(base, brim, CFrame.new(0, 4.95, 0) * CFrame.Angles(0, 0, math.rad(90)))
        local crown = part(m, "Crown", Vector3.new(1.0, 1.2, 1.2), black, nil, Enum.PartType.Cylinder)
        weld(base, crown, CFrame.new(0, 5.5, 0) * CFrame.Angles(0, 0, math.rad(90)))
        local arms = {}
        for _, side in ipairs({-1, 1}) do
            local arm = part(m, "Arm", Vector3.new(1.9, 0.18, 0.18), rgb(92, 62, 38), Enum.Material.Wood)
            local a = {W = weld(base, arm), Side = side}
            poseArm(a, math.rad(30))
            arms[#arms + 1] = a
        end
        return m, arms
    end

    local function addSnowman(center)
        local spot = findSpot(center, 12, 70)
        if not spot then return end
        local m, arms = buildSnowman()
        local dx, dz = center.X - spot.X, center.Z - spot.Z
        local yaw = math.atan2(-dx, -dz) + rng:NextNumber(-0.6, 0.6) -- menghadap ke arahmu
        m:PivotTo(CFrame.new(spot.X, spot.Y + 1.6, spot.Z) * CFrame.Angles(0, yaw, 0))
        m.Parent = Z.Folder
        Z.Snowmen[#Z.Snowmen + 1] = {Arms = arms, Phase = rng:NextNumber(0, TAU)}
    end

    ---------------- HEWAN ----------------
    local function buildDeer()
        local brown, dark, cream = rgb(150, 105, 66), rgb(112, 76, 46), rgb(236, 224, 205)
        local fab, wood = Enum.Material.Fabric, Enum.Material.Wood
        local m = Instance.new("Model")
        m.Name = "Deer"
        local body = part(m, "Body", Vector3.new(1.4, 1.3, 2.8), brown, fab)
        body.Anchored = true
        m.PrimaryPart = body
        local neck = part(m, "Neck", Vector3.new(0.6, 1.4, 0.6), brown, fab)
        weld(body, neck, CFrame.new(0, 0.7, -1.25) * CFrame.Angles(math.rad(-35), 0, 0))
        local head = part(m, "Head", Vector3.new(0.7, 0.7, 1.1), brown, fab)
        weld(body, head, CFrame.new(0, 1.35, -2.1) * CFrame.Angles(math.rad(15), 0, 0))
        local nose = part(m, "Nose", Vector3.new(0.28, 0.28, 0.28), rgb(20, 20, 20), nil, Enum.PartType.Ball)
        weld(head, nose, CFrame.new(0, -0.05, -0.6))
        for _, s in ipairs({-1, 1}) do
            local ear = part(m, "Ear", Vector3.new(0.12, 0.5, 0.28), dark, fab)
            weld(head, ear, CFrame.new(s * 0.38, 0.4, 0.25) * CFrame.Angles(0, 0, -s * math.rad(35)))
            local ant = part(m, "Antler", Vector3.new(0.1, 1.1, 0.1), rgb(205, 185, 150), wood)
            weld(head, ant, CFrame.new(s * 0.22, 0.85, 0.1) * CFrame.Angles(0, 0, -s * math.rad(18)))
            local br = part(m, "AntlerBranch", Vector3.new(0.08, 0.55, 0.08), rgb(205, 185, 150), wood)
            weld(head, br, CFrame.new(s * 0.34, 0.95, -0.1) * CFrame.Angles(math.rad(-30), 0, -s * math.rad(50)))
        end
        local tail = part(m, "Tail", Vector3.new(0.3, 0.4, 0.25), cream, fab)
        weld(body, tail, CFrame.new(0, 0.4, 1.45))
        local legs = {}
        for _, dx in ipairs({-0.5, 0.5}) do
            for _, dz in ipairs({-1.0, 1.0}) do
                local leg = part(m, "Leg", Vector3.new(0.32, 1.8, 0.32), dark, fab)
                legs[#legs + 1] = {W = weld(body, leg), dx = dx, dz = dz, hy = -0.65, len = 1.8}
            end
        end
        return m, legs, 2.45
    end

    local function buildBear()
        local white, grey, black = rgb(240, 244, 250), rgb(222, 228, 238), rgb(20, 20, 22)
        local fab = Enum.Material.Fabric
        local m = Instance.new("Model")
        m.Name = "PolarBear"
        local body = part(m, "Body", Vector3.new(2.6, 2.2, 3.6), white, fab)
        body.Anchored = true
        m.PrimaryPart = body
        local head = part(m, "Head", Vector3.new(1.5, 1.3, 1.4), white, fab)
        weld(body, head, CFrame.new(0, 0.6, -2.3))
        local snout = part(m, "Snout", Vector3.new(0.8, 0.6, 0.8), grey, fab)
        weld(head, snout, CFrame.new(0, -0.2, -0.95))
        local nose = part(m, "Nose", Vector3.new(0.3, 0.3, 0.3), black, nil, Enum.PartType.Ball)
        weld(snout, nose, CFrame.new(0, 0.12, -0.42))
        for _, s in ipairs({-1, 1}) do
            local eye = part(m, "Eye", Vector3.new(0.16, 0.16, 0.16), black, nil, Enum.PartType.Ball)
            weld(head, eye, CFrame.new(s * 0.42, 0.2, -0.72))
            local ear = part(m, "Ear", Vector3.new(0.45, 0.45, 0.25), grey, fab, Enum.PartType.Ball)
            weld(head, ear, CFrame.new(s * 0.62, 0.72, 0.1))
        end
        local tail = part(m, "Tail", Vector3.new(0.5, 0.5, 0.5), white, fab, Enum.PartType.Ball)
        weld(body, tail, CFrame.new(0, 0.7, 1.85))
        local legs = {}
        for _, dx in ipairs({-0.85, 0.85}) do
            for _, dz in ipairs({-1.25, 1.25}) do
                local leg = part(m, "Leg", Vector3.new(0.95, 1.5, 0.95), white, fab)
                legs[#legs + 1] = {W = weld(body, leg), dx = dx, dz = dz, hy = -1.1, len = 1.5}
            end
        end
        return m, legs, 2.6
    end

    local function pose(a)
        local bob = math.sin(a.Phase * 2) * 0.05 * a.Mv
        for _, l in ipairs(a.Legs) do
            local off = ((l.dx * l.dz) > 0) and 0 or math.pi
            local ang = math.sin(a.Phase + off) * a.Amp * a.Mv
            l.W.C0 = CFrame.new(l.dx, l.hy, l.dz) * CFrame.Angles(ang, 0, 0) * CFrame.new(0, -l.len / 2, 0)
        end
        a.Model:PivotTo(CFrame.new(a.Pos.X, a.Pos.Y + a.BodyH + bob, a.Pos.Z) * CFrame.Angles(0, a.Yaw, 0))
    end

    local function placeAnimal(a, center)
        local spot = findSpot(center, 25, 85)
        if not spot then return false end
        a.Pos, a.GroundY, a.Good = spot, spot.Y, spot
        a.Yaw = rng:NextNumber(0, TAU)
        a.State, a.Timer, a.Mv = "idle", rng:NextNumber(0.5, 4), 0
        return true
    end

    local function addAnimal(kind, center)
        local m, legs, h
        if kind == "bear" then m, legs, h = buildBear() else m, legs, h = buildDeer() end
        local a = {Kind = kind, Model = m, Legs = legs, BodyH = h, Phase = 0, Mv = 0, LastRay = 0,
            Speed = (kind == "bear") and 5 or 7.5, Amp = (kind == "bear") and 0.45 or 0.6}
        if not placeAnimal(a, center) then m:Destroy() return end
        m.Parent = Z.Folder
        pose(a)
        Z.Animals[#Z.Animals + 1] = a
    end

    local function step(a, dt, t, ppos)
        if not a.Model.Parent then return end
        -- terlalu jauh dari kamu: pindah lagi ke sekitarmu
        if ppos and (a.Pos - ppos).Magnitude > 170 then
            if placeAnimal(a, ppos) then pose(a) end
            return
        end
        if a.State == "idle" then
            a.Timer = a.Timer - dt
            if a.Timer <= 0 then
                local picked = false
                for _ = 1, 6 do
                    local ang = rng:NextNumber(0, TAU)
                    local dist = rng:NextNumber(8, 24)
                    local tx, tz = a.Pos.X + math.cos(ang) * dist, a.Pos.Z + math.sin(ang) * dist
                    local gy = groundAt(tx, tz, a.Pos.Y)
                    if gy and math.abs(gy - a.Pos.Y) < 6 then
                        a.Target = Vector3.new(tx, gy, tz)
                        a.State = "walk"
                        picked = true
                        break
                    end
                end
                if not picked then a.Timer = 1.5 end
            end
        else
            local to = Vector3.new(a.Target.X - a.Pos.X, 0, a.Target.Z - a.Pos.Z)
            local d = to.Magnitude
            if d < 1.2 then
                a.State = "idle"
                a.Timer = rng:NextNumber(2.5, 7)
            else
                local dir = to.Unit
                local want = math.atan2(-dir.X, -dir.Z)
                local diff = (want - a.Yaw + math.pi) % TAU - math.pi
                a.Yaw = a.Yaw + math.clamp(diff, -3 * dt, 3 * dt)
                if math.abs(diff) < 1.2 then
                    local fx, fz = -math.sin(a.Yaw), -math.cos(a.Yaw)
                    a.Pos = Vector3.new(a.Pos.X + fx * a.Speed * dt, a.Pos.Y, a.Pos.Z + fz * a.Speed * dt)
                end
            end
        end
        -- ikut kontur tanah (cek tiap 0.1 detik); air / tebing = mundur dan berhenti
        if t - a.LastRay > 0.1 then
            a.LastRay = t
            local gy = groundAt(a.Pos.X, a.Pos.Z, a.Pos.Y)
            if gy and math.abs(gy - a.GroundY) < 7 then
                a.GroundY, a.Good = gy, a.Pos
            elseif a.Good then
                a.Pos = a.Good
                a.State, a.Timer = "idle", 1
            end
        end
        a.Pos = Vector3.new(a.Pos.X, a.Pos.Y + (a.GroundY - a.Pos.Y) * math.min(dt * 10, 1), a.Pos.Z)
        a.Mv = a.Mv + (((a.State == "walk") and 1 or 0) - a.Mv) * math.min(dt * 8, 1)
        a.Phase = a.Phase + dt * a.Speed * 1.5 * (0.2 + 0.8 * a.Mv)
        pose(a)
    end

    function Z.Stop()
        if Z.Conn then Z.Conn:Disconnect() Z.Conn = nil end
        if Z.Folder then pcall(function() Z.Folder:Destroy() end) Z.Folder = nil end
        Z.Animals, Z.Snowmen = {}, {}
    end

    function Z.Start()
        Z.Stop()
        local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        Z.Folder = Instance.new("Folder")
        Z.Folder.Name = "DiiUi_SnowZoo"
        Z.Folder.Parent = workspace
        Z.Params = RaycastParams.new()
        Z.Params.FilterType = Enum.RaycastFilterType.Exclude
        Z.Params.RespectCanCollide = true
        setFilter()
        local c = root.Position
        for _ = 1, 8 do addSnowman(c) end
        for _ = 1, 5 do addAnimal("deer", c) end
        for _ = 1, 3 do addAnimal("bear", c) end
        Z.Conn = RunService.Heartbeat:Connect(function(dt)
            dt = math.min(dt, 0.1)
            local t = os.clock()
            if LP.Character ~= Z.LastChar then setFilter() end
            local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            local ppos = r and r.Position
            for _, a in ipairs(Z.Animals) do
                pcall(step, a, dt, t, ppos)
            end
            -- boneka salju diam (tidak bergerak); hanya rusa & beruang yang berjalan
        end)
    end

    return Z
end)()


local function buildSantaHat()
    local hat = Instance.new("Model")
    hat.Name = "DiiUi_SantaHat"
    local brim = Instance.new("Part")
    brim.Name = "Brim"
    brim.Shape = Enum.PartType.Cylinder
    brim.Size = Vector3.new(0.35, 1.3, 1.3)
    brim.Color = Color3.new(1, 1, 1)
    brim.Material = Enum.Material.Fabric
    brim.CanCollide, brim.CanTouch, brim.CanQuery, brim.Massless, brim.Anchored = false, false, false, true, false
    brim.Parent = hat
    local cone = Instance.new("Part")
    cone.Name = "Cone"
    cone.Shape = Enum.PartType.Block
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = "rbxasset://fonts/cone.mesh" -- cone bawaan Roblox, tanpa perlu Asset ID luar
    mesh.Scale = Vector3.new(1.1, 1.6, 1.1)
    mesh.Parent = cone
    cone.Size = Vector3.new(1, 1, 1)
    cone.Color = Color3.fromRGB(196, 30, 40)
    cone.Material = Enum.Material.Fabric
    cone.CanCollide, cone.CanTouch, cone.CanQuery, cone.Massless, cone.Anchored = false, false, false, true, false
    cone.Parent = hat
    local pom = Instance.new("Part")
    pom.Name = "Pom"
    pom.Shape = Enum.PartType.Ball
    pom.Size = Vector3.new(0.55, 0.55, 0.55)
    pom.Color = Color3.new(1, 1, 1)
    pom.Material = Enum.Material.Fabric
    pom.CanCollide, pom.CanTouch, pom.CanQuery, pom.Massless, pom.Anchored = false, false, false, true, false
    pom.Parent = hat
    local w1 = Instance.new("Weld")
    w1.Part0, w1.Part1 = brim, cone
    w1.C0 = CFrame.new(0, 0.55, 0) * CFrame.Angles(math.rad(90), 0, 0)
    w1.Parent = brim
    local w2 = Instance.new("Weld")
    w2.Part0, w2.Part1 = brim, pom
    w2.C0 = CFrame.new(0, 1.6, -0.35)
    w2.Parent = brim
    hat.PrimaryPart = brim
    return hat, brim
end

local function attachSantaHat(char)
    local head = char and char:FindFirstChild("Head")
    if not head then return nil end
    local hat, brim = buildSantaHat()
    local weld = Instance.new("Weld")
    weld.Name = "DiiUi_Attach"
    weld.Part0, weld.Part1 = head, brim
    weld.C0 = CFrame.new(0, 0.5, 0.05) * CFrame.Angles(math.rad(-6), 0, 0)
    weld.Parent = brim
    hat.Parent = char
    return hat
end

-- Rusa kecil (prosedural, tanpa Asset ID) yang berjalan mengikutimu dari belakang
local function buildReindeer()
    local m = Instance.new("Model")
    m.Name = "DiiUi_Reindeer"
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(1.6, 1.1, 2.2)
    body.Shape = Enum.PartType.Block
    body.Color = Color3.fromRGB(120, 78, 48)
    body.Material = Enum.Material.Fabric
    body.Anchored = true
    body.CanCollide, body.CanTouch, body.CanQuery = false, false, false
    body.Parent = m
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(0.8, 0.8, 0.9)
    head.Color = Color3.fromRGB(132, 88, 54)
    head.Material = Enum.Material.Fabric
    head.Anchored = true
    head.CanCollide, head.CanTouch, head.CanQuery = false, false, false
    head.Parent = m
    local nose = Instance.new("Part")
    nose.Name = "Nose"
    nose.Shape = Enum.PartType.Ball
    nose.Size = Vector3.new(0.3, 0.3, 0.3)
    nose.Color = Color3.fromRGB(220, 30, 30)
    nose.Material = Enum.Material.Neon
    nose.Anchored = true
    nose.CanCollide, nose.CanTouch, nose.CanQuery = false, false, false
    nose.Parent = m
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 60, 60)
    light.Range = 6
    light.Brightness = 2
    light.Parent = nose
    for i, side in ipairs({-1, 1}) do
        local antler = Instance.new("Part")
        antler.Name = "Antler" .. i
        antler.Size = Vector3.new(0.15, 0.7, 0.15)
        antler.Color = Color3.fromRGB(90, 60, 35)
        antler.Material = Enum.Material.Wood
        antler.Anchored = true
        antler.CanCollide, antler.CanTouch, antler.CanQuery = false, false, false
        antler.Parent = m
        antler:SetAttribute("Side", side)
    end
    for i, dx in ipairs({-0.55, 0.55}) do
        for j, dz in ipairs({-0.8, 0.8}) do
            local leg = Instance.new("Part")
            leg.Name = "Leg" .. i .. j
            leg.Size = Vector3.new(0.22, 1, 0.22)
            leg.Color = Color3.fromRGB(100, 68, 42)
            leg.Material = Enum.Material.Fabric
            leg.Anchored = true
            leg.CanCollide, leg.CanTouch, leg.CanQuery = false, false, false
            leg.Parent = m
            leg:SetAttribute("DX", dx)
            leg:SetAttribute("DZ", dz)
        end
    end
    m.PrimaryPart = body
    return m
end

local function spawnReindeer()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local m = buildReindeer()
    local startCf = root.CFrame * CFrame.new(3, 0, 4)
    m:PivotTo(startCf)
    m.Parent = workspace
    return m
end

local function updateReindeer(m, t, dt)
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local body = m:FindFirstChild("Body")
    if not (root and body) then return end
    -- selalu mengikuti agak di belakang-samping kamu, dengan sedikit jeda biar hidup
    local targetCf = root.CFrame * CFrame.new(3.2, 0, 3.5)
    local cur = XmasDeco.ReindeerCF or body.CFrame
    local alpha = 1 - math.exp(-dt * 3.2)
    local newPos = cur.Position:Lerp(targetCf.Position, alpha)
    local lookDir = (targetCf.Position - newPos)
    local flat = Vector3.new(lookDir.X, 0, lookDir.Z)
    local facing = flat.Magnitude > 0.1 and CFrame.lookAt(newPos, newPos + flat) or CFrame.new(newPos)
    local bob = math.sin(t * 4) * 0.08
    local finalCf = facing * CFrame.new(0, 1.6 + bob, 0)
    XmasDeco.ReindeerCF = finalCf
    body.CFrame = finalCf
    local head = m:FindFirstChild("Head")
    if head then head.CFrame = finalCf * CFrame.new(0, 0.55, -1.3) end
    local nose = m:FindFirstChild("Nose")
    if nose then nose.CFrame = finalCf * CFrame.new(0, 0.5, -1.75) end
    for i = 1, 2 do
        local a = m:FindFirstChild("Antler" .. i)
        if a then
            local side = a:GetAttribute("Side") or 1
            a.CFrame = finalCf * CFrame.new(0.25 * side, 1.0, -1.3) * CFrame.Angles(math.rad(20 * side), 0, math.rad(25 * side))
        end
    end
    for i = 1, 2 do
        for j = 1, 2 do
            local leg = m:FindFirstChild("Leg" .. i .. j)
            if leg then
                local dx, dz = leg:GetAttribute("DX") or 0, leg:GetAttribute("DZ") or 0
                local step = math.sin(t * 6 + (dx + dz) * 2) * 0.15
                leg.CFrame = finalCf * CFrame.new(dx, -0.55 + math.abs(step), dz)
            end
        end
    end
end
-- Lampu natal kelap-kelip mengorbit pelan di atas kepalamu
local function spawnXmasLights()
    local holder = Instance.new("Part")
    holder.Name = "DiiUi_XmasLightsRig"
    holder.Size = Vector3.new(0.2, 0.2, 0.2)
    holder.Transparency = 1
    holder.Anchored = true
    holder.CanCollide, holder.CanTouch, holder.CanQuery = false, false, false
    holder.Parent = workspace
    local colors = {
        Color3.fromRGB(220, 40, 40), Color3.fromRGB(40, 170, 80),
        Color3.fromRGB(255, 210, 60), Color3.fromRGB(60, 140, 230),
    }
    local bulbs = {}
    for i = 1, 8 do
        local b = Instance.new("Part")
        b.Name = "Bulb"
        b.Shape = Enum.PartType.Ball
        b.Size = Vector3.new(0.22, 0.22, 0.22)
        b.Material = Enum.Material.Neon
        b.Color = colors[((i - 1) % #colors) + 1]
        b.Anchored = true
        b.CanCollide, b.CanTouch, b.CanQuery = false, false, false
        b.Parent = holder
        local pl = Instance.new("PointLight")
        pl.Color = b.Color
        pl.Range = 5
        pl.Brightness = 1.5
        pl.Parent = b
        table.insert(bulbs, {Part = b, Light = pl, Offset = (i - 1) / 8 * math.pi * 2})
    end
    return holder, bulbs
end

local function updateXmasLights(rig, t)
    local char = LP.Character
    local head = char and char:FindFirstChild("Head")
    if not (rig and head) then return end
    for _, b in ipairs(rig.Bulbs or {}) do
        local ang = b.Offset + t * 1.1
        local pos = head.CFrame.Position + Vector3.new(math.cos(ang) * 1.6, 1.3 + math.sin(t * 2 + b.Offset) * 0.1, math.sin(ang) * 1.6)
        b.Part.CFrame = CFrame.new(pos)
        b.Light.Brightness = 1 + math.sin(t * 5 + b.Offset * 3) * 0.9
    end
end

local function createXmasDeco()
    removeXmasDeco()
    -- topi Santa di kepala dihilangkan (permintaan)
    XmasDeco.Reindeer = spawnReindeer()
    -- lampu natal di atas kepala dihilangkan (permintaan)
    XmasDeco.Active = true
    pcall(XmasDeco.Zoo.Start)
    local t0 = os.clock()
    XmasDeco.Conn = RunService.Heartbeat:Connect(function(dt)
        local t = os.clock() - t0
        if XmasDeco.Reindeer and XmasDeco.Reindeer.Parent then
            pcall(updateReindeer, XmasDeco.Reindeer, t, dt)
        end
        if XmasDeco.Lights and XmasDeco.Lights.Parent then
            pcall(updateXmasLights, XmasDeco.Lights, t)
        end
    end)
end

Gui.Destroying:Connect(function() pcall(removeXmasDeco) end)

removeXmasDeco = function()
    XmasDeco.Active = false
    if XmasDeco.Conn then XmasDeco.Conn:Disconnect() XmasDeco.Conn = nil end
    if XmasDeco.CharConn then XmasDeco.CharConn:Disconnect() XmasDeco.CharConn = nil end
    if XmasDeco.Hat then pcall(function() XmasDeco.Hat:Destroy() end) XmasDeco.Hat = nil end
    if XmasDeco.Reindeer then pcall(function() XmasDeco.Reindeer:Destroy() end) XmasDeco.Reindeer = nil end
    if XmasDeco.Lights then pcall(function() XmasDeco.Lights:Destroy() end) XmasDeco.Lights = nil end
    pcall(XmasDeco.Zoo.Stop)
    XmasDeco.ReindeerCF = nil
end

-- Salju: salju turun + langit putih kebiruan + dekorasi Natal (topi, rusa, lampu)
GraphicsPresets.Salju = function()
    setLight({ClockTime = 13, Brightness = 2.2, GlobalShadows = true, ExposureCompensation = 0.15,
        FogStart = 30, FogEnd = 650, FogColor = Color3.fromRGB(215, 225, 238),
        Ambient = Color3.fromRGB(110, 125, 150), OutdoorAmbient = Color3.fromRGB(150, 165, 190)})
    local a = getAtmo()
    a.Density, a.Offset, a.Glare, a.Haze = 0.4, 0.15, 0, 1.8
    a.Color = Color3.fromRGB(225, 233, 245)
    a.Decay = Color3.fromRGB(180, 195, 215)
    addFx("ColorCorrectionEffect", "Salju", {TintColor = Color3.fromRGB(225, 236, 255),
        Saturation = -0.25, Contrast = 0.08, Brightness = 0.05})
    addFx("BloomEffect", "SaljuBloom", {Intensity = 0.35, Size = 28, Threshold = 1.1})
    setClouds(0.85, 0.7, Color3.fromRGB(235, 240, 248))
    applySnowGround()
    startWeather({Size = Vector3.new(90, 1, 90), Height = 24, Count = 3, Props = {
        Texture = SMOKE_TEX, Rate = 140,
        Color = ColorSequence.new(Color3.new(1, 1, 1)),
        Size = NumberSequence.new(0.28),
        Transparency = ns({0, 1}, {0.08, 0.15}, {0.9, 0.15}, {1, 1}),
        Lifetime = NumberRange.new(7, 10), Speed = NumberRange.new(2, 4),
        SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(1.2, -1.2, 0.4),
        Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
        LightInfluence = 0.2, LightEmission = 0.3,
    }})
    pcall(createXmasDeco)
end

-- Kemarau: terik, kering, berdebu, langit hampir tanpa awan
GraphicsPresets.Kemarau = function()
    setLight({ClockTime = 12.5, Brightness = 3.4, GlobalShadows = true, ExposureCompensation = 0.1,
        FogStart = 200, FogEnd = 2500, FogColor = Color3.fromRGB(240, 215, 170),
        Ambient = Color3.fromRGB(120, 100, 75), OutdoorAmbient = Color3.fromRGB(150, 130, 100)})
    local a = getAtmo()
    a.Density, a.Offset, a.Glare, a.Haze = 0.28, 0.2, 0.6, 2.2
    a.Color = Color3.fromRGB(240, 215, 170)
    a.Decay = Color3.fromRGB(210, 150, 90)
    addFx("ColorCorrectionEffect", "Kemarau", {TintColor = Color3.fromRGB(255, 226, 170),
        Contrast = 0.2, Saturation = -0.05, Brightness = 0.03})
    addFx("BloomEffect", "KemarauBloom", {Intensity = 0.5, Size = 30, Threshold = 0.95})
    addFx("SunRaysEffect", "KemarauRays", {Intensity = 0.25, Spread = 1})
    setClouds(0.08, 0.2, Color3.fromRGB(255, 245, 225))
    -- debu tipis melayang di sekitar kamera
    startWeather({Size = Vector3.new(70, 8, 70), Height = 3, Count = 1, Props = {
        Texture = SMOKE_TEX, Rate = 30,
        Color = ColorSequence.new(Color3.fromRGB(205, 175, 125)),
        Size = ns({0, 0.2}, {0.5, 0.9}, {1, 0.2}),
        Transparency = ns({0, 1}, {0.2, 0.82}, {0.8, 0.82}, {1, 1}),
        Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(1, 3),
        SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(1.5, 0.3, 0.5),
        Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-15, 15),
        LightInfluence = 0.6,
    }})
end

-- Hujan gerimis: ringan, langit abu terang
GraphicsPresets.Gerimis = function()
    setLight({ClockTime = 16, Brightness = 1.7, ExposureCompensation = -0.1,
        FogStart = 40, FogEnd = 900, FogColor = Color3.fromRGB(175, 185, 196),
        Ambient = Color3.fromRGB(95, 105, 120), OutdoorAmbient = Color3.fromRGB(125, 135, 150)})
    local a = getAtmo()
    a.Density, a.Offset, a.Glare, a.Haze = 0.35, 0.1, 0, 1.6
    a.Color = Color3.fromRGB(180, 190, 202)
    a.Decay = Color3.fromRGB(140, 150, 165)
    addFx("ColorCorrectionEffect", "Gerimis", {TintColor = Color3.fromRGB(210, 222, 235),
        Saturation = -0.18, Contrast = 0.05})
    setClouds(0.7, 0.55, Color3.fromRGB(200, 206, 214))
    applyWetGround(0.6)
    startWeather({Size = Vector3.new(70, 1, 70), Height = 22, Count = 2, Props = rainProps(55, 45, 60, 0.35, 0.55)})
end

-- Hujan deras: gelap, lebat, kabut tipis
GraphicsPresets.HujanDeras = function()
    setLight({ClockTime = 15, Brightness = 1.0, ExposureCompensation = -0.3,
        FogStart = 40, FogEnd = 350, FogColor = Color3.fromRGB(110, 120, 135),
        Ambient = Color3.fromRGB(80, 90, 105), OutdoorAmbient = Color3.fromRGB(100, 110, 125)})
    local a = getAtmo()
    a.Density, a.Offset, a.Glare, a.Haze = 0.45, 0.1, 0, 2.4
    a.Color = Color3.fromRGB(150, 160, 175)
    a.Decay = Color3.fromRGB(100, 110, 125)
    addFx("ColorCorrectionEffect", "HujanDeras", {TintColor = Color3.fromRGB(190, 203, 220),
        Saturation = -0.3, Contrast = 0.12})
    setClouds(0.95, 0.9, Color3.fromRGB(120, 128, 140))
    applyWetGround(1.0)
    startWeather({Size = Vector3.new(80, 1, 80), Height = 22, Count = 4, Props = rainProps(400, 70, 90, 0.45, 0.45)})
end

-- Hujan deras + kabut tebal: jarak pandang pendek
GraphicsPresets.HujanKabut = function()
    setLight({ClockTime = 15, Brightness = 0.85, ExposureCompensation = -0.35,
        FogStart = 0, FogEnd = 140, FogColor = Color3.fromRGB(135, 145, 158),
        Ambient = Color3.fromRGB(85, 95, 110), OutdoorAmbient = Color3.fromRGB(105, 115, 130)})
    local a = getAtmo()
    a.Density, a.Offset, a.Glare, a.Haze = 0.7, 0.3, 0, 3.5
    a.Color = Color3.fromRGB(160, 170, 182)
    a.Decay = Color3.fromRGB(110, 120, 135)
    addFx("ColorCorrectionEffect", "HujanKabut", {TintColor = Color3.fromRGB(175, 190, 205),
        Saturation = -0.35, Contrast = 0.08})
    setClouds(0.95, 0.9, Color3.fromRGB(125, 133, 145))
    applyWetGround(1.0)
    startWeather({Size = Vector3.new(80, 1, 80), Height = 22, Count = 4, Props = rainProps(400, 70, 90, 0.45, 0.5)})
end


-- ===== GRAFIK BARU 2 =====
-- Senja: matahari terbenam, langit oranye-pink
GraphicsPresets.Senja = function()
    setLight({ClockTime = 18.2, Brightness = 2.3, GlobalShadows = true, ExposureCompensation = -0.05,
        FogStart = 300, FogEnd = 4000, FogColor = Color3.fromRGB(255, 170, 120),
        Ambient = Color3.fromRGB(120, 85, 95), OutdoorAmbient = Color3.fromRGB(165, 110, 115),
        ColorShift_Top = Color3.fromRGB(255, 170, 110)})
    local a = getAtmo()
    a.Density, a.Offset, a.Glare, a.Haze = 0.3, 0.25, 0.8, 1.6
    a.Color = Color3.fromRGB(255, 175, 120)
    a.Decay = Color3.fromRGB(255, 110, 95)
    addFx("ColorCorrectionEffect", "Senja", {TintColor = Color3.fromRGB(255, 200, 170),
        Contrast = 0.18, Saturation = 0.12})
    addFx("BloomEffect", "SenjaBloom", {Intensity = 0.6, Size = 36, Threshold = 0.9})
    addFx("SunRaysEffect", "SenjaRays", {Intensity = 0.3, Spread = 1})
    setClouds(0.35, 0.5, Color3.fromRGB(255, 190, 160))
end

-- HD anti blur: tajam maksimal, blur/DOF game dimatikan, kabut udara dihilangkan
GraphicsPresets.HDAntiBlur = function()
    disableGameBlur()
    setLight({Brightness = 3, GlobalShadows = true, ShadowSoftness = 0.05, ExposureCompensation = 0,
        EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1, FogStart = 0, FogEnd = 100000})
    local a = getAtmo()
    a.Density, a.Offset, a.Glare, a.Haze = 0.05, 0, 0, 0
    addFx("ColorCorrectionEffect", "HDAntiBlur", {Contrast = 0.22, Saturation = 0.2, Brightness = 0})
    setQuality(21)
end

-- Cinematic + kabut: warna film, garis film, kabut tebal melayang
GraphicsPresets.CinematicKabut = function()
    setLight({ClockTime = 17, Brightness = 1.8, ExposureCompensation = -0.2, GlobalShadows = true,
        ShadowSoftness = 0.3, FogStart = 15, FogEnd = 380, FogColor = Color3.fromRGB(205, 200, 205),
        Ambient = Color3.fromRGB(110, 100, 110), OutdoorAmbient = Color3.fromRGB(140, 130, 140)})
    local a = getAtmo()
    a.Density, a.Offset, a.Glare, a.Haze = 0.55, 0.25, 0.3, 2.8
    a.Color = Color3.fromRGB(215, 205, 205)
    a.Decay = Color3.fromRGB(190, 150, 130)
    addFx("ColorCorrectionEffect", "CineKabut", {TintColor = Color3.fromRGB(255, 232, 210),
        Contrast = 0.28, Saturation = -0.12, Brightness = -0.02})
    addFx("BloomEffect", "CineKabutBloom", {Intensity = 0.8, Size = 44, Threshold = 0.85})
    addFx("DepthOfFieldEffect", "CineKabutDOF", {FarIntensity = 0.3, FocusDistance = 30,
        InFocusRadius = 35, NearIntensity = 0})
    addFx("SunRaysEffect", "CineKabutRays", {Intensity = 0.15, Spread = 1})
    setClouds(0.5, 0.6, Color3.fromRGB(225, 220, 225))
    setQuality(21)
    startLetterbox(0.11)
    -- kabut tipis melayang di sekitar kamera
    startWeather({Size = Vector3.new(80, 6, 80), Height = 2, Count = 2, Props = {
        Texture = SMOKE_TEX, Rate = 18,
        Color = ColorSequence.new(Color3.fromRGB(225, 225, 232)),
        Size = ns({0, 6}, {0.5, 12}, {1, 14}),
        Transparency = ns({0, 1}, {0.25, 0.86}, {0.75, 0.86}, {1, 1}),
        Lifetime = NumberRange.new(9, 12), Speed = NumberRange.new(0.5, 1.5),
        SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0.6, 0, 0.3),
        Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-6, 6),
        LightInfluence = 0.8,
    }})
end

-- Cinematic + hujan (suasana galau): biru gelap, murung, hujan, garis film
GraphicsPresets.CinematicGalau = function()
    setLight({ClockTime = 19.2, Brightness = 1.2, ExposureCompensation = -0.35, GlobalShadows = true,
        ShadowSoftness = 0.3, FogStart = 30, FogEnd = 500, FogColor = Color3.fromRGB(95, 110, 135),
        Ambient = Color3.fromRGB(60, 72, 95), OutdoorAmbient = Color3.fromRGB(80, 95, 120)})
    local a = getAtmo()
    a.Density, a.Offset, a.Glare, a.Haze = 0.45, 0.2, 0, 2.2
    a.Color = Color3.fromRGB(120, 135, 160)
    a.Decay = Color3.fromRGB(70, 85, 115)
    addFx("ColorCorrectionEffect", "CineGalau", {TintColor = Color3.fromRGB(190, 210, 240),
        Contrast = 0.3, Saturation = -0.35, Brightness = -0.03})
    addFx("BloomEffect", "CineGalauBloom", {Intensity = 0.9, Size = 44, Threshold = 0.8})
    addFx("DepthOfFieldEffect", "CineGalauDOF", {FarIntensity = 0.3, FocusDistance = 28,
        InFocusRadius = 30, NearIntensity = 0})
    setClouds(0.95, 0.85, Color3.fromRGB(90, 100, 118))
    setQuality(21)
    startLetterbox(0.12)
    applyWetGround(0.9)
    startWeather({Size = Vector3.new(80, 1, 80), Height = 22, Count = 3, Props = rainProps(250, 60, 80, 0.4, 0.45)})
end

function preset(name)
    do local PS = shared.DiiUiPersist if PS then PS.SetPreset(name) end end
    resetLighting() -- selalu mulai dari kondisi asli supaya efek tidak numpuk
    if name == "Reset" then
        setQuality(0) -- 0 = Automatic
        return
    end
    local fn = GraphicsPresets[name]
    if fn then
        local ok, err = pcall(fn)
        if not ok then warn("[DiiUi HUB] graphics: " .. tostring(err)) end
    end
end

end -- do graphics

local Inv = {}

do
-- INVISIBLE (diri sendiri + sembunyikan pemain lain, hanya di client)
local invisible = false          -- diri sendiri
local hideAllPlayers = false     -- semua pemain lain
local HiddenPlayers = {}         -- [Player] = true (per pemain)
local savedDecals = setmetatable({}, {__mode = "k"})

local function applyHide(char, hide)
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.LocalTransparencyModifier = hide and 1 or 0
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            if hide then
                if savedDecals[obj] == nil then savedDecals[obj] = obj.Transparency end
                obj.Transparency = 1
            elseif savedDecals[obj] ~= nil then
                obj.Transparency = savedDecals[obj]
                savedDecals[obj] = nil
            end
        elseif obj:IsA("BillboardGui") then
            obj.Enabled = not hide
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.DisplayDistanceType = hide and Enum.HumanoidDisplayDistanceType.None
                or Enum.HumanoidDisplayDistanceType.Viewer
        end)
    end
end

local function shouldHide(p)
    return hideAllPlayers or HiddenPlayers[p] == true
end

local function refreshOthers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then applyHide(p.Character, shouldHide(p)) end
    end
end

local function setInvisible(state)
    invisible = state
    applyHide(LP.Character, state)
end

local function setHideAll(state)
    hideAllPlayers = state
    refreshOthers()
end

local function setHidePlayer(p, state)
    HiddenPlayers[p] = state or nil
    applyHide(p.Character, shouldHide(p))
end

-- kamera dekat bisa mereset transparansi -> terapkan ulang berkala
task.spawn(function()
    while Gui.Parent do
        if invisible and LP.Character then
            for _, obj in ipairs(LP.Character:GetDescendants()) do
                if obj:IsA("BasePart") and obj.LocalTransparencyModifier ~= 1 then
                    obj.LocalTransparencyModifier = 1
                end
            end
        end
        if hideAllPlayers or next(HiddenPlayers) then refreshOthers() end
        task.wait(0.5)
    end
end)

local function hookPlayerHide(p)
    p.CharacterAdded:Connect(function(char)
        task.wait(0.8)
        if p ~= LP and shouldHide(p) then applyHide(char, true) end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then hookPlayerHide(p) end
end
Players.PlayerAdded:Connect(hookPlayerHide)
Players.PlayerRemoving:Connect(function(p) HiddenPlayers[p] = nil end)

-- INVISIBLE TAB
local function invisibleTab()
    clearContent()
    label("👻 INVISIBLE")
    button(invisible and "Diri Sendiri: ON  (tap untuk matikan)" or "Diri Sendiri: OFF  (tap untuk aktifkan)", function()
        setInvisible(not invisible)
        invisibleTab()
    end)
    button(hideAllPlayers and "Sembunyikan SEMUA Pemain: ON" or "Sembunyikan SEMUA Pemain: OFF", function()
        setHideAll(not hideAllPlayers)
        invisibleTab()
    end)
    label("DAFTAR PEMAIN  (tap = sembunyi / tampil)")
    local n = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            n = n + (1)
            local hidden = shouldHide(p)
            button((hidden and "🚫  " or "👁  ") .. p.Name, function()
                if hideAllPlayers then
                    notify("Matikan 'Sembunyikan SEMUA' dulu")
                    return
                end
                setHidePlayer(p, not HiddenPlayers[p])
                invisibleTab()
            end)
        end
    end
    if n == 0 then label("Belum ada pemain lain di server.") end
    button("🔄  Refresh Daftar", invisibleTab)
    label("Efek hanya terlihat di layar kamu sendiri (client).")
end

Inv.tab = invisibleTab
Inv.set = setInvisible
Inv.isOn = function() return invisible end
end -- do invisible

-- SPECTATOR
local spectating = false
local function stopSpectate()
    spectating = false
    local cam = workspace.CurrentCamera
    if cam then cam.CameraSubject = getHumanoid() end
end

local function spectatePlayer(name)
    name = string.lower(tostring(name or ""))
    if name == "" then return end
    local target
    for _, p in ipairs(Players:GetPlayers()) do
        local n, d = string.lower(p.Name), string.lower(p.DisplayName)
        if n == name or d == name then target = p break end
        if not target and (n:sub(1, #name) == name or d:sub(1, #name) == name) then
            target = p
        end
    end
    local hum = target and target.Character
        and target.Character:FindFirstChildOfClass("Humanoid")
    local cam = workspace.CurrentCamera
    if hum and cam then
        spectating = true
        cam.CameraSubject = hum
    end
end

-- TABS
local ActiveTab
local function makeTab(name, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -12, 0, compact and 34 or 37)
    b.BackgroundColor3 = Color3.fromRGB(48, 35, 70)
    b.Text = name
    b.TextColor3 = WHITE
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = compact and 11 or 13
    b.TextTruncate = Enum.TextTruncate.AtEnd
    b.Parent = Side
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    guardedClick(b, Side, function()
        ActiveTab = callback
        shared.DiiMergeHeader = nil
        local ok, err = pcall(callback)
        if not ok then warn("[DiiUi HUB] tab error: " .. tostring(err)) end
    end, 0.3)
end

-- HOME
local function homeTab()
    clearContent()
    label("WELCOME TO DiiUi HUB")
    label("Version 3.9 | Real Executor")
    label("Executor GUI test: successful!")
    label("M = Show / Hide GUI  |  F = Fly  |  G = Trik Fly  |  N = NoClip")
    label("Pilih menu di sebelah kiri.")
    button("Refresh Character", function()
        getCharacter()
        notify("Character refreshed")
    end)
end

-- GRAPHICS TAB
local function graphicsTab()
    clearContent()
    label("GRAPHICS SETTINGS")
    label("🌟 GRAFIK SUPER")
    button("🖥  DLSS 5 / RTX Ultra HD (Future lighting)", function() preset("DLSS5") notify("DLSS 5 Ultra aktif") end)
    button("💎  Super HD", function() preset("SuperHD") notify("Super HD aktif") end)
    button("🎞  Super Cinematic", function() preset("SuperCinematic") notify("Super Cinematic aktif") end)
    button("🌇  Senja", function() preset("Senja") notify("Senja aktif") end)
    button("🔍  HD Anti Blur", function() preset("HDAntiBlur") notify("HD Anti Blur aktif") end)
    button("🌫  Cinematic + Kabut", function() preset("CinematicKabut") notify("Cinematic + Kabut aktif") end)
    button("🌧  Cinematic + Hujan (Galau)", function() preset("CinematicGalau") notify("Cinematic Galau aktif") end)
    label("🌦 CUACA")
    button("❄  Salju", function() preset("Salju") notify("Salju aktif") end)
    button("☀  Kemarau", function() preset("Kemarau") notify("Kemarau aktif") end)
    button("🌦  Hujan Gerimis", function() preset("Gerimis") notify("Hujan gerimis aktif") end)
    button("🌧  Hujan Deras", function() preset("HujanDeras") notify("Hujan deras aktif") end)
    button("⛈  Hujan Deras + Kabut", function() preset("HujanKabut") notify("Hujan deras berkabut aktif") end)
    label("🎨 GRAFIK LAINNYA")
    button("🎬  Cinematic", function() preset("Cinematic") notify("Cinematic aktif") end)
    button("🌫  Kabut", function() preset("Kabut") notify("Kabut aktif") end)
    button("💎  Ultra HD", function() preset("UltraHD") notify("Ultra HD aktif") end)
    button("🌈  Vibrant (Anime)", function() preset("Vibrant") notify("Vibrant aktif") end)
    button("🌃  Cyberpunk Neon", function() preset("Cyberpunk") notify("Cyberpunk aktif") end)
    button("📽  Vintage", function() preset("Vintage") notify("Vintage aktif") end)
    button("HD Graphics", function() preset("HD") end)
    button("Low Graphics", function() preset("Low") end)
    button("Horror Mode", function() preset("Horror") end)
    button("Sunset Mode", function() preset("Sunset") end)
    button("Night Mode", function() preset("Night") end)
    button("🔁  Reset Graphics", function() preset("Reset") notify("Graphics direset") end)
end

-- TELEPORT TAB: AUTO PLAYER LIST
local function teleportTab()
    clearContent()

    label("📍 TELEPORT TO PLAYER")
    label("Pilih pemain dari daftar server:")

    local function refreshPlayers()
        clearContent()

        label("📍 TELEPORT TO PLAYER")
        label("PLAYER LIST - " .. #Players:GetPlayers() .. " PLAYERS")

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LP then
                button("📍  " .. player.Name, function()
                    local target = player.Character
                    local targetRoot = target and
                        target:FindFirstChild("HumanoidRootPart")

                    local myRoot = getCharacter():FindFirstChild(
                        "HumanoidRootPart"
                    )

                    if targetRoot and myRoot then
                        myRoot.CFrame =
                            targetRoot.CFrame * CFrame.new(0, 0, 3)
                        notify("Teleport dicoba ke " .. player.Name)
                    else
                        notify("Character pemain belum tersedia")
                    end
                end)
            end
        end

        button("🔄  Refresh Player List", refreshPlayers)
    end

    refreshPlayers()
end

-- SPECTATOR TAB
local function spectatorTab()
    clearContent()
    label("SPECTATOR")
    local nameBox = textbox("Masukkan username pemain")
    button("Spectate Player", function()
        spectatePlayer(nameBox.Text)
    end)
    button("Stop Spectating", stopSpectate)

    label("PLAYER LIST")
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            button(player.Name, function()
                spectatePlayer(player.Name)
            end)
        end
    end
end

--====================================
-- LIMITED ITEM VISUAL (CLIENT-SIDE COSMETIC PREVIEW)
-- Item hanya terlihat di client sendiri; tidak memberikan item/inventory.
--====================================
local LimitedPresets = {
    {Name="Spec Beta Biograft Energy Sword", AssetId=14876573, MeshId="rbxassetid://11996935", TextureId="rbxassetid://14876424", Effect="Diamond", Gear=true},
    {Name="St Patrick's Day Fairy", AssetId=226189871, MeshId="rbxassetid://226143404", TextureId="rbxassetid://226143506", Effect="Green"},
    {Name="Winter Fairy", AssetId=141742418, MeshId="rbxassetid://128216670", TextureId="rbxassetid://141740743", Effect="Cyan"},
    {Name="8-Bit HP Bar", AssetId=10159610478, Effect="Native"},
    {Name="8-Bit Extra Life", AssetId=10159606132, Effect="Native"},
    {Name="8-Bit Tabby Cat", AssetId=10159617728, Effect="Native"},
    {Name="8-Bit Roblox Coin", AssetId=10159622004, Effect="Native"},
    {Name="8-Bit Crown", AssetId=10159600649, Effect="Native"},
    {Name="Fiery Horns of the Netherworld", AssetId=215718515, Effect="Orange"},
    {Name="Frozen Horns of the Frigid Planes", AssetId=74891470, Effect="Blue"},
    {Name="Poisoned Horns of the Toxic Wasteland", AssetId=1744060292, Effect="GreenFire"},
    {Name="Sparkle Time Fedora", AssetId=1285307, Effect="Sparkles"},
    {Name="Valkyrie Helm", AssetId=1365767, Effect="None"},
    {Name="Dominus Empyreus", AssetId=21070012, Effect="None"},
    {Name="💀 Headless Horseman (Headless)", Special="Headless"},
    {Name="🦴 Korblox Deathspeaker (kaki kanan)", Special="Korblox"},
}

local LimitedActive = {}
local LimitedConfig = {}
Inv.LSync = {Send = false, View = true}
local selectedLimited = LimitedPresets[1].Name
local function defaultLimitedConfig()
    return {Scale=100, X=0, Y=0, Z=0, RX=0, RY=0, RZ=0, Effects=true}
end
local function getLimitedConfig(name)
    if not LimitedConfig[name] then LimitedConfig[name] = defaultLimitedConfig() end
    return LimitedConfig[name]
end
local function muteNative(handle, mute)
    for _, d in ipairs(handle:GetDescendants()) do
        if d:IsA("ParticleEmitter") and string.sub(d.Name, 1, 13) ~= "DiiUi_Limited" then
            d:SetAttribute("DiiUiOff", mute)
            if mute then d.Enabled = false end
        end
    end
end
local function addLimitedEffect(handle, kind)
    if kind == "None" or kind == "Native" then return end
    if kind == "Pixel" then
        -- AURA HALUS HD: kubah cahaya cyan menempel di mahkota + serpihan kuning/oranye di atas
        local function emitter(name, tex)
            local e = Instance.new("ParticleEmitter")
            e.Name = name
            e.Texture = tex
            e.LightEmission = 1
            e.LightInfluence = 0
            e.EmissionDirection = Enum.NormalId.Top
            e.Shape = Enum.ParticleEmitterShape.Box
            e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
            e.Rotation = NumberRange.new(0, 360)
            e.RotSpeed = NumberRange.new(-20, 20)
            e.Parent = handle
            return e
        end
        local function seq(...) return NumberSequence.new({...}) end
        local K = NumberSequenceKeypoint.new
        local C = ColorSequenceKeypoint.new
        local cyan = Color3.fromRGB(40, 225, 235)
        local green = Color3.fromRGB(80, 230, 120)
        local yellow = Color3.fromRGB(235, 230, 60)
        local orange = Color3.fromRGB(255, 120, 40)

        -- 1) kubah cahaya lebar, rendah, menempel di mahkota
        local dome = emitter("DiiUi_LimitedHaze", "rbxasset://textures/particles/smoke_main.dds")
        dome.Color = ColorSequence.new({C(0, cyan), C(1, cyan:Lerp(green, 0.5))})
        dome.Size = seq(K(0, 1.8), K(0.5, 2.4), K(1, 2.8))
        dome.Transparency = seq(K(0, 1), K(0.2, 0.55), K(0.7, 0.8), K(1, 1))
        dome.Lifetime = NumberRange.new(0.9, 1.3)
        dome.Rate = 12
        dome.Speed = NumberRange.new(0.15, 0.5)
        dome.SpreadAngle = Vector2.new(45, 45)
        dome.Acceleration = Vector3.new(0, 0.5, 0)

        -- 2) inti terang cyan -> hijau (lembut, rendah)
        local core = emitter("DiiUi_LimitedAura", "rbxasset://textures/particles/fire_main.dds")
        core.Color = ColorSequence.new({C(0, cyan), C(0.6, cyan:Lerp(green, 0.6)), C(1, green)})
        core.Size = seq(K(0, 0.9), K(0.3, 1.5), K(1, 0.6))
        core.Transparency = seq(K(0, 1), K(0.15, 0.3), K(0.7, 0.65), K(1, 1))
        core.Lifetime = NumberRange.new(0.7, 1.1)
        core.Rate = 20
        core.Speed = NumberRange.new(0.4, 0.9)
        core.SpreadAngle = Vector2.new(25, 25)
        core.Acceleration = Vector3.new(0, 0.9, 0)

        -- 3) serpihan kuning -> oranye kecil di bagian atas
        local top = emitter("DiiUi_LimitedTop", "rbxasset://textures/particles/fire_main.dds")
        top.Color = ColorSequence.new({C(0, green), C(0.4, yellow), C(1, orange)})
        top.Size = seq(K(0, 0.45), K(0.4, 0.5), K(1, 0.15))
        top.Transparency = seq(K(0, 1), K(0.2, 0.35), K(0.7, 0.6), K(1, 1))
        top.Lifetime = NumberRange.new(1.0, 1.5)
        top.Rate = 9
        top.Speed = NumberRange.new(1.0, 1.8)
        top.SpreadAngle = Vector2.new(18, 18)
        top.Acceleration = Vector3.new(0, 0.6, 0)

        -- 4) butir cahaya halus
        local dust = emitter("DiiUi_LimitedDust", "rbxasset://textures/particles/sparkles_main.dds")
        dust.Color = ColorSequence.new({C(0, cyan), C(1, yellow)})
        dust.Size = seq(K(0, 0.16), K(1, 0))
        dust.Transparency = seq(K(0, 0.1), K(1, 1))
        dust.Lifetime = NumberRange.new(1.0, 1.8)
        dust.Rate = 6
        dust.Speed = NumberRange.new(0.6, 1.4)
        dust.SpreadAngle = Vector2.new(40, 40)

        -- cahaya lembut sekitar mahkota
        local glow = Instance.new("PointLight")
        glow.Name = "DiiUi_LimitedGlow"
        glow.Color = Color3.fromRGB(70, 230, 210)
        glow.Brightness = 1.5
        glow.Range = 6
        glow.Parent = handle
        return
    end
    if kind == "Diamond" or kind == "Crown" or kind == "Green" or kind == "Cyan" or kind == "Sparkles" then
        local color = kind == "Diamond" and Color3.fromRGB(190,240,255)
            or kind == "Green" and Color3.fromRGB(70,255,100)
            or kind == "Cyan" and Color3.fromRGB(130,230,255)
            or Color3.fromRGB(255,215,90)
        local pe = Instance.new("ParticleEmitter")
        pe.Name = "DiiUi_LimitedParticles"
        pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        pe.Color = ColorSequence.new(color)
        pe.LightEmission = 1
        pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0)})
        pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
        pe.Lifetime = NumberRange.new(0.6, 1.2)
        pe.Rate = 8
        pe.Speed = NumberRange.new(0.3, 1)
        pe.SpreadAngle = Vector2.new(180, 180)
        pe.Acceleration = Vector3.new(0, 1, 0)
        pe.Parent = handle
    else
        local fire = Instance.new("Fire")
        fire.Name = "DiiUi_LimitedFire"
        fire.Color = kind == "Orange" and Color3.fromRGB(255,140,30)
            or kind == "Blue" and Color3.fromRGB(60,170,255)
            or Color3.fromRGB(70,255,70)
        fire.SecondaryColor = fire.Color:Lerp(Color3.new(1,1,1), 0.35)
        fire.Size = 3
        fire.Heat = 5
        fire.Parent = handle
    end
end
local function applyLimitedTransform(name)
    local entry = LimitedActive[name]
    if not entry or not entry.Handle or not entry.Handle.Parent then return end
    local c = entry.Config
    local factor = math.clamp((tonumber(c.Scale) or 100) / 100, 0.1, 4)
    if entry.Weld then
        entry.Weld.C0 = entry.BaseC0
            * CFrame.new((c.X or 0)/10, (c.Y or 0)/10, (c.Z or 0)/10)
            * CFrame.Angles(math.rad(c.RX or 0), math.rad(c.RY or 0), math.rad(c.RZ or 0))
    end
    if entry.Mesh and entry.BaseMeshScale then
        entry.Mesh.Scale = entry.BaseMeshScale * factor
    elseif entry.BaseSize then
        entry.Handle.Size = entry.BaseSize * factor
    end
    entry.Handle:SetAttribute("DiiUiFXOn", c.Effects)
    for _, d in ipairs(entry.Handle:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Smoke") or d:IsA("PointLight") then
            d.Enabled = c.Effects and not d:GetAttribute("DiiUiOff")
        end
    end
end
local function removeLimitedItem(name)
    local entry = LimitedActive[name]
    if entry then
        pcall(function() entry.Model:Destroy() end)
        LimitedActive[name] = nil
    end
end
local AssetCache, AssetLoading = {}, {}
AssetCache.Err = {}   -- [id] = alasan gagal terakhir (disimpan di sini agar tidak menambah variabel lokal)
-- Muat aset dengan beberapa cara + batas waktu 15 detik (sebelumnya bisa menggantung selamanya
-- di executor yang GetObjects-nya macet, sehingga tombol item "tidak ada reaksi").
local function loadAsset(id)
    id = tonumber(id) or id
    if AssetCache[id] then return AssetCache[id] end
    if AssetLoading[id] then
        local t0 = os.clock()
        while AssetLoading[id] and os.clock() - t0 < 16 do task.wait(0.1) end
        return AssetCache[id]
    end
    AssetLoading[id] = true
    local finished = false
    task.spawn(function()
        local methods = {
            function() return game:GetObjects("rbxassetid://" .. tostring(id)) end,
            function() return game:GetObjects("http://www.roblox.com/asset/?id=" .. tostring(id)) end,
            function() return game:GetService("InsertService"):LoadAsset(tonumber(id)) end,
        }
        local lastErr = "tidak ada respon"
        for _, fn in ipairs(methods) do
            local ok, result = pcall(fn)
            local obj
            if ok then
                if type(result) == "table" then obj = result[1]
                elseif typeof(result) == "Instance" then obj = result end
                if not obj then lastErr = "aset kosong / tidak bisa diakses" end
            else
                lastErr = tostring(result)
            end
            if obj then
                -- InsertService membungkus aset di Model; ambil isinya kalau ada
                if obj:IsA("Model") and obj.Name == "Model" and #obj:GetChildren() == 1 and not obj:FindFirstChildWhichIsA("BasePart") then
                    local inner = obj:GetChildren()[1]
                    if inner then obj = inner end
                end
                AssetCache[id] = obj
                AssetCache.Err[id] = nil
                break
            end
        end
        if not AssetCache[id] then AssetCache.Err[id] = lastErr end
        finished = true
        AssetLoading[id] = nil
    end)
    local t0 = os.clock()
    while not finished and os.clock() - t0 < 15 do task.wait(0.1) end
    if not finished then
        AssetCache.Err[id] = "timeout (executor tidak merespon GetObjects)"
        AssetLoading[id] = nil
    end
    return AssetCache[id]
end
local function getAssetClone(id)
    local a = loadAsset(id)
    return a and a:Clone() or nil
end
local function preloadAsset(id)
    if id and not AssetCache[id] and not AssetLoading[id] then
        task.spawn(loadAsset, id)
    end
end
-- preload semua preset di latar belakang supaya saat ditekan langsung muncul
task.spawn(function()
    for _, it in ipairs(LimitedPresets) do
        preloadAsset(it.AssetId)
        task.wait(0.15)
    end
end)

-- HEADLESS & KORBLOX (visual lokal): bukan aksesori, tapi mengubah tampilan badan di layarmu.
-- Disimpan di LimitedPresets.Special supaya tidak menambah variabel lokal utama (batas 200).
do
    local SP = {}                 -- SP.Headless / SP.Korblox = state aktif
    LimitedPresets.Special = SP
    LimitedPresets.KorbloxId = ""
    local conn

    local function applyHeadless(char)
        local head = char:FindFirstChild("Head")
        if not head then return nil, "Head belum tersedia" end
        local oldT = head.Transparency
        local decals = {}
        for _, d in ipairs(head:GetChildren()) do
            if d:IsA("Decal") then decals[d] = d.Transparency end
        end
        head.Transparency = 1
        for d in pairs(decals) do d.Transparency = 1 end
        return {Char = char, Head = head, Undo = {function()
            if head.Parent then head.Transparency = oldT end
            for d, t in pairs(decals) do if d.Parent then d.Transparency = t end end
        end}}
    end

    local function applyKorblox(char)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return nil, "Humanoid belum tersedia" end
        local id = tonumber(string.match(tostring(LimitedPresets.KorbloxId or ""), "%d+"))
        local obj = id and getAssetClone(id) or nil
        local undo = {}
        if hum.RigType == Enum.HumanoidRigType.R6 then
            local leg = char:FindFirstChild("Right Leg")
            if not leg then return nil, "Right Leg tidak ditemukan" end
            -- ID bawaan ini dari ingatan saya & BELUM dites; kalau kosong/tidak muncul, isi Asset ID sendiri.
            local meshId, texId = "rbxassetid://902942096", "rbxassetid://902843398"
            if obj then
                local cm = obj:FindFirstChildWhichIsA("CharacterMesh", true)
                if cm and cm.MeshId ~= 0 then
                    meshId = "rbxassetid://" .. cm.MeshId
                    if cm.BaseTextureId ~= 0 then texId = "rbxassetid://" .. cm.BaseTextureId end
                end
            end
            local m = leg:FindFirstChildOfClass("SpecialMesh")
            if m then
                local o = {m.MeshType, m.MeshId, m.TextureId, m.Scale}
                table.insert(undo, function()
                    if m.Parent then m.MeshType, m.MeshId, m.TextureId, m.Scale = o[1], o[2], o[3], o[4] end
                end)
            else
                m = Instance.new("SpecialMesh")
                m.Name = "DiiUi_Korblox"
                m.Parent = leg
                table.insert(undo, function() m:Destroy() end)
            end
            m.MeshType = Enum.MeshType.FileMesh
            m.MeshId = meshId
            m.TextureId = texId
            m.Scale = Vector3.one
        else
            -- R15: butuh Asset ID paket kaki kanan R15 (yang berisi MeshPart), lalu dipasang menimpa kaki asli
            if not obj then
                return nil, "R15: isi dulu Asset ID Korblox kaki kanan R15 di kolom atas"
            end
            local found = 0
            for _, nm in ipairs({"RightUpperLeg", "RightLowerLeg", "RightFoot"}) do
                local orig = char:FindFirstChild(nm)
                local src = obj:FindFirstChild(nm, true)
                if orig and src and src:IsA("BasePart") then
                    local c = src:Clone()
                    for _, d in ipairs(c:GetDescendants()) do
                        if d:IsA("Weld") or d:IsA("Motor6D") or d:IsA("WeldConstraint")
                        or d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
                    end
                    c.Name = "DiiUi_Korblox_" .. nm
                    c.Anchored, c.CanCollide, c.CanTouch, c.CanQuery, c.Massless = false, false, false, false, true
                    local w = Instance.new("Weld")
                    w.Part0, w.Part1 = orig, c
                    w.Parent = c
                    c.Parent = char
                    local oldT = orig.Transparency
                    orig.Transparency = 1
                    table.insert(undo, function()
                        c:Destroy()
                        if orig.Parent then orig.Transparency = oldT end
                    end)
                    found = found + (1)
                end
            end
            if found == 0 then
                if obj then obj:Destroy() end
                return nil, "Asset itu tidak berisi MeshPart kaki R15 (RightUpperLeg/LowerLeg/Foot)"
            end
        end
        if obj then obj:Destroy() end
        return {Char = char, Undo = undo}
    end

    local function removeSpecial(kind)
        local st = SP[kind]
        if not st then return end
        for _, f in ipairs(st.Undo) do pcall(f) end
        SP[kind] = nil
        if not next(SP) and conn then conn:Disconnect() conn = nil end
    end

    local function ensureConn()
        if conn then return end
        conn = RunService.Heartbeat:Connect(function()
            local char = LP.Character
            for kind, st in pairs(SP) do
                if st.Char ~= char then
                    -- karakter respawn: pasang ulang ke karakter baru (dicoba tiap 0.5 dtk sampai siap)
                    if char and char:FindFirstChildOfClass("Humanoid") and os.clock() - (st.Retry or 0) > 0.5 then
                        st.Retry = os.clock()
                        local fn = (kind == "Headless") and applyHeadless or applyKorblox
                        local ok, new = pcall(fn, char)
                        if ok and new then
                            for _, f in ipairs(st.Undo) do pcall(f) end
                            SP[kind] = new
                        end
                    end
                elseif kind == "Headless" and st.Head and st.Head.Parent then
                    if st.Head.Transparency ~= 1 then st.Head.Transparency = 1 end
                    for _, d in ipairs(st.Head:GetChildren()) do
                        if d:IsA("Decal") and d.Transparency ~= 1 then d.Transparency = 1 end
                    end
                end
            end
        end)
    end

    function LimitedPresets.Toggle(kind)
        if SP[kind] then
            removeSpecial(kind)
            return true, "off"
        end
        local char = LP.Character
        if not char then return false, "Karakter belum tersedia" end
        local fn = (kind == "Headless") and applyHeadless or applyKorblox
        local st, err = fn(char)
        if not st then return false, err or "Gagal memasang" end
        SP[kind] = st
        ensureConn()
        return true
    end

    function LimitedPresets.ClearSpecial()
        for kind in pairs(table.clone(SP)) do removeSpecial(kind) end
    end
end

local function attachLimitedItem(item)
    if item.Special then return LimitedPresets.Toggle(item.Special) end
    local char = LP.Character
    local head = char and char:FindFirstChild("Head")
    if not head then return false, "Karakter/Head belum tersedia" end
    removeLimitedItem(item.Name)
    local asset = getAssetClone(item.AssetId)
    local model = Instance.new("Model")
    model.Name = "DiiUi_Limited_" .. item.Name:gsub("[^%w]", "_")
    local handle
    if asset then
        if asset:IsA("BasePart") then
            handle = asset
            handle.Parent = model
        elseif asset:IsA("Model") or asset:IsA("Accessory") or asset:IsA("Hat") or asset:IsA("Tool") then
            local found = asset:FindFirstChild("Handle", true) or asset:FindFirstChildWhichIsA("BasePart", true)
            if found then
                handle = found:Clone()
                handle.Parent = model
            end
            asset:Destroy()
        end
    end
    if not handle and not item.MeshId then
        model:Destroy()
        do
            local why = tostring(AssetCache.Err[tonumber(item.AssetId) or item.AssetId] or "")
            if why:find("GetObjects") and (why:find("nil") or why:find("not")) then
                why = "executor kamu tidak mendukung GetObjects"
            end
            return false, "Aset gagal dimuat: " .. (why ~= "" and why:sub(1, 70) or "ID salah / tidak bisa diakses")
        end
    end
    if not handle then
        handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(1,1,1)
        handle.Parent = model
        if item.MeshId then
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = item.MeshId
            mesh.TextureId = item.TextureId or ""
            mesh.Parent = handle
        end
    end
    for _, d in ipairs(handle:GetDescendants()) do
        if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") or d:IsA("SurfaceGui")
        or d:IsA("BillboardGui") or d:IsA("Beam") or d:IsA("Trail") then
            d:Destroy()
        end
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("TouchTransmitter") then
            d:Destroy()
        elseif d:IsA("BasePart") then
            d.CanCollide = false
            d.CanTouch = false
            d.CanQuery = false
            d.Massless = true
            d.Anchored = false
        end
    end
    local baseC0 = CFrame.new(0, 1.3 + (item.Lift or 0), 0) -- lebih tinggi agar tidak masuk kepala
    if item.Gear then baseC0 = CFrame.new(0.7, -0.7, -0.8) * CFrame.Angles(math.rad(-90), 0, 0) end
    if item.Effect == "Pixel" then muteNative(handle, true) end
    addLimitedEffect(handle, item.Effect)
    local weld = Instance.new("Weld")
    weld.Name = "DiiUi_Attach"
    weld.Part0 = item.Gear and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or head) or head
    weld.Part1 = handle
    weld.C0 = baseC0
    weld.Parent = handle
    model.Parent = char
    local mesh = handle:FindFirstChildOfClass("SpecialMesh")
    LimitedActive[item.Name] = {
        Model=model, Handle=handle, Weld=weld, BaseC0=baseC0,
        BaseSize=handle.Size, Mesh=mesh, BaseMeshScale=mesh and mesh.Scale or nil,
        Config=getLimitedConfig(item.Name), Item=item
    }
    applyLimitedTransform(item.Name)
    return true
end

local function limitedItemTab()
    local LSync = Inv.LSync
    local toggleButton = Inv.ToggleButton -- toggleButton baru didefinisikan di bawah; ambil lewat Inv supaya tidak jadi nil
    clearContent()
    label("LIMITED ITEM VISUAL")
    label("Preview kosmetik. Aktifkan Sinkron supaya terlihat oleh pengguna script ini lainnya.")
    toggleButton("🌐  Sinkron: kirim item saya ke pengguna lain", function() return LSync.Send end, function()
        LSync.SetSend(not LSync.Send)
        notify(LSync.Send and "Sinkron ON: item dikirim lewat 1 baris kode di chat" or "Sinkron OFF")
    end)
    toggleButton("👁  Lihat item pengguna script lain", function() return LSync.View end, function()
        LSync.SetView(not LSync.View)
    end)
    label("⚡ TEMPEL ASSET ID LALU GENERATE")
    local idBox = textbox("Tempel Asset ID atau link katalog")
    idBox:GetPropertyChangedSignal("Text"):Connect(function()
        preloadAsset(tonumber(string.match(idBox.Text or "", "%d%d%d+")))
    end)
    local function generate(gear)
        local id = tonumber(string.match(idBox.Text or "", "%d%d%d+"))
        if not id then notify("Tempel Asset ID yang valid dulu") return end
        local item = {Name = "Custom " .. id .. (gear and " (tangan)" or ""), AssetId = id, Effect = "None", Gear = gear}
        local ok, err = attachLimitedItem(item)
        if ok then
            selectedLimited = item.Name
            limitedItemTab()
            notify(item.Name .. " dipasang secara lokal")
        else
            notify(err)
        end
    end
    button("⚡ Generate & Pasang di Kepala", function() generate(false) end)
    button("⚡ Generate & Pasang di Tangan", function() generate(true) end)
    label("🦴 KORBLOX / 💀 HEADLESS")
    label("Ada di daftar preset paling bawah (tap = pasang, tap lagi = lepas). Korblox R15 butuh Asset ID kaki kanan R15 dari katalog; R6 boleh dikosongkan.")
    do
        local kbBox = textbox("Asset ID Korblox (opsional, wajib utk R15)")
        kbBox.Text = tostring(LimitedPresets.KorbloxId or "")
        LimitedPresets.KbBox = kbBox
        kbBox.FocusLost:Connect(function() LimitedPresets.KorbloxId = kbBox.Text end)
    end
    label("ITEM PRESET")
    for _, item in ipairs(LimitedPresets) do
        button("➕  " .. item.Name, function()
            if item.Special and LimitedPresets.KbBox and LimitedPresets.KbBox.Parent then
                LimitedPresets.KorbloxId = LimitedPresets.KbBox.Text
            end
            if not item.Special and not AssetCache[item.AssetId] then notify("Memuat " .. item.Name .. "...") end
            local ok, err = attachLimitedItem(item)
            if ok then
                if not item.Special then selectedLimited = item.Name end
                limitedItemTab()
                notify(item.Name .. (err == "off" and " dilepas" or " dipasang secara lokal"))
            else
                notify(err)
            end
        end)
    end
    button("LEPAS SEMUA LIMITED ITEM", function()
        for name in pairs(LimitedActive) do removeLimitedItem(name) end
        LimitedPresets.ClearSpecial()
        notify("Semua item visual dilepas")
    end)
    label("PENGATURAN ITEM AKTIF")
    local names = {}
    for name in pairs(LimitedActive) do table.insert(names, name) end
    table.sort(names)
    if #names == 0 then label("Pasang item terlebih dahulu untuk mengatur.") return end
    for _, name in ipairs(names) do
        button("Pilih: " .. name, function()
            selectedLimited = name
            limitedItemTab()
        end)
    end
    label("Terpilih: " .. selectedLimited)
    local cfg = getLimitedConfig(selectedLimited)
    label("Geser slider ke samping. ⏪ ⏩ untuk atur halus.")
    local fields = {
        {"Ukuran (%)", "Scale", 20, 300},
        {"Posisi X (kiri/kanan)", "X", -300, 300},
        {"Posisi Y (atas/bawah)", "Y", -300, 300},
        {"Posisi Z (depan/belakang)", "Z", -300, 300},
        {"Rotasi X", "RX", -180, 180},
        {"Rotasi Y", "RY", -180, 180},
        {"Rotasi Z", "RZ", -180, 180},
    }
    for _, field in ipairs(fields) do
        slider(field[1], field[3], field[4], cfg[field[2]], 1, function(v)
            cfg[field[2]] = v
            applyLimitedTransform(selectedLimited)
        end)
    end
    local effectChoices = {
        {"Asli (bawaan item)", "Native"}, {"Aura Halus HD", "Pixel"}, {"Sparkle Emas", "Crown"}, {"Sparkle Es", "Diamond"},
        {"Sparkle Hijau", "Green"}, {"Api Oranye", "Orange"}, {"Api Biru", "Blue"}, {"Tanpa Efek", "None"},
    }
    local entry = LimitedActive[selectedLimited]
    local function setEffectChoice(idx)
        if not entry or not entry.Handle then return end
        entry.EffectIdx = idx
        for _, d in ipairs(entry.Handle:GetDescendants()) do
            if string.sub(d.Name, 1, 13) == "DiiUi_Limited" then d:Destroy() end
        end
        muteNative(entry.Handle, effectChoices[idx][2] ~= "Native")
        addLimitedEffect(entry.Handle, effectChoices[idx][2])
        applyLimitedTransform(selectedLimited)
    end
    local curIdx = entry and (entry.EffectIdx or (entry.Item.Effect == "Pixel" and 2 or 1)) or 1
    local effBtn
    effBtn = button("Ganti Efek: " .. effectChoices[curIdx][1], function()
        curIdx = curIdx % #effectChoices + 1
        setEffectChoice(curIdx)
        effBtn.Text = "Ganti Efek: " .. effectChoices[curIdx][1]
    end)
    button("Efek: ON / OFF", function()
        cfg.Effects = not cfg.Effects
        applyLimitedTransform(selectedLimited)
        notify("Efek " .. (cfg.Effects and "ON" or "OFF"))
    end)
    button("Reset Transform", function()
        LimitedConfig[selectedLimited] = defaultLimitedConfig()
        if LimitedActive[selectedLimited] then
            LimitedActive[selectedLimited].Config = LimitedConfig[selectedLimited]
        end
        applyLimitedTransform(selectedLimited)
        limitedItemTab()
    end)
end

--====================================
-- LIMITED SYNC: dilihat sesama pengguna script ini
-- Cara kerja: item yang kamu pasang dikirim sebagai 1 baris kode singkat
-- "[DUI] ..." di chat. Pengguna script lain otomatis menyembunyikan baris itu
-- dan menampilkan item di karaktermu. Pemain tanpa script melihat baris kode
-- itu di chat dan TIDAK melihat itemnya.
--====================================
do
    local LSync = Inv.LSync
    local TextChatService = game:GetService("TextChatService")
    local TAG = "[DUI] "
    local EMPTY = TAG .. "-"
    local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
    local function toB36(n)
        n = math.floor(n)
        if n <= 0 then return "0" end
        local s = ""
        while n > 0 do
            local r = n % 36
            s = B36:sub(r + 1, r + 1) .. s
            n = (n - r) / 36
        end
        return s
    end
    local function fromB36(s)
        local n = 0
        for c in s:gmatch(".") do
            local i = B36:find(c, 1, true)
            if not i then return nil end
            n = n * 36 + (i - 1)
        end
        return n
    end

    ---------------- KIRIM ----------------
    local function build()
        local names = {}
        for name in pairs(LimitedActive) do names[#names + 1] = name end
        table.sort(names)
        local msg = TAG
        local count = 0
        for _, name in ipairs(names) do
            local e = LimitedActive[name]
            local it, c = e.Item, e.Config
            if it and it.AssetId and c then
                local part = table.concat({
                    toB36(it.AssetId), it.Gear and 1 or 0, c.Scale or 100,
                    c.X or 0, c.Y or 0, c.Z or 0, c.RX or 0, c.RY or 0, c.RZ or 0,
                }, ",")
                local nxt = msg .. (count > 0 and "." or "") .. part
                if #nxt > 190 then break end   -- batas panjang chat
                msg, count = nxt, count + 1
            end
        end
        return count > 0 and msg or EMPTY
    end

    local function sendText(text)
        pcall(function()
            local ch = TextChatService:FindFirstChild("TextChannels")
            local general = ch and ch:FindFirstChild("RBXGeneral")
            if general then
                general:SendAsync(text)
            else
                game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, "All")
            end
        end)
    end

    ---------------- TERIMA & TAMPILKAN ----------------
    local Remote = {}   -- [UserId] = {list=, models={}, token=0, conn=}

    local function parse(text)
        if type(text) ~= "string" or text:sub(1, #TAG) ~= TAG then return nil end
        local body = text:sub(#TAG + 1)
        local list = {}
        if body == "-" then return list end
        for item in body:gmatch("[^%.]+") do
            local f = {}
            for v in item:gmatch("[^,]+") do f[#f + 1] = v end
            local id = fromB36(f[1] or "")
            if id and #f >= 9 then
                list[#list + 1] = {
                    id = id, gear = f[2] == "1",
                    scale = math.clamp(tonumber(f[3]) or 100, 20, 300),
                    x = math.clamp(tonumber(f[4]) or 0, -300, 300),
                    y = math.clamp(tonumber(f[5]) or 0, -300, 300),
                    z = math.clamp(tonumber(f[6]) or 0, -300, 300),
                    rx = math.clamp(tonumber(f[7]) or 0, -180, 180),
                    ry = math.clamp(tonumber(f[8]) or 0, -180, 180),
                    rz = math.clamp(tonumber(f[9]) or 0, -180, 180),
                }
            end
            if #list >= 4 then break end
        end
        return list
    end

    local function clearRemote(uid)
        local r = Remote[uid]
        if not r then return end
        r.token = (r.token or 0) + 1
        for _, m in ipairs(r.models or {}) do pcall(function() m:Destroy() end) end
        r.models = {}
    end

    local function buildRemoteModel(id)
        local asset = getAssetClone(id)
        if not asset then return nil end
        local model = Instance.new("Model")
        model.Name = "DiiUi_RemoteLimited"
        local handle
        if asset:IsA("BasePart") then
            handle = asset
            handle.Parent = model
        else
            local found = asset:FindFirstChild("Handle", true) or asset:FindFirstChildWhichIsA("BasePart", true)
            if found then
                handle = found:Clone()
                handle.Parent = model
            end
            asset:Destroy()
        end
        if not handle then model:Destroy() return nil end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") or d:IsA("SurfaceGui")
            or d:IsA("BillboardGui") or d:IsA("Beam") or d:IsA("Trail")
            or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("TouchTransmitter") then
                d:Destroy()
            elseif d:IsA("BasePart") then
                d.CanCollide, d.CanTouch, d.CanQuery, d.Massless, d.Anchored = false, false, false, true, false
            end
        end
        return model, handle
    end

    local function render(plr)
        local r = Remote[plr.UserId]
        if not r or not LSync.View then return end
        clearRemote(plr.UserId)
        local token = r.token
        local char = plr.Character
        local head = char and char:FindFirstChild("Head")
        if not head then return end
        for _, d in ipairs(r.list) do
            task.spawn(function()
                local model, handle = buildRemoteModel(d.id)
                if not model then return end
                if token ~= r.token or not char.Parent then model:Destroy() return end
                local part0 = head
                local baseC0 = CFrame.new(0, 1.3, 0)
                if d.gear then
                    part0 = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or head
                    baseC0 = CFrame.new(0.7, -0.7, -0.8) * CFrame.Angles(math.rad(-90), 0, 0)
                end
                local factor = d.scale / 100
                local mesh = handle:FindFirstChildOfClass("SpecialMesh")
                if mesh then mesh.Scale = mesh.Scale * factor else handle.Size = handle.Size * factor end
                local weld = Instance.new("Weld")
                weld.Part0, weld.Part1 = part0, handle
                weld.C0 = baseC0 * CFrame.new(d.x / 10, d.y / 10, d.z / 10)
                    * CFrame.Angles(math.rad(d.rx), math.rad(d.ry), math.rad(d.rz))
                weld.Parent = handle
                model.Parent = char
                table.insert(r.models, model)
            end)
        end
    end

    local function onText(text, plr)
        if not plr or plr == LP then return end
        local list = parse(text)
        if not list then return end
        local r = Remote[plr.UserId]
        if not r then
            r = {models = {}, token = 0}
            Remote[plr.UserId] = r
        end
        r.list = list
        if not r.conn then
            r.conn = plr.CharacterAdded:Connect(function()
                task.wait(1)
                render(plr)
            end)
        end
        render(plr)
    end

    -- sembunyikan baris "[DUI] ..." dari chat milik pengguna script
    pcall(function()
        local old = TextChatService.OnIncomingMessage
        TextChatService.OnIncomingMessage = function(m)
            local props = old and old(m) or nil
            if type(m.Text) == "string" and m.Text:sub(1, #TAG) == TAG then
                props = props or Instance.new("TextChatMessageProperties")
                props.Text = ""
                props.PrefixText = ""
            end
            return props
        end
    end)
    pcall(function()
        TextChatService.MessageReceived:Connect(function(m)
            local src = m.TextSource
            if src then onText(m.Text, Players:GetPlayerByUserId(src.UserId)) end
        end)
    end)
    local function watch(plr)
        if plr == LP then return end
        plr.Chatted:Connect(function(msg) onText(msg, plr) end)
    end
    for _, p in ipairs(Players:GetPlayers()) do watch(p) end
    Players.PlayerAdded:Connect(function(p)
        watch(p)
        -- beri tahu pemain baru item apa yang sedang kamu pakai
        if LSync.Send and LSync.LastSent and LSync.LastSent ~= EMPTY then
            task.delay(8, function() sendText(LSync.LastSent) end)
        end
    end)
    Players.PlayerRemoving:Connect(function(p)
        clearRemote(p.UserId)
        local r = Remote[p.UserId]
        if r and r.conn then r.conn:Disconnect() end
        Remote[p.UserId] = nil
    end)

    -- pengatur kirim: kirim hanya kalau perubahan sudah stabil (hindari spam chat)
    LSync.LastSent, LSync.LastTime = EMPTY, 0
    LSync.SetSend = function(on)
        LSync.Send = on
        if on then LSync.LastSent = EMPTY end
    end
    LSync.SetView = function(on)
        LSync.View = on
        for uid, r in pairs(Remote) do
            if on then
                local plr = Players:GetPlayerByUserId(uid)
                if plr then render(plr) end
            else
                clearRemote(uid)
            end
        end
    end
    task.spawn(function()
        local pending, stable = nil, 0
        while true do
            task.wait(3)
            if LSync.Send then
                local msg = build()
                if msg ~= LSync.LastSent then
                    if msg == pending then stable = stable + (1) else pending, stable = msg, 1 end
                    if stable >= 2 and os.clock() - LSync.LastTime > 6 then
                        LSync.LastSent, LSync.LastTime = msg, os.clock()
                        pending, stable = nil, 0
                        sendText(msg)
                    end
                else
                    pending, stable = nil, 0
                end
            end
        end
    end)
end

LP.CharacterAdded:Connect(function()
    for name in pairs(LimitedActive) do LimitedActive[name] = nil end
    if Inv.isOn() then
        task.wait(1)
        pcall(Inv.set, true)
    end
end)

--====================================
-- FREE CAM (CLIENT CAMERA ONLY)
--====================================
local CAS = game:GetService("ContextActionService")
local freeCam = {Enabled=false, Speed=35, Sensitivity=0.22, FOV=70, Pitch=0, Yaw=0, CFrame=nil,
    SavedType=nil, SavedSubject=nil, SavedFOV=70, Rotating=false, Saved=nil, LookTouch=nil,
    Hold={X=0, Y=0, Z=0},
    -- fitur baru: kamera mengikuti & goyang
    Follow=false, FollowTarget=nil, FollowDist=12, FollowSmooth=8, FocusPos=nil,
    Shake=false, ShakeAmt=0.35, ShakeMove=false}
local freeCamConnection
local FREECAM_ACTION = "DiiUiFreeCamLock"
local lockKeys = {
    Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
    Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Space,
    Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
}

-- Pad kontrol sentuh (HP) - bisa digeser lewat header
local Pad = Instance.new("Frame")
Pad.Name = "FreeCamPad"
Pad.Size = UDim2.fromOffset(150, 172)
Pad.Position = UDim2.new(0, 10, 1, -190)
Pad.BackgroundTransparency = 1
Pad.Visible = false
Pad.Parent = Gui
local PadHandle = Instance.new("TextButton")
PadHandle.Size = UDim2.new(1, 0, 0, 24)
PadHandle.BackgroundColor3 = PURPLE
PadHandle.BackgroundTransparency = 0.25
PadHandle.Text = "🎥 Free Cam"
PadHandle.TextColor3 = WHITE
PadHandle.Font = Enum.Font.GothamBold
PadHandle.TextSize = 11
PadHandle.AutoButtonColor = false
PadHandle.Parent = Pad
Instance.new("UICorner", PadHandle).CornerRadius = UDim.new(0, 7)
makeDraggable(PadHandle, Pad)

local function holdButton(txt, x, y, axis, dir)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(46, 46)
    b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = Color3.fromRGB(40, 30, 65)
    b.BackgroundTransparency = 0.25
    b.Text = txt
    b.TextColor3 = WHITE
    b.Font = Enum.Font.GothamBold
    b.TextSize = 18
    b.AutoButtonColor = false
    b.Parent = Pad
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            freeCam.Hold[axis] = dir
            b.BackgroundColor3 = PURPLE
        end
    end)
    b.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if freeCam.Hold[axis] == dir then freeCam.Hold[axis] = 0 end
            b.BackgroundColor3 = Color3.fromRGB(40, 30, 65)
        end
    end)
end
holdButton("🔼", 52, 28, "Z", -1)
holdButton("⏪", 4, 76, "X", -1)
holdButton("⏩", 100, 76, "X", 1)
holdButton("🔽", 52, 124, "Z", 1)
holdButton("⏫", 4, 28, "Y", 1)
holdButton("⏬", 100, 28, "Y", -1)

-- Kunci karakter: tombol gerak tidak menggerakkan karakter selama Free Cam
local function lockCharacter(state)
    if state then
        CAS:BindActionAtPriority(FREECAM_ACTION, function()
            return Enum.ContextActionResult.Sink
        end, false, Enum.ContextActionPriority.High.Value, table.unpack(lockKeys))
    else
        CAS:UnbindAction(FREECAM_ACTION)
        local sv = freeCam.Saved
        if sv and sv.Hum and sv.Hum.Parent then
            sv.Hum.WalkSpeed = sv.WS
            if sv.UJP then sv.Hum.JumpPower = sv.JP else sv.Hum.JumpHeight = sv.JH end
        end
        freeCam.Saved = nil
    end
end

local function holdCharacterStill()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if not freeCam.Saved or freeCam.Saved.Hum ~= hum then
        freeCam.Saved = {Hum=hum, WS=hum.WalkSpeed, JP=hum.JumpPower, JH=hum.JumpHeight, UJP=hum.UseJumpPower}
    end
    hum.WalkSpeed = 0
    if freeCam.Saved.UJP then hum.JumpPower = 0 else hum.JumpHeight = 0 end
end

local function startFreeCam()
    local cam = workspace.CurrentCamera
    if not cam then return end
    freeCam.SavedType = cam.CameraType
    freeCam.SavedSubject = cam.CameraSubject
    freeCam.SavedFOV = cam.FieldOfView
    freeCam.CFrame = cam.CFrame
    local pitch, yaw = cam.CFrame:ToOrientation()
    freeCam.Pitch, freeCam.Yaw = pitch, yaw
    cam.CameraType = Enum.CameraType.Scriptable
    cam.FieldOfView = freeCam.FOV
    freeCam.Enabled = true
    freeCam.Hold.X, freeCam.Hold.Y, freeCam.Hold.Z = 0, 0, 0
    lockCharacter(true)
    Pad.Visible = UIS.TouchEnabled
    if freeCamConnection then freeCamConnection:Disconnect() end
    freeCamConnection = RunService.RenderStepped:Connect(function(dt)
        if not freeCam.Enabled then return end
        cam = workspace.CurrentCamera
        if not cam then return end
        holdCharacterStill()
        local move = Vector3.new(freeCam.Hold.X, freeCam.Hold.Y, freeCam.Hold.Z)
        if not UIS:GetFocusedTextBox() then
            if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + (Vector3.new(0,0,-1)) end
            if UIS:IsKeyDown(Enum.KeyCode.S) then move = move + (Vector3.new(0,0,1)) end
            if UIS:IsKeyDown(Enum.KeyCode.A) then move = move + (Vector3.new(-1,0,0)) end
            if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + (Vector3.new(1,0,0)) end
            if UIS:IsKeyDown(Enum.KeyCode.E) then move = move + (Vector3.new(0,1,0)) end
            if UIS:IsKeyDown(Enum.KeyCode.Q) then move = move + (Vector3.new(0,-1,0)) end
        end
        local rotation = CFrame.fromOrientation(freeCam.Pitch, freeCam.Yaw, 0)
        local speed = freeCam.Speed * (UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 0.35 or 1)
        local followRoot
        if freeCam.Follow then
            local fchar = (freeCam.FollowTarget and freeCam.FollowTarget.Character) or LP.Character
            followRoot = fchar and fchar:FindFirstChild("HumanoidRootPart")
        end
        if followRoot then
            -- MODE IKUTI: kamera mengorbit target, W/S = dekat/jauh, geser layar/klik kanan = putar
            freeCam.FollowDist = math.clamp(freeCam.FollowDist + move.Z * speed * 0.35 * dt, 3, 200)
            local focus = followRoot.Position + Vector3.new(0, 2, 0)
            local a = 1 - math.exp(-dt * freeCam.FollowSmooth)
            freeCam.FocusPos = freeCam.FocusPos and freeCam.FocusPos:Lerp(focus, a) or focus
            freeCam.CFrame = CFrame.new(freeCam.FocusPos) * rotation * CFrame.new(0, 0, freeCam.FollowDist)
        else
            freeCam.FocusPos = nil
            local delta = rotation:VectorToWorldSpace(move)
            if delta.Magnitude > 0 then delta = delta.Unit end
            freeCam.CFrame = CFrame.new(freeCam.CFrame.Position + delta * speed * dt) * rotation
        end
        local final = freeCam.CFrame
        if freeCam.Shake then
            -- GOYANG: noise halus (bukan acak kasar) supaya terasa seperti kamera genggam
            local amp = freeCam.ShakeAmt
            if freeCam.ShakeMove then
                local spd = followRoot and followRoot.AssemblyLinearVelocity.Magnitude or (move.Magnitude * speed)
                amp = amp * math.clamp(spd / 16, 0.15, 2.5)
            end
            local t = os.clock()
            local nx = math.noise(t * 7.3, 0.11, 0.31)
            local ny = math.noise(0.27, t * 7.9, 0.73)
            local nr = math.noise(0.51, 0.93, t * 6.1)
            final = final * CFrame.new(nx * amp * 0.9, ny * amp * 0.9, 0)
                * CFrame.Angles(math.rad(ny * amp * 3), math.rad(nx * amp * 3), math.rad(nr * amp * 4))
        end
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = final
        cam.FieldOfView = freeCam.FOV
    end)
end

local function stopFreeCam()
    freeCam.Enabled = false
    freeCam.Rotating = false
    freeCam.LookTouch = nil
    freeCam.Hold.X, freeCam.Hold.Y, freeCam.Hold.Z = 0, 0, 0
    freeCam.FocusPos = nil
    Pad.Visible = false
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    if freeCamConnection then freeCamConnection:Disconnect(); freeCamConnection = nil end
    lockCharacter(false)
    local cam = workspace.CurrentCamera
    if cam then
        cam.CameraType = freeCam.SavedType or Enum.CameraType.Custom
        cam.CameraSubject = freeCam.SavedSubject
            or (LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"))
        cam.FieldOfView = freeCam.SavedFOV or 70
    end
end

Gui.Destroying:Connect(function()
    if freeCam.Enabled then pcall(stopFreeCam) end
    pcall(LimitedPresets.ClearSpecial)
    for name in pairs(LimitedActive) do pcall(removeLimitedItem, name) end
end)

UIS.InputBegan:Connect(function(input, processed)
    if not freeCam.Enabled or processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        freeCam.Rotating = true
        UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
    elseif input.UserInputType == Enum.UserInputType.Touch and not freeCam.LookTouch then
        freeCam.LookTouch = input -- geser di layar kosong untuk melihat sekitar
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        freeCam.Rotating = false
        UIS.MouseBehavior = Enum.MouseBehavior.Default
    elseif input == freeCam.LookTouch then
        freeCam.LookTouch = nil
    end
end)
UIS.InputChanged:Connect(function(input)
    if not freeCam.Enabled then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement and freeCam.Rotating then
        freeCam.Yaw = freeCam.Yaw - math.rad(input.Delta.X * freeCam.Sensitivity)
        freeCam.Pitch = math.clamp(freeCam.Pitch - math.rad(input.Delta.Y * freeCam.Sensitivity), -math.rad(89), math.rad(89))
    elseif input == freeCam.LookTouch then
        freeCam.Yaw = freeCam.Yaw - math.rad(input.Delta.X * freeCam.Sensitivity * 1.4)
        freeCam.Pitch = math.clamp(freeCam.Pitch - math.rad(input.Delta.Y * freeCam.Sensitivity * 1.4), -math.rad(89), math.rad(89))
    elseif input.UserInputType == Enum.UserInputType.MouseWheel then
        freeCam.FOV = math.clamp(freeCam.FOV - input.Position.Z * 4, 10, 120)
    end
end)

local function freeCamTab()
    clearContent()
    label("FREE CAM")
    label("PC: WASD + Q/E, tahan klik kanan untuk melihat.\nHP: pakai tombol panah di layar, geser layar kosong untuk melihat. Karakter tidak ikut bergerak.")
    button(freeCam.Enabled and "Matikan Free Cam" or "Aktifkan Free Cam", function()
        if freeCam.Enabled then stopFreeCam() else startFreeCam() end
        freeCamTab()
    end)
    slider("Kecepatan", 1, 150, freeCam.Speed, 1, function(v) freeCam.Speed = v end)
    slider("FOV", 10, 120, freeCam.FOV, 1, function(v)
        freeCam.FOV = v
        if freeCam.Enabled and workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = v end
    end)
    slider("Sensitivitas Kamera", 0.05, 1, freeCam.Sensitivity, 0.01, function(v) freeCam.Sensitivity = v end, "%.2f")
    -- helper lokal (toggleButton & dn didefinisikan setelah fungsi ini, jadi tidak terlihat di sini)
    local function tgl(text, getState, onToggle)
        local b
        local function paint()
            local on = getState()
            b.Text = text .. (on and "  :  ON ✅" or "  :  OFF")
            b.BackgroundColor3 = on and Color3.fromRGB(40, 150, 90) or Color3.fromRGB(65, 39, 105)
        end
        b = button(text, function() onToggle() paint() end)
        paint()
    end
    label("🎥 KAMERA IKUTI")
    tgl("🎯  Kamera Ngikutin Karakter",
        function() return freeCam.Follow end,
        function()
            freeCam.Follow = not freeCam.Follow
            freeCam.FocusPos = nil
            if freeCam.Follow and not freeCam.Enabled then startFreeCam() end
            freeCamTab()
        end)
    do
        local who = freeCam.FollowTarget and freeCam.FollowTarget.Parent == Players
            and freeCam.FollowTarget.Name or "Diri sendiri"
        button("👤  Target ikut: " .. who .. "  (tap = ganti)", function()
            local list = {false}
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then table.insert(list, pl) end
            end
            local cur = 1
            for i, v in ipairs(list) do
                if v == (freeCam.FollowTarget or false) then cur = i end
            end
            local nxt = list[cur % #list + 1]
            freeCam.FollowTarget = nxt or nil
            freeCam.FocusPos = nil
            freeCamTab()
        end)
    end
    slider("Jarak Kamera (mode ikuti)", 3, 80, freeCam.FollowDist, 1, function(v) freeCam.FollowDist = v end)
    slider("Kehalusan Ikut (kecil = lembut)", 2, 30, freeCam.FollowSmooth, 1, function(v) freeCam.FollowSmooth = v end)
    label("📳 KAMERA GOYANG")
    tgl("📳  Kamera Goyang",
        function() return freeCam.Shake end,
        function()
            freeCam.Shake = not freeCam.Shake
            if freeCam.Shake and not freeCam.Enabled then startFreeCam() end
        end)
    tgl("🏃  Goyang makin kuat saat bergerak",
        function() return freeCam.ShakeMove end,
        function() freeCam.ShakeMove = not freeCam.ShakeMove end)
    slider("Kekuatan Goyang", 0.05, 2, freeCam.ShakeAmt, 0.05, function(v) freeCam.ShakeAmt = v end, "%.2f")
    button("Reset Kamera", function()
        freeCam.Speed, freeCam.FOV, freeCam.Sensitivity = 35, 70, 0.22
        freeCam.Follow, freeCam.Shake, freeCam.ShakeMove = false, false, false
        freeCam.FollowDist, freeCam.FollowSmooth, freeCam.ShakeAmt = 12, 8, 0.35
        freeCam.FollowTarget, freeCam.FocusPos = nil, nil
        if freeCam.Enabled then stopFreeCam() end
        freeCamTab()
    end)
end

--====================================
-- COIN HUTAN
-- Saldo coin (read-only) + pencari koin di map (highlight / ambil).
-- Jumlah koin bisa diatur lewat slider.
--====================================
local coinHutanTab
do
local CoinHutan = {
    Amount = 10,
    Keywords = {"coin", "koin"},
    Running = false,
    Highlights = {},
}

local function coinMatches(name)
    name = name:lower()
    for _, k in ipairs(CoinHutan.Keywords) do
        if k ~= "" and name:find(k, 1, true) then return true end
    end
    return false
end

local function coinPart(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end
end

local function coinScan()
    local found, seen = {}, {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) and coinMatches(obj.Name) then
            local part = coinPart(obj)
            local owner = part and part:FindFirstAncestorOfClass("Model")
            if part and not seen[part]
            and not (owner and Players:GetPlayerFromCharacter(owner)) then
                seen[part] = true
                table.insert(found, {obj = obj, part = part})
            end
        end
    end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        table.sort(found, function(x, y)
            return (x.part.Position - hrp.Position).Magnitude
                < (y.part.Position - hrp.Position).Magnitude
        end)
    end
    return found
end

local function coinClearHighlights()
    for _, h in ipairs(CoinHutan.Highlights) do pcall(function() h:Destroy() end) end
    CoinHutan.Highlights = {}
end

local function coinHighlight(list)
    coinClearHighlights()
    for i = 1, math.min(CoinHutan.Amount, #list) do
        local h = Instance.new("Highlight")
        h.FillColor = Color3.fromRGB(255, 215, 0)
        h.OutlineColor = Color3.new(1, 1, 1)
        h.FillTransparency = 0.3
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Adornee = list[i].obj
        h.Parent = Gui
        table.insert(CoinHutan.Highlights, h)
    end
end

Gui.Destroying:Connect(function()
    CoinHutan.Running = false
    coinClearHighlights()
end)

coinHutanTab = function()
    clearContent()
    label("🪙 COIN HUTAN")

    -- saldo coin (read-only)
    local balanceLabel = label("Coins: memuat...")
    local function refreshCoinBalance()
        local stats = LP:FindFirstChild("leaderstats")
        local coins = stats and (
            stats:FindFirstChild("Coins")
            or stats:FindFirstChild("Coin")
            or stats:FindFirstChild("Cash")
        )
        if coins and (coins:IsA("IntValue") or coins:IsA("NumberValue")) then
            balanceLabel.Text = "Coins: " .. tostring(coins.Value)
        else
            balanceLabel.Text = "Coins: tidak ditemukan"
        end
    end
    button("🔄  Refresh Coin Balance", refreshCoinBalance)
    refreshCoinBalance()

    -- pencari koin
    label("🔍 CARI KOIN DI MAP")
    slider("Jumlah Koin", 1, 100, CoinHutan.Amount, 1, function(v)
        CoinHutan.Amount = math.floor(v)
    end)

    local kb = textbox("Kata kunci nama koin, pisah koma (contoh: coin,koin)")
    kb.Text = table.concat(CoinHutan.Keywords, ",")
    local function applyKeywords()
        local list = {}
        for k in kb.Text:gmatch("[^,]+") do
            k = k:gsub("^%s+", ""):gsub("%s+$", ""):lower()
            if k ~= "" then table.insert(list, k) end
        end
        if #list > 0 then CoinHutan.Keywords = list end
    end

    local status = label("Siap.")
    local function setStatus(t)
        if status and status.Parent then status.Text = t end
    end

    button("🔍  Cari & tandai koin", function()
        applyKeywords()
        local list = coinScan()
        coinHighlight(list)
        setStatus(("Ditemukan %d koin, %d ditandai."):format(
            #list, math.min(CoinHutan.Amount, #list)))
    end)

    button("🪙  Ambil koin", function()
        if CoinHutan.Running then return end
        applyKeywords()
        local list = coinScan()
        if #list == 0 then
            setStatus("Koin tidak ditemukan. Coba ganti kata kunci.")
            return
        end
        coinHighlight(list)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        CoinHutan.Running = true
        task.spawn(function()
            local origin = hrp.CFrame
            local total = math.min(CoinHutan.Amount, #list)
            local got = 0
            for i = 1, total do
                if not CoinHutan.Running or not hrp.Parent then break end
                local item = list[i]
                if item.part and item.part.Parent then
                    hrp.CFrame = item.part.CFrame + Vector3.new(0, 2, 0)
                    if firetouchinterest then
                        pcall(function()
                            firetouchinterest(hrp, item.part, 0)
                            firetouchinterest(hrp, item.part, 1)
                        end)
                    end
                    got = got + (1)
                    setStatus(("Mengambil %d / %d"):format(got, total))
                    task.wait(0.25)
                end
            end
            if hrp.Parent then hrp.CFrame = origin end
            CoinHutan.Running = false
            setStatus(("Selesai: %d koin dikunjungi."):format(got))
        end)
    end)

    button("🛑  Stop / Hapus tanda", function()
        CoinHutan.Running = false
        coinClearHighlights()
        setStatus("Dihentikan.")
    end)

    label("Kalau koin tidak ketemu, ganti kata kunci sesuai nama koin di map.")
end
end

--====================================
-- SPEED & JUMP (1 menu: kecepatan lari + tinggi lompat)
-- Hanya mengubah Humanoid milik client sendiri.
--====================================
local Move = {Speed = nil, Jump = nil, Base = nil}
local function myHumanoid()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function applyMove()
    if freeCam.Enabled then return end
    local hum = myHumanoid()
    if not hum then return end
    if Move.Speed and hum.WalkSpeed ~= Move.Speed then
        hum.WalkSpeed = Move.Speed
    end
    if Move.Jump then
        if hum.UseJumpPower then
            if hum.JumpPower ~= Move.Jump then hum.JumpPower = Move.Jump end
        else
            local h = (Move.Jump ^ 2) / (2 * math.max(workspace.Gravity, 1))
            if math.abs(hum.JumpHeight - h) > 0.01 then hum.JumpHeight = h end
        end
    end
end
local function captureMoveBase()
    if Move.Base or freeCam.Enabled then return end
    local hum = myHumanoid()
    if hum then
        Move.Base = {WS = hum.WalkSpeed, JP = hum.JumpPower, JH = hum.JumpHeight, UJP = hum.UseJumpPower}
    end
end
local moveConn = RunService.Heartbeat:Connect(applyMove)
Gui.Destroying:Connect(function()
    moveConn:Disconnect()
    pcall(function()
        local hum, b = myHumanoid(), Move.Base
        if hum and b then
            hum.WalkSpeed = b.WS
            if b.UJP then hum.JumpPower = b.JP else hum.JumpHeight = b.JH end
        end
    end)
end)
LP.CharacterAdded:Connect(function() Move.Base = nil end)

local function moveSection()
    label("⚡ SPEED & JUMP")
    label("Kecepatan lari dan tinggi lompat dalam satu menu. Tetap aktif walau game mereset nilainya.")
    captureMoveBase()
    local hum = myHumanoid()
    local baseSpeed = Move.Speed or (Move.Base and Move.Base.WS) or (hum and hum.WalkSpeed) or 16
    local baseJump = Move.Jump or (Move.Base and Move.Base.JP) or (hum and hum.JumpPower) or 50
    slider("Kecepatan Lari", 0, 300, baseSpeed, 1, function(v)
        captureMoveBase()
        Move.Speed = v
        applyMove()
    end)
    slider("Tinggi Lompat", 0, 400, baseJump, 1, function(v)
        captureMoveBase()
        Move.Jump = v
        applyMove()
    end)
    button("Preset Normal (16 / 50)", function()
        captureMoveBase()
        Move.Speed, Move.Jump = 16, 50
        applyMove()
        Inv.movementTab()
    end)
    button("Preset Cepat (50 / 100)", function()
        captureMoveBase()
        Move.Speed, Move.Jump = 50, 100
        applyMove()
        Inv.movementTab()
    end)
    button("Preset Super (100 / 200)", function()
        captureMoveBase()
        Move.Speed, Move.Jump = 100, 200
        applyMove()
        Inv.movementTab()
    end)
    button("Reset ke Nilai Asli Game", function()
        local h, b = myHumanoid(), Move.Base
        Move.Speed, Move.Jump = nil, nil
        if h and b then
            h.WalkSpeed = b.WS
            if b.UJP then h.JumpPower = b.JP else h.JumpHeight = b.JH end
        end
        Inv.movementTab()
    end)
end

--====================================
-- UTIL: nama pemain
--====================================
local function dn(p)
    if p.DisplayName ~= p.Name then
        return p.DisplayName .. " (@" .. p.Name .. ")"
    end
    return p.Name
end

local PINK = Color3.fromRGB(255, 60, 140)
local CHIP = Color3.fromRGB(48, 35, 70)
local CARD = Color3.fromRGB(38, 29, 58)

-- forward declarations (dipakai lintas fitur)
local Fly = {Enabled = false, Speed = 60, Vel = Vector3.zero, Up = 0, Aura = 1, AuraOn = true, WingsOn = true, T = 0, Flat = Vector3.new(0, 0, -1), AnimOn = true, Style = 1, Spin = 0, TrickN = 0}
local stopFly
local updateTempelUI
local tempelUI = {cards = {}, subs = {}}

local toastLabel, toastToken = nil, 0
local function toast(msg)
    if not Gui.Parent then return end
    if not toastLabel then
        toastLabel = Instance.new("TextLabel")
        toastLabel.Name = "DiiUiToast"
        toastLabel.Size = UDim2.fromOffset(300, 36)
        toastLabel.AnchorPoint = Vector2.new(0.5, 0)
        toastLabel.Position = UDim2.new(0.5, 0, 0, 12)
        toastLabel.BackgroundColor3 = PANEL
        toastLabel.TextColor3 = WHITE
        toastLabel.Font = Enum.Font.GothamSemibold
        toastLabel.TextSize = 13
        toastLabel.TextWrapped = true
        toastLabel.ZIndex = 20
        toastLabel.Visible = false
        toastLabel.Parent = Gui
        Instance.new("UICorner", toastLabel).CornerRadius = UDim.new(0, 9)
        local st = Instance.new("UIStroke")
        st.Color = PINK
        st.Thickness = 1.2
        st.Parent = toastLabel
    end
    toastToken = toastToken + (1)
    local my = toastToken
    toastLabel.Text = tostring(msg)
    toastLabel.Visible = true
    task.delay(2.4, function()
        if toastToken == my and toastLabel then toastLabel.Visible = false end
    end)
end

-- kotak pilihan (grid 2 kolom). onPick(i) dipanggil saat ditekan. Mengembalikan fungsi refresh.
local function chipGrid(items, getSel, onPick, cellH)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -5, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.BackgroundTransparency = 1
    holder.Parent = Content
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0.5, -4, 0, cellH or 46)
    grid.CellPadding = UDim2.fromOffset(6, 6)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = holder
    local btns = {}
    local function refresh()
        local sel = getSel()
        for i, b in ipairs(btns) do
            b.BackgroundColor3 = (i == sel) and PURPLE or CHIP
        end
    end
    for i, name in ipairs(items) do
        local b = Instance.new("TextButton")
        b.Text = name
        b.TextColor3 = WHITE
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = compact and 11 or 12
        b.TextWrapped = true
        b.AutoButtonColor = true
        b.LayoutOrder = i
        b.Parent = holder
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        b.MouseButton1Click:Connect(function()
            local ok, err = pcall(onPick, i)
            if not ok then warn("[DiiUi HUB] " .. tostring(err)) end
            refresh()
        end)
        btns[i] = b
    end
    refresh()
    return refresh
end

-- tombol ON/OFF dengan warna status
local function toggleButton(text, getState, onToggle)
    local b
    local function paint()
        local on = getState()
        b.Text = text .. (on and "  :  ON ✅" or "  :  OFF")
        b.BackgroundColor3 = on and Color3.fromRGB(40, 150, 90) or Color3.fromRGB(65, 39, 105)
    end
    b = button(text, function()
        onToggle()
        paint()
        local PS = shared.DiiUiPersist
        if PS then PS.Toggle(text, getState()) end
    end)
    do local PS = shared.DiiUiPersist if PS then PS.Reg["t:" .. text] = {get = getState, set = onToggle} end end
    paint()
    return b, paint
end

--====================================
-- SALIN AVATAR (lokal, hanya terlihat di layarmu)
-- Cara kerja: menyalin Accessory, baju, celana, warna kulit, wajah
-- langsung dari karakter pemain (instan) atau dari data avatar online.
--====================================
local AVATAR_CLASSES = {"Accessory", "Hat", "Shirt", "Pants", "ShirtGraphic", "BodyColors", "CharacterMesh"}
local function isAvatarPiece(inst)
    for _, cn in ipairs(AVATAR_CLASSES) do
        if inst:IsA(cn) then return true end
    end
    return false
end

local avatarBackup
local avatarBox
LP.CharacterAdded:Connect(function() avatarBackup = nil end)

local function snapshotAvatar(char)
    if avatarBackup then return end
    local b = {Pieces = {}}
    for _, c in ipairs(char:GetChildren()) do
        if isAvatarPiece(c) then table.insert(b.Pieces, c:Clone()) end
    end
    local head = char:FindFirstChild("Head")
    if head then
        local f = head:FindFirstChildOfClass("Decal")
        local m = head:FindFirstChildOfClass("SpecialMesh")
        b.Face = f and f:Clone()
        b.HeadMesh = m and m:Clone()
    end
    avatarBackup = b
end

local function removeAvatarPieces(char)
    for _, c in ipairs(char:GetChildren()) do
        if isAvatarPiece(c) then c:Destroy() end
    end
end

local function putPiece(src, char, hum)
    local n = src:Clone()
    for _, d in ipairs(n:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
            d:Destroy()
        end
    end
    if n:IsA("Accessory") or n:IsA("Hat") then
        -- buang weld bawaan (masih menunjuk ke karakter asal), biar dipasang ulang ke karaktermu
        for _, d in ipairs(n:GetDescendants()) do
            if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then d:Destroy() end
        end
        pcall(function() hum:AddAccessory(n) end)
    end
    if n.Parent ~= char then n.Parent = char end
end

local function setHeadLook(head, face, mesh)
    if not head then return end
    if face then
        local old = head:FindFirstChildOfClass("Decal")
        if old then old:Destroy() end
        face:Clone().Parent = head
    end
    if mesh then
        local old = head:FindFirstChildOfClass("SpecialMesh")
        if old then old:Destroy() end
        mesh:Clone().Parent = head
    end
end

local function applyAvatarFrom(src, name)
    local char, hum = LP.Character, myHumanoid()
    if not (char and hum) then notify("Karakter belum tersedia") return false end
    local pieces = {}
    for _, c in ipairs(src:GetChildren()) do
        if isAvatarPiece(c) then table.insert(pieces, c) end
    end
    local sHead = src:FindFirstChild("Head")
    local sFace = sHead and sHead:FindFirstChildOfClass("Decal")
    local sMesh = sHead and sHead:FindFirstChildOfClass("SpecialMesh")
    if #pieces == 0 and not sFace then
        notify("Avatar " .. name .. " kosong / tidak bisa dibaca")
        return false
    end
    snapshotAvatar(char)
    removeAvatarPieces(char)
    for _, c in ipairs(pieces) do putPiece(c, char, hum) end
    setHeadLook(char:FindFirstChild("Head"), sFace, sMesh)
    notify("Avatar " .. name .. " disalin (" .. #pieces .. " item)")
    return true
end

local function restoreAvatar()
    local char, hum = LP.Character, myHumanoid()
    if not (char and hum and avatarBackup) then notify("Belum ada avatar yang disalin") return end
    removeAvatarPieces(char)
    for _, piece in ipairs(avatarBackup.Pieces) do putPiece(piece, char, hum) end
    setHeadLook(char:FindFirstChild("Head"), avatarBackup.Face, avatarBackup.HeadMesh)
    notify("Avatar asli dikembalikan")
end

local function copyAvatar(userId, name)
    -- 1) pemain ada di server -> salin langsung dari karakternya (instan)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.UserId == userId and p ~= LP and p.Character and p.Character:FindFirstChild("Head") then
            applyAvatarFrom(p.Character, name)
            return
        end
    end
    -- 2) tidak di server -> ambil data avatar online
    notify("Mengambil avatar " .. name .. "...")
    local ok, model = pcall(function() return Players:GetCharacterAppearanceAsync(userId) end)
    if ok and model then
        applyAvatarFrom(model, name)
        pcall(function() model:Destroy() end)
        return
    end
    -- 3) cadangan terakhir
    local hum = myHumanoid()
    local ok2, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(userId) end)
    if hum and ok2 and desc then
        snapshotAvatar(LP.Character)
        local ok3 = pcall(function() hum:ApplyDescription(desc) end)
        notify(ok3 and ("Avatar " .. name .. " diterapkan") or "Gagal menerapkan avatar")
    else
        notify("Gagal mengambil avatar (cek username / UserId)")
    end
end

local function avatarTab()
    clearContent()
    label("SALIN AVATAR")
    label("Tinggal tap username pemain, avatar langsung disalin. Hanya terlihat di layarmu.")
    local any = false
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            any = true
            button("👤  " .. dn(player), function()
                copyAvatar(player.UserId, player.Name)
            end)
        end
    end
    if not any then label("Belum ada pemain lain di server.") end
    button("🔙  Kembalikan Avatar Asli", restoreAvatar)
    label("PEMAIN DI LUAR SERVER (opsional)")
    avatarBox = textbox("Username atau UserId")
    button("Salin dari yang diketik", function()
        local txt = tostring(avatarBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if txt == "" then notify("Isi username atau UserId dulu") return end
        local uid = tonumber(txt)
        if not uid then
            local ok, res = pcall(function() return Players:GetUserIdFromNameAsync(txt) end)
            if not ok or not res then notify("Username tidak ditemukan") return end
            uid = res
        end
        copyAvatar(uid, txt)
    end)
    label("Catatan: bentuk badan R15 khusus (bundle) tidak ikut tersalin.")
end

--====================================
-- TEMPEL / BACKPACK V3
-- Tap username -> langsung menempel. Gaya bisa diganti kapan saja saat menempel.
-- Lepas: lompat, tombol ❌ di layar, atau tombol di menu.
--====================================
local Tempel = {Target = nil, StyleIdx = 1, T = 0, Saved = nil, AnimOn = true, Tracks = {}, AnimKey = nil, Predict = true, PredictMul = 2.2, Vel = nil, Precise = true, Tight = 0.85, MP = nil, MT = 0, MV = nil}
local TempelStyles = {
    {Name = "🎒 Backpack (di punggung)", Fn = function(t) return CFrame.new(0, 0.2, 1.3) end},
    {Name = "🐴 Gendong naik punggung", Fn = function(t) return CFrame.new(0, 1.0, 0.9) * CFrame.Angles(math.rad(-12), 0, 0) end},
    {Name = "🦸 Superman di punggung", Fn = function(t) return CFrame.new(0, 1.1 + math.sin(t * 3) * 0.15, 1.5) * CFrame.Angles(math.rad(-90), 0, 0) end},
    {Name = "🛌 Dibawa sambil tiduran", Fn = function(t) return CFrame.new(0, 0.4, 1.6) * CFrame.Angles(math.rad(90), 0, 0) end},
    {Name = "🦇 Gantung terbalik", Fn = function(t) return CFrame.new(0, -0.3 + math.sin(t * 2) * 0.2, 1.3) * CFrame.Angles(0, 0, math.pi) end},
    {Name = "🐒 Duduk di kepala", Fn = function(t) return CFrame.new(0, 3.6, 0) end},
    {Name = "🦜 Nangkring di bahu", Fn = function(t) return CFrame.new(1.5, 2.4, 0.2) * CFrame.Angles(0, 0, math.rad(-8)) end},
    {Name = "🤗 Peluk dari depan", Fn = function(t) return CFrame.new(0, 0, -1.3) * CFrame.Angles(0, math.pi, 0) end},
    {Name = "🚁 Melayang di atas kepala", Fn = function(t) return CFrame.new(0, 6 + math.sin(t * 2) * 0.6, 0) * CFrame.Angles(0, t * 2, 0) end},
    {Name = "🌀 Mengorbit pemain", Fn = function(t) return CFrame.Angles(0, t * 1.8, 0) * CFrame.new(0, math.sin(t * 3) * 0.8, -5) * CFrame.Angles(0, math.pi, 0) end},
    {Name = "💃 Muter-muter di depan", Fn = function(t) return CFrame.new(0, 0, -3.2) * CFrame.Angles(0, t * 8, 0) end},
    {Name = "🤝 Jalan bareng di samping", Fn = function(t) return CFrame.new(2.4, 0, 0.2) end},
    {Name = "🎢 Goyang-goyang di punggung", Fn = function(t) return CFrame.new(math.sin(t * 4) * 0.6, 0.2, 1.3) * CFrame.Angles(0, 0, math.sin(t * 4) * 0.3) end},
    {Name = "🐸 Loncat-loncat di kepala", Fn = function(t) return CFrame.new(0, 3.6 + math.abs(math.sin(t * 5)) * 2, 0) end},
    {Name = "👑 Duduk di pundak", Fn = function(t) return CFrame.new(0, 2.3, 0.35) end},
    {Name = "🏄 Surfing di atas kepala", Fn = function(t) return CFrame.new(0, 3.9, 0) * CFrame.Angles(0, math.rad(90), math.sin(t * 2.5) * 0.18) end},
    {Name = "🧲 Nempel di dada (depan)", Fn = function(t) return CFrame.new(0, 0.1, -1.05) end},
    {Name = "🕊 Sayap terbang di belakang", Fn = function(t) return CFrame.new(math.sin(t * 2) * 2.6, 1.6 + math.sin(t * 4) * 0.4, 2.3) * CFrame.Angles(math.rad(-25), 0, math.sin(t * 2) * 0.4) end},
    {Name = "🚶 Ngekor di belakang", Fn = function(t) return CFrame.new(0, 0, 3.6) end},
    {Name = "🌪 Spiral naik-turun", Fn = function(t) return CFrame.Angles(0, t * 3, 0) * CFrame.new(0, 3 + math.sin(t * 1.5) * 3, -3.5) * CFrame.Angles(0, math.pi, 0) end},
    {Name = "🗼 Totem (berdiri di atas kepala)", Fn = function(t) return CFrame.new(0, 5.2, 0) end},
    {Name = "💞 Gandengan tangan", Fn = function(t) return CFrame.new(-1.9, 0, -0.1) end},
    {Name = "🌀 Gasing di punggung", Fn = function(t) return CFrame.new(0, 0.2, 1.1) * CFrame.Angles(0, t * 9, 0) end},
    {Name = "🎈 Balon (ngambang di belakang atas)", Fn = function(t) return CFrame.new(0.8, 3.2 + math.sin(t * 2.2) * 0.5, 2.6) * CFrame.Angles(0, 0, math.sin(t * 2) * 0.15) end},
}
local TempelNames = {}
for i, st in ipairs(TempelStyles) do TempelNames[i] = st.Name end


-- ANIMASI GERAK saat menempel (animasi bawaan Roblox, ikut terlihat pemain lain)
Tempel.Ids = {
    R15 = {idle = 507766388, walk = 507777826, run = 507767714, jump = 507765000,
        fall = 507767968, climb = 507765644, sit = 2506281703, swim = 507784897,
        cheer = 507770677, laugh = 507770818, dance1 = 507771019, dance2 = 507776043},
    R6 = {idle = 180435571, walk = 180426354, run = 180426354, jump = 125750702,
        fall = 180436148, climb = 180436334, sit = 178130996, swim = 180436148,
        cheer = 129423030, laugh = 129423131, dance1 = 182435998, dance2 = 182436842},
}
-- per gaya: {animasi diam, animasi saat target bergerak, kecepatan diam, kecepatan gerak}
Tempel.AnimMap = {
    [1] = {"climb", "climb", 0.25, 1},    -- backpack: berpegangan di punggung
    [2] = {"climb", "climb", 0.25, 1},    -- gendong
    [3] = {"fall", "fall", 0.6, 1.2},     -- superman
    [4] = {"laugh", "laugh", 0.7, 1},     -- tiduran santai
    [5] = {"fall", "fall", 0.8, 1.4},     -- gantung terbalik
    [6] = {"sit", "sit", 1, 1},           -- duduk di kepala
    [7] = {"sit", "sit", 1, 1},           -- nangkring di bahu
    [8] = {"cheer", "cheer", 0.8, 1},     -- peluk
    [9] = {"swim", "swim", 0.8, 1.2},     -- melayang
    [10] = {"run", "run", 1, 1},          -- mengorbit
    [11] = {"dance1", "dance1", 1, 1},    -- muter-muter
    [12] = {"idle", "walk", 1, 1},        -- jalan bareng
    [13] = {"dance2", "dance2", 1, 1.2},  -- goyang-goyang
    [14] = {"jump", "jump", 1, 1.3},      -- loncat-loncat
    [15] = {"sit", "sit", 1, 1},          -- duduk di pundak
    [16] = {"idle", "idle", 1, 1},        -- surfing
    [17] = {"climb", "climb", 0.25, 1},   -- nempel di dada
    [18] = {"fall", "fall", 0.8, 1.3},    -- sayap terbang
    [19] = {"idle", "walk", 1, 1},        -- ngekor
    [20] = {"swim", "swim", 1, 1.2},      -- spiral
    [21] = {"idle", "idle", 1, 1},        -- totem
    [22] = {"idle", "walk", 1, 1},        -- gandengan tangan
    [23] = {"dance1", "dance1", 1.2, 1.4}, -- gasing
    [24] = {"swim", "swim", 0.7, 1},      -- balon
}

Tempel.StopAnim = function()
    for _, tr in pairs(Tempel.Tracks) do
        pcall(function() tr:Stop(0.15) end)
    end
    Tempel.Tracks = {}
    Tempel.AnimKey = nil
end

Tempel.UpdateAnim = function(hum, tr)
    if not Tempel.AnimOn then return end
    local ids = Tempel.Ids[hum.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15"]
    local map = Tempel.AnimMap[Tempel.StyleIdx] or Tempel.AnimMap[1]
    local v = tr.AssemblyLinearVelocity
    local speed = Vector3.new(v.X, 0, v.Z).Magnitude
    local moving = speed > 1.5
    local name = moving and map[2] or map[1]
    -- jalan bareng: jalan pelan / lari sesuai kecepatan target
    if Tempel.StyleIdx == 12 and moving then name = speed > 18 and "run" or "walk" end
    local rate = (moving and map[4] or map[3])
    if Tempel.StyleIdx == 12 and moving then rate = math.clamp(speed / 16, 0.5, 1.8) end

    local track = Tempel.Tracks[name]
    if not track then
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then animator = Instance.new("Animator") animator.Parent = hum end
        local a = Instance.new("Animation")
        a.AnimationId = "rbxassetid://" .. tostring(ids[name] or ids.idle)
        local ok, t = pcall(function() return animator:LoadAnimation(a) end)
        if not ok or not t then return end
        t.Priority = Enum.AnimationPriority.Action4
        t.Looped = true
        Tempel.Tracks[name] = t
        track = t
    end
    if Tempel.AnimKey ~= name then
        local old = Tempel.AnimKey and Tempel.Tracks[Tempel.AnimKey]
        if old then old:Stop(0.2) end
        track:Play(0.2)
        Tempel.AnimKey = name
    end
    if not track.IsPlaying then track:Play(0.1) end
    if track.IsPlaying then track:AdjustSpeed(rate) end
end

local tempelConn
local stopTempel

local detachBtn = Instance.new("TextButton")
detachBtn.Name = "DiiUiDetach"
detachBtn.Size = UDim2.fromOffset(140, 40)
detachBtn.Position = UDim2.new(0.5, -70, 1, -90)
detachBtn.BackgroundColor3 = Color3.fromRGB(190, 50, 80)
detachBtn.Text = "❌ Lepas Tempel"
detachBtn.TextColor3 = Color3.new(1, 1, 1)
detachBtn.Font = Enum.Font.GothamBold
detachBtn.TextSize = 13
detachBtn.AutoButtonColor = false
detachBtn.Visible = false
detachBtn.ZIndex = 6
detachBtn.Parent = Gui
Instance.new("UICorner", detachBtn).CornerRadius = UDim.new(0, 10)
makeDraggable(detachBtn, detachBtn, function() stopTempel("Dilepas") end)

function stopTempel(msg)
    local was = Tempel.Target ~= nil
    Tempel.Target = nil
    detachBtn.Visible = false
    local hum = myHumanoid()
    if hum then
        hum.PlatformStand = Tempel.Saved and Tempel.Saved.PS or false
        hum.AutoRotate = (not Tempel.Saved) or Tempel.Saved.AR
    end
    Tempel.Saved = nil
    Tempel.Cur = nil
    Tempel.From = nil
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    Tempel.StopAnim()
    if msg and was then toast(msg) end
    if updateTempelUI then updateTempelUI() end
end

Tempel.Pop = function(dur)
    if Tempel.Precise then
        Tempel.From = nil
        Tempel.Intro = 0
        return
    end
    Tempel.From = Tempel.Cur
    Tempel.Intro = os.clock()
    Tempel.IntroDur = dur or 0.18
end

local function startTempel(player)
    local hum = myHumanoid()
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not (player and hum and root) then toast("Karakter belum tersedia") return end
    if Fly.Enabled and stopFly then stopFly(true) end
    if not Tempel.Saved then
        Tempel.Saved = {PS = hum.PlatformStand, AR = hum.AutoRotate}
    end
    Tempel.Target = player
    Tempel.T = 0
    -- mulai dari posisi sekarang, nanti meluncur halus ke gaya tempel (tidak snap)
    Tempel.Cur = root.CFrame
    detachBtn.Visible = true
    -- animasi masuk: lompat kecil + easing, lalu terkunci TANPA delay
    if Tempel.Precise then
        Tempel.From = nil   -- tanpa animasi masuk: langsung terkunci di frame pertama
        Tempel.Intro = 0
        Tempel.IntroDur = 0.2
    else
        Tempel.From = root.CFrame
        Tempel.Intro = os.clock()
        Tempel.IntroDur = 0.22
    end
    Tempel.Last = os.clock()
    Tempel.Lean = 0
    Tempel.Vel = nil
    Tempel.MP, Tempel.MV, Tempel.MT = nil, nil, 0
    if not Tempel.Step then
        Tempel.Step = function()
            local tgt = Tempel.Target
            if not tgt then return end
            if tgt.Parent ~= Players then
                stopTempel("Target keluar dari server")
                return
            end
            local char = LP.Character
            local h = char and char:FindFirstChildOfClass("Humanoid")
            local r = char and char:FindFirstChild("HumanoidRootPart")
            local tr = tgt.Character and tgt.Character:FindFirstChild("HumanoidRootPart")
            if not (h and r and tr) then return end
            if h.PlatformStand ~= true then h.PlatformStand = true end
            h.AutoRotate = false

            local now = os.clock()
            local dt = math.clamp(now - (Tempel.Last or now), 0, 0.1)
            Tempel.Last = now
            Tempel.T = Tempel.T + (dt)
            local t = Tempel.T

            -- badan ikut miring sedikit sesuai arah/kecepatan target (hidup, bukan patung)
            -- kecepatan target dihaluskan sedikit supaya tidak bergetar
            -- velocity pemain lain sering 0/telat, jadi kita ukur sendiri dari selisih posisi
            -- (dihaluskan) dan dipakai kalau velocity bawaan tidak bisa dipercaya
            local rawV = tr.AssemblyLinearVelocity
            local trPos = tr.Position
            local mdt = now - (Tempel.MT or 0)
            if mdt >= 0.008 then
                if Tempel.MP and mdt < 0.3 then
                    local inst = (trPos - Tempel.MP) / mdt
                    if inst.Magnitude > 150 then inst = Vector3.zero end -- target teleport: abaikan
                    Tempel.MV = (Tempel.MV or inst):Lerp(inst, 1 - math.exp(-mdt * 14))
                else
                    Tempel.MV = Vector3.zero
                end
                Tempel.MP, Tempel.MT = trPos, now
            end
            local useV = (rawV.Magnitude > 1 and rawV.Magnitude < 150) and rawV or (Tempel.MV or Vector3.zero)
            if useV.Magnitude < 0.3 then useV = Vector3.zero end
            Tempel.Vel = (not Tempel.Precise and Tempel.Vel) and Tempel.Vel:Lerp(useV, 1 - math.exp(-dt * 45)) or useV
            local lv = tr.CFrame:VectorToObjectSpace(Tempel.Vel)
            local leanGoal = math.clamp(-lv.Z / 16, -1, 1) * math.rad(8)
            Tempel.Lean = Tempel.Lean + ((leanGoal - Tempel.Lean) * (1 - math.exp(-dt * 12)))

            -- gerak hidup: napas, hentakan langkah, dan goyang kiri-kanan ikut kecepatan target
            local spd = Vector3.new(Tempel.Vel.X, 0, Tempel.Vel.Z).Magnitude
            local walkAmt = math.min(spd / 16, 1)
            local stepRate = math.clamp(spd, 0, 24) * 0.6
            local bob = math.sin(t * 2.2) * 0.04 + math.abs(math.sin(t * stepRate)) * 0.14 * walkAmt
            local roll = math.sin(t * stepRate * 0.5) * 0.07 * walkAmt

            -- ANTI DELAY: posisi target di layar kita terlambat sebesar ping, jadi kita
            -- menempel ke posisi "tebakan ke depan" (posisi + kecepatan x ping)
            local lead = 0
            if Tempel.Predict then
                local okp, ping = pcall(function() return LP:GetNetworkPing() end)
                lead = math.clamp((okp and ping or 0) * Tempel.PredictMul, 0, 2.0)
            end
            local base = tr.CFrame + Tempel.Vel * lead

            -- offset gaya diskalakan oleh slider "Rapat" (kecil = lebih nempel, tanpa celah)
            local off = TempelStyles[Tempel.StyleIdx].Fn(t)
            off = CFrame.new(off.Position * (Tempel.Tight or 1)) * off.Rotation
            local desired
            if Tempel.Precise then
                desired = base * off   -- tepat di titik gaya, tanpa goyang tambahan
            else
                desired = base * off
                    * CFrame.new(0, bob, 0) * CFrame.Angles(Tempel.Lean, 0, roll)
            end

            local p = (now - (Tempel.Intro or 0)) / (Tempel.IntroDur or 0.2)
            if p < 1 and Tempel.From then
                -- easeOutBack: sedikit "overshoot" lalu mengunci, ditambah lengkung lompat
                local c1 = 1.70158
                local q = p - 1
                local e = 1 + (c1 + 1) * q * q * q + c1 * q * q
                local smooth = p * p * (3 - 2 * p)
                local pos = Tempel.From.Position:Lerp(desired.Position, e)
                    + Vector3.new(0, math.sin(math.pi * p) * 1.3, 0)
                Tempel.Cur = CFrame.new(pos) * Tempel.From.Rotation:Lerp(desired.Rotation, smooth)
            else
                Tempel.Cur = desired -- terkunci langsung ke target: tidak ada delay
            end
            r.CFrame = Tempel.Cur
            r.AssemblyLinearVelocity = (p < 1 and Tempel.From) and Vector3.zero or Tempel.Vel
            r.AssemblyAngularVelocity = Vector3.zero
            Tempel.UpdateAnim(h, tr)
        end
    end
    -- RenderStepped = posisi target paling baru (anti delay); Heartbeat = jaga sinkron fisika
    if not tempelConn then
        -- 150 = sebelum kamera membaca posisi (kamera ikut mulus), 2000 = pas sebelum frame digambar
        RunService:BindToRenderStep("DiiUiTempelA", 150, Tempel.Step)
        RunService:BindToRenderStep("DiiUiTempelB", 2000, Tempel.Step)
        tempelConn = {Disconnect = function()
            pcall(function() RunService:UnbindFromRenderStep("DiiUiTempelA") end)
            pcall(function() RunService:UnbindFromRenderStep("DiiUiTempelB") end)
        end}
    end
    if not Tempel.Conn2 then Tempel.Conn2 = RunService.Heartbeat:Connect(Tempel.Step) end
    -- sebelum fisika dihitung: posisi sudah benar saat server/replikasi mengambil posisimu
    if not Tempel.Conn3 then
        Tempel.Conn3 = (RunService.PreSimulation or RunService.Stepped):Connect(Tempel.Step)
    end
    toast("Menempel ke " .. player.Name .. "  •  gaya bisa diganti di menu")
    if updateTempelUI then updateTempelUI() end
end

UIS.JumpRequest:Connect(function()
    if Tempel.Target then stopTempel("Dilepas (lompat)") end
end)


Inv.Tempel, Inv.toast, Inv.dn = Tempel, toast, dn

updateTempelUI = function()
    local ui = tempelUI
    if not (ui.status and ui.status.Parent) then return end
    if Tempel.Target then
        ui.status.Text = "✅ Menempel ke  " .. dn(Tempel.Target) .. "\nGaya: " .. TempelStyles[Tempel.StyleIdx].Name
        ui.detach.Visible = true
    else
        ui.status.Text = "Belum menempel\nTap username pemain di bawah"
        ui.detach.Visible = false
    end
    if ui.chips then ui.chips() end
    for p, card in pairs(ui.cards) do
        local on = (Tempel.Target == p)
        card.BackgroundColor3 = on and PURPLE or CARD
        if ui.subs[p] then ui.subs[p].Text = on and "✅ sedang menempel" or "tap untuk menempel" end
    end
end

local function tempelTab()
    clearContent()
    tempelUI = {cards = {}, subs = {}}
    label("🎯 TEMPEL")
    toggleButton("🎞  Animasi gerak (tidak kaku)", function() return Tempel.AnimOn end, function()
        Tempel.AnimOn = not Tempel.AnimOn
        if not Tempel.AnimOn then Tempel.StopAnim() end
    end)
    toggleButton("🎯  No Delay (nempel instan, tanpa animasi/goyang)", function() return Tempel.Precise end, function()
        Tempel.Precise = not Tempel.Precise
        if Tempel.Precise then Tempel.From = nil Tempel.Intro = 0 end
    end)
    toggleButton("⚡  Anti delay (prediksi gerak)", function() return Tempel.Predict end, function()
        Tempel.Predict = not Tempel.Predict
    end)
    slider("Kekuatan prediksi delay (maks 15.0)", 0, 15, Tempel.PredictMul, 0.1, function(v) Tempel.PredictMul = v end, "%.1f")
    slider("Rapat / jarak tempel (kecil = lebih rapat)", 0.3, 1.5, Tempel.Tight, 0.05, function(v) Tempel.Tight = v end, "%.2f")
    label("Tip: kalau masih terasa ada jarak pas target lari kencang, nyalakan "
        .. "'No Delay' di atas (langsung terkunci, tanpa goyang tambahan) dan "
        .. "naikkan slider prediksi ini.")

    -- kartu status
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -5, 0, 56)
    f.BackgroundColor3 = DARK
    f.BorderSizePixel = 0
    f.Parent = Content
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 9)
    local fs = Instance.new("UIStroke")
    fs.Color = PINK
    fs.Thickness = 1
    fs.Parent = f
    local st = Instance.new("TextLabel")
    st.Size = UDim2.new(1, -104, 1, 0)
    st.Position = UDim2.fromOffset(10, 0)
    st.BackgroundTransparency = 1
    st.TextColor3 = WHITE
    st.Font = Enum.Font.GothamSemibold
    st.TextSize = 12
    st.TextWrapped = true
    st.TextXAlignment = Enum.TextXAlignment.Left
    st.Parent = f
    local dt = Instance.new("TextButton")
    dt.Size = UDim2.fromOffset(88, 34)
    dt.Position = UDim2.new(1, -96, 0.5, -17)
    dt.BackgroundColor3 = Color3.fromRGB(190, 50, 80)
    dt.Text = "❌ Lepas"
    dt.TextColor3 = WHITE
    dt.Font = Enum.Font.GothamBold
    dt.TextSize = 13
    dt.Parent = f
    Instance.new("UICorner", dt).CornerRadius = UDim.new(0, 8)
    dt.MouseButton1Click:Connect(function() stopTempel("Dilepas") end)
    tempelUI.status, tempelUI.detach = st, dt

    -- gaya (selalu terlihat, bisa diganti saat sedang menempel)
    label("GAYA  (tap = langsung berganti)")
    tempelUI.chips = chipGrid(TempelNames, function() return Tempel.StyleIdx end, function(i)
        Tempel.StyleIdx = i
        Tempel.T = 0
        Tempel.Pop(0.18)
        updateTempelUI()
    end, 48)
    button("🎲  Gaya Acak", function()
        Tempel.StyleIdx = math.random(1, #TempelStyles)
        Tempel.T = 0
        Tempel.Pop(0.18)
        updateTempelUI()
    end)

    -- pemain
    label("PEMAIN  (tap = langsung nempel)")
    local any = false
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            any = true
            local card = Instance.new("TextButton")
            card.Size = UDim2.new(1, -5, 0, 54)
            card.BackgroundColor3 = CARD
            card.Text = ""
            card.AutoButtonColor = true
            card.Parent = Content
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 9)
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.fromOffset(42, 42)
            img.Position = UDim2.fromOffset(8, 6)
            img.BackgroundColor3 = DARK
            img.BorderSizePixel = 0
            img.Parent = card
            Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
            task.spawn(function()
                local ok, url = pcall(function()
                    return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                end)
                if ok and url and img.Parent then img.Image = url end
            end)
            local nm = Instance.new("TextLabel")
            nm.Size = UDim2.new(1, -66, 0, 24)
            nm.Position = UDim2.fromOffset(58, 5)
            nm.BackgroundTransparency = 1
            nm.Text = dn(player)
            nm.TextColor3 = WHITE
            nm.Font = Enum.Font.GothamBold
            nm.TextSize = 13
            nm.TextXAlignment = Enum.TextXAlignment.Left
            nm.TextTruncate = Enum.TextTruncate.AtEnd
            nm.Parent = card
            local sub = Instance.new("TextLabel")
            sub.Size = UDim2.new(1, -66, 0, 18)
            sub.Position = UDim2.fromOffset(58, 29)
            sub.BackgroundTransparency = 1
            sub.Text = "tap untuk menempel"
            sub.TextColor3 = GREY
            sub.Font = Enum.Font.Gotham
            sub.TextSize = 11
            sub.TextXAlignment = Enum.TextXAlignment.Left
            sub.Parent = card
            card.MouseButton1Click:Connect(function() startTempel(player) end)
            tempelUI.cards[player] = card
            tempelUI.subs[player] = sub
        end
    end
    if not any then label("Belum ada pemain lain di server.") end

    label("Lepas: tekan lompat / tombol ❌ di layar / tombol ❌ Lepas.")
    updateTempelUI()
end

--====================================
-- FLY & NOCLIP (1 menu) + aura animasi
-- Pose/animasi badan (Motor6D), posisi & putaran tubuh terlihat SEMUA pemain.
-- Aura, sayap energi & partikel dibuat lokal, jadi hanya terlihat di layarmu.
--====================================
local NoClip = {Enabled = false}
local noclipSaved = setmetatable({}, {__mode = "k"})
local noclipActive = false
local noclipConn = RunService.Stepped:Connect(function()
    local want = NoClip.Enabled or Tempel.Target ~= nil
    local char = LP.Character
    if want and char then
        noclipActive = true
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then
                if noclipSaved[d] == nil then noclipSaved[d] = d.CanCollide end
                d.CanCollide = false
            end
        end
    elseif noclipActive and not want then
        noclipActive = false
        for part, was in pairs(noclipSaved) do
            if part.Parent then part.CanCollide = was end
            noclipSaved[part] = nil
        end
    end
end)

local AURAS = {
    {Name = "💗 Pink DiiHub", C1 = Color3.fromRGB(255, 60, 140), C2 = Color3.fromRGB(255, 190, 230)},
    {Name = "🔥 Api Neon", C1 = Color3.fromRGB(255, 80, 10), C2 = Color3.fromRGB(255, 220, 70)},
    {Name = "⚡ Petir Biru", C1 = Color3.fromRGB(40, 140, 255), C2 = Color3.fromRGB(200, 245, 255)},
    {Name = "🌌 Galaxy", C1 = Color3.fromRGB(140, 60, 255), C2 = Color3.fromRGB(60, 210, 255)},
    {Name = "🌈 Pelangi", Rainbow = true, C1 = Color3.fromRGB(255, 255, 255), C2 = Color3.fromRGB(255, 255, 255)},
    {Name = "❄ Es Kristal", C1 = Color3.fromRGB(130, 215, 255), C2 = Color3.fromRGB(255, 255, 255)},
    {Name = "🍀 Hijau Toxic", C1 = Color3.fromRGB(40, 255, 110), C2 = Color3.fromRGB(200, 255, 120)},
    {Name = "🖤 Dark Flame", C1 = Color3.fromRGB(110, 0, 160), C2 = Color3.fromRGB(255, 0, 80)},
}
local AuraNames = {}
for i, a in ipairs(AURAS) do AuraNames[i] = a.Name end

local function auraColor(a, k, t)
    if a.Rainbow then return Color3.fromHSV((t * 0.35 + k) % 1, 0.75, 1) end
    return a.C1:Lerp(a.C2, k)
end
local function auraSeq(a)
    if a.Rainbow then
        local kp = {}
        for i = 0, 6 do
            table.insert(kp, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 7, 0.75, 1)))
        end
        return ColorSequence.new(kp)
    end
    return ColorSequence.new(a.C1, a.C2)
end

local function clearAura()
    if Fly.Folder then pcall(function() Fly.Folder:Destroy() end) end
    if Fly.Parts then
        for _, o in ipairs(Fly.Parts) do pcall(function() o:Destroy() end) end
    end
    Fly.Folder, Fly.Parts, Fly.Orbs, Fly.Feathers, Fly.Emitter, Fly.Light, Fly.Haze = nil, nil, nil, nil, nil, nil, nil
end

local function buildAura(root)
    clearAura()
    if not Fly.AuraOn then return end
    local a = AURAS[Fly.Aura]
    local K = NumberSequenceKeypoint.new
    local folder = Instance.new("Folder")
    folder.Name = "DiiUi_FlyAura"
    folder.Parent = workspace.CurrentCamera or workspace
    local parts = {}
    local function keep(o) table.insert(parts, o) return o end
    local function att(x, y, z)
        local at = keep(Instance.new("Attachment"))
        at.Position = Vector3.new(x, y, z)
        at.Parent = root
        return at
    end
    local function trail(a0, a1, life, width)
        local tr = keep(Instance.new("Trail"))
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Lifetime = life
        tr.Color = auraSeq(a)
        tr.LightEmission = 1
        tr.Transparency = NumberSequence.new({K(0, 0.1), K(1, 1)})
        tr.WidthScale = NumberSequence.new({K(0, width), K(1, 0)})
        tr.FaceCamera = true
        tr.Parent = root
    end
    -- 3 pita cahaya di belakang
    trail(att(0, 1.4, 0.6), att(0, -1.4, 0.6), 0.75, 1)
    trail(att(1.7, 0.9, 0), att(1.7, -0.9, 0), 0.55, 1)
    trail(att(-1.7, 0.9, 0), att(-1.7, -0.9, 0), 0.55, 1)

    -- percikan cahaya
    local em = keep(Instance.new("ParticleEmitter"))
    em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    em.Color = auraSeq(a)
    em.LightEmission = 1
    em.LightInfluence = 0
    em.Size = NumberSequence.new({K(0, 0.9), K(1, 0)})
    em.Transparency = NumberSequence.new({K(0, 0), K(1, 1)})
    em.Lifetime = NumberRange.new(0.6, 1.1)
    em.Rate = 40
    em.Speed = NumberRange.new(1, 4)
    em.SpreadAngle = Vector2.new(180, 180)
    em.Rotation = NumberRange.new(0, 360)
    em.RotSpeed = NumberRange.new(-90, 90)
    em.Parent = root

    -- kabut cahaya
    local haze = keep(Instance.new("ParticleEmitter"))
    haze.Texture = "rbxasset://textures/particles/smoke_main.dds"
    haze.Color = auraSeq(a)
    haze.LightEmission = 0.9
    haze.LightInfluence = 0
    haze.Size = NumberSequence.new({K(0, 2.5), K(1, 5)})
    haze.Transparency = NumberSequence.new({K(0, 0.8), K(0.5, 0.88), K(1, 1)})
    haze.Lifetime = NumberRange.new(0.8, 1.3)
    haze.Rate = 14
    haze.Speed = NumberRange.new(0.2, 1)
    haze.SpreadAngle = Vector2.new(180, 180)
    haze.Parent = root

    local light = keep(Instance.new("PointLight"))
    light.Range = 16
    light.Brightness = 2.2
    light.Color = a.C1
    light.Parent = root

    local function neon(size)
        local p = Instance.new("Part")
        p.Anchored = true
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        p.CastShadow = false
        p.Material = Enum.Material.Neon
        p.Size = size
        p.Parent = folder
        return p
    end

    -- bola cahaya mengorbit
    local orbs = {}
    for i = 1, 8 do
        local p = neon(Vector3.new(0.55, 0.55, 0.55))
        p.Shape = Enum.PartType.Ball
        p.Transparency = 0.1
        orbs[i] = p
    end

    -- sayap energi
    local feathers = {}
    if Fly.WingsOn then
        for side = -1, 1, 2 do
            for i = 1, 5 do
                local p = neon(Vector3.new(1, 1, 1))
                p.Transparency = 0.3
                local len = 2.0 + (i - 1) * 0.5
                local m = Instance.new("SpecialMesh")
                m.MeshType = Enum.MeshType.Sphere
                m.Scale = Vector3.new(len, 0.12, 0.7)
                m.Parent = p
                feathers[#feathers + 1] = {Part = p, Side = side, Idx = i, Len = len}
            end
        end
    end

    Fly.Folder, Fly.Parts, Fly.Orbs, Fly.Feathers, Fly.Emitter, Fly.Light = folder, parts, orbs, feathers, em, light
    Fly.Haze = haze
end

local function updateAura(root, frac)
    if not Fly.Folder then return end
    local a = AURAS[Fly.Aura]
    local t = Fly.T
    local base = root.CFrame
    local orbs = Fly.Orbs
    for i, orb in ipairs(orbs) do
        local ang = t * 3 + i * (math.pi * 2 / #orbs)
        orb.CFrame = base * CFrame.new(math.cos(ang) * 3.2, math.sin(t * 4 + i) * 0.6, math.sin(ang) * 3.2)
        orb.Color = auraColor(a, i / #orbs, t)
    end
    local flap = math.sin(t * (5 + frac * 6)) * math.rad(10 + frac * 14)
    for _, f in ipairs(Fly.Feathers) do
        local ang = math.rad(34 - (f.Idx - 1) * 16) + flap
        f.Part.CFrame = base * CFrame.new(f.Side * 0.8, 1.0, 0.6)
            * CFrame.Angles(0, f.Side * math.rad(-30), f.Side * ang)
            * CFrame.new(f.Side * f.Len / 2, 0, 0)
        f.Part.Color = auraColor(a, f.Idx / 5, t)
    end
    if Fly.Emitter then Fly.Emitter.Rate = 25 + 90 * frac end
    if Fly.Haze then Fly.Haze.Rate = 10 + 30 * frac end
    if Fly.Light then
        Fly.Light.Color = auraColor(a, (math.sin(t * 2) + 1) / 2, t)
        Fly.Light.Brightness = 2 + frac * 2
    end
end

local function shockwave(root)
    local a = AURAS[Fly.Aura]
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Cylinder
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = auraColor(a, 0, 0)
    p.Transparency = 0.15
    p.Size = Vector3.new(0.25, 2, 2)
    p.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
    p.Parent = workspace.CurrentCamera or workspace
    TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.25, 22, 22),
        Transparency = 1,
    }):Play()
    task.delay(0.8, function() p:Destroy() end)
end

--====================================
-- ANIMASI GERAKAN FLY
-- Memutar sendi Motor6D karaktermu (Waist, Neck, bahu, siku, pinggul, lutut).
-- Posisi anggota badan ikut direplikasi fisika, jadi pemain lain ikut melihatnya.
--====================================
local FAL = (function()
local D2R = math.rad
local function dv(x, y, z) return Vector3.new(D2R(x or 0), D2R(y or 0), D2R(z or 0)) end
local function mir(v) return Vector3.new(v.X, -v.Y, -v.Z) end
local POSE_KEYS = {"RS", "LS", "RE", "LE", "RH", "LH", "RK", "LK", "Neck", "Waist"}

-- arm/fore/leg/shin = sisi kanan, sisi kiri otomatis dicerminkan
local function mk(arm, fore, leg, shin, neck, waist)
    return {
        RS = arm, LS = mir(arm), RE = fore, LE = mir(fore),
        RH = leg, LH = mir(leg), RK = shin, LK = mir(shin),
        Neck = neck or Vector3.zero, Waist = waist or Vector3.zero,
    }
end
local function blendPose(a, b, w)
    if w <= 0.001 then return a end
    w = math.min(w, 1)
    local o = {}
    for _, k in ipairs(POSE_KEYS) do o[k] = a[k]:Lerp(b[k], w) end
    return o
end

local FLY_STYLES = {"🦸 Superman", "🕊 Burung", "🚀 Jet / Ninja", "🧘 Santai", "🌀 Gasing"}
local LEAN_SCALE = {1, 0.9, 1.12, 0.35, 0.55}

local POSE_UP    = mk(dv(172, 0, 10), dv(0, 0, 0), dv(-6, 0, 2), dv(-5, 0, 0))
local POSE_DOWN  = mk(dv(-30, 0, 20), dv(12, 0, 0), dv(14, 0, 8), dv(-30, 0, 0))
local POSE_BACK  = mk(dv(20, 0, 45), dv(25, 0, 0), dv(14, 0, 6), dv(-18, 0, 0))
local POSE_TUCK  = mk(dv(70, 0, 14), dv(105, 0, 0), dv(100, 0, 4), dv(-115, 0, 0))
local POSE_SPREAD = mk(dv(0, 0, 88), dv(0, 0, 0), dv(0, 0, 14), dv(-6, 0, 0))

local function idlePose(style, t)
    local sw = math.sin(t * 1.7)
    if style == 1 then
        return mk(dv(8 + sw * 4, 0, 30), dv(22, 0, 0), dv(-4, 0, 6), dv(10 + sw * 3, 0, 0), nil, dv(sw * 2, 0, 0))
    elseif style == 2 then
        return mk(dv(0, 0, 55 + math.sin(t * 3) * 22), dv(0, 0, 0), dv(-5, 0, 4), dv(8, 0, 0))
    elseif style == 3 then
        return mk(dv(-15, 0, 10), dv(10, 0, 0), dv(0, 0, 3), dv(6, 0, 0))
    elseif style == 4 then
        return mk(dv(-25 + sw * 3, 0, 22), dv(15, 0, 0), dv(78, 0, 6), dv(-85, 0, 0), nil, dv(-6, 0, 0))
    end
    return mk(dv(0, 0, 80 + sw * 4), dv(0, 0, 0), dv(0, 0, 14), dv(-6, 0, 0))
end

local function flyPose(style, t, frac)
    local rate = 10 + frac * 6
    local fl = math.sin(t * rate)
    if style == 1 then
        local p = mk(dv(165, 0, 6), dv(0, 0, 0), dv(-6 + fl * 14, 0, 2), dv(-8 - 14 * math.max(0, fl), 0, 0), nil, dv(-8, 0, 0))
        p.LH = dv(-6 - fl * 14, 0, -2)
        p.LK = dv(-8 - 14 * math.max(0, -fl), 0, 0)
        return p
    elseif style == 2 then
        local flap = math.sin(t * (7 + frac * 5)) * 38
        return mk(dv(18, 0, 62 + flap), dv(0, 0, 0), dv(-14, 0, 0), dv(-20, 0, 0))
    elseif style == 3 then
        return mk(dv(-72, 0, 6), dv(0, 0, 0), dv(-4, 0, 0), dv(-4, 0, 0), nil, dv(-6, 0, 0))
    elseif style == 4 then
        return mk(dv(-35, 0, 28), dv(20, 0, 0), dv(72, 0, 8), dv(-82, 0, 0))
    end
    return mk(dv(0, 0, 86), dv(0, 0, 0), dv(0, 0, 14), dv(-6, 0, 0))
end

local FA = {Joint = {}, Orig = {}, Cur = {}, Active = false, Animate = nil, Clock = 0}

local function setScriptOn(sc, on)
    local ok = pcall(function() sc.Enabled = on end)
    if not ok then pcall(function() sc.Disabled = not on end) end
end

local function faKillTracks(hum)
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
        pcall(function() tr:Stop(0.1) end)
    end
end

local function faStart(char, hum)
    if FA.Active then return end
    FA.Joint, FA.Orig, FA.Cur = {}, {}, {}
    local map
    if hum.RigType == Enum.HumanoidRigType.R15 then
        map = {
            Waist = {"UpperTorso", "Waist"}, Neck = {"Head", "Neck"},
            RS = {"RightUpperArm", "RightShoulder"}, LS = {"LeftUpperArm", "LeftShoulder"},
            RE = {"RightLowerArm", "RightElbow"}, LE = {"LeftLowerArm", "LeftElbow"},
            RH = {"RightUpperLeg", "RightHip"}, LH = {"LeftUpperLeg", "LeftHip"},
            RK = {"RightLowerLeg", "RightKnee"}, LK = {"LeftLowerLeg", "LeftKnee"},
        }
    else
        map = {
            Neck = {"Torso", "Neck"},
            RS = {"Torso", "Right Shoulder"}, LS = {"Torso", "Left Shoulder"},
            RH = {"Torso", "Right Hip"}, LH = {"Torso", "Left Hip"},
        }
    end
    for k, pr in pairs(map) do
        local part = char:FindFirstChild(pr[1])
        local m = part and part:FindFirstChild(pr[2])
        if m and m:IsA("Motor6D") then
            FA.Joint[k], FA.Orig[k] = m, m.C0
        end
    end
    for _, k in ipairs(POSE_KEYS) do FA.Cur[k] = Vector3.zero end
    -- matikan skrip Animate bawaan supaya tidak menimpa pose
    local an = char:FindFirstChild("Animate")
    if an and (an:IsA("LocalScript") or an:IsA("Script")) then
        FA.Animate = an
        setScriptOn(an, false)
    end
    faKillTracks(hum)
    FA.Active = true
end

local function faStop()
    if not FA.Active then return end
    for k, m in pairs(FA.Joint) do
        if m.Parent and FA.Orig[k] then m.C0 = FA.Orig[k] end
    end
    if FA.Animate and FA.Animate.Parent then setScriptOn(FA.Animate, true) end
    FA.Joint, FA.Orig, FA.Cur, FA.Animate = {}, {}, {}, nil
    FA.Active = false
end

local function faApply(pose, dt)
    local a = math.clamp(dt * 10, 0, 1)
    for _, k in ipairs(POSE_KEYS) do
        FA.Cur[k] = FA.Cur[k]:Lerp(pose[k], a)
        local m, o = FA.Joint[k], FA.Orig[k]
        if m and m.Parent and o then
            local v = FA.Cur[k]
            m.C0 = CFrame.new(o.Position) * CFrame.Angles(v.X, v.Y, v.Z) * (o - o.Position)
        end
    end
end

-- gabungan pose: diam -> maju -> mundur -> naik/turun -> strafe -> takeoff -> trik
local function computePose(t, frac, mv, vy, trick, trickW, takeoffW)
    local st = Fly.Style
    local f = math.min(frac, 1)
    local pose = idlePose(st, t)
    pose = blendPose(pose, flyPose(st, t, f), math.clamp(-mv.Z, 0, 1) * f)
    pose = blendPose(pose, POSE_BACK, math.clamp(mv.Z, 0, 1) * f)
    pose = blendPose(pose, POSE_UP, math.max(vy, 0) * 0.85)
    pose = blendPose(pose, POSE_DOWN, math.max(-vy, 0) * 0.85)
    local bank = mv.X * f * D2R(28)
    if math.abs(bank) > 0.001 then
        local o = {}
        for _, k in ipairs(POSE_KEYS) do o[k] = pose[k] end
        o.RS = o.RS + Vector3.new(0, 0, -bank)
        o.LS = o.LS + Vector3.new(0, 0, -bank)
        pose = o
    end
    if takeoffW > 0 then pose = blendPose(pose, POSE_UP, takeoffW) end
    if trick and trickW > 0 then
        pose = blendPose(pose, (trick.Kind == 2) and POSE_TUCK or POSE_SPREAD, trickW * ((trick.Kind == 1) and 0 or 1))
    end
    return pose
end

return {
    STYLES = FLY_STYLES, LEAN = LEAN_SCALE, KEYS = POSE_KEYS, FA = FA,
    start = faStart, stop = faStop, apply = faApply, kill = faKillTracks,
    compute = computePose, blend = blendPose,
}
end)()
local FA = FAL.FA

local function startTrick()
    if not Fly.Enabled or Fly.Trick then return end
    Fly.TrickN = Fly.TrickN + (1)
    Fly.Trick = {Kind = ((Fly.TrickN - 1) % 3) + 1, T0 = os.clock(), Dur = 0.8}
end

-- kontrol di layar (HP): naik / turun / trik / stop
local FlyPad = Instance.new("Frame")
FlyPad.Name = "FlyPad"
FlyPad.Size = UDim2.fromOffset(150, 164)
FlyPad.Position = UDim2.new(1, -165, 1, -236)
FlyPad.BackgroundTransparency = 1
FlyPad.Visible = false
FlyPad.Parent = Gui
local FlyPadHandle = Instance.new("TextButton")
FlyPadHandle.Size = UDim2.new(1, 0, 0, 24)
FlyPadHandle.BackgroundColor3 = PINK
FlyPadHandle.BackgroundTransparency = 0.2
FlyPadHandle.Text = "✈ Fly  (geser)"
FlyPadHandle.TextColor3 = WHITE
FlyPadHandle.Font = Enum.Font.GothamBold
FlyPadHandle.TextSize = 11
FlyPadHandle.AutoButtonColor = false
FlyPadHandle.Parent = FlyPad
Instance.new("UICorner", FlyPadHandle).CornerRadius = UDim.new(0, 7)
makeDraggable(FlyPadHandle, FlyPad)

local function flyHold(txt, x, dir)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(64, 44)
    b.Position = UDim2.fromOffset(x, 30)
    b.BackgroundColor3 = Color3.fromRGB(40, 30, 65)
    b.BackgroundTransparency = 0.2
    b.Text = txt
    b.TextColor3 = WHITE
    b.Font = Enum.Font.GothamBold
    b.TextSize = 20
    b.AutoButtonColor = false
    b.Parent = FlyPad
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            Fly.Up = dir
            b.BackgroundColor3 = PINK
        end
    end)
    b.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if Fly.Up == dir then Fly.Up = 0 end
            b.BackgroundColor3 = Color3.fromRGB(40, 30, 65)
        end
    end)
end
flyHold("🔼", 8, 1)
flyHold("🔽", 78, -1)

local flyTrickBtn = Instance.new("TextButton")
flyTrickBtn.Size = UDim2.fromOffset(134, 32)
flyTrickBtn.Position = UDim2.fromOffset(8, 80)
flyTrickBtn.BackgroundColor3 = PURPLE
flyTrickBtn.BackgroundTransparency = 0.15
flyTrickBtn.Text = "🌀 Trik Akrobat"
flyTrickBtn.TextColor3 = WHITE
flyTrickBtn.Font = Enum.Font.GothamBold
flyTrickBtn.TextSize = 12
flyTrickBtn.Parent = FlyPad
Instance.new("UICorner", flyTrickBtn).CornerRadius = UDim.new(0, 9)
flyTrickBtn.MouseButton1Click:Connect(startTrick)

local flyStopBtn = Instance.new("TextButton")
flyStopBtn.Size = UDim2.fromOffset(134, 38)
flyStopBtn.Position = UDim2.fromOffset(8, 118)
flyStopBtn.BackgroundColor3 = Color3.fromRGB(190, 50, 80)
flyStopBtn.BackgroundTransparency = 0.15
flyStopBtn.Text = "❌ Stop Fly"
flyStopBtn.TextColor3 = WHITE
flyStopBtn.Font = Enum.Font.GothamBold
flyStopBtn.TextSize = 13
flyStopBtn.Parent = FlyPad
Instance.new("UICorner", flyStopBtn).CornerRadius = UDim.new(0, 9)
flyStopBtn.MouseButton1Click:Connect(function() if stopFly then stopFly() end end)

local flyConn
local controlsTried = false
local function getMoveLocal()
    if not controlsTried then
        controlsTried = true
        pcall(function()
            local pm = LP:FindFirstChild("PlayerScripts") and LP.PlayerScripts:FindFirstChild("PlayerModule")
            if pm then Fly.Controls = require(pm):GetControls() end
        end)
    end
    if Fly.Controls then
        local ok, v = pcall(function() return Fly.Controls:GetMoveVector() end)
        if ok and typeof(v) == "Vector3" then return v end
    end
    local hum, cam = myHumanoid(), workspace.CurrentCamera
    if hum and cam then
        local v = cam.CFrame:VectorToObjectSpace(hum.MoveDirection)
        local flat = Vector3.new(v.X, 0, v.Z)
        if flat.Magnitude > 0.01 then return flat.Unit * math.min(hum.MoveDirection.Magnitude, 1) end
    end
    return Vector3.zero
end

local function destroyFlyBody()
    if Fly.LV then pcall(function() Fly.LV:Destroy() end) end
    if Fly.Att then pcall(function() Fly.Att:Destroy() end) end
    Fly.LV, Fly.Att = nil, nil
end

function stopFly(silent)
    local was = Fly.Enabled
    Fly.Enabled = false
    FlyPad.Visible = false
    clearAura()
    destroyFlyBody()
    FAL.stop()
    Fly.Up = 0
    Fly.Hold = nil
    Fly.Trick = nil
    if flyConn then flyConn:Disconnect() flyConn = nil end
    local hum = myHumanoid()
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hum then
        hum.PlatformStand = false
        hum.AutoRotate = true
    end
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.lookAt(root.Position, root.Position + Fly.Flat)
    end
    if was and not silent then toast("Fly mati") end
    if Fly.OnChange then pcall(Fly.OnChange) end
end

-- nyalakan / matikan animasi saat sedang terbang
local function setFlyAnim(on)
    Fly.AnimOn = on
    if not Fly.Enabled then return end
    local char = LP.Character
    local hum = myHumanoid()
    if on then
        if char and hum then FAL.start(char, hum) end
    else
        FAL.stop()
    end
end

local function startFly()
    if Fly.Enabled then return end
    local hum = myHumanoid()
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then toast("Karakter belum tersedia") return end
    if Tempel.Target then stopTempel() end
    Fly.Enabled = true
    Fly.Vel = Vector3.new(0, 28, 0)
    Fly.T = 0
    Fly.Up = 0
    Fly.Spin = 0
    Fly.Hold = nil
    Fly.Trick = nil
    local cam = workspace.CurrentCamera
    local look = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
    local flat = Vector3.new(look.X, 0, look.Z)
    Fly.Flat = flat.Magnitude > 0.05 and flat.Unit or Vector3.new(0, 0, -1)
    buildAura(root)
    shockwave(root)

    -- penahan posisi: kecepatan dikunci lewat constraint, jadi tidak turun sendiri oleh gravitasi
    destroyFlyBody()
    local att = Instance.new("Attachment")
    att.Name = "DiiUi_FlyAtt"
    att.Parent = root
    local lv = Instance.new("LinearVelocity")
    lv.Name = "DiiUi_FlyLV"
    lv.Attachment0 = att
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.MaxForce = math.huge
    lv.VectorVelocity = Fly.Vel
    lv.Parent = root
    Fly.Att, Fly.LV = att, lv

    root.AssemblyLinearVelocity = Fly.Vel
    if Fly.AnimOn and LP.Character then FAL.start(LP.Character, hum) end
    FlyPad.Visible = true

    flyConn = RunService.Heartbeat:Connect(function(dt)
        if not Fly.Enabled then return end
        local char = LP.Character
        local h = char and char:FindFirstChildOfClass("Humanoid")
        local r = char and char:FindFirstChild("HumanoidRootPart")
        local c = workspace.CurrentCamera
        if not (h and r and c) then return end
        if h.PlatformStand ~= true then h.PlatformStand = true end
        h.AutoRotate = false
        Fly.T = Fly.T + (dt)

        local mv = getMoveLocal()
        local up = Fly.Up
        if not UIS:GetFocusedTextBox() then
            if UIS:IsKeyDown(Enum.KeyCode.Space) then up = up + (1) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.C) then up = up - (1) end
        end
        up = math.clamp(up, -1, 1)
        local boost = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 1.8 or 1

        local dir = c.CFrame.RightVector * mv.X + c.CFrame.LookVector * (-mv.Z) + Vector3.new(0, up, 0)
        local moving = dir.Magnitude > 0.05
        local target = Vector3.zero
        if moving then
            target = dir.Unit * Fly.Speed * boost * math.min(dir.Magnitude, 1)
        end
        Fly.Vel = Fly.Vel:Lerp(target, math.clamp(dt * 8, 0, 1))

        -- berhenti = diam total di titik itu (tidak melorot, tidak naik-turun)
        local vel = Fly.Vel
        if moving then
            Fly.Hold = nil
        elseif Fly.Vel.Magnitude < 2 then
            if not Fly.Hold then Fly.Hold = r.Position end
            vel = (Fly.Hold - r.Position) * 12
            if vel.Magnitude > 25 then vel = vel.Unit * 25 end
            Fly.Vel = Vector3.zero
        end
        if Fly.LV then Fly.LV.VectorVelocity = vel end
        r.AssemblyLinearVelocity = vel
        r.AssemblyAngularVelocity = Vector3.zero

        local look2 = c.CFrame.LookVector
        local fl = Vector3.new(look2.X, 0, look2.Z)
        if fl.Magnitude > 0.05 then Fly.Flat = fl.Unit end
        local frac = math.clamp(Fly.Vel.Magnitude / math.max(Fly.Speed, 1), 0, 1.5)
        local fm = math.min(frac, 1)

        local ls = FAL.LEAN[Fly.Style] or 1
        local lean = (-math.rad(75) * fm * math.clamp(-mv.Z, 0, 1)
            + math.rad(25) * fm * math.clamp(mv.Z, 0, 1)) * ls
        local roll = -mv.X * math.rad(25) * fm

        -- trik akrobat (putaran badan terlihat semua orang)
        local pre, post = CFrame.identity, CFrame.identity
        local trick, trickW = Fly.Trick, 0
        if trick then
            local p = (os.clock() - trick.T0) / trick.Dur
            if p >= 1 then
                Fly.Trick, trick = nil, nil
            else
                local e = p * p * (3 - 2 * p)
                local a = e * math.pi * 2
                trickW = math.sin(p * math.pi)
                if trick.Kind == 1 then post = CFrame.Angles(0, a, 0)       -- barrel roll
                elseif trick.Kind == 2 then pre = CFrame.Angles(-a, 0, 0)  -- salto
                else pre = CFrame.Angles(0, a * 2, 0) end                  -- putar 2x
            end
        end

        if Fly.Style == 5 then Fly.Spin = Fly.Spin + (dt * (2.5 + fm * 5)) end
        local cf = CFrame.lookAt(r.Position, r.Position + Fly.Flat)
        if Fly.Style == 5 then cf = cf * CFrame.Angles(0, Fly.Spin, 0) end
        r.CFrame = cf * pre * CFrame.Angles(lean, 0, roll) * post

        -- animasi anggota badan
        if Fly.AnimOn and FA.Active then
            FA.Clock = FA.Clock + (dt)
            if FA.Clock > 0.5 then
                FA.Clock = 0
                FAL.kill(h)
            end
            local vy = math.clamp(Fly.Vel.Y / math.max(Fly.Speed, 1), -1, 1)
            local takeoffW = math.clamp(1 - Fly.T / 0.9, 0, 1)
            local pose = FAL.compute(Fly.T, frac, mv, vy, trick, trickW, takeoffW)
            -- kepala tetap menghadap depan saat badan miring
            local neckFix = Vector3.new(-lean * 0.65, 0, 0)
            local fixed = {}
            for _, k in ipairs(FAL.KEYS) do fixed[k] = pose[k] end
            fixed.Neck = fixed.Neck + neckFix
            FAL.apply(fixed, dt)
        end

        updateAura(r, fm)
    end)
    toast("Fly aktif  •  WASD/joystick, Space naik, Ctrl turun, G = trik")
    if Fly.OnChange then pcall(Fly.OnChange) end
end

LP.CharacterAdded:Connect(function()
    if Fly.Enabled then stopFly(true) end
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F then
        if Fly.Enabled then stopFly() else startFly() end
    elseif input.KeyCode == Enum.KeyCode.G then
        startTrick()
    elseif input.KeyCode == Enum.KeyCode.N then
        NoClip.Enabled = not NoClip.Enabled
        toast("NoClip " .. (NoClip.Enabled and "ON" or "OFF"))
        if NoClip.OnChange then pcall(NoClip.OnChange) end
    end
end)

Gui.Destroying:Connect(function()
    pcall(stopTempel)
    pcall(stopFly, true)
    if tempelConn then tempelConn:Disconnect() end
    if Tempel.Conn2 then Tempel.Conn2:Disconnect() end
    if flyConn then flyConn:Disconnect() end
    noclipConn:Disconnect()
    NoClip.Enabled = false
    for part, was in pairs(noclipSaved) do
        if part.Parent then part.CanCollide = was end
    end
end)

local function flySection()
    label("🕊 FLY & NOCLIP")
    local flyBtn, paintFly = toggleButton("✈  FLY", function() return Fly.Enabled end, function()
        if Fly.Enabled then stopFly() else startFly() end
    end)
    local ncBtn, paintNc = toggleButton("👻  NOCLIP (tembus tembok)", function() return NoClip.Enabled end, function()
        NoClip.Enabled = not NoClip.Enabled
        toast("NoClip " .. (NoClip.Enabled and "ON" or "OFF"))
    end)
    Fly.OnChange = function() if flyBtn.Parent then paintFly() end end
    NoClip.OnChange = function() if ncBtn.Parent then paintNc() end end
    slider("Kecepatan Terbang", 10, 300, Fly.Speed, 1, function(v) Fly.Speed = v end)

    label("🎬 ANIMASI GERAKAN  (terlihat semua pemain)")
    toggleButton("🎬  Animasi Badan", function() return Fly.AnimOn end, function()
        setFlyAnim(not Fly.AnimOn)
    end)
    chipGrid(FAL.STYLES, function() return Fly.Style end, function(i)
        Fly.Style = i
        Fly.Spin = 0
    end, 40)
    button("🌀  Trik Akrobat (barrel roll / salto / putar)  [G]", function() startTrick() end)

    label("AURA  (hanya terlihat di layarmu)")
    toggleButton("✨  Aura", function() return Fly.AuraOn end, function()
        Fly.AuraOn = not Fly.AuraOn
        local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if Fly.Enabled and r then buildAura(r) end
    end)
    toggleButton("🪽  Sayap Energi", function() return Fly.WingsOn end, function()
        Fly.WingsOn = not Fly.WingsOn
        local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if Fly.Enabled and r then buildAura(r) end
    end)
    chipGrid(AuraNames, function() return Fly.Aura end, function(i)
        Fly.Aura = i
        local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if Fly.Enabled and r then buildAura(r) end
    end, 44)
    label("PC: WASD gerak, Space naik, Ctrl turun, Shift ngebut.\nHP: joystick + tombol 🔼 🔽 🌀 di layar.\nHotkey: F = Fly, G = Trik, N = NoClip.\nBerhenti = karakter diam di tempat (tidak turun sendiri).")
end

-- daftar pemain otomatis ter-refresh saat ada yang masuk / keluar
local function refreshPlayerTabs()
    task.delay(0.3, function()
        if not Gui.Parent then return end
        if ActiveTab == tempelTab then
            tempelTab()
        elseif ActiveTab == avatarTab and (not avatarBox or avatarBox.Text == "") then
            avatarTab()
        end
    end)
end
Players.PlayerAdded:Connect(refreshPlayerTabs)
Players.PlayerRemoving:Connect(refreshPlayerTabs)

--====================================
-- DiiUi HUB: ANTI LAG / ANTI CRASH (client-side)
-- Melindungi KLIENT kamu dari lag/crash akibat server atau pemain lain:
--   Safe Mode, Auto Guard (FPS watchdog), Anti Flood objek,
--   Batas suara, Anti Fling. Semua hanya berlaku di layarmu.
--====================================
local Stats = game:GetService("Stats")

local AntiLag = {
    SafeMode = false,
    AutoGuard = false,
    Flood = false,
    SoundCap = false,
    AntiFling = false,
    FpsLimit = 20,
    FloodLimit = 400,
    MaxSounds = 12,
    FPS = 60,
    Alive = true,
}

local alSaved = setmetatable({}, {__mode = "k"})   -- [efek] = Enabled asli
local alSounds = setmetatable({}, {__mode = "k"})  -- sound yang dilacak
local alQuality, alShadows
local alFloodCount, alFloodUntil, alFloodToast = 0, 0, false
local alLowTicks = 0

local EFFECT_CLASSES = {
    ParticleEmitter = true, Trail = true, Beam = true,
    Smoke = true, Fire = true, Sparkles = true,
    BloomEffect = true, BlurEffect = true, SunRaysEffect = true,
    DepthOfFieldEffect = true,
}

-- objek milik HUB / karaktermu sendiri tidak boleh disentuh
local function isOwnObject(inst)
    local char = LP.Character
    if char and inst:IsDescendantOf(char) then return true end
    local cur = inst
    for _ = 1, 8 do
        if not cur then return false end
        if string.sub(cur.Name, 1, 5) == "DiiUi" then return true end
        cur = cur.Parent
    end
    return false
end

local function isCharacterObject(inst)
    local m = inst:FindFirstAncestorWhichIsA("Model")
    while m do
        if m:FindFirstChildOfClass("Humanoid") then return true end
        m = m:FindFirstAncestorWhichIsA("Model")
    end
    return false
end

local function calmEffect(inst)
    if not EFFECT_CLASSES[inst.ClassName] then return end
    if isOwnObject(inst) then return end
    pcall(function()
        if alSaved[inst] == nil then alSaved[inst] = inst.Enabled end
        inst.Enabled = false
    end)
end

local function setSafeMode(on)
    if on == AntiLag.SafeMode then return end
    AntiLag.SafeMode = on
    if on then
        pcall(function()
            local r = settings().Rendering
            alQuality = r.QualityLevel
            r.QualityLevel = Enum.QualityLevel.Level01
        end)
        alShadows = Lighting.GlobalShadows
        Lighting.GlobalShadows = false
        task.spawn(function() -- dipindai bertahap supaya tidak freeze
            local n = 0
            for _, root in ipairs({workspace, Lighting}) do
                for _, d in ipairs(root:GetDescendants()) do
                    if not AntiLag.SafeMode then return end
                    calmEffect(d)
                    n = n + (1)
                    if n % 400 == 0 then task.wait() end
                end
            end
        end)
    else
        for inst, was in pairs(alSaved) do
            if inst.Parent then pcall(function() inst.Enabled = was end) end
            alSaved[inst] = nil
        end
        pcall(function()
            if alQuality then settings().Rendering.QualityLevel = alQuality end
        end)
        if alShadows ~= nil then Lighting.GlobalShadows = alShadows end
    end
    if AntiLag.OnChange then pcall(AntiLag.OnChange) end
end

local function seedSounds()
    task.spawn(function()
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Sound") then alSounds[d] = true end
            n = n + (1)
            if n % 400 == 0 then task.wait() end
        end
    end)
end

-- pantau objek baru: matikan efek (Safe Mode) & tahan banjir objek (Anti Flood)
local alAddedConn = workspace.DescendantAdded:Connect(function(d)
    if AntiLag.SafeMode then calmEffect(d) end
    if d:IsA("Sound") then alSounds[d] = true end
    if not AntiLag.Flood then return end

    -- yang dihitung hanya objek "spam": part tidak anchored, efek, suara
    local spammy = EFFECT_CLASSES[d.ClassName] or d:IsA("Sound")
        or (d:IsA("BasePart") and not d.Anchored)
    if not spammy then return end

    alFloodCount = alFloodCount + (1)
    if alFloodCount > AntiLag.FloodLimit then
        alFloodUntil = os.clock() + 4
    end
    if os.clock() < alFloodUntil then
        task.defer(function()
            if d.Parent and not isOwnObject(d) and not isCharacterObject(d) then
                pcall(function() d:Destroy() end)
            end
        end)
        if not alFloodToast then
            alFloodToast = true
            toast("🌊 Banjir objek terdeteksi — dibersihkan")
        end
    end
end)

-- FPS counter
local alFrames, alAccum = 0, 0
local alHeartbeat = RunService.Heartbeat:Connect(function(dt)
    alFrames = alFrames + (1)
    alAccum = alAccum + (dt)
    if alAccum >= 0.5 then
        AntiLag.FPS = math.floor(alFrames / alAccum + 0.5)
        alFrames, alAccum = 0, 0
    end
end)

-- loop 1 detik: reset hitungan banjir, batas suara, Auto Guard
task.spawn(function()
    while AntiLag.Alive and Gui.Parent do
        task.wait(1)
        alFloodCount = 0
        if os.clock() >= alFloodUntil then alFloodToast = false end

        if AntiLag.SoundCap then
            local playing = {}
            for s in pairs(alSounds) do
                if s.Parent and s.IsPlaying and not isOwnObject(s) then
                    table.insert(playing, s)
                end
            end
            for i = AntiLag.MaxSounds + 1, #playing do
                pcall(function() playing[i]:Stop() end)
            end
        end

        if AntiLag.AutoGuard and not AntiLag.SafeMode then
            if AntiLag.FPS < AntiLag.FpsLimit then
                alLowTicks = alLowTicks + (1)
                if alLowTicks >= 3 then
                    alLowTicks = 0
                    AntiLag.SoundCap = true
                    if AntiLag.Piano then AntiLag.Piano.Set(true) end
                    setSafeMode(true)
                    toast("🛡 FPS rendah — Safe Mode otomatis aktif")
                end
            else
                alLowTicks = 0
            end
        end
    end
end)

-- Anti Fling: pemain lain tidak bisa menabrak + redam velocity ekstrem
local alFlingConn = RunService.Stepped:Connect(function()
    if not AntiLag.AntiFling then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            for _, part in ipairs(p.Character:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return end
    if Fly.Enabled or Tempel.Target or hum.SeatPart then return end
    local v = root.AssemblyLinearVelocity
    local horiz = Vector3.new(v.X, 0, v.Z).Magnitude
    local limit = math.max(150, hum.WalkSpeed * 2)
    if horiz > limit or math.abs(v.Y) > 350 then
        root.AssemblyLinearVelocity = Vector3.zero
    end
    if root.AssemblyAngularVelocity.Magnitude > 30 then
        root.AssemblyAngularVelocity = Vector3.zero
    end
end)

Gui.Destroying:Connect(function()
    AntiLag.Alive = false
    AntiLag.AntiFling = false
    AntiLag.Flood = false
    pcall(setSafeMode, false)
    if AntiLag.Piano then pcall(AntiLag.Piano.Set, false) end
    alAddedConn:Disconnect()
    alHeartbeat:Disconnect()
    alFlingConn:Disconnect()
end)

-- ANTI PIANO LAG: pemain rusuh spam piano => ratusan Sound/efek baru per detik => layar patah-patah.
-- Perlindungan di KLIENT: (1) batasi jumlah Sound baru per detik, (2) hanya N suara terdekat yang boleh
-- bunyi, (3) matikan efek suara berat (reverb/echo). Dibungkus do-block agar tidak menambah variabel lokal.
;(function() -- blok dipisah agar tidak melebihi batas 200 variabel lokal
    local SoundService = game:GetService("SoundService")
    local PS = {
        On = false, Rusuh = false, RateLimit = 30, MaxPlaying = 8, KillFX = true,
        Blocked = 0, Count = 0, Window = 0, BlockUntil = 0,
        FxSaved = setmetatable({}, {__mode = "k"}),
    }
    AntiLag.Piano = PS
    local conns = {}

    local function killFx(d)
        if d:IsA("SoundEffect") and not isOwnObject(d) then
            pcall(function()
                if PS.FxSaved[d] == nil then PS.FxSaved[d] = d.Enabled end
                d.Enabled = false
            end)
        end
    end

    local function onAdded(d)
        if not PS.On then return end
        if d:IsA("Sound") then
            if isOwnObject(d) then return end
            alSounds[d] = true
            local now = os.clock()
            if now - PS.Window >= 1 then PS.Window, PS.Count = now, 0 end
            PS.Count = PS.Count + (1)
            if PS.Count > PS.RateLimit then PS.BlockUntil = now + 2 end
            if now < PS.BlockUntil then
                PS.Blocked = PS.Blocked + (1)
                task.defer(function()
                    pcall(function() d.Volume = 0 d:Stop() d:Destroy() end)
                end)
            end
        elseif PS.KillFX then
            killFx(d)
        end
    end

    function PS.Set(on)
        if on == PS.On then return end
        PS.On = on
        if on then
            PS.Blocked, PS.Count, PS.BlockUntil = 0, 0, 0
            seedSounds()
            conns = {
                workspace.DescendantAdded:Connect(onAdded),
                SoundService.DescendantAdded:Connect(onAdded),
            }
            if PS.KillFX then
                task.spawn(function() -- efek yang sudah ada, dipindai bertahap
                    local n = 0
                    for _, root in ipairs({workspace, SoundService}) do
                        for _, d in ipairs(root:GetDescendants()) do
                            if not PS.On then return end
                            killFx(d)
                            n = n + (1)
                            if n % 400 == 0 then task.wait() end
                        end
                    end
                end)
            end
        else
            for _, c in ipairs(conns) do c:Disconnect() end
            conns = {}
            for fx, was in pairs(PS.FxSaved) do
                if fx.Parent then pcall(function() fx.Enabled = was end) end
                PS.FxSaved[fx] = nil
            end
        end
        if PS.OnChange then pcall(PS.OnChange) end
    end

    -- MODE ANTI-RUSUH: satu tombol untuk semua perlindungan
    function PS.SetRusuh(on)
        PS.Rusuh = on
        PS.Set(on)
        AntiLag.Flood = on
        AntiLag.SoundCap = on
        AntiLag.AutoGuard = on
        if on then
            AntiLag.MaxSounds = math.min(AntiLag.MaxSounds, PS.MaxPlaying)
            seedSounds()
        end
        setSafeMode(on)
        if PS.OnChange then pcall(PS.OnChange) end
        if AntiLag.OnChange then pcall(AntiLag.OnChange) end
    end

    -- batas suara aktif: hanya N suara TERDEKAT dari kamera yang boleh bunyi
    task.spawn(function()
        while AntiLag.Alive and Gui.Parent do
            task.wait(0.2)
            if PS.On then
                local cam = workspace.CurrentCamera
                local camPos = cam and cam.CFrame.Position
                local list = {}
                for snd in pairs(alSounds) do
                    if not snd.Parent then
                        alSounds[snd] = nil
                    elseif snd.IsPlaying and not isOwnObject(snd) then
                        local par, pos = snd.Parent, nil
                        if par:IsA("BasePart") then pos = par.Position
                        elseif par:IsA("Attachment") then pos = par.WorldPosition end
                        list[#list + 1] = {snd, (pos and camPos) and (pos - camPos).Magnitude or 60}
                    end
                end
                if #list > PS.MaxPlaying then
                    table.sort(list, function(a, b) return a[2] < b[2] end)
                    for i = PS.MaxPlaying + 1, #list do
                        pcall(function() list[i][1]:Stop() end)
                        PS.Blocked = PS.Blocked + (1)
                    end
                end
            end
        end
    end)
end)()

local function antiLagTab()
    clearContent()
    label("🛡 ANTI LAG / CRASH")

    local statLabel = label("Memuat statistik...")
    statLabel.Font = Enum.Font.Gotham
    statLabel.TextSize = 12
    task.spawn(function()
        while statLabel.Parent and AntiLag.Alive do
            local ping, mem = "?", "?"
            pcall(function()
                ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            pcall(function() mem = math.floor(Stats:GetTotalMemoryUsageMb()) end)
            local f = AntiLag.FPS
            local icon = f >= 45 and "🟢" or (f >= 25 and "🟡" or "🔴")
            statLabel.Text = string.format("%s FPS: %d   |   Ping: %s ms   |   RAM: %s MB",
                icon, f, tostring(ping), tostring(mem))
                .. (AntiLag.Piano.On and ("   |   🎹 diblokir: " .. AntiLag.Piano.Blocked) or "")
            task.wait(0.5)
        end
    end)

    label("🎹 ANTI PIANO / ANTI RUSUH")
    local PS = AntiLag.Piano
    local _, paintPiano = toggleButton("🎹  Piano Shield (blok spam suara piano)",
        function() return PS.On end,
        function() PS.Set(not PS.On) end)
    local _, paintRusuh = toggleButton("🚨  MODE ANTI-RUSUH (aktifkan semua)",
        function() return PS.Rusuh end,
        function() PS.SetRusuh(not PS.Rusuh) end)
    PS.OnChange = function()
        if statLabel.Parent then paintPiano() paintRusuh() end
    end
    slider("Batas suara baru per detik", 5, 100, PS.RateLimit, 1, function(v) PS.RateLimit = v end)
    slider("Maks suara bunyi (terdekat dulu)", 2, 30, PS.MaxPlaying, 1, function(v) PS.MaxPlaying = v end)
    toggleButton("🎚  Matikan efek suara berat (reverb/echo)",
        function() return PS.KillFX end,
        function() PS.KillFX = not PS.KillFX end)
    label("🛡 PERLINDUNGAN UMUM")
    local _, paintSafe = toggleButton("🛡  Safe Mode (FPS Boost)",
        function() return AntiLag.SafeMode end,
        function() setSafeMode(not AntiLag.SafeMode) end)
    local _, paintAuto = toggleButton("🤖  Auto Guard (FPS drop → Safe Mode)",
        function() return AntiLag.AutoGuard end,
        function()
            AntiLag.AutoGuard = not AntiLag.AutoGuard
            alLowTicks = 0
        end)
    AntiLag.OnChange = function()
        if statLabel.Parent then paintSafe() paintAuto() end
    end
    slider("Batas FPS Auto Guard", 5, 240, AntiLag.FpsLimit, 1, function(v)
        AntiLag.FpsLimit = v
    end)

    label("⚡ UNLOCK FPS (buka batas FPS game)")
    local fpsCap = 240
    slider("FPS Cap", 30, 240, fpsCap, 10, function(v) fpsCap = v end)
    button("⚡  Terapkan FPS Cap", function()
        if setfpscap then
            setfpscap(fpsCap)
            toast("FPS cap: " .. fpsCap)
        else
            toast("Executor tidak mendukung setfpscap")
        end
    end)
    button("♾  Tanpa batas (uncapped)", function()
        if setfpscap then
            setfpscap(0)
            toast("FPS tanpa batas")
        else
            toast("Executor tidak mendukung setfpscap")
        end
    end)

    toggleButton("🌊  Anti Flood (spam part / efek)",
        function() return AntiLag.Flood end,
        function() AntiLag.Flood = not AntiLag.Flood end)
    slider("Batas objek baru per detik", 100, 2000, AntiLag.FloodLimit, 50, function(v)
        AntiLag.FloodLimit = v
    end)

    toggleButton("🔇  Batasi Suara (anti sound spam)",
        function() return AntiLag.SoundCap end,
        function()
            AntiLag.SoundCap = not AntiLag.SoundCap
            if AntiLag.SoundCap then seedSounds() end
        end)
    slider("Maks suara aktif", 4, 40, AntiLag.MaxSounds, 1, function(v)
        AntiLag.MaxSounds = v
    end)

    toggleButton("🚫  Anti Fling (tabrakan & velocity)",
        function() return AntiLag.AntiFling end,
        function() AntiLag.AntiFling = not AntiLag.AntiFling end)

    label("Catatan: semua fitur ini bekerja di KLIENT (layarmu) saja.\n"
        .. "Server tidak bisa diperbaiki dari sini — kalau server benar-benar "
        .. "mati/lag berat, kamu tetap bisa terkena. Fitur ini mengurangi "
        .. "efeknya ke FPS & stabilitas game-mu.\n"
        .. "Anti Flood hanya menghapus part tidak-anchored, efek & suara yang "
        .. "muncul massal; matikan jika ada objek game yang ikut hilang.")
end

--====================================
-- DiiUi HUB: GROBAK (TP otomatis + kendali grobak)
-- Hanya memengaruhi dirimu & grobak yang kamu naiki.
-- Dibungkus do-block agar tidak menambah jumlah variabel lokal utama
-- (batas Luau = 200 per fungsi).
--====================================
local cartTab
;(function() -- blok dipisah agar tidak melebihi batas 200 variabel lokal
    local Cart = {
        Drive = false, Face = false, Speed = 40, AutoRespawn = false,
        Keyword = "", Target = nil, Vel = Vector3.zero, Alive = true,
    }
    local DEFAULT_WORDS = {
        "grobak", "gerobak", "cart", "wagon", "troli", "trolley",
        "kereta", "dorong", "minecart", "mine cart", "handcart",
    }

    local function wordMatch(name)
        local n = string.lower(name)
        if Cart.Keyword ~= "" then
            return string.find(n, string.lower(Cart.Keyword), 1, true) ~= nil
        end
        for _, w in ipairs(DEFAULT_WORDS) do
            if string.find(n, w, 1, true) then return true end
        end
        return false
    end

    -- cocok kalau nama seat SENDIRI, nama parent langsung, atau nama model
    -- leluhur mana pun mengandung kata kuncinya (tidak harus persis model-nya)
    local function seatMatches(seat)
        if wordMatch(seat.Name) then return true, seat.Name end
        local cur = seat.Parent
        local depth = 0
        while cur and cur ~= workspace and depth < 6 do
            if wordMatch(cur.Name) then return true, cur.Name end
            cur = cur.Parent
            depth = depth + (1)
        end
        return false, nil
    end

    local function sortByDistance(list)
        local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if root then
            table.sort(list, function(a, b)
                return (a.seat.Position - root.Position).Magnitude
                    < (b.seat.Position - root.Position).Magnitude
            end)
        end
        return list
    end

    -- kumpulkan SEMUA Seat/VehicleSeat yang ada di client sekarang (tanpa filter nama)
    local function scanAllSeats()
        local list = {}
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            n = n + (1)
            if n % 1500 == 0 then task.wait() end
            if d:IsA("Seat") or d:IsA("VehicleSeat") then
                local display = (d.Parent and d.Parent.Name) or d.Name
                table.insert(list, {model = d.Parent, seat = d, name = display})
            end
        end
        return sortByDistance(list)
    end

    -- cari grobak: Seat/VehicleSeat yang namanya (atau nama leluhurnya) cocok kata kunci
    local function scanCarts()
        local list = {}
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            n = n + (1)
            if n % 1500 == 0 then task.wait() end
            if d:IsA("Seat") or d:IsA("VehicleSeat") then
                local ok, matchedName = seatMatches(d)
                if ok then
                    table.insert(list, {model = d.Parent, seat = d, name = matchedName})
                end
            end
        end
        return sortByDistance(list)
    end

    local function goToCart(c)
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not (c and c.seat and c.seat.Parent and hum and root) then
            toast("Grobak / karakter tidak tersedia, memindai ulang...")
            return false
        end
        local occ = c.seat.Occupant
        if occ and occ ~= hum then
            toast("Grobak sedang dipakai pemain lain")
            return false
        end

        Cart.Target = c
        pcall(function() if Fly.Enabled then stopFly(true) end end)
        pcall(function() if Tempel.Target then stopTempel() end end)

        -- anchor sebentar supaya tidak terpental fisika saat teleport
        local wasAnchored = root.Anchored
        root.Anchored = true
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        -- PivotTo memindahkan seluruh model (lebih stabil daripada set CFrame root saja)
        local ok = pcall(function()
            char:PivotTo(c.seat.CFrame * CFrame.new(0, 3, 0))
        end)
        if not ok then
            root.CFrame = c.seat.CFrame * CFrame.new(0, 3, 0)
        end
        task.wait()
        root.Anchored = wasAnchored

        -- coba duduk beberapa kali (fisika butuh sedikit waktu untuk settle)
        local sat = false
        for _ = 1, 12 do
            if not (c.seat and c.seat.Parent) then break end
            if hum.SeatPart == c.seat then sat = true break end
            pcall(function() c.seat:Sit(hum) end)
            task.wait(0.1)
        end

        if sat then
            toast("🛒 TP & duduk di " .. c.name)
        else
            toast("🛒 TP dekat " .. c.name .. " — duduk manual jika belum")
        end
        return true
    end

    -- kendali grobak: gerakkan assembly dari seat yang sedang kamu duduki
    local driveConn = RunService.Heartbeat:Connect(function(dt)
        if not Cart.Drive then
            Cart.Vel = Vector3.zero
            return
        end
        local hum = myHumanoid()
        local seat = hum and hum.SeatPart
        local cam = workspace.CurrentCamera
        if not (seat and cam) then return end
        local part = seat.AssemblyRootPart or seat

        local mv = getMoveLocal()
        local look = cam.CFrame.LookVector
        local right = cam.CFrame.RightVector
        local fwd = Vector3.new(look.X, 0, look.Z)
        local rgt = Vector3.new(right.X, 0, right.Z)
        fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(0, 0, -1)
        rgt = rgt.Magnitude > 0.01 and rgt.Unit or Vector3.new(1, 0, 0)

        local dir = rgt * mv.X + fwd * (-mv.Z)
        local target = Vector3.zero
        if dir.Magnitude > 0.05 then
            target = dir.Unit * Cart.Speed * math.min(dir.Magnitude, 1)
        end
        Cart.Vel = Cart.Vel:Lerp(target, math.clamp(dt * 6, 0, 1))
        local cur = part.AssemblyLinearVelocity
        part.AssemblyLinearVelocity = Vector3.new(Cart.Vel.X, cur.Y, Cart.Vel.Z)

        if Cart.Face and dir.Magnitude > 0.2 then
            local pos = part.Position
            local want = CFrame.lookAt(pos, pos + dir.Unit)
            part.CFrame = part.CFrame:Lerp(want, math.clamp(dt * 5, 0, 1))
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end)

    -- Auto TP saat respawn (ke grobak terakhir, atau yang terdekat)
    local charConn = LP.CharacterAdded:Connect(function()
        if not Cart.AutoRespawn then return end
        task.wait(1.2)
        if not Cart.Alive then return end
        local c = Cart.Target
        if not (c and c.seat and c.seat.Parent) then
            c = scanCarts()[1]
        end
        if c then goToCart(c) end
    end)

    Gui.Destroying:Connect(function()
        Cart.Alive = false
        Cart.Drive = false
        driveConn:Disconnect()
        charConn:Disconnect()
    end)

    cartTab = function()
        clearContent()
        label("🛒 GROBAK")

        button("⚡  Auto TP ke Grobak Terdekat", function()
            toast("🔎 Memindai grobak...")
            local c = scanCarts()[1]
            if c then
                goToCart(c)
            else
                toast("Grobak tidak ditemukan — coba ganti kata kunci di bawah")
            end
        end)
        toggleButton("🔁  Auto TP saat respawn",
            function() return Cart.AutoRespawn end,
            function() Cart.AutoRespawn = not Cart.AutoRespawn end)

        label("KENDALI  (duduk di grobak dulu)")
        toggleButton("🕹  Kendali Grobak (WASD / joystick)",
            function() return Cart.Drive end,
            function() Cart.Drive = not Cart.Drive end)
        toggleButton("🔄  Grobak menghadap arah gerak",
            function() return Cart.Face end,
            function() Cart.Face = not Cart.Face end)
        slider("Kecepatan Grobak", 10, 150, Cart.Speed, 1, function(v)
            Cart.Speed = v
        end)

        label("CARI GROBAK")
        local box = textbox("Kata kunci nama model (kosong = grobak/cart)")
        box.Text = Cart.Keyword
        box.FocusLost:Connect(function()
            Cart.Keyword = box.Text
        end)

        local status = label("Memindai grobak...")
        local found = scanCarts()
        if ActiveTab ~= cartTab or not status.Parent then return end
        local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")

        if #found == 0 then
            local allSeats = scanAllSeats()
            if #allSeats == 0 then
                status.Text = "❌ Tidak ada Seat/VehicleSeat apa pun yang ter-load di client.\n"
                    .. "Kemungkinan besar grobaknya belum ter-render (map pakai "
                    .. "StreamingEnabled & grobaknya jauh/belum terlihat), atau "
                    .. "grobak itu bukan Seat Roblox biasa (pakai sistem naik "
                    .. "custom / ProximityPrompt). Jalan dulu mendekat ke lokasi "
                    .. "grobaknya, lalu tekan Pindai Ulang."
            else
                status.Text = string.format(
                    "⚠ 0 cocok nama, tapi ada %d Seat lain ter-load.\n"
                    .. "Tekan '🔍 Tampilkan SEMUA Seat' di bawah untuk pilih manual.",
                    #allSeats)
            end
        else
            status.Text = string.format("✅ Ditemukan %d grobak (terdekat di atas)", #found)
            for i, c in ipairs(found) do
                if i > 15 then break end
                local dist = root and math.floor((c.seat.Position - root.Position).Magnitude) or 0
                button(string.format("🛒 %s  •  %d stud", c.name, dist), function()
                    goToCart(c)
                end)
            end
        end

        button("🔍  Pindai ulang", function() cartTab() end)

        button("🔍  Tampilkan SEMUA Seat (abaikan kata kunci)", function()
            clearContent()
            label("🔍 SEMUA SEAT YANG TER-LOAD")
            local all = scanAllSeats()
            if #all == 0 then
                label("Tidak ada Seat/VehicleSeat sama sekali di client sekarang.\n"
                    .. "Coba jalan mendekat ke lokasi grobaknya dulu (kalau map "
                    .. "pakai StreamingEnabled, objek jauh belum ter-load), lalu "
                    .. "kembali ke menu ini dan coba lagi.")
            else
                label(string.format("Ditemukan %d seat (terdekat di atas). Tap untuk TP + duduk:", #all))
                local r2 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                for i, c in ipairs(all) do
                    if i > 25 then break end
                    local dist = r2 and math.floor((c.seat.Position - r2.Position).Magnitude) or 0
                    local path = c.seat:GetFullName()
                    button(string.format("🪑 %s  •  %d stud\n%s", c.name, dist, path), function()
                        goToCart(c)
                    end)
                end
            end
            button("← Kembali", function() cartTab() end)
        end)

        label("Catatan: kendali grobak butuh grobak yang fisiknya dipegang "
            .. "klienmu (network ownership). Di sebagian game grobak yang "
            .. "dikunci server tidak akan bergerak. Kalau Auto TP tidak "
            .. "ketemu, pakai tombol 'Tampilkan SEMUA Seat' di atas untuk "
            .. "cari manual, lalu isi kata kunci sesuai nama yang muncul.")
    end
end)()

--====================================
-- EMOTE & ANIMASI KATALOG (cari langsung dari katalog Roblox)
-- Dibungkus fungsi sendiri supaya tidak menambah local di level atas.
--====================================
Inv.emoteTab, Inv.animTab = (function()
    local AvatarEditorService = game:GetService("AvatarEditorService")

    local EMOTE_CATS = {
        {"Emote", Enum.AvatarAssetType.EmoteAnimation},
    }
    local ANIM_CATS = {
        {"Idle", Enum.AvatarAssetType.IdleAnimation},
        {"Walk", Enum.AvatarAssetType.WalkAnimation},
        {"Run", Enum.AvatarAssetType.RunAnimation},
        {"Jump", Enum.AvatarAssetType.JumpAnimation},
        {"Fall", Enum.AvatarAssetType.FallAnimation},
        {"Climb", Enum.AvatarAssetType.ClimbAnimation},
        {"Swim", Enum.AvatarAssetType.SwimAnimation},
    }
    local CATS = EMOTE_CATS
    local SORTS = {
        {"Terbaru", Enum.CatalogSortType.RecentlyCreated},
        {"Relevan", Enum.CatalogSortType.Relevance},
        {"Terlaris", Enum.CatalogSortType.Bestselling},
        {"Favorit", Enum.CatalogSortType.MostFavorited},
    }
    -- kategori -> {folder di script Animate, nama Animation di dalamnya}
    local ANIMATE_MAP = {
        Idle = {"idle", {"Animation1", "Animation2"}},
        Walk = {"walk", {"WalkAnim"}},
        Run = {"run", {"RunAnim"}},
        Jump = {"jump", {"JumpAnim"}},
        Fall = {"fall", {"FallAnim"}},
        Climb = {"climb", {"ClimbAnim"}},
        Swim = {"swim", {"Swim"}},
        SwimIdle = {"swimidle", {"SwimIdle"}},
    }
    local MAX_RESULTS = 200 -- batas aman biar menu tidak berat di HP

    local catIdx, sortIdx = 1, 1
    local keyword = ""
    local searchId = 0
    local rows = {}
    local cache = {}      -- assetId -> daftar AnimationId
    local chosen = {}     -- kategori -> assetId (dipasang ulang saat respawn)
    local originals = {}  -- kategori -> {namaAnim = idAsli}
    local currentTrack
    local statusLabel

    local function isActive()
        return (ActiveTab == Inv.emoteTab or ActiveTab == Inv.animTab or ActiveTab == Inv.newEmoteTab) and statusLabel and statusLabel.Parent ~= nil
    end

    local function setStatus(t)
        if statusLabel and statusLabel.Parent then statusLabel.Text = t end
    end

    local function getHum()
        local char = LP.Character
        return char and char:FindFirstChildOfClass("Humanoid"), char
    end

    local function getAnimationIds(assetId)
        if type(assetId) == "table" then return assetId end
        if cache[assetId] then return cache[assetId] end
        local ok, objs = pcall(function()
            return game:GetObjects("rbxassetid://" .. tostring(assetId))
        end)
        if not ok or type(objs) ~= "table" then return nil end
        local ids = {}
        for _, o in ipairs(objs) do
            if o:IsA("Animation") and o.AnimationId ~= "" then
                table.insert(ids, o.AnimationId)
            end
            for _, d in ipairs(o:GetDescendants()) do
                if d:IsA("Animation") and d.AnimationId ~= "" then
                    table.insert(ids, d.AnimationId)
                end
            end
        end
        if #ids == 0 then return nil end
        cache[assetId] = ids
        return ids
    end

    local function stopEmote()
        if currentTrack then
            pcall(function() currentTrack:Stop(0.2) end)
            currentTrack = nil
        end
    end

    local function playEmote(assetId)
        local hum = getHum()
        if not hum then return false end
        local ids = getAnimationIds(assetId)
        if not ids then return false end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        stopEmote()
        local anim = Instance.new("Animation")
        anim.AnimationId = ids[1]
        local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
        if not ok or not track then return false end
        track.Priority = Enum.AnimationPriority.Action
        track:Play(0.2)
        currentTrack = track
        return true
    end

    local function restartAnimate(hum, animate)
        for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
            pcall(function() t:Stop(0) end)
        end
        animate.Disabled = true
        task.wait()
        animate.Disabled = false
    end

    local function applyAnimation(category, assetId, noRestart)
        local map = ANIMATE_MAP[category]
        local hum, char = getHum()
        if not map or not hum then return false end
        local animate = char:FindFirstChild("Animate")
        local folder = animate and animate:FindFirstChild(map[1])
        if not folder then return false end
        local ids = getAnimationIds(assetId)
        if not ids then return false end

        originals[category] = originals[category] or {}
        for i, animName in ipairs(map[2]) do
            local a = folder:FindFirstChild(animName)
            if a then
                if originals[category][animName] == nil then
                    originals[category][animName] = a.AnimationId
                end
                a.AnimationId = ids[i] or ids[1]
            end
        end
        if not noRestart then restartAnimate(hum, animate) end
        chosen[category] = assetId
        if type(assetId) ~= "table" then
            local PS = shared.DiiUiPersist
            if PS then PS.SetAnim(category, assetId) end
        end
        return true
    end

    local function resetAnimations()
        do local PS = shared.DiiUiPersist if PS then PS.ClearAnim() end end
        chosen = {}
        local hum, char = getHum()
        local animate = char and char:FindFirstChild("Animate")
        if hum and animate then
            for cat, saved in pairs(originals) do
                local map = ANIMATE_MAP[cat]
                local folder = map and animate:FindFirstChild(map[1])
                if folder then
                    for animName, id in pairs(saved) do
                        local a = folder:FindFirstChild(animName)
                        if a then a.AnimationId = id end
                    end
                end
            end
            restartAnimate(hum, animate)
        end
        originals = {}
    end

    -- PAKET ANIMASI (ID dari dokumentasi resmi Roblox, khusus R15)
    local PACKS = {
        {Name = "🚀  Astronaut", Ids = {Idle = {891621366, 891633237}, Walk = {891636393}, Run = {891636393}, Jump = {891627522}, Fall = {891617961}, Climb = {891609353}, Swim = {891639666}, SwimIdle = {891663592}}},
        {Name = "🎈  Bubbly", Ids = {Idle = {910004836, 910009958}, Walk = {910034870}, Run = {910025107}, Jump = {910016857}, Fall = {910001910}, Climb = {909997997}, Swim = {910028158}, SwimIdle = {910030921}}},
        {Name = "🤡  Cartoony", Ids = {Idle = {742637544, 742638445}, Walk = {742640026}, Run = {742638842}, Jump = {742637942}, Fall = {742637151}, Climb = {742636889}, Swim = {742639220}, SwimIdle = {742639812}}},
        {Name = "👴  Elder", Ids = {Idle = {845397899, 845400520}, Walk = {845403856}, Run = {845386501}, Jump = {845398858}, Fall = {845396048}, Climb = {845392038}, Swim = {845401742}, SwimIdle = {845403127}}},
        {Name = "🏰  Knight", Ids = {Idle = {657595757, 657568135}, Walk = {657552124}, Run = {657564596}, Jump = {658409194}, Fall = {657600338}, Climb = {658360781}, Swim = {657560551}, SwimIdle = {657557095}}},
        {Name = "🧘  Levitation", Ids = {Idle = {616006778, 616008087}, Walk = {616013216}, Run = {616010382}, Jump = {616008936}, Fall = {616005863}, Climb = {616003713}, Swim = {616011509}, SwimIdle = {616012453}}},
        {Name = "🧙  Mage", Ids = {Idle = {707742142, 707855907}, Walk = {707897309}, Run = {707861613}, Jump = {707853694}, Fall = {707829716}, Climb = {707826056}, Swim = {707876443}, SwimIdle = {707894699}}},
        {Name = "🥷  Ninja", Ids = {Idle = {656117400, 656118341}, Walk = {656121766}, Run = {656118852}, Jump = {656117878}, Fall = {656115606}, Climb = {656114359}, Swim = {656119721}, SwimIdle = {656121397}}},
        {Name = "🦜  Pirate", Ids = {Idle = {750781874, 750782770}, Walk = {750785693}, Run = {750783738}, Jump = {750782230}, Fall = {750780242}, Climb = {750779899}, Swim = {750784579}, SwimIdle = {750785176}}},
        {Name = "🤖  Robot", Ids = {Idle = {616088211, 616089559}, Walk = {616095330}, Run = {616091570}, Jump = {616090535}, Fall = {616087089}, Climb = {616086039}, Swim = {616092998}, SwimIdle = {616094091}}},
        {Name = "🚶  Rthro", Ids = {Idle = {2510197257, 2510196951}, Walk = {2510202577}, Run = {2510198475}, Jump = {2510197830}, Fall = {2510195892}, Climb = {2510192778}, Swim = {2510199791}, SwimIdle = {2510201162}}},
        {Name = "😎  Stylish", Ids = {Idle = {616136790, 616138447}, Walk = {616146177}, Run = {616140816}, Jump = {616139451}, Fall = {616134815}, Climb = {616133594}, Swim = {616143378}, SwimIdle = {616144772}}},
        {Name = "🦸  Superhero", Ids = {Idle = {616111295, 616113536}, Walk = {616122287}, Run = {616117076}, Jump = {616115533}, Fall = {616108001}, Climb = {616104706}, Swim = {616119360}, SwimIdle = {616120861}}},
        {Name = "🧸  Toy", Ids = {Idle = {782841498, 782845736}, Walk = {782843345}, Run = {782842708}, Jump = {782847020}, Fall = {782846423}, Climb = {782843869}, Swim = {782844582}, SwimIdle = {782845186}}},
        {Name = "🧛  Vampire", Ids = {Idle = {1083445855, 1083450166}, Walk = {1083473930}, Run = {1083462077}, Jump = {1083455352}, Fall = {1083443587}, Climb = {1083439238}, Swim = {1083464683}, SwimIdle = {1083467779}}},
        {Name = "🐺  Werewolf", Ids = {Idle = {1083195517, 1083214717}, Walk = {1083178339}, Run = {1083216690}, Jump = {1083218792}, Fall = {1083189019}, Climb = {1083182000}, Swim = {1083222527}, SwimIdle = {1083225406}}},
        {Name = "🧟  Zombie", Ids = {Idle = {616158929, 616160636}, Walk = {616168032}, Run = {616163682}, Jump = {616161997}, Fall = {616157476}, Climb = {616156119}, Swim = {616165109}, SwimIdle = {616166655}}},
    }

    local function applyPack(pack)
        local hum, char = getHum()
        if not hum then return false, "Karakter belum tersedia." end
        if hum.RigType ~= Enum.HumanoidRigType.R15 then
            return false, "Paket animasi hanya untuk karakter R15."
        end
        local animate = char:FindFirstChild("Animate")
        if not animate then return false, "Script Animate tidak ditemukan." end
        local any = false
        for cat, ids in pairs(pack.Ids) do
            local list = {}
            for i, id in ipairs(ids) do list[i] = "rbxassetid://" .. tostring(id) end
            if applyAnimation(cat, list, true) then any = true end
        end
        if any then restartAnimate(hum, animate) end
        return any, "Gagal memasang paket ini."
    end

    -- dipakai auto save: pasang lagi paket/animasi terakhir saat execute berikutnya
    Inv.RestoreAnim = function()
        local PS = shared.DiiUiPersist
        if not PS or not PS.Data.enabled then return end
        local D = PS.Data
        if not D.pack and next(D.anim) == nil then return end
        local char = LP.Character
        if not (char and char:WaitForChild("Humanoid", 10) and char:WaitForChild("Animate", 10)) then return end
        task.wait(1)
        PS.Replaying = true
        if D.pack then
            for _, pk in ipairs(PACKS) do
                if pk.Name == D.pack then pcall(applyPack, pk) break end
            end
        end
        for cat, id in pairs(D.anim) do
            pcall(applyAnimation, cat, tonumber(id) or id)
        end
        PS.Replaying = false
    end

    -- emote berhenti kalau karakter bergerak (seperti emote bawaan)
    RunService.Heartbeat:Connect(function()
        if currentTrack then
            local hum = getHum()
            if hum and hum.MoveDirection.Magnitude > 0.1 then stopEmote() end
        end
    end)

    -- pasang ulang animasi pilihan setelah respawn
    LP.CharacterAdded:Connect(function(char)
        currentTrack = nil
        originals = {}
        task.spawn(function()
            if not char:WaitForChild("Humanoid", 10) then return end
            if not char:WaitForChild("Animate", 10) then return end
            task.wait(1)
            for cat, id in pairs(chosen) do
                pcall(applyAnimation, cat, id)
            end
        end)
    end)

    local seen, orderLow, orderHigh = {}, 1000, 1000
    local curPages, loadingMore, renderId, scrollConn = nil, false, 0, nil
    local INITIAL_LOAD = 240
    local AutoAll, MAX_ALL, loadedCount, startAll = true, 3000, 0, nil
    local function clearRows()
        for _, r in ipairs(rows) do
            if r and r.Parent then r:Destroy() end
        end
        rows = {}
    end

    local function addItems(items, prepend)
        local added = 0
        local list = items
        if prepend then
            list = {}
            for i = #items, 1, -1 do list[#list + 1] = items[i] end
        end
        for _, item in ipairs(list) do
            if item.ItemType ~= Enum.AvatarItemType.Bundle and not seen[item.Id] then
                seen[item.Id] = true
                local b = Instance.new("TextButton")
                if prepend then
                    orderLow = orderLow - 1
                    b.LayoutOrder = orderLow
                else
                    orderHigh = orderHigh + 1
                    b.LayoutOrder = orderHigh
                end
                b.Size = UDim2.new(1, -5, 0, 54)
                b.BackgroundColor3 = Color3.fromRGB(65, 39, 105)
                b.Text = ""
                b.AutoButtonColor = true
                b.Parent = Content
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)

                local img = Instance.new("ImageLabel")
                img.Size = UDim2.fromOffset(44, 44)
                img.Position = UDim2.fromOffset(5, 5)
                img.BackgroundTransparency = 1
                img.Image = string.format("rbxthumb://type=Asset&id=%d&w=150&h=150", item.Id)
                img.Parent = b

                local nameLbl = Instance.new("TextLabel")
                nameLbl.Position = UDim2.fromOffset(56, 0)
                nameLbl.Size = UDim2.new(1, -62, 1, 0)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Active = false
                nameLbl.Text = tostring(item.Name)
                nameLbl.TextColor3 = WHITE
                nameLbl.Font = Enum.Font.GothamSemibold
                nameLbl.TextSize = 12
                nameLbl.TextWrapped = true
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                nameLbl.Parent = b

                guardedClick(b, Content, function()
                    setStatus("Memuat " .. tostring(item.Name) .. "...")
                    task.spawn(function()
                        local ok
                        if CATS[catIdx][1] == "Emote" then
                            ok = playEmote(item.Id)
                        else
                            ok = applyAnimation(CATS[catIdx][1], item.Id)
                        end
                        setStatus(ok and ("Dipakai: " .. tostring(item.Name))
                            or "Gagal memuat item ini (item berbayar yang belum dimiliki sering gagal). Coba item lain.")
                    end)
                end)

                table.insert(rows, b)
                added = added + 1
            end
        end
        return added
    end

    local function makeParams(limit)
        local params = CatalogSearchParams.new()
        params.SearchKeyword = keyword
        params.AssetTypes = {CATS[catIdx][2]}
        params.SortType = SORTS[sortIdx][2]
        params.IncludeOffSale = true
        params.Limit = limit
        return params
    end

    local moreBtn
    local loadMore, updateMoreBtn

    updateMoreBtn = function()
        if moreBtn and moreBtn.Parent then moreBtn:Destroy() end
        moreBtn = nil
        if curPages and not curPages.IsFinished and isActive() then
            moreBtn = button("⬇  Muat lebih banyak", function() task.spawn(loadMore) end)
            moreBtn.LayoutOrder = 10000000
            table.insert(rows, moreBtn)
        end
    end

    loadMore = function()
        if loadingMore or not curPages or curPages.IsFinished then return "skip" end
        loadingMore = true
        local my = searchId
        setStatus("Memuat lebih banyak...")
        local ok = pcall(function() curPages:AdvanceToNextPageAsync() end)
        if ok and my == searchId and isActive() then
            local n = addItems(curPages:GetCurrentPage())
            loadedCount = loadedCount + n
            setStatus("Memuat semua... " .. loadedCount .. " item")
            updateMoreBtn()
        end
        loadingMore = false
        return ok
    end

    -- muat halaman berikutnya terus sampai habis (atau sampai batas MAX_ALL)
    startAll = function(my)
        my = my or searchId
        local fails = 0
        while AutoAll and my == searchId and isActive() and curPages
            and not curPages.IsFinished and loadedCount < MAX_ALL do
            local r = loadMore()
            if r == false then
                fails = fails + 1
                if fails >= 6 then break end
                task.wait(1.5)
            else
                if r == true then fails = 0 end
                task.wait(0.25)
            end
        end
        if my == searchId and isActive() then
            if curPages and curPages.IsFinished then
                setStatus("✅ Semua sudah dimuat: " .. loadedCount .. " item.")
            elseif loadedCount >= MAX_ALL then
                setStatus("Batas " .. MAX_ALL .. " item tercapai (biar tidak berat). Pakai kolom cari untuk menyempit.")
            end
        end
    end

    local function doSearch()
        searchId = searchId + 1
        local my = searchId
        clearRows()
        seen, orderLow, orderHigh, curPages, moreBtn = {}, 1000, 1000, nil, nil
        setStatus("Mencari...")

        local ok, pages = pcall(function()
            return AvatarEditorService:SearchCatalog(makeParams(120))
        end)
        if my ~= searchId or not isActive() then return end
        if not ok or not pages then
            setStatus("Pencarian gagal. Coba lagi sebentar.")
            return
        end

        curPages = pages
        local total = addItems(pages:GetCurrentPage())
        while not pages.IsFinished and total < INITIAL_LOAD and my == searchId and isActive() do
            setStatus("Memuat hasil... (" .. total .. ")")
            local okNext = pcall(function() pages:AdvanceToNextPageAsync() end)
            if not okNext or my ~= searchId or not isActive() then break end
            total = total + addItems(pages:GetCurrentPage())
        end

        if my ~= searchId or not isActive() then return end
        loadedCount = total
        updateMoreBtn()
        setStatus(total == 0 and "Tidak ada hasil."
            or (total .. " hasil. Ketuk item untuk memakai."))
        if AutoAll and startAll and total > 0 then task.spawn(startAll, my) end
    end

    -- cek item paling baru; yang belum pernah tampil ditaruh di paling atas
    local function refreshNewest()
        local ok, pages = pcall(function()
            return AvatarEditorService:SearchCatalog(makeParams(120))
        end)
        if not ok or not pages or not isActive() then return 0 end
        local n = addItems(pages:GetCurrentPage(), true)
        loadedCount = loadedCount + n
        if n > 0 then setStatus("🆕 " .. n .. " item baru ditambahkan di atas.") end
        return n
    end

    local lastMode
    local function render(m)
        CATS = (m == "emote") and EMOTE_CATS or ANIM_CATS
        if lastMode ~= m then
            catIdx, keyword, lastMode = 1, "", m
        end
        clearContent()
        rows = {}
        renderId = renderId + 1
        local myRender = renderId
        if scrollConn then scrollConn:Disconnect() scrollConn = nil end
        pcall(function()
            scrollConn = Content:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                if renderId ~= myRender or not isActive() then return end
                if Content.CanvasPosition.Y + Content.AbsoluteSize.Y >= Content.AbsoluteCanvasSize.Y - 300 then
                    task.spawn(loadMore)
                end
            end)
        end)
        task.spawn(function()
            while renderId == myRender do
                task.wait(15) -- cek item terbaru tiap 15 detik
                if renderId ~= myRender or not isActive() then break end
                if SORTS[sortIdx][1] == "Terbaru" and not loadingMore then pcall(refreshNewest) end
            end
        end)
        label(m == "emote" and "🎭 EMOTE" or "🏃 ANIMASI")
        statusLabel = label(m == "emote"
            and "Ketik nama emote, hasil muncul otomatis."
            or "Pilih paket (1 klik) atau cari animasi satuan.")
        statusLabel.Font = Enum.Font.Gotham
        statusLabel.TextSize = 12
        statusLabel.TextColor3 = GREY

        if m == "anim" then
            label("📦 PAKET ANIMASI  (ketuk = pasang semua gerakan)")
            for _, pack in ipairs(PACKS) do
                button(pack.Name, function()
                    setStatus("Memasang " .. pack.Name .. "...")
                    task.spawn(function()
                        local ok, why = applyPack(pack)
                        if ok then local PS = shared.DiiUiPersist if PS then PS.SetPack(pack.Name) end end
                        setStatus(ok and ("Paket dipakai: " .. pack.Name) or why)
                    end)
                end)
            end
            button("🔁  Kembalikan semua animasi ke bawaan", function()
                resetAnimations()
                setStatus("Animasi dikembalikan ke bawaan.")
            end)
            label("🔎 CARI ANIMASI SATUAN (katalog)")
            button("Kategori: " .. CATS[catIdx][1] .. "  (ketuk untuk ganti)", function()
                catIdx = catIdx % #CATS + 1
                render(m)
            end)
        end

        button("Urut: " .. SORTS[sortIdx][1] .. "  (ketuk untuk ganti)", function()
            sortIdx = sortIdx % #SORTS + 1
            render(m)
        end)
        toggleButton("⏬  Muat SEMUA otomatis (sampai habis)", function() return AutoAll end, function()
            AutoAll = not AutoAll
            if AutoAll and startAll then task.spawn(startAll, searchId) end
        end)

        local box = textbox(m == "emote" and "Cari nama emote..." or "Cari nama animasi...")
        box.Text = keyword
        local typeToken = 0
        box:GetPropertyChangedSignal("Text"):Connect(function()
            keyword = box.Text
            typeToken = typeToken + 1
            local my = typeToken
            task.delay(0.6, function()
                if my == typeToken and isActive() then doSearch() end
            end)
        end)
        box.FocusLost:Connect(function(enter)
            if enter and isActive() then doSearch() end
        end)

        if m == "emote" then
            button("🆕  Cek emote terbaru sekarang", function()
                task.spawn(function()
                    local n = refreshNewest()
                    if n == 0 then setStatus("Belum ada item baru.") end
                end)
            end)
            button("⏹  Stop Emote", stopEmote)
        end

        task.spawn(doSearch)
    end

    return function() render("emote") end, function() render("anim") end
end)()

--====================================
-- CINEMATIC CAM (kamera depan karakter + goyangan halus)
-- Kamera ada di depan karakter, karakter tetap di tengah frame,
-- ada sway pelan seperti kamera tangan. Hanya mengubah kamera client.
--====================================
;(function() -- blok dipisah agar tidak melebihi batas 200 variabel lokal
    local StarterGui = game:GetService("StarterGui")
    local C = {
        Enabled = false, Locked = false, HideUI = false,
        Dist = 9, Height = 1.5, Yaw = 0, FOV = 60,
        Sway = 0, SwaySpeed = 2, Smooth = 10, Follow = 1.5,
        TargetPlayer = nil, Filter = "", Orbit = 0, YawAuto = 0,
        T = 0, Pos = nil, Look = nil, OldFOV = nil, Conn = nil,
    }
    Inv.Cine = C

    local function cineTarget()
        local pl = C.TargetPlayer
        if pl and pl.Parent == Players then return pl.Character end
        return LP.Character
    end

    -- pilih pemain yang difokuskan (nil = diri sendiri)
    local function cineSelect(pl)
        C.TargetPlayer = pl
        C.Base, C.Anim, C.Pos = nil, nil, nil   -- kamera meluncur halus ke target baru
    end

    local function cineStop()
        C.Enabled = false
        if C.Conn then C.Conn:Disconnect() C.Conn = nil end
        local cam = workspace.CurrentCamera
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            if C.OldFOV then cam.FieldOfView = C.OldFOV end
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then cam.CameraSubject = hum end
        end
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
        C.HideUI, C.Pos, C.Look, C.Base, C.Anim, C.Cur = false, nil, nil, nil, nil, nil
    end

    local function cineStart()
        pcall(function() if freeCam.Enabled then stopFreeCam() end end)
        local cam = workspace.CurrentCamera
        if not cam then return end
        C.OldFOV = C.OldFOV or cam.FieldOfView
        cam.CameraType = Enum.CameraType.Scriptable
        C.Enabled, C.Pos, C.Look = true, nil, nil
        if C.Conn then C.Conn:Disconnect() end
        C.Conn = RunService.RenderStepped:Connect(function(dt)
            if C.TargetPlayer and C.TargetPlayer.Parent ~= Players then
                cineSelect(nil)
                toast("Target keluar, kamera kembali ke dirimu")
            end
            local char = cineTarget()
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            C.YawAuto = (C.YawAuto + C.Orbit * dt) % 360
            local cam2 = workspace.CurrentCamera
            if cam2.CameraType ~= Enum.CameraType.Scriptable then
                cam2.CameraType = Enum.CameraType.Scriptable
            end
            cam2.FieldOfView = C.FOV

            -- gerakan tubuh (emote / jalan): selisih posisi kepala terhadap
            -- posisi "diam"-nya, difilter agar yang terbaca hanya gerakan animasi
            local head = char:FindFirstChild("Head")
            local rel = head and (head.Position - hrp.Position) or Vector3.zero
            C.Base = C.Base and C.Base:Lerp(rel, 1 - math.exp(-dt * 0.8)) or rel
            local anim = (rel - C.Base) * C.Follow
            C.Anim = C.Anim and C.Anim:Lerp(anim, 1 - math.exp(-dt * 25)) or anim

            local pivot = hrp.Position + Vector3.new(0, C.Height, 0)
            local flat = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
            if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
            local dir = (CFrame.Angles(0, math.rad(C.Yaw + C.YawAuto), 0) * CFrame.new(flat.Unit)).Position
            local wantPos = pivot + dir * C.Dist + Vector3.new(0, 0.6, 0)

            -- mode kunci: posisi kamera diam di tempat pertama dihitung
            if C.Locked then
                C.Pos = C.Pos or wantPos
                wantPos = C.Pos
            else
                C.Pos = nil
            end

            local a = 1 - math.exp(-dt * C.Smooth)
            C.Look = C.Look and C.Look:Lerp(pivot, a) or pivot
            local pos = C.Pos and wantPos or (C.Cur and C.Cur:Lerp(wantPos, a) or wantPos)
            C.Cur = pos

            -- kamera ikut bergeser mengikuti gerakan tubuh (latar bergeser, karakter tetap)
            local camPos = pos + C.Anim
            local lookAt = C.Look + C.Anim * 0.5

            -- goyangan konstan opsional (default mati)
            C.T = C.T + (dt * C.SwaySpeed)
            local base = CFrame.lookAt(camPos, lookAt)
            cam2.CFrame = base * CFrame.new(
                math.sin(C.T) * C.Sway,
                math.cos(C.T * 0.8) * C.Sway * 0.6,
                0
            )
        end)
    end

    Gui.Destroying:Connect(cineStop)

    Inv.cinemaTab = function()
        clearContent()
        label("🎬 CINEMATIC CAM")
        label("Kamera di depan karakter; goyangan mengikuti gerakan karakter saat jalan/emote.")

        toggleButton("🎬  Cinematic Cam", function() return C.Enabled end, function()
            if C.Enabled then cineStop() else cineStart() end
        end)
        toggleButton("📌  Kunci posisi kamera (diam)", function() return C.Locked end, function()
            C.Locked = not C.Locked
            C.Pos = nil
        end)
        toggleButton("🙈  Sembunyikan UI game", function() return C.HideUI end, function()
            C.HideUI = not C.HideUI
            pcall(function()
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not C.HideUI)
            end)
        end)

        -- ===== DAFTAR PEMAIN: kunci kamera ke avatar orang lain =====
        local who = (C.TargetPlayer and C.TargetPlayer.Parent == Players) and dn(C.TargetPlayer) or "Diri sendiri"
        label("🎯 Kamera mengikuti: " .. who)
        label("👥 PILIH PEMAIN YANG DIREKAM")
        local tb = textbox("Cari nama pemain (filter daftar)")
        tb.Text = C.Filter or ""
        tb.FocusLost:Connect(function()
            C.Filter = tb.Text
            Inv.cinemaTab()
        end)
        button((C.TargetPlayer == nil and "✅  " or "🧍  ") .. "Diri sendiri", function()
            cineSelect(nil)
            if not C.Enabled then cineStart() end
            Inv.cinemaTab()
        end)
        local q = (C.Filter or ""):lower()
        local any = false
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and (q == "" or pl.Name:lower():find(q, 1, true)
                or pl.DisplayName:lower():find(q, 1, true)) then
                any = true
                local mark = (C.TargetPlayer == pl) and "✅  " or "🎯  "
                button(mark .. dn(pl), function()
                    cineSelect(pl)
                    if not C.Enabled then cineStart() end
                    toast("Kamera mengikuti " .. pl.Name)
                    Inv.cinemaTab()
                end)
            end
        end
        if not any then label("Tidak ada pemain lain yang cocok.") end
        button("🔄  Refresh daftar pemain", function() Inv.cinemaTab() end)

        label("🎥 FRAMING CEPAT (untuk konten dance)")
        button("🧍  Seluruh badan", function()
            C.Dist, C.Height, C.FOV = 11, 1.2, 60
            Inv.cinemaTab()
        end)
        button("🙂  Setengah badan", function()
            C.Dist, C.Height, C.FOV = 6.5, 1.8, 60
            Inv.cinemaTab()
        end)
        button("😀  Wajah (close up)", function()
            C.Dist, C.Height, C.FOV = 3.2, 2.4, 50
            Inv.cinemaTab()
        end)

        slider("Jarak kamera", 2, 40, C.Dist, 0.5, function(v) C.Dist = v end, "%.1f")
        slider("Tinggi fokus", -2, 8, C.Height, 0.1, function(v) C.Height = v end, "%.1f")
        slider("Sudut (0 = depan, 180 = belakang)", -180, 180, C.Yaw, 5, function(v) C.Yaw = v end, "%d")
        slider("FOV", 30, 100, C.FOV, 1, function(v) C.FOV = v end, "%d")
        slider("Putar kamera otomatis (derajat/detik, 0 = mati)", -90, 90, C.Orbit, 5, function(v) C.Orbit = v end, "%d")
        slider("Ikut gerakan karakter (emote/jalan)", 0, 5, C.Follow, 0.1, function(v) C.Follow = v end, "%.1f")
        slider("Goyangan konstan (0 = mati)", 0, 1.5, C.Sway, 0.05, function(v) C.Sway = v end, "%.2f")
        slider("Kecepatan goyang", 0.5, 6, C.SwaySpeed, 0.1, function(v) C.SwaySpeed = v end, "%.1f")
        slider("Kehalusan ikut", 2, 30, C.Smooth, 1, function(v) C.Smooth = v end, "%d")

        button("↩  Preset mirip video (depan, ikut gerakan)", function()
            C.Dist, C.Height, C.Yaw, C.FOV = 9, 1.5, 0, 60
            C.Sway, C.SwaySpeed, C.Smooth, C.Follow = 0, 2, 10, 1.5
            C.Orbit, C.YawAuto = 0, 0
            Inv.cinemaTab()
        end)
        label("Free Cam otomatis mati saat Cinematic Cam menyala. Kamera hanya berubah di layarmu.")
    end
end)()

--====================================
-- SERVER: REJOIN + CARI SERVER
--====================================
;(function() -- blok dipisah agar tidak melebihi batas 200 variabel lokal
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local S = {Sort = "Asc", Cursor = nil, List = {}, Busy = false, Msg = "Tekan Muat daftar server.",
        JobText = "", Friends = nil, FMsg = "Tekan Muat daftar teman.", FBusy = false}

    local function httpGet(url)
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if req then
            local ok, res = pcall(req, {Url = url, Method = "GET"})
            if ok and type(res) == "table" and res.Body then return res.Body end
        end
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok then return body end
    end

    local function joinServer(id)
        toast("Pindah server...")
        local ok, err = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LP) end)
        if not ok then toast("Gagal pindah: " .. tostring(err):sub(1, 60)) end
    end

    -- ID pendek ala daftar server Roblox: 4 karakter awal + "-" + 4 karakter akhir dari Job ID (contoh: a8f3-4ad9)
    local function shortId(id)
        id = tostring(id or ""):lower()
        return id:sub(1, 4) .. "-" .. id:sub(-4)
    end

    local findByShort -- didefinisikan setelah fetch

    local function rejoin()
        toast("Rejoin...")
        local ok, err = pcall(function()
            if #Players:GetPlayers() <= 1 then
                TeleportService:Teleport(game.PlaceId, LP)   -- server sepi: otomatis dapat server baru
            else
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
            end
        end)
        if not ok then toast("Gagal rejoin: " .. tostring(err):sub(1, 60)) end
    end

    local function fetch(more)
        if S.Busy then return end
        S.Busy = true
        S.Msg = "Memuat server..."
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100")
            :format(game.PlaceId, S.Sort)
        if more and S.Cursor then url = url .. "&cursor=" .. S.Cursor end
        local body = httpGet(url)
        local ok, data = pcall(function() return HttpService:JSONDecode(body or "") end)
        if not ok or type(data) ~= "table" or type(data.data) ~= "table" then
            S.Msg = "Gagal memuat (executor tanpa HTTP, atau kena limit). Coba lagi sebentar."
        else
            if not more then S.List = {} end
            for _, sv in ipairs(data.data) do
                if sv.id ~= game.JobId and (sv.playing or 0) < (sv.maxPlayers or 0) then
                    table.insert(S.List, sv)
                end
            end
            S.Cursor = data.nextPageCursor
            S.Msg = #S.List .. " server ditemukan."
        end
        S.Busy = false
    end

    local function refresh()
        if ActiveTab == Inv.serverTab then Inv.serverTab() end
    end

    -- cari server di daftar publik yang ID pendeknya cocok (maks 20 halaman)
    findByShort = function(short)
        local function scan()
            for _, sv in ipairs(S.List) do
                if shortId(sv.id) == short then return sv end
            end
        end
        local hit = scan()
        if hit then return hit end
        S.Cursor = nil
        for page = 1, 20 do
            fetch(page > 1)
            hit = scan()
            if hit then return hit end
            if not S.Cursor then break end
            task.wait(0.4)
        end
    end


    -- DAFTAR TEMAN: username semua teman di akunmu + yang online sedang main di mana
    local function loadFriends()
        if S.FBusy then return end
        S.FBusy = true
        S.FMsg = "Memuat daftar teman..."
        refresh()
        local online, offline, onlineIds = {}, {}, {}
        local okOn, res = pcall(function() return LP:GetFriendsOnline(200) end)
        if okOn and type(res) == "table" then
            for _, f in ipairs(res) do
                onlineIds[f.VisitorId] = true
                online[#online + 1] = f
            end
        end
        local okAll = pcall(function()
            local pages = Players:GetFriendsAsync(LP.UserId)
            while true do
                for _, it in ipairs(pages:GetCurrentPage()) do
                    if not onlineIds[it.Id] then offline[#offline + 1] = it.Username end
                end
                if pages.IsFinished or #offline >= 300 then break end
                pages:AdvanceToNextPageAsync()
            end
        end)
        table.sort(offline, function(a, b) return a:lower() < b:lower() end)
        S.Friends = {Online = online, Offline = offline}
        if okOn or okAll then
            S.FMsg = ("%d teman online  •  %d offline"):format(#online, #offline)
        else
            S.FMsg = "Gagal memuat teman (coba lagi sebentar)."
        end
        S.FBusy = false
        refresh()
    end

    Inv.serverTab = function()
        clearContent()
        label("🌐 SERVER")
        local status = label(S.Msg)
        status.Font = Enum.Font.Gotham
        status.TextSize = 12
        status.TextColor3 = GREY

        button("🔁  Rejoin (masuk lagi ke server ini)", rejoin)
        button("🎲  Pindah ke server acak", function()
            toast("Pindah ke server acak...")
            pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
        end)
        button("🏝  Masuk server paling sepi", function()
            task.spawn(function()
                S.Sort = "Asc"
                fetch(false)
                if S.List[1] then joinServer(S.List[1].id) else refresh() end
            end)
        end)
        button("🎉  Masuk server paling ramai (belum penuh)", function()
            task.spawn(function()
                S.Sort = "Desc"
                fetch(false)
                if S.List[1] then joinServer(S.List[1].id) else refresh() end
            end)
        end)


        label("🔑 GABUNG LEWAT ID SERVER")
        local jobBox = textbox("Tempel ID server (contoh: a8f3-4ad9)")
        jobBox.Text = S.JobText or ""
        jobBox:GetPropertyChangedSignal("Text"):Connect(function() S.JobText = jobBox.Text end)
        button("🚪  Gabung ke ID ini", function()
            local id = ((S.JobText or ""):gsub("[%s\"']", "")):lower()
            if id == "" then toast("Isi ID server dulu") return end
            if id == game.JobId:lower() or id == shortId(game.JobId) then toast("Kamu sudah ada di server ini") return end
            if #id > 12 then
                joinServer(id) -- Job ID panjang (GUID lengkap) tetap didukung
                return
            end
            if not id:match("^%x%x%x%x%-%x%x%x%x$") then toast("Format ID salah, contoh: a8f3-4ad9") return end
            task.spawn(function()
                toast("Mencari server " .. id .. "...")
                local sv = findByShort(id)
                refresh()
                if sv then joinServer(sv.id) else toast("Server " .. id .. " tidak ditemukan (mungkin penuh/sudah tutup)") end
            end)
        end)
        button("📋  Salin ID server ini", function()
            if setclipboard then
                setclipboard(shortId(game.JobId))
                toast("ID disalin: " .. shortId(game.JobId))
            else
                toast("Executor tidak mendukung salin")
            end
        end)
        local jl = label("ID server sekarang:\n" .. shortId(game.JobId))
        jl.Font = Enum.Font.Gotham
        jl.TextSize = 11
        jl.TextColor3 = GREY
        label("ID harus dari game yang sama dengan yang kamu mainkan sekarang.")

        label("👥 TEMAN DI AKUNMU")
        local fl = label(S.FMsg)
        fl.Font = Enum.Font.Gotham
        fl.TextSize = 12
        fl.TextColor3 = GREY
        button("📥  Muat daftar teman", function() task.spawn(loadFriends) end)
        if S.Friends then
            for i, f in ipairs(S.Friends.Online) do
                if i > 60 then break end
                local uname = f.UserName or f.Username or "?"
                local dname = (f.DisplayName and f.DisplayName ~= "") and f.DisplayName or uname
                local where = f.LastLocation
                if not where or where == "" then where = "Online" end
                local inGame = f.GameId and f.GameId ~= "" and f.PlaceId and f.PlaceId ~= 0
                local tag = inGame and "   →  Susul" or ""
                button(("🟢 %s (@%s)\n🎮 %s%s"):format(dname, uname, where, tag), function()
                    if not inGame then toast(dname .. " tidak sedang di dalam game") return end
                    if f.GameId == game.JobId then toast("Kamu sudah satu server dengan " .. dname) return end
                    toast("Menyusul " .. dname .. "...")
                    local ok, err = pcall(function()
                        TeleportService:TeleportToPlaceInstance(f.PlaceId, f.GameId, LP)
                    end)
                    if not ok then toast("Gagal: " .. tostring(err):sub(1, 60)) end
                end)
            end
            if #S.Friends.Offline > 0 then
                local shown = {}
                for i, n in ipairs(S.Friends.Offline) do
                    if i > 80 then break end
                    shown[#shown + 1] = n
                end
                local extra = #S.Friends.Offline - #shown
                local ol = label("⚫ Offline: " .. table.concat(shown, ", ")
                    .. (extra > 0 and ("  … +" .. extra .. " lainnya") or ""))
                ol.Font = Enum.Font.Gotham
                ol.TextSize = 12
                ol.TextColor3 = GREY
            end
            label("Menyusul teman hanya bisa kalau dia main di game/experience yang sama denganmu.")
        end

        label("🔎 DAFTAR SERVER")
        button("Urut: " .. (S.Sort == "Asc" and "paling sepi" or "paling ramai") .. "  (ketuk untuk ganti)", function()
            S.Sort = S.Sort == "Asc" and "Desc" or "Asc"
            refresh()
        end)
        button("📥  Muat daftar server", function()
            task.spawn(function() fetch(false) refresh() end)
        end)

        for i, sv in ipairs(S.List) do
            if i > 40 then break end
            local ping = sv.ping and (" • " .. tostring(sv.ping) .. "ms") or ""
            button(("👥 %d/%d%s  •  %s   →  Masuk"):format(sv.playing or 0, sv.maxPlayers or 0, ping, shortId(sv.id)), function()
                joinServer(sv.id)
            end)
        end
        if S.Cursor and #S.List > 0 then
            button("⬇  Muat lebih banyak server", function()
                task.spawn(function() fetch(true) refresh() end)
            end)
        end
    end
end)()

--====================================
-- TELEPORT TEMPAT
-- Cara kerja baru (lebih akurat):
--  1. Lokasi yang kamu SIMPAN = koordinat pasti (disimpan per-map/PlaceId).
--  2. Kalau belum disimpan, ketuk nama -> script mencari objek asli di map
--     dan menampilkan DAFTAR HASIL (nama asli + jarak). Kamu pilih yang benar,
--     lalu otomatis tersimpan ke slot itu, jadi berikutnya langsung pas.
--  3. Kotak CARI: ketik nama objek apa saja di map, pilih hasilnya.
--====================================
;(function() -- blok dipisah agar tidak melebihi batas 200 variabel lokal
    local HttpService = game:GetService("HttpService")
    -- file per-map supaya koordinat map lain tidak ikut tercampur
    local FILE = "DiiUi_TeleportSpots_" .. tostring(game.PlaceId) .. ".json"
    local MODES = {"go", "save", "del"}
    local S = {Saved = {}, Mode = 1, Msg = "Ketuk lokasi untuk teleport.", Pick = nil}
    local MAX_RESULTS = 25

    pcall(function()
        if isfile and readfile and isfile(FILE) then
            local data = HttpService:JSONDecode(readfile(FILE))
            if type(data) == "table" then S.Saved = data end
        end
    end)
    local function persist()
        pcall(function()
            if writefile then writefile(FILE, HttpService:JSONEncode(S.Saved)) end
        end)
    end

    -- kw = kata kunci nama objek di map (dipakai untuk mencari kandidat)
    local PLACES = {
        {name = "Piano Konser", kw = {"piano"}},
        {name = "Tempat Nonton", kw = {"nonton", "theater", "theatre", "cinema", "bioskop"}},
        {name = "Rumah Ayam", kw = {"ayam", "chicken", "coop"}},
        {name = "Rumah Pohon", kw = {"treehouse", "rumah pohon", "rumahpohon"}},
        {name = "Tempat Santai", kw = {"santai", "chill", "lounge"}},
        {name = "Perosotan", kw = {"perosot", "slide"}},
        {name = "Picnic", kw = {"picnic", "piknik"}},
        {name = "Api Unggun", kw = {"campfire", "bonfire", "api unggun", "apiunggun"}},
        {name = "Papan Iklan", kw = {"billboard", "iklan"}},
        {name = "Jembatan", kw = {"bridge", "jembatan"}},
        {name = "Green House", kw = {"greenhouse", "green house"}},
        {name = "Kereta Gantung", kw = {"gondola", "cable", "kereta"}},
        {name = "Hutan Studio", kw = {"studio"}},
        {name = "Taman Bermain", kw = {"playground", "taman bermain", "tamanbermain"}},
        {name = "Labirin", kw = {"labirin", "maze"}},
        {name = "Spawn 1", spawn = true},
        {name = "Spawn 2", spawn = true},
        {name = "Isolasi Diri 1", kw = {"isolasi", "isolation"}},
        {name = "Isolasi Diri 2", kw = {"isolasi", "isolation"}},
        {name = "Carriage", kw = {"carriage"}},
        {name = "Leaderboard", kw = {"leaderboard"}},
        {name = "Market Stall", kw = {"market", "stall"}},
        {name = "Booth System", kw = {"booth"}},
    }

    local function inCharacter(inst)
        local p = inst
        while p and p ~= workspace do
            if p:IsA("Model") and Players:GetPlayerFromCharacter(p) then return true end
            p = p.Parent
        end
        return false
    end

    local function myPos()
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        return hrp and hrp.Position
    end

    local function centerOf(inst)
        if inst:IsA("Model") then
            local ok, cf = pcall(function() return (inst:GetBoundingBox()) end)
            if ok and cf then return cf.Position end
            return inst:GetPivot().Position
        end
        return inst.Position
    end

    local function sizeOf(inst)
        if inst:IsA("Model") then
            local ok, _, size = pcall(function() return inst:GetBoundingBox() end)
            if ok and size then return size end
            return Vector3.new(4, 4, 4)
        end
        return inst.Size
    end

    -- cari kandidat; hasil diurutkan dari yang terdekat denganmu
    local function findMatches(kw, spawnOnly)
        local found, set = {}, {}
        for _, d in ipairs(workspace:GetDescendants()) do
            if spawnOnly then
                if d:IsA("SpawnLocation") then found[#found + 1] = d; set[d] = true end
            elseif d:IsA("Model") or d:IsA("BasePart") then
                local n = d.Name:lower()
                for _, k in ipairs(kw) do
                    if n:find(k, 1, true) then
                        if not inCharacter(d) then found[#found + 1] = d; set[d] = true end
                        break
                    end
                end
            end
        end
        -- buang objek yang induknya sudah masuk hasil (hindari duplikat model + isinya)
        local list = {}
        for _, d in ipairs(found) do
            local skip, p = false, d.Parent
            while p and p ~= workspace do
                if set[p] then skip = true break end
                p = p.Parent
            end
            if not skip then list[#list + 1] = d end
        end
        local me = myPos()
        local dist = {}
        for _, d in ipairs(list) do
            local ok, c = pcall(centerOf, d)
            dist[d] = (ok and me) and (c - me).Magnitude or math.huge
        end
        table.sort(list, function(a, b) return dist[a] < dist[b] end)
        while #list > MAX_RESULTS do table.remove(list) end
        return list, dist
    end

    -- titik mendarat: tepat di tengah objek, turun ke lantai di bawahnya
    local function landingFor(inst)
        local c = centerOf(inst)
        local size = sizeOf(inst)
        if inst:IsA("SpawnLocation") then return c + Vector3.new(0, size.Y / 2 + 4, 0) end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {LP.Character}
        local hit = workspace:Raycast(c + Vector3.new(0, 1, 0), Vector3.new(0, -(size.Y / 2 + 60), 0), params)
        if hit then return hit.Position + Vector3.new(0, 3.5, 0) end
        return c + Vector3.new(0, 3.5, 0)
    end

    local function teleportTo(pos)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        char:PivotTo(CFrame.new(pos))
        hrp.AssemblyLinearVelocity = Vector3.zero
        return true
    end

    Inv.teleportTab = function()
        clearContent()
        label("🏠 TELEPORT TEMPAT")
        local status = label(S.Msg)
        status.Font = Enum.Font.Gotham
        status.TextSize = 12
        status.TextColor3 = GREY
        local function setStatus(t)
            S.Msg = t
            if status and status.Parent then status.Text = t end
        end

        local function modeText()
            local m = MODES[S.Mode]
            if m == "go" then return "Mode: 🚀 PERGI (teleport)" end
            if m == "save" then return "Mode: 💾 SIMPAN posisiku ke lokasi" end
            return "Mode: 🗑 HAPUS lokasi tersimpan"
        end
        button(modeText() .. "  (ketuk untuk ganti)", function()
            S.Mode = S.Mode % #MODES + 1
            local m = MODES[S.Mode]
            S.Msg = (m == "go" and "Ketuk lokasi untuk teleport.")
                or (m == "save" and "Berdiri di lokasi yang diinginkan, lalu ketuk namanya.")
                or "Ketuk nama lokasi untuk menghapus simpanannya."
            Inv.teleportTab()
        end)

        -- CARI BEBAS
        label("🔎 CARI OBJEK DI MAP")
        local searchBox = textbox("Ketik nama objek (mis. piano, bridge)")
        button("🔎  Cari", function()
            local q = ((searchBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")):lower()
            if q == "" then setStatus("Isi kata kunci dulu.") return end
            local list, dist = findMatches({q}, false)
            if #list == 0 then setStatus("Tidak ada objek bernama '" .. q .. "' di map.") return end
            S.Pick = {title = "Hasil cari: " .. q, list = list, dist = dist}
            S.Msg = #list .. " hasil. Pilih yang benar."
            Inv.teleportTab()
        end)

        -- HASIL KANDIDAT (pilih yang benar)
        if S.Pick then
            label("✅ " .. S.Pick.title)
            for _, m in ipairs(S.Pick.list) do
                if m.Parent then
                    local parentName = (m.Parent ~= workspace) and ("  ‹" .. m.Parent.Name .. "›") or ""
                    local d = S.Pick.dist[m]
                    local dtxt = (d and d < math.huge) and ("  •  " .. math.floor(d) .. " studs") or ""
                    button("📍 " .. m.Name .. parentName .. dtxt, function()
                        local pos = landingFor(m)
                        if teleportTo(pos) then
                            if S.Pick and S.Pick.slot then
                                -- simpan koordinat pasti (go() menambah +3 di Y, jadi kurangi 3 di sini)
                                S.Saved[S.Pick.slot] = {pos.X, pos.Y - 3, pos.Z}
                                persist()
                                setStatus("Teleport ke " .. m.Name .. " dan disimpan ke '" .. S.Pick.slot .. "'.")
                            else
                                setStatus("Teleport ke " .. m.Name)
                            end
                        else
                            setStatus("Karakter belum tersedia.")
                        end
                    end)
                end
            end
            button("✖  Tutup hasil", function()
                S.Pick = nil
                Inv.teleportTab()
            end)
        end

        local function go(entry)
            local name = entry.name
            local sv = S.Saved[name]
            if sv then
                if teleportTo(Vector3.new(sv[1], sv[2] + 3, sv[3])) then
                    setStatus("Teleport ke " .. name .. " (lokasi tersimpan)")
                end
                return
            end
            setStatus("Mencari " .. name .. " di map...")
            local list, dist = findMatches(entry.kw or {}, entry.spawn)
            if #list == 0 then
                setStatus("'" .. name .. "' tidak ketemu. Berdiri di sana, ganti mode ke SIMPAN, lalu ketuk namanya. Atau pakai kotak CARI.")
                return
            end
            S.Pick = {title = "Pilih yang benar untuk: " .. name, list = list, dist = dist, slot = name}
            S.Msg = #list .. " kandidat untuk '" .. name .. "'. Pilih yang benar (otomatis tersimpan)."
            Inv.teleportTab()
        end

        local function saveHere(name)
            local p = myPos()
            if not p then setStatus("Karakter belum tersedia.") return false end
            S.Saved[name] = {p.X, p.Y, p.Z}
            persist()
            setStatus("Lokasi '" .. name .. "' disimpan.")
            return true
        end

        label("📌 DAFTAR LOKASI")
        for i, entry in ipairs(PLACES) do
            local text = i .. ". " .. entry.name
            button((S.Saved[entry.name] and "✅ " or "📍 ") .. text, function()
                local m = MODES[S.Mode]
                if m == "save" then
                    if saveHere(entry.name) then Inv.teleportTab() end
                elseif m == "del" then
                    S.Saved[entry.name] = nil
                    persist()
                    setStatus("Simpanan '" .. entry.name .. "' dihapus.")
                    Inv.teleportTab()
                else
                    go(entry)
                end
            end)
        end

        -- lokasi buatan sendiri
        local custom = {}
        for name in pairs(S.Saved) do
            local isDefault = false
            for _, e in ipairs(PLACES) do if e.name == name then isDefault = true break end end
            if not isDefault then custom[#custom + 1] = name end
        end
        table.sort(custom)
        if #custom > 0 then label("⭐ LOKASI BUATANMU") end
        for _, name in ipairs(custom) do
            button("⭐ " .. name, function()
                local m = MODES[S.Mode]
                if m == "save" then
                    if saveHere(name) then Inv.teleportTab() end
                elseif m == "del" then
                    S.Saved[name] = nil
                    persist()
                    setStatus("Lokasi '" .. name .. "' dihapus.")
                    Inv.teleportTab()
                else
                    local sv = S.Saved[name]
                    if sv and teleportTo(Vector3.new(sv[1], sv[2] + 3, sv[3])) then
                        setStatus("Teleport ke " .. name)
                    end
                end
            end)
        end

        label("➕ TAMBAH LOKASI BARU")
        local nameBox = textbox("Nama lokasi baru")
        button("💾  Simpan posisiku sebagai lokasi baru", function()
            local name = ((nameBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
            if name == "" then setStatus("Isi nama lokasinya dulu.") return end
            if saveHere(name) then Inv.teleportTab() end
        end)
        button("🗑  Hapus semua lokasi tersimpan", function()
            S.Saved = {}
            persist()
            S.Msg = "Semua lokasi tersimpan dihapus."
            Inv.teleportTab()
        end)
    end
end)()

--====================================
-- TORNADO SPIN (karakter berputar + efek debu pusaran)
--====================================
;(function() -- blok dipisah agar tidak melebihi batas 200 variabel lokal
    local T = {On = false, Speed = 3000, Particles = true, Lift = true, LiftSpeed = 40, MaxH = 80,
        StartY = 0, Conn = nil, Emitter = nil, OldAuto = nil}

    local function stopTornado()
        T.On = false
        if T.Conn then T.Conn:Disconnect() T.Conn = nil end
        if T.Emitter then pcall(function() T.Emitter:Destroy() end) T.Emitter = nil end
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum and T.OldAuto ~= nil then hum.AutoRotate = T.OldAuto end
        T.OldAuto = nil
    end

    local function startTornado()
        stopTornado()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not (hum and hrp) then toast("Karakter belum tersedia") return end
        T.On = true
        T.StartY = hrp.Position.Y
        T.OldAuto = hum.AutoRotate
        hum.AutoRotate = false

        if T.Particles then
            local e = Instance.new("ParticleEmitter")
            e.Texture = "rbxasset://textures/particles/smoke_main.dds"
            e.Color = ColorSequence.new(Color3.fromRGB(200, 200, 210))
            e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 7)})
            e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1)})
            e.Lifetime = NumberRange.new(0.8, 1.4)
            e.Rate = 60
            e.Speed = NumberRange.new(10, 16)
            e.SpreadAngle = Vector2.new(25, 25)
            e.EmissionDirection = Enum.NormalId.Top
            e.Rotation = NumberRange.new(0, 360)
            e.RotSpeed = NumberRange.new(-180, 180)
            e.LightInfluence = 0.5
            e.Parent = hrp
            T.Emitter = e
        end

        T.Conn = RunService.RenderStepped:Connect(function(dt)
            local c = LP.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if not r then return end
            r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(T.Speed * math.min(dt, 0.05)), 0)
            if T.Lift then
                -- terangkat ke atas seperti baling-baling; sampai tinggi maksimal lalu melayang diam
                local v = r.AssemblyLinearVelocity
                local targetY = T.StartY + T.MaxH
                local up
                if r.Position.Y < targetY - 1 then
                    up = T.LiftSpeed
                else
                    up = math.clamp((targetY - r.Position.Y) * 10, -20, 20)
                end
                r.AssemblyLinearVelocity = Vector3.new(v.X, up, v.Z)
            end
        end)
    end

    LP.CharacterAdded:Connect(function() if T.On then stopTornado() end end)
    Gui.Destroying:Connect(stopTornado)

    Inv.tornadoSection = function()
        label("🌪 TORNADO SPIN")
        label("Karakter berputar SUPER kencang sambil terangkat ke atas, dengan efek debu pusaran. Hanya untuk dirimu sendiri.")
        toggleButton("🌪  Tornado Spin", function() return T.On end, function()
            if T.On then stopTornado() else startTornado() end
        end)
        slider("Kecepatan putar (derajat/detik)", 60, 10000, T.Speed, 50, function(v) T.Speed = v end, "%d")
        toggleButton("⬆  Terangkat ke atas", function() return T.Lift end, function()
            T.Lift = not T.Lift
            if T.On and T.Lift then T.StartY = (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                and LP.Character.HumanoidRootPart.Position.Y) or T.StartY end
        end)
        slider("Kecepatan naik", 5, 150, T.LiftSpeed, 1, function(v) T.LiftSpeed = v end, "%d")
        slider("Tinggi maksimal (stud)", 10, 500, T.MaxH, 5, function(v) T.MaxH = v end, "%d")
        button("Preset Normal (360)", function() T.Speed = 360 Inv.movementTab() end)
        button("Preset Super (3000)", function() T.Speed = 3000 Inv.movementTab() end)
        button("Preset Ekstrem (8000)", function() T.Speed = 8000 Inv.movementTab() end)
        toggleButton("💨  Efek debu pusaran", function() return T.Particles end, function()
            T.Particles = not T.Particles
            if T.On then startTornado() end
        end)
    end
end)()



--====================================
-- SHIFT LOCK (karakter menghadap arah kamera + kamera geser ke bahu)
-- Hanya berlaku di layarmu. Tidak aktif saat Free Cam / Fly / Tempel / duduk.
--====================================
;(function() -- blok dipisah agar tidak melebihi batas 200 variabel lokal
    local SL = {On = false, Offset = 1.75, Cur = 0, Conn = nil}
    local touchOnly = UIS.TouchEnabled and not UIS.MouseEnabled

    local function stopSL()
        SL.On = false
        if SL.Conn then SL.Conn:Disconnect() SL.Conn = nil end
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.AutoRotate = true
            hum.CameraOffset = Vector3.zero
        end
        SL.Cur = 0
        pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
    end

    local function startSL()
        stopSL()
        SL.On = true
        SL.Conn = RunService.RenderStepped:Connect(function(dt)
            local c = LP.Character
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            local r = c and c:FindFirstChild("HumanoidRootPart")
            local cam = workspace.CurrentCamera
            if not (hum and r and cam) or hum.Health <= 0 then return end
            if freeCam.Enabled then return end

            -- kursor terkunci di tengah (PC) hanya saat menu DiiUi tertutup
            local menuOpen = Main.Visible and Gui.Enabled
            if not touchOnly and not menuOpen then
                UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
            elseif UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
                UIS.MouseBehavior = Enum.MouseBehavior.Default
            end

            SL.Cur = SL.Cur + (SL.Offset - SL.Cur) * math.clamp(dt * 12, 0, 1)
            hum.CameraOffset = Vector3.new(SL.Cur, 0, 0)

            if hum.Sit or Fly.Enabled or Tempel.Target then return end
            hum.AutoRotate = false
            local look = cam.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude < 0.05 then return end
            r.CFrame = CFrame.lookAt(r.Position, r.Position + flat.Unit)
        end)
        toast("Shift Lock ON")
    end

    Gui.Destroying:Connect(stopSL)

    Inv.shiftLockTab = function()
        clearContent()
        label("🔒 SHIFT LOCK")
        label("Karakter selalu menghadap arah kamera dan kamera sedikit bergeser ke bahu, seperti Shift Lock bawaan Roblox.")
        toggleButton("🔒  Shift Lock", function() return SL.On end, function()
            if SL.On then stopSL() toast("Shift Lock OFF") else startSL() end
        end)
        slider("Geser kamera (+ kanan / - kiri)", -4, 4, SL.Offset, 0.25, function(v) SL.Offset = v end, "%.2f")
        label("PC: kursor terkunci di tengah saat menu DiiUi ditutup (tekan M), dan bebas lagi saat menu dibuka. "
            .. "HP: karakter ikut menghadap arah kamera.")
    end
end)()

--====================================
-- GRAVITY 0 (melayang) — hanya di klienmu
--====================================
;(function() -- blok dipisah agar tidak melebihi batas 200 variabel lokal
    local G = {On = false, Value = 0, Orig = nil, Conn = nil}

    local function applyG()
        pcall(function() workspace.Gravity = G.Value end)
    end

    local function stopG()
        G.On = false
        if G.Conn then G.Conn:Disconnect() G.Conn = nil end
        pcall(function() workspace.Gravity = G.Orig or 196.2 end)
        G.Orig = nil
    end

    local function startG()
        if G.On then return end
        G.Orig = workspace.Gravity
        G.On = true
        applyG()
        G.Conn = RunService.Heartbeat:Connect(function()
            if workspace.Gravity ~= G.Value then applyG() end
        end)
    end

    Gui.Destroying:Connect(function() if G.On then stopG() end end)

    Inv.gravitySection = function()
        label("🪐 GRAVITY")
        toggleButton("🪐  Gravity 0 (melayang)", function() return G.On end, function()
            if G.On then stopG() else startG() end
        end)
        slider("Nilai gravity (0 = melayang)", 0, 196.2, G.Value, 0.1, function(v) G.Value = v end, "%.1f")
        label("Gravity 0: lompat = terus melayang naik. Matikan tombolnya untuk kembali normal.")
    end
end)()

--====================================
-- MENU GABUNGAN: Fly, NoClip, Speed & Jump, Tornado Spin
--====================================
Inv.movementTab = function()
    clearContent()
    flySection()
    Inv.gravitySection()
    moveSection()
    Inv.tornadoSection()
end

--====================================
-- ANTI AFK & ANTI KICK (kode terbuka, bisa dibaca semua)
--  - Anti AFK : mencegah dikick karena idle 20 menit.
--  - Anti Kick: memblokir pemanggilan LocalPlayer:Kick() dari script game
--               (client-side). Kick dari SERVER tetap tidak bisa dicegah.
--  - Anti VC Ban tidak ada: ban voice chat ditentukan server Roblox.
--====================================
;(function() -- blok dipisah agar tidak melebihi batas 200 variabel lokal
    local VirtualUser = game:GetService("VirtualUser")
    local A = {AFK = false, Kick = false, KickHooked = false, Blocked = 0}

    LP.Idled:Connect(function()
        if not A.AFK then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)

    local function hookKick()
        if A.KickHooked then return true end
        if not (hookmetamethod and getnamecallmethod) then return false end
        local ok = pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", function(self, ...)
                if A.Kick and self == LP and getnamecallmethod() == "Kick" then
                    A.Blocked = A.Blocked + 1
                    return nil
                end
                return old(self, ...)
            end)
        end)
        A.KickHooked = ok
        return ok
    end

    -- MIC GUARD: paksa mikrofon tetap mati (client-side, benar-benar berfungsi
    -- di game yang memakai AudioDeviceInput). Ini mengurangi risiko dilaporkan
    -- karena voice chat, tapi BUKAN pencegah ban dari server Roblox.
    A.Mic = false
    A.MicCount = 0
    local micConns = {}
    local function guardInput(inp)
        if not inp:IsA("AudioDeviceInput") or micConns[inp] then return end
        micConns[inp] = inp:GetPropertyChangedSignal("Muted"):Connect(function()
            if A.Mic and not inp.Muted then inp.Muted = true end
        end)
        A.MicCount = A.MicCount + 1
        if A.Mic then inp.Muted = true end
    end
    local function scanMic()
        for _, d in ipairs(LP:GetDescendants()) do guardInput(d) end
    end
    LP.DescendantAdded:Connect(guardInput)
    scanMic()

    Inv.antiTab = function()
        clearContent()
        label("🛡 ANTI AFK & ANTI KICK")
        local info = label("Anti AFK: cegah kick karena idle. Anti Kick: blokir Kick() dari script game (client-side).")
        info.Font = Enum.Font.Gotham
        info.TextSize = 12
        info.TextColor3 = GREY

        toggleButton("Anti AFK", function() return A.AFK end, function()
            A.AFK = not A.AFK
        end)

        local msg
        toggleButton("Anti Kick", function() return A.Kick end, function()
            if not A.Kick then
                if hookKick() then
                    A.Kick = true
                else
                    if msg then msg.Text = "Executor kamu tidak mendukung hookmetamethod, Anti Kick tidak bisa aktif." end
                end
            else
                A.Kick = false
            end
        end)
        msg = label("Kick diblokir: " .. A.Blocked .. "x")
        msg.Font = Enum.Font.Gotham
        msg.TextSize = 12
        msg.TextColor3 = GREY

        local micMsg
        toggleButton("Mic Guard (mic dipaksa mati)", function() return A.Mic end, function()
            A.Mic = not A.Mic
            scanMic()
            if A.Mic then
                for inp in pairs(micConns) do if inp.Parent then inp.Muted = true end end
            end
            if micMsg then
                micMsg.Text = A.MicCount > 0
                    and ("Mic Guard menjaga " .. A.MicCount .. " input mikrofon.")
                    or "Tidak ada input mikrofon terdeteksi (game ini mungkin tanpa voice chat)."
            end
        end)
        micMsg = label("Mengurangi risiko dilaporkan lewat voice. Tidak mencegah ban dari server Roblox.")
        micMsg.Font = Enum.Font.Gotham
        micMsg.TextSize = 12
        micMsg.TextColor3 = GREY
    end
end)()

--====================================
-- MUSIK (playlist + share ID, mirip pemutar lagu)
-- Catatan: suara diputar lokal, hanya kamu yang dengar. "Share" = bagikan
-- ID/playlist lewat clipboard atau chat, lalu temanmu memutar di menunya.
-- Banyak audio Roblox kini privat; hanya audio publik yang bisa diputar.
--====================================
;(function() -- blok dipisah agar tidak melebihi batas 200 variabel lokal
    --[[ =====================================================================
         DAFTAR LAGU BAWAAN  (ISI DI SINI)
         Semua pengguna script otomatis dapat lagu-lagu ini di menu Musik.
         Format tiap baris:   {"Judul Lagu", "ID_AUDIO"},   (ID pakai tanda kutip)
         Contoh (hapus tanda -- di depan untuk mengaktifkan):
             -- {"Nama Lagu Pertama", "1234567890"},
             -- {"Nama Lagu Kedua", "9876543210"},
         Tambah baris baru di bawah garis ini, jangan lupa koma di akhir.
         Pastikan audionya PUBLIK, kalau privat tidak akan bunyi.
       ===================================================================== ]]
    local DEFAULT_SONGS = {
        -- TAMBAH LAGU DI BAWAH INI --------------------------------------
        {"About You", "74244279298033"},
        {"No One Noticed", "135609653444873"},
        ------------------------------------------------------------------
    }

    local HttpService = game:GetService("HttpService")
    local SoundService = game:GetService("SoundService")
    local TextChatService = game:GetService("TextChatService")
    local FILE = "DiiUi_Playlist.json"
    local M = {User = {}, Index = 0, Loop = false, Shuffle = false, Volume = 0.5, Msg = "Tambah lagu lewat ID audio.", Status = nil, Token = 0}

    pcall(function()
        if isfile and readfile and isfile(FILE) then
            local d = HttpService:JSONDecode(readfile(FILE))
            if type(d) == "table" then M.User = d end
        end
    end)
    local function persist()
        pcall(function()
            if writefile then writefile(FILE, HttpService:JSONEncode(M.User)) end
        end)
    end


    -- gabungan: lagu bawaan (DEFAULT_SONGS) + lagu tambahan pengguna
    local function all()
        local out, seen = {}, {}
        for _, s in ipairs(DEFAULT_SONGS) do
            local raw = s[2]
            local id
            if type(raw) == "number" then
                id = string.format("%.0f", raw)
            else
                id = tostring(raw or ""):match("%d+")
            end
            if id and not seen[id] then
                seen[id] = true
                out[#out + 1] = {name = tostring(s[1] or ("Lagu " .. id)), id = id, default = true}
            end
        end
        for _, s in ipairs(M.User) do
            if not seen[s.id] then
                seen[s.id] = true
                out[#out + 1] = s
            end
        end
        return out
    end

    local sound = Instance.new("Sound")
    sound.Name = "DiiUiMusic"
    sound.Volume = M.Volume
    sound.Parent = SoundService

    local function parseId(text)
        return tostring(text or ""):match("%d+")
    end
    local function current()
        return all()[M.Index]
    end
    local function fmtTime(t)
        t = math.max(0, math.floor(t or 0))
        return string.format("%d:%02d", t // 60, t % 60)
    end

    local function setMsg(t)
        M.Msg = t
    end

    local function play(i)
        local song = all()[i]
        if not song then return end
        M.Index = i
        M.Token = M.Token + 1
        local token = M.Token
        sound:Stop()
        sound.SoundId = "rbxassetid://" .. song.id
        sound.Looped = M.Loop
        sound:Play()
        setMsg("Memuat: " .. song.name)
        task.delay(4, function()
            if token == M.Token and not sound.IsLoaded then
                setMsg("Gagal memuat '" .. song.name .. "' (audio privat / ID salah). Coba lagu lain.")
            end
        end)
    end

    local function nextSong()
        local n = #all()
        if n == 0 then return end
        local i
        if M.Shuffle and n > 1 then
            repeat i = math.random(n) until i ~= M.Index
        else
            i = (M.Index % n) + 1
        end
        play(i)
    end
    local function prevSong()
        local n = #all()
        if n == 0 then return end
        play(((M.Index - 2) % n) + 1)
    end

    sound.Ended:Connect(function()
        if not sound.Looped then nextSong() end
    end)

    -- update teks status tiap 0,5 detik
    task.spawn(function()
        while true do
            task.wait(0.5)
            local lbl = M.Status
            if lbl and lbl.Parent then
                local song = current()
                if song and sound.IsPlaying then
                    lbl.Text = "▶ " .. song.name .. "  " .. fmtTime(sound.TimePosition) .. " / " .. fmtTime(sound.TimeLength)
                elseif song and sound.IsPaused then
                    lbl.Text = "⏸ " .. song.name .. "  " .. fmtTime(sound.TimePosition)
                else
                    lbl.Text = M.Msg
                end
            end
        end
    end)

    local function copy(text, okMsg)
        if setclipboard then
            setclipboard(text)
            setMsg(okMsg)
        else
            setMsg("Executor tidak mendukung clipboard.")
        end
    end

    local function sendChat(text)
        local ok = pcall(function()
            local ch = TextChatService:FindFirstChild("TextChannels")
            local general = ch and ch:FindFirstChild("RBXGeneral")
            if general then
                general:SendAsync(text)
            else
                game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, "All")
            end
        end)
        setMsg(ok and "Terkirim ke chat." or "Gagal kirim ke chat.")
    end

    local function addSong(name, id)
        for _, s in ipairs(all()) do
            if s.id == id then return false end
        end
        M.User[#M.User + 1] = {name = name, id = id}
        return true
    end

    Inv.musicTab = function()
        clearContent()
        label("🎵 MUSIK")
        local st = label(M.Msg)
        st.Font = Enum.Font.Gotham
        st.TextSize = 12
        st.TextColor3 = GREY
        M.Status = st

        local ver = label("Musik v2 • bawaan: " .. #DEFAULT_SONGS .. " lagu • tambahan: " .. #M.User .. " lagu")
        ver.Font = Enum.Font.Gotham
        ver.TextSize = 11
        ver.TextColor3 = GREY

        button("⏮  Sebelumnya", function() prevSong() end)
        button("⏯  Putar / Jeda", function()
            if sound.IsPlaying then
                sound:Pause()
            elseif sound.IsPaused then
                sound:Resume()
            elseif current() then
                play(M.Index)
            elseif #all() > 0 then
                play(1)
            else
                setMsg("Playlist kosong. Tambah lagu dulu.")
            end
        end)
        button("⏭  Berikutnya", function() nextSong() end)
        button("⏹  Stop", function()
            M.Token = M.Token + 1
            sound:Stop()
            setMsg("Dihentikan.")
        end)

        slider("Volume", 0, 100, math.floor(M.Volume * 100), 1, function(v)
            M.Volume = v / 100
            sound.Volume = M.Volume
        end)
        toggleButton("Ulangi lagu ini", function() return M.Loop end, function()
            M.Loop = not M.Loop
            sound.Looped = M.Loop
        end)
        toggleButton("Acak (shuffle)", function() return M.Shuffle end, function()
            M.Shuffle = not M.Shuffle
        end)

        label("➕ TAMBAH LAGU")
        local nameBox = textbox("Judul lagu")
        local idBox = textbox("ID audio (angka atau rbxassetid://...)")
        button("➕  Tambah ke playlist", function()
            local id = parseId(idBox.Text)
            local name = ((nameBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
            if not id then setMsg("ID audio tidak valid.") return end
            if name == "" then name = "Lagu " .. id end
            if addSong(name, id) then
                persist()
                setMsg("Ditambahkan: " .. name)
                Inv.musicTab()
            else
                setMsg("Lagu dengan ID itu sudah ada.")
            end
        end)

        label("📥 IMPOR PLAYLIST")
        local importBox = textbox("Tempel: Judul|ID;Judul|ID;...")
        button("📥  Impor", function()
            local added = 0
            for entry in tostring(importBox.Text or ""):gmatch("[^;\n]+") do
                local name, id = entry:match("^%s*(.-)%s*|%s*(%d+)%s*$")
                if not id then
                    id = parseId(entry)
                    name = id and ("Lagu " .. id)
                end
                if id and addSong(name ~= "" and name or ("Lagu " .. id), id) then added = added + 1 end
            end
            if added > 0 then
                persist()
                setMsg(added .. " lagu diimpor.")
                Inv.musicTab()
            else
                setMsg("Tidak ada lagu valid / semua sudah ada.")
            end
        end)

        label("📤 BAGIKAN")
        button("📋  Salin lagu yang diputar", function()
            local s = current()
            if not s then setMsg("Belum ada lagu yang dipilih.") return end
            copy(s.name .. "|" .. s.id, "Disalin: " .. s.name .. "|" .. s.id)
        end)
        button("📋  Salin seluruh playlist", function()
            local list = all()
            if #list == 0 then setMsg("Playlist kosong.") return end
            local parts = {}
            for _, s in ipairs(list) do parts[#parts + 1] = s.name:gsub("[|;]", " ") .. "|" .. s.id end
            copy(table.concat(parts, ";"), "Playlist (" .. #list .. " lagu) disalin.")
        end)
        button("💬  Kirim lagu yang diputar ke chat", function()
            local s = current()
            if not s then setMsg("Belum ada lagu yang dipilih.") return end
            sendChat("🎵 " .. s.name .. " | ID: " .. s.id)
        end)

        local list = all()
        label("📜 PLAYLIST (" .. #list .. ")")
        for i, s in ipairs(list) do
            button((i == M.Index and "▶ " or (s.default and "⭐ " or "🎵 ")) .. s.name, function() play(i) end)
            if not s.default then
                button("🗑  Hapus: " .. s.name, function()
                    for k, u in ipairs(M.User) do
                        if u.id == s.id then table.remove(M.User, k) break end
                    end
                    if M.Index == i then
                        M.Token = M.Token + 1
                        sound:Stop()
                    end
                    M.Index = 0
                    persist()
                    Inv.musicTab()
                end)
            end
        end
    end
end)()

--====================================
-- FLING
--  Memutar karaktermu dengan kecepatan tinggi lalu menempel ke target
--  sampai target terlempar. Posisimu otomatis dikembalikan setelah selesai.
--====================================
;(function() -- blok dipisah agar tidak melebihi batas 200 variabel lokal
    local RunService = game:GetService("RunService")
    local F = {Busy = false, Stop = false}

    local function flingPlayer(target)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local tchar = target.Character
        local thrp = tchar and tchar:FindFirstChild("HumanoidRootPart")
        local thum = tchar and tchar:FindFirstChildOfClass("Humanoid")
        if not (hrp and hum and thrp and thum) then return false end

        local cam = workspace.CurrentCamera
        local origin = hrp.CFrame
        local head = tchar:FindFirstChild("Head")
        if head then cam.CameraSubject = head end

        local spin = Instance.new("BodyAngularVelocity")
        spin.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        spin.AngularVelocity = Vector3.new(0, 1e5, 0)
        spin.P = math.huge
        spin.Parent = hrp

        local flung = false
        local t0 = tick()
        while tick() - t0 < 2.5 and not F.Stop do
            if not (thrp.Parent and hrp.Parent and thum.Health > 0) then break end
            if thrp.AssemblyLinearVelocity.Magnitude > 300 or thrp.Position.Y < workspace.FallenPartsDestroyHeight + 50 then
                flung = true
                break
            end
            local lead = thum.MoveDirection * math.clamp(thrp.AssemblyLinearVelocity.Magnitude / 12, 0, 6)
            hrp.CFrame = CFrame.new(thrp.Position + lead)
            hrp.AssemblyLinearVelocity = Vector3.new(5e4, 5e4, 5e4)
            RunService.Heartbeat:Wait()
        end

        spin:Destroy()
        -- kembalikan diri sendiri dengan aman (reset kecepatan beberapa frame)
        for _ = 1, 12 do
            if not hrp.Parent then break end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.CFrame = origin
            RunService.Heartbeat:Wait()
        end
        cam.CameraSubject = hum
        return flung
    end

    Inv.flingTab = function()
        clearContent()
        label("💥 FLING")
        local status = label("Pilih pemain untuk di-fling.")
        status.Font = Enum.Font.Gotham
        status.TextSize = 12
        status.TextColor3 = GREY
        local function say(t)
            if status and status.Parent then status.Text = t end
        end

        local function run(list)
            if F.Busy then say("Masih memproses, tunggu atau tekan Stop.") return end
            F.Busy, F.Stop = true, false
            task.spawn(function()
                for _, plr in ipairs(list) do
                    if F.Stop then break end
                    say("Fling: " .. plr.DisplayName .. "...")
                    local ok = flingPlayer(plr)
                    say(ok and ("Berhasil melempar " .. plr.DisplayName) or ("Gagal / target terlalu kuat: " .. plr.DisplayName))
                    task.wait(0.4)
                end
                F.Busy = false
                if F.Stop then say("Dihentikan.") end
            end)
        end

        button("⏹  Stop", function()
            F.Stop = true
        end)
        button("🔄  Refresh daftar pemain", function() Inv.flingTab() end)
        button("💥  Fling semua pemain", function()
            local list = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then list[#list + 1] = p end
            end
            if #list == 0 then say("Tidak ada pemain lain.") return end
            run(list)
        end)

        label("👥 PILIH PEMAIN")
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                button("💥 " .. p.DisplayName .. " (@" .. p.Name .. ")", function()
                    run({p})
                end)
            end
        end
    end
end)()

--====================================
-- TAMBAHAN V3.8: CARRY, JALAN DI ATAS AIR, TARGET (chat / emote / cek akun)
-- (menu Teleport Void sudah dihapus)
--====================================
;(function() -- blok dipisah agar tidak melebihi batas 200 variabel lokal
    local HttpService = game:GetService("HttpService")
    local TextChatService = game:GetService("TextChatService")
    local Tempel, toast, dn = Inv.Tempel, Inv.toast, Inv.dn

    local function setSmall(l)
        l.Font = Enum.Font.Gotham
        l.TextSize = 12
        l.TextColor3 = GREY
        return l
    end

    ------------------------------------------------
    -- 🌊 JALAN DI ATAS AIR (client-side)
    ------------------------------------------------
    local Water = {On = false, Conn = nil, Part = nil}
    local function setWater(on)
        Water.On = on
        if Water.Conn then Water.Conn:Disconnect() Water.Conn = nil end
        if Water.Part then Water.Part:Destroy() Water.Part = nil end
        if not on then return end
        local part = Instance.new("Part")
        part.Name = "DiiUiWaterWalk"
        part.Anchored = true
        part.CanCollide = true
        part.Transparency = 1
        part.Size = Vector3.new(14, 1, 14)
        part.CFrame = CFrame.new(0, -5000, 0)
        part.Parent = workspace
        Water.Part = part
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = false
        Water.Conn = RunService.Heartbeat:Connect(function()
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            params.FilterDescendantsInstances = {char, part}
            local res = workspace:Raycast(hrp.Position + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params)
            if res and res.Material == Enum.Material.Water then
                part.CFrame = CFrame.new(hrp.Position.X, res.Position.Y - 0.5, hrp.Position.Z)
            else
                part.CFrame = CFrame.new(0, -5000, 0)
            end
        end)
    end

    Inv.waterTab = function()
        clearContent()
        label("🌊 JALAN DI ATAS AIR")
        button(Water.On and "Jalan di Air: ON ✅  (tap untuk matikan)" or "Jalan di Air: OFF  (tap untuk aktifkan)", function()
            setWater(not Water.On)
            Inv.waterTab()
        end)
        setSmall(label("Membuat pijakan tak terlihat di permukaan air Terrain (client-side). Air berupa Part biasa tidak diubah."))
    end

    ------------------------------------------------
    -- 🌐 HTTP util untuk cek akun
    ------------------------------------------------
    local function httpGetJson(url)
        local req = (syn and syn.request) or http_request or request or (http and http.request)
        if not req then return nil, "executor tidak punya fungsi request" end
        local ok, res = pcall(req, {Url = url, Method = "GET"})
        if not ok or not res then return nil, "request gagal" end
        if res.StatusCode and res.StatusCode ~= 200 then return nil, "HTTP " .. tostring(res.StatusCode) end
        local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if not ok2 then return nil, "respon tidak valid" end
        return data
    end

    ------------------------------------------------
    -- 🎯 TARGET: chat / emote / cek akun
    ------------------------------------------------
    local T = {
        Player = nil,
        ChatOn = false, ChatConn = nil, LastMsg = "", LastAt = 0,
        EmoteOn = false, EmoteToken = 0, Mine = nil, CurId = nil,
    }

    local function sendChat(msg)
        if os.clock() - T.LastAt < 0.4 then return end
        T.LastAt = os.clock()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local chans = TextChatService:FindFirstChild("TextChannels")
            local ch = chans and (chans:FindFirstChild("RBXGeneral") or chans:FindFirstChildWhichIsA("TextChannel"))
            if ch then pcall(function() ch:SendAsync(msg) end) return end
        end
        local ev = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
        local say = ev and ev:FindFirstChild("SayMessageRequest")
        if say then pcall(function() say:FireServer(msg, "All") end) end
    end

    local function stopChat()
        T.ChatOn = false
        if T.ChatConn then T.ChatConn:Disconnect() T.ChatConn = nil end
    end
    local function startChat()
        stopChat()
        local p = T.Player
        if not p then return end
        T.ChatOn = true
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            T.ChatConn = TextChatService.MessageReceived:Connect(function(m)
                local src = m.TextSource
                if src and src.UserId == p.UserId and m.Text and m.Text ~= "" then
                    sendChat(m.Text)
                end
            end)
        else
            T.ChatConn = p.Chatted:Connect(function(msg) sendChat(msg) end)
        end
    end

    local function stopEmote()
        T.EmoteOn = false
        T.EmoteToken = T.EmoteToken + (1)
        if T.Mine then pcall(function() T.Mine:Stop() end) T.Mine = nil end
        T.CurId = nil
    end
    local function isEmoteTrack(tr)
        if not (tr and tr.Animation and tr.IsPlaying) then return false end
        local pr = tr.Priority
        if pr ~= Enum.AnimationPriority.Action and pr ~= Enum.AnimationPriority.Action2
        and pr ~= Enum.AnimationPriority.Action3 and pr ~= Enum.AnimationPriority.Action4 then
            return false
        end
        if tostring(tr.Animation.Name):lower():find("tool") then return false end
        return tr.Animation.AnimationId ~= ""
    end
    local function startEmote()
        stopEmote()
        local p = T.Player
        if not p then return end
        T.EmoteOn = true
        local token = T.EmoteToken
        task.spawn(function()
            while T.EmoteOn and T.EmoteToken == token do
                if not (p.Parent == Players) then stopEmote() break end
                local tHum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
                local tAnim = tHum and tHum:FindFirstChildOfClass("Animator")
                local myHum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if tAnim and myHum then
                    local myAnim = myHum:FindFirstChildOfClass("Animator") or Instance.new("Animator", myHum)
                    local found
                    for _, tr in ipairs(tAnim:GetPlayingAnimationTracks()) do
                        if isEmoteTrack(tr) then found = tr break end
                    end
                    if found then
                        local id = found.Animation.AnimationId
                        if id ~= T.CurId or not T.Mine then
                            if T.Mine then pcall(function() T.Mine:Stop() end) end
                            local a = Instance.new("Animation")
                            a.AnimationId = id
                            local ok, tr = pcall(function() return myAnim:LoadAnimation(a) end)
                            if ok and tr then
                                tr.Priority = Enum.AnimationPriority.Action4
                                tr.Looped = found.Looped
                                tr:Play()
                                tr.TimePosition = found.TimePosition
                                T.Mine, T.CurId = tr, id
                            end
                        elseif T.Mine and math.abs(T.Mine.TimePosition - found.TimePosition) > 0.35 then
                            T.Mine.TimePosition = found.TimePosition
                        end
                    elseif T.Mine then
                        pcall(function() T.Mine:Stop() end)
                        T.Mine, T.CurId = nil, nil
                    end
                end
                task.wait(0.15)
            end
        end)
    end

    local function ageText(days)
        local y = math.floor(days / 365)
        local m = math.floor((days % 365) / 30)
        local d = (days % 365) % 30
        return string.format("%d hari  (±%d thn %d bln %d hr)", days, y, m, d)
    end

    local function checkAccount(p, setLine)
        setLine(1, "📅 Umur akun: " .. ageText(p.AccountAge))
        setLine(2, "👗 Avatar tersimpan: memuat...")
        setLine(3, "👁 Visibilitas inventory: memuat...")
        task.spawn(function()
            local data, err = httpGetJson(("https://avatar.roblox.com/v1/users/%d/outfits?page=1&itemsPerPage=50&isEditable=true"):format(p.UserId))
            if data and data.data then
                local names = {}
                for i, o in ipairs(data.data) do
                    if i > 8 then break end
                    table.insert(names, tostring(o.name))
                end
                local total = #data.data
                local extra = total > 8 and (" ...+" .. (total - 8)) or ""
                setLine(2, ("👗 Avatar tersimpan: %d outfit%s"):format(total,
                    total > 0 and ("\n   " .. table.concat(names, ", ") .. extra) or ""))
            else
                setLine(2, "👗 Avatar tersimpan: gagal (" .. tostring(err) .. ")")
            end
        end)
        task.spawn(function()
            local data, err = httpGetJson(("https://inventory.roblox.com/v1/users/%d/can-view-inventory"):format(p.UserId))
            if data and data.canView ~= nil then
                setLine(3, "👁 Visibilitas inventory: " .. (data.canView and "ON ✅ (publik)" or "OFF 🔒 (privat)"))
            else
                setLine(3, "👁 Visibilitas inventory: gagal (" .. tostring(err) .. ")")
            end
        end)
    end

    Inv.targetTab = function()
        clearContent()
        label("🎯 TARGET")
        local p = T.Player
        if p and p.Parent ~= Players then
            stopChat() stopEmote() T.Player = nil p = nil
        end
        setSmall(label(p and ("Target: " .. dn(p)) or "Pilih username target dari daftar server:"))

        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP then
                local sel = (pl == p)
                button((sel and "✅  " or "👤  ") .. dn(pl), function()
                    if T.Player ~= pl then
                        stopChat() stopEmote()
                        T.Player = pl
                    end
                    Inv.targetTab()
                end)
            end
        end
        button("🔄  Refresh daftar", Inv.targetTab)
        if not p then return end

        label("💬 THRU CHAT TARGET")
        button(T.ChatOn and "Ikuti chat target: ON ✅  (tap matikan)" or "Ikuti chat target: OFF  (tap aktifkan)", function()
            if T.ChatOn then stopChat() else startChat() end
            Inv.targetTab()
        end)
        setSmall(label("Setiap target mengetik, kamu otomatis mengirim kalimat yang sama."))

        label("🎭 EMOTE TARGET")
        button(T.EmoteOn and "Tiru emote target: ON ✅  (tap matikan)" or "Tiru emote target: OFF  (tap aktifkan)", function()
            if T.EmoteOn then stopEmote() else startEmote() end
            Inv.targetTab()
        end)
        setSmall(label("Saat target memainkan emote, karaktermu memainkan emote yang sama."))

        label("🔎 CEK AKUN TARGET")
        local lines = {}
        for i = 1, 3 do lines[i] = setSmall(label("")) end
        local function setLine(i, txt)
            if lines[i] and lines[i].Parent then lines[i].Text = txt end
        end
        button("🔎  Cek umur, avatar tersimpan & visibilitas", function()
            checkAccount(p, setLine)
        end)
        button("🔎  Cek akun saya sendiri", function()
            checkAccount(LP, setLine)
        end)
    end

    Players.PlayerRemoving:Connect(function(pl)
        if T.Player == pl then
            stopChat() stopEmote() T.Player = nil
        end
    end)
end)()



Inv.ToggleButton = toggleButton


--====================================
-- TAB AUTO SAVE
--====================================
Inv.saveTab = function()
    local PS = shared.DiiUiPersist
    clearContent()
    label("💾 AUTO SAVE")
    if not PS.CanSave then
        label("⚠ Executor kamu tidak mendukung writefile/readfile, jadi pengaturan tidak bisa disimpan.")
        return
    end
    label("Toggle, slider, grafis, dan animasi pilihanmu disimpan otomatis ke file DiiUi_Settings.json "
        .. "dan dipasang lagi saat execute berikutnya. Tidak perlu aktifkan satu-satu.")
    toggleButton("💾  Auto Save", function() return PS.Data.enabled end, function()
        PS.Data.enabled = not PS.Data.enabled
        PS.Save(true)
    end)
    toggleButton("⚠  Pulihkan juga aksi (Fly / Tornado / Gravity 0)", function() return PS.Data.restoreActions end, function()
        PS.Data.restoreActions = not PS.Data.restoreActions
        PS.Save(true)
    end)
    local nT, nS = 0, 0
    for _ in pairs(PS.Data.toggles) do nT = nT + 1 end
    for _ in pairs(PS.Data.sliders) do nS = nS + 1 end
    local info = label(("Tersimpan: %d toggle  •  %d slider  •  grafis: %s  •  paket animasi: %s"):format(
        nT, nS, PS.Data.preset or "-", PS.Data.pack or "-"))
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextColor3 = GREY
    button("📤  Simpan sekarang", function()
        PS.Save(true)
        toast("Pengaturan disimpan")
    end)
    button("🗑  Hapus semua data tersimpan", function()
        PS.ClearAll()
        toast("Data tersimpan dihapus")
        Inv.saveTab()
    end)
    label("Yang tidak ikut dipulihkan demi keamanan: Free Cam, Spectator, Fling, Invisible, dan target Tempel.")
end

--====================================
-- DiiEmote: roda emote Marketplace (62.000+ emote, favorit, pencarian, kecepatan 0.05x - 10x)
--====================================
Inv.diiEmoteRun = function()
    local Players              = game:GetService("Players")
    local UserInputService     = game:GetService("UserInputService")
    local TweenService         = game:GetService("TweenService")
    local StarterGui           = game:GetService("StarterGui")
    local HttpService          = game:GetService("HttpService")
    local MarketplaceService   = game:GetService("MarketplaceService")
    local AvatarEditorService  = game:GetService("AvatarEditorService")
    local CoreGui              = game:GetService("CoreGui")

    local lingkungan = (type(getgenv) == "function" and getgenv()) or _G
    if type(lingkungan.DiiEmoteCleanup) == "function" then
        pcall(lingkungan.DiiEmoteCleanup)
    end

    local VERSI              = "1.1.0"
    local NAMA_FOLDER        = "DiiEmote"
    local FILE_FAVORIT       = NAMA_FOLDER .. "/favorites.json"
    local FILE_CACHE         = NAMA_FOLDER .. "/emotes_catalog_v2.json"
    local FILE_META_CACHE    = NAMA_FOLDER .. "/emotes_catalog_v2_meta.json"
    local UMUR_MAKS_CACHE    = 60 * 60 * 24
    local MIN_CACHE_VALID    = 50
    local SLOT_PER_HALAMAN   = 8
    local KECEPATAN_MIN      = 0.05
    local KECEPATAN_MAKS     = 10
    local KECEPATAN_DEFAULT  = 1

    local URL_JSON_EMOTE_REMOTE = {
        "https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json",
        "https://raw.githubusercontent.com/7yd7/sniper-Emote/test/EmoteSniper.json",
    }

    local WARNA = {
        LatarWheel     = Color3.fromRGB(36, 37, 42),
        GarisWheel     = Color3.fromRGB(70, 72, 82),
        LatarTengah    = Color3.fromRGB(16, 17, 21),
        GarisTengah    = Color3.fromRGB(58, 60, 70),
        GarisPembagi   = Color3.fromRGB(220, 224, 235),
        SlotNormal     = Color3.fromRGB(48, 50, 58),
        SlotHover      = Color3.fromRGB(78, 84, 102),
        SlotModeFav    = Color3.fromRGB(95, 80, 32),
        SlotModeUnfav  = Color3.fromRGB(110, 42, 46),
        LatarPanel     = Color3.fromRGB(20, 21, 26),
        GarisPanel     = Color3.fromRGB(62, 65, 78),
        TombolNav      = Color3.fromRGB(24, 26, 33),
        TombolNavHover = Color3.fromRGB(44, 48, 60),
        Aksen          = Color3.fromRGB(0, 207, 255),
        Emas           = Color3.fromRGB(255, 204, 51),
        Bahaya         = Color3.fromRGB(245, 78, 86),
        Sukses         = Color3.fromRGB(64, 214, 128),
        TeksUtama      = Color3.fromRGB(245, 247, 252),
        TeksSekunder   = Color3.fromRGB(168, 174, 190),
        TeksRedup      = Color3.fromRGB(115, 120, 136),
    }

    local EMOTE_CADANGAN = {
        { id = 3360686498, name = "Stadium" },
        { id = 3360692915, name = "Tilt" },
        { id = 3576968026, name = "Shrug" },
        { id = 3576686446, name = "Hello" },
        { id = 3360689775, name = "Salute" },
        { id = 3576823880, name = "Agree" },
        { id = 3576717965, name = "Disagree" },
        { id = 3360694441, name = "Applaud" },
        { id = 3576721660, name = "Shy" },
        { id = 3576719440, name = "Sleep" },
        { id = 3576745472, name = "Hero Landing" },
        { id = 3696761354, name = "Line Dance" },
        { id = 3696763549, name = "Heisman Pose" },
        { id = 3994130516, name = "Hype Dance" },
        { id = 4049646104, name = "Curtsy" },
        { id = 4212496830, name = "Cower" },
    }

    local PemainLokal = Players.LocalPlayer

    local function ambilKamera()
        return workspace.CurrentCamera
    end

    local function apakahPerangkatMobile()
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end

    local function buatUrlThumbnail(assetId)
        return "rbxthumb://type=Asset&id=" .. tostring(assetId) .. "&w=150&h=150"
    end

    local function batasiKecepatan(nilai)
        local angka = tonumber(nilai)
        if not angka or angka ~= angka then
            return KECEPATAN_DEFAULT
        end
        return math.clamp(angka, KECEPATAN_MIN, KECEPATAN_MAKS)
    end

    local function formatKecepatan(nilai)
        local dibulatkan = math.floor(nilai * 100 + 0.5) / 100
        return tostring(dibulatkan)
    end

    local function formatAngka(n)
        local teks = tostring(math.floor(tonumber(n) or 0))
        local hasil = teks:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
        return hasil
    end

    local function ambilIndukGui()
        if type(gethui) == "function" then
            local ok, hasil = pcall(gethui)
            if ok and hasil then
                return hasil
            end
        end
        local ok, _ = pcall(function()
            return CoreGui.Name
        end)
        if ok then
            return CoreGui
        end
        return PemainLokal:WaitForChild("PlayerGui")
    end

    local punyaAksesFile = (type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function")

    local function pastikanFolderAda()
        if not punyaAksesFile then return end
        if type(isfolder) == "function" and type(makefolder) == "function" then
            pcall(function()
                if not isfolder(NAMA_FOLDER) then
                    makefolder(NAMA_FOLDER)
                end
            end)
        end
    end

    local function tulisFileMentah(jalur, isi)
        if not punyaAksesFile or type(isi) ~= "string" then return false end
        pastikanFolderAda()
        local ok = pcall(writefile, jalur, isi)
        return ok
    end

    local function bacaFileMentah(jalur)
        if not punyaAksesFile then return nil end
        local okCek, ada = pcall(isfile, jalur)
        if not okCek or not ada then return nil end
        local okBaca, isi = pcall(readfile, jalur)
        if not okBaca or type(isi) ~= "string" or isi == "" then return nil end
        return isi
    end

    local function tulisFileJson(jalur, data)
        if not punyaAksesFile then return false end
        pastikanFolderAda()
        local ok, jsonTeks = pcall(HttpService.JSONEncode, HttpService, data)
        if not ok then return false end
        return tulisFileMentah(jalur, jsonTeks)
    end

    local function bacaFileJson(jalur)
        local mentah = bacaFileMentah(jalur)
        if not mentah then return nil end
        local ok, hasil = pcall(HttpService.JSONDecode, HttpService, mentah)
        if not ok then return nil end
        return hasil
    end

    local function ambilFungsiRequest()
        if type(request) == "function" then return request end
        if type(http_request) == "function" then return http_request end
        if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
        if type(http) == "table" and type(http.request) == "function" then return http.request end
        if type(fluxus) == "table" and type(fluxus.request) == "function" then return fluxus.request end
        return nil
    end

    local function ambilTeksHttp(url)
        local ok, res = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and type(res) == "string" and #res > 20 then
            return res, 200
        end

        local fnReq = ambilFungsiRequest()
        if fnReq then
            local reqOk, resp = pcall(fnReq, {
                Url = url,
                Method = "GET",
                Headers = {
                    ["Accept"] = "application/json, text/plain, */*",
                    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                },
            })
            if reqOk and type(resp) == "table" and type(resp.Body) == "string" and #resp.Body > 20 then
                return resp.Body, tonumber(resp.StatusCode) or 200
            end
        end

        return nil, nil
    end

    local function uraiJsonKatalog(mentah)
        if type(mentah) ~= "string" or #mentah < 2 then return nil, nil end
        local ok, data = pcall(HttpService.JSONDecode, HttpService, mentah)
        if ok and type(data) == "table" then
            if type(data.data) == "table" then
                return data.data, data.nextPageCursor
            elseif #data > 0 and type(data[1]) == "table" then
                return data, nil
            end
        end
        return nil, nil
    end

    local function ambilDataKatalogHttp(url)
        local fnReq = ambilFungsiRequest()
        local kodeStatus = nil

        if fnReq then
            local reqOk, resp = pcall(fnReq, {
                Url = url,
                Method = "GET",
                Headers = {
                    ["Accept"] = "application/json",
                    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                },
            })
            if reqOk and type(resp) == "table" then
                kodeStatus = tonumber(resp.StatusCode)
                local daftar, cursor = uraiJsonKatalog(resp.Body)
                if daftar then
                    return daftar, cursor, kodeStatus
                end
            end
        end

        local ok, res = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and type(res) == "string" then
            local daftar, cursor = uraiJsonKatalog(res)
            if daftar then
                return daftar, cursor, 200
            end
        end

        return nil, nil, kodeStatus
    end

    local Status = {
        Terbuka             = false,
        SudahDihancurkan    = false,
        ModeTampilan        = "Semua",
        ModeBintang         = false,
        Kecepatan           = KECEPATAN_DEFAULT,
        KataKunciCari       = "",
        HalamanSekarang     = 1,
        TotalHalaman        = 1,

        SemuaEmote          = {},
        SetSemuaEmote       = {},
        DaftarFavorit       = {},
        SetFavorit          = {},
        DaftarTampil        = {},
        HasilCariLive       = {},
        KataKunciLive       = "",
        CacheNamaId         = {},
        CacheAnimId         = {},

        SedangMuatKatalog   = false,
        MasihPakaiCadangan  = true,
        IdDebounceCari      = 0,
        IdPermintaanCari    = 0,

        PosisiIkonKustom    = false,

        TrackAktif          = nil,
        IdEmoteAktif        = nil,
        DaftarKoneksi       = {},
        KoneksiKarakter     = {},
    }

    local function catatKoneksi(koneksi)
        if koneksi then
            table.insert(Status.DaftarKoneksi, koneksi)
        end
        return koneksi
    end

    local function bersihkanKoneksiKarakter()
        for _, koneksi in ipairs(Status.KoneksiKarakter) do
            pcall(function() koneksi:Disconnect() end)
        end
        table.clear(Status.KoneksiKarakter)
    end

    local function muatFavorit()
        local data = bacaFileJson(FILE_FAVORIT)
        Status.DaftarFavorit = {}
        Status.SetFavorit = {}
        if type(data) == "table" then
            for _, item in ipairs(data) do
                local id = tonumber(item.id)
                local nama = tostring(item.name or ("Emote #" .. tostring(id)))
                if id and not Status.SetFavorit[id] then
                    Status.SetFavorit[id] = true
                    table.insert(Status.DaftarFavorit, {
                        id   = id,
                        name = nama,
                        l    = string.lower(nama),
                    })
                end
            end
        end
    end

    local function simpanFavorit()
        local ringkas = {}
        for _, item in ipairs(Status.DaftarFavorit) do
            table.insert(ringkas, { id = item.id, name = item.name })
        end
        tulisFileJson(FILE_FAVORIT, ringkas)
    end

    local function tambahEmoteKeDaftar(id, nama)
        id = tonumber(id)
        if not id or Status.SetSemuaEmote[id] then return false end
        local namaBersih = tostring(nama or ("Emote #" .. tostring(id)))
        Status.SetSemuaEmote[id] = true
        table.insert(Status.SemuaEmote, {
            id   = id,
            name = namaBersih,
            l    = string.lower(namaBersih),
        })
        return true
    end

    local function masukkanArrayEmote(daftarItem, gantiCadangan)
        if type(daftarItem) ~= "table" or #daftarItem == 0 then return 0 end

        if gantiCadangan and Status.MasihPakaiCadangan then
            Status.SemuaEmote = {}
            Status.SetSemuaEmote = {}
            Status.MasihPakaiCadangan = false
        end

        local jumlahBaru = 0
        for idx = 1, #daftarItem do
            if Status.SudahDihancurkan then break end
            local item = daftarItem[idx]
            if type(item) == "table" then
                local id = tonumber(item.id or item.Id)
                local nama = item.name or item.Name
                if id and not Status.SetSemuaEmote[id] then
                    local namaBersih = tostring(nama or ("Emote #" .. tostring(id)))
                    Status.SetSemuaEmote[id] = true
                    Status.SemuaEmote[#Status.SemuaEmote + 1] = {
                        id   = id,
                        name = namaBersih,
                        l    = string.lower(namaBersih),
                    }
                    jumlahBaru = jumlahBaru + 1
                end
            end
            if idx % 6000 == 0 then
                task.wait()
            end
        end
        return jumlahBaru
    end

    local function muatCacheEmote()
        local mentah = bacaFileMentah(FILE_CACHE)
        if not mentah then return false, false end

        local daftar = uraiJsonKatalog(mentah)
        if not daftar or #daftar < MIN_CACHE_VALID then
            return false, false
        end

        masukkanArrayEmote(daftar, true)

        local meta = bacaFileJson(FILE_META_CACHE)
        local waktuUpdate = (type(meta) == "table" and tonumber(meta.updatedAt)) or 0
        local masihSegar = (os.time() - waktuUpdate) < UMUR_MAKS_CACHE
        return (#Status.SemuaEmote >= MIN_CACHE_VALID), masihSegar
    end

    local function simpanCacheMentah(jsonMentah)
        if type(jsonMentah) ~= "string" or #jsonMentah < 500 then return end
        tulisFileMentah(FILE_CACHE, jsonMentah)
        tulisFileJson(FILE_META_CACHE, {
            version   = VERSI,
            updatedAt = os.time(),
            count     = #Status.SemuaEmote,
        })
    end

    local function simpanCacheTabel()
        if #Status.SemuaEmote < MIN_CACHE_VALID then return end
        local ringkas = {}
        for idx = 1, #Status.SemuaEmote do
            local item = Status.SemuaEmote[idx]
            ringkas[idx] = { id = item.id, name = item.name }
        end
        tulisFileJson(FILE_CACHE, { data = ringkas })
        tulisFileJson(FILE_META_CACHE, {
            version   = VERSI,
            updatedAt = os.time(),
            count     = #Status.SemuaEmote,
        })
    end

    local function matikanEmoteBawaan()
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
        end)
    end

    matikanEmoteBawaan()

    local tampilkanNotif

    local function hentikanEmoteAktif(waktuFade)
        if Status.TrackAktif then
            pcall(function()
                Status.TrackAktif:Stop(waktuFade or 0.15)
            end)
            Status.TrackAktif = nil
            Status.IdEmoteAktif = nil
        end
    end

    local function pasangDeteksiGerakKarakter(karakter)
        bersihkanKoneksiKarakter()
        if not karakter then return end

        local humanoid = karakter:FindFirstChildOfClass("Humanoid") or karakter:WaitForChild("Humanoid", 5)
        if not humanoid then return end

        table.insert(Status.KoneksiKarakter, humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
            if Status.TrackAktif and humanoid.MoveDirection.Magnitude > 0.05 then
                hentikanEmoteAktif(0.15)
            end
        end))

        table.insert(Status.KoneksiKarakter, humanoid.Jumping:Connect(function(aktif)
            if aktif and Status.TrackAktif then
                hentikanEmoteAktif(0.1)
            end
        end))

        table.insert(Status.KoneksiKarakter, humanoid.StateChanged:Connect(function(_, statusBaru)
            if not Status.TrackAktif then return end
            if statusBaru == Enum.HumanoidStateType.Climbing
                or statusBaru == Enum.HumanoidStateType.Swimming
                or statusBaru == Enum.HumanoidStateType.Seated
                or statusBaru == Enum.HumanoidStateType.FallingDown
                or statusBaru == Enum.HumanoidStateType.Ragdoll
                or statusBaru == Enum.HumanoidStateType.Dead
                or statusBaru == Enum.HumanoidStateType.Freefall
            then
                hentikanEmoteAktif(0.15)
            end
        end))

        table.insert(Status.KoneksiKarakter, humanoid.Died:Connect(function()
            hentikanEmoteAktif(0)
        end))
    end

    if PemainLokal.Character then
        pasangDeteksiGerakKarakter(PemainLokal.Character)
    end
    catatKoneksi(PemainLokal.CharacterAdded:Connect(function(karakterBaru)
        hentikanEmoteAktif(0)
        pasangDeteksiGerakKarakter(karakterBaru)
    end))

    local function ambilAnimationId(assetId)
        assetId = tonumber(assetId)
        if not assetId then return nil end

        if Status.CacheAnimId[assetId] then
            return Status.CacheAnimId[assetId]
        end

        local ok, daftarObjek = pcall(function()
            return game:GetObjects("rbxassetid://" .. tostring(assetId))
        end)

        if ok and type(daftarObjek) == "table" and #daftarObjek > 0 then
            local animIdKetemu = nil
            for _, obj in ipairs(daftarObjek) do
                if obj:IsA("Animation") and obj.AnimationId ~= "" then
                    animIdKetemu = obj.AnimationId
                else
                    local anim = obj:FindFirstChildWhichIsA("Animation", true)
                    if anim and anim.AnimationId ~= "" then
                        animIdKetemu = anim.AnimationId
                    end
                end
                pcall(function() obj:Destroy() end)
                if animIdKetemu then break end
            end
            if animIdKetemu then
                Status.CacheAnimId[assetId] = animIdKetemu
                return animIdKetemu
            end
        end

        return nil
    end

    local function ikatSiklusTrack(track, idEmote)
        Status.TrackAktif = track
        Status.IdEmoteAktif = idEmote
        pcall(function()
            track:AdjustSpeed(Status.Kecepatan)
        end)
        track.Stopped:Connect(function()
            if Status.TrackAktif == track then
                Status.TrackAktif = nil
                Status.IdEmoteAktif = nil
            end
        end)
    end

    local function putarEmote(itemEmote)
        if not itemEmote or not itemEmote.id then return end

        local karakter = PemainLokal.Character
        if not karakter then
            tampilkanNotif("Karakter belum siap!", WARNA.Bahaya)
            return
        end

        local humanoid = karakter:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            tampilkanNotif("Tidak bisa melakukan emote saat ini.", WARNA.Bahaya)
            return
        end

        if humanoid.RigType == Enum.HumanoidRigType.R6 then
            tampilkanNotif("Avatar R6 terdeteksi — Emote Marketplace membutuhkan R15.", WARNA.Emas)
        end

        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end

        hentikanEmoteAktif(0.1)

        task.spawn(function()
            local karSaatIni = PemainLokal.Character
            local humSaatIni = karSaatIni and karSaatIni:FindFirstChildOfClass("Humanoid")
            local animSaatIni = humSaatIni and humSaatIni:FindFirstChildOfClass("Animator")
            if not humSaatIni or humSaatIni.Health <= 0 or not animSaatIni or Status.SudahDihancurkan then return end

            local animId = ambilAnimationId(itemEmote.id)
            if animId then
                local animObj = Instance.new("Animation")
                animObj.AnimationId = animId
                local okMuat, track = pcall(function()
                    return animSaatIni:LoadAnimation(animObj)
                end)
                animObj:Destroy()

                if okMuat and track then
                    track.Priority = Enum.AnimationPriority.Action
                    track:Play(0.1)
                    ikatSiklusTrack(track, itemEmote.id)
                    return
                end
            end

            local okNative, hasil1, hasil2 = pcall(function()
                local deskripsi = humSaatIni:FindFirstChildOfClass("HumanoidDescription")
                if deskripsi then
                    deskripsi:AddEmote(tostring(itemEmote.name or itemEmote.id), itemEmote.id)
                end
                return humSaatIni:PlayEmoteAndGetAnimTrackById(itemEmote.id)
            end)

            local trackNative = nil
            if okNative then
                if typeof(hasil1) == "Instance" and hasil1:IsA("AnimationTrack") then
                    trackNative = hasil1
                elseif typeof(hasil2) == "Instance" and hasil2:IsA("AnimationTrack") then
                    trackNative = hasil2
                end
            end

            if trackNative then
                ikatSiklusTrack(trackNative, itemEmote.id)
                return
            end

            local animMentah = Instance.new("Animation")
            animMentah.AnimationId = "rbxassetid://" .. tostring(itemEmote.id)
            local okMentah, trackMentah = pcall(function()
                return animSaatIni:LoadAnimation(animMentah)
            end)
            animMentah:Destroy()

            if okMentah and trackMentah then
                trackMentah.Priority = Enum.AnimationPriority.Action
                trackMentah:Play(0.1)
                ikatSiklusTrack(trackMentah, itemEmote.id)
            else
                tampilkanNotif("Gagal memutar emote: " .. tostring(itemEmote.name), WARNA.Bahaya)
            end
        end)
    end

    local IndukGui = ambilIndukGui()
    local LayarGui = Instance.new("ScreenGui")
    LayarGui.Name = "DiiEmote_UI"
    LayarGui.ResetOnSpawn = false
    LayarGui.IgnoreGuiInset = true
    LayarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    LayarGui.DisplayOrder = 100
    LayarGui.Parent = IndukGui

    local WadahNotif = Instance.new("Frame")
    WadahNotif.Name = "WadahNotif"
    WadahNotif.AnchorPoint = Vector2.new(0.5, 0)
    WadahNotif.Position = UDim2.new(0.5, 0, 0, 68)
    WadahNotif.Size = UDim2.new(0, 380, 0, 200)
    WadahNotif.BackgroundTransparency = 1
    WadahNotif.ZIndex = 50
    WadahNotif.Parent = LayarGui

    local LayoutNotif = Instance.new("UIListLayout")
    LayoutNotif.SortOrder = Enum.SortOrder.LayoutOrder
    LayoutNotif.HorizontalAlignment = Enum.HorizontalAlignment.Center
    LayoutNotif.Padding = UDim.new(0, 6)
    LayoutNotif.Parent = WadahNotif

    tampilkanNotif = function(pesan, warnaAksen)
        if Status.SudahDihancurkan or not WadahNotif.Parent then return end
        warnaAksen = warnaAksen or WARNA.Aksen

        local kartu = Instance.new("Frame")
        kartu.Size = UDim2.new(0, 0, 0, 34)
        kartu.AutomaticSize = Enum.AutomaticSize.X
        kartu.BackgroundColor3 = Color3.fromRGB(18, 19, 24)
        kartu.BackgroundTransparency = 0.08
        kartu.BorderSizePixel = 0
        kartu.ZIndex = 51
        kartu.Parent = WadahNotif

        local sudut = Instance.new("UICorner")
        sudut.CornerRadius = UDim.new(0, 10)
        sudut.Parent = kartu

        local garis = Instance.new("UIStroke")
        garis.Color = warnaAksen
        garis.Thickness = 1.4
        garis.Transparency = 0.25
        garis.Parent = kartu

        local jarak = Instance.new("UIPadding")
        jarak.PaddingLeft = UDim.new(0, 14)
        jarak.PaddingRight = UDim.new(0, 14)
        jarak.Parent = kartu

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(0, 0, 1, 0)
        label.AutomaticSize = Enum.AutomaticSize.X
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 13
        label.TextColor3 = WARNA.TeksUtama
        label.Text = tostring(pesan)
        label.ZIndex = 52
        label.Parent = kartu

        kartu.BackgroundTransparency = 1
        label.TextTransparency = 1
        garis.Transparency = 1

        TweenService:Create(kartu, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.08,
        }):Play()
        TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()
        TweenService:Create(garis, TweenInfo.new(0.18), { Transparency = 0.25 }):Play()

        task.delay(2.4, function()
            if not kartu or not kartu.Parent then return end
            local animKeluar = TweenService:Create(kartu, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                BackgroundTransparency = 1,
            })
            TweenService:Create(label, TweenInfo.new(0.22), { TextTransparency = 1 }):Play()
            TweenService:Create(garis, TweenInfo.new(0.22), { Transparency = 1 }):Play()
            animKeluar:Play()
            animKeluar.Completed:Wait()
            if kartu and kartu.Parent then
                kartu:Destroy()
            end
        end)
    end

    local TombolIkonEmote = Instance.new("TextButton")
    TombolIkonEmote.Name = "TombolIkonEmote"
    TombolIkonEmote.Text = ""
    TombolIkonEmote.AutoButtonColor = false
    TombolIkonEmote.BackgroundColor3 = Color3.fromRGB(18, 19, 23)
    TombolIkonEmote.BackgroundTransparency = 0.18
    TombolIkonEmote.BorderSizePixel = 0
    TombolIkonEmote.ZIndex = 40
    TombolIkonEmote.Parent = LayarGui

    local SudutIkonEmote = Instance.new("UICorner")
    SudutIkonEmote.CornerRadius = UDim.new(1, 0)
    SudutIkonEmote.Parent = TombolIkonEmote

    local GarisIkonEmote = Instance.new("UIStroke")
    GarisIkonEmote.Color = Color3.fromRGB(95, 100, 118)
    GarisIkonEmote.Thickness = 1.4
    GarisIkonEmote.Transparency = 0.35
    GarisIkonEmote.Parent = TombolIkonEmote

    local LabelSenyum = Instance.new("TextLabel")
    LabelSenyum.Name = "IkonSenyum"
    LabelSenyum.BackgroundTransparency = 1
    LabelSenyum.Size = UDim2.new(1, 0, 1, 0)
    LabelSenyum.Position = UDim2.new(0, 0, 0, -1)
    LabelSenyum.Font = Enum.Font.GothamBold
    LabelSenyum.Text = "☺"
    LabelSenyum.TextColor3 = WARNA.TeksUtama
    LabelSenyum.TextScaled = false
    LabelSenyum.TextSize = 24
    LabelSenyum.ZIndex = 41
    LabelSenyum.Parent = TombolIkonEmote

    local WadahWheel = Instance.new("Frame")
    WadahWheel.Name = "WadahWheel"
    WadahWheel.AnchorPoint = Vector2.new(0.5, 0.5)
    WadahWheel.Position = UDim2.new(0.5, 0, 0.5, 8)
    WadahWheel.Size = UDim2.new(0, 560, 0, 502)
    WadahWheel.BackgroundTransparency = 1
    WadahWheel.Visible = false
    WadahWheel.ZIndex = 10
    WadahWheel.Parent = LayarGui

    local SkalaWheel = Instance.new("UIScale")
    SkalaWheel.Scale = 1
    SkalaWheel.Parent = WadahWheel

    local LabelWatermark = Instance.new("TextLabel")
    LabelWatermark.Name = "Watermark"
    LabelWatermark.AnchorPoint = Vector2.new(0.5, 0)
    LabelWatermark.Position = UDim2.new(0.5, 0, 0, 0)
    LabelWatermark.Size = UDim2.new(0, 320, 0, 22)
    LabelWatermark.BackgroundTransparency = 1
    LabelWatermark.Font = Enum.Font.GothamBold
    LabelWatermark.TextSize = 15
    LabelWatermark.TextColor3 = WARNA.TeksUtama
    LabelWatermark.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    LabelWatermark.TextStrokeTransparency = 0.55
    LabelWatermark.RichText = true
    LabelWatermark.Text = '<font color="#00CFFF">Dii</font>Emote  <font size="11" color="#A8AEBE">v' .. VERSI .. "</font>"
    LabelWatermark.ZIndex = 15
    LabelWatermark.Parent = WadahWheel

    local BingkaiCari = Instance.new("Frame")
    BingkaiCari.Name = "BingkaiCari"
    BingkaiCari.AnchorPoint = Vector2.new(0.5, 0)
    BingkaiCari.Position = UDim2.new(0.5, 0, 0, 26)
    BingkaiCari.Size = UDim2.new(0, 310, 0, 36)
    BingkaiCari.BackgroundColor3 = WARNA.LatarPanel
    BingkaiCari.BackgroundTransparency = 0.1
    BingkaiCari.BorderSizePixel = 0
    BingkaiCari.ZIndex = 15
    BingkaiCari.Parent = WadahWheel

    local SudutCari = Instance.new("UICorner")
    SudutCari.CornerRadius = UDim.new(0, 18)
    SudutCari.Parent = BingkaiCari

    local GarisCari = Instance.new("UIStroke")
    GarisCari.Color = WARNA.GarisPanel
    GarisCari.Thickness = 1.3
    GarisCari.Parent = BingkaiCari

    local IkonCari = Instance.new("TextLabel")
    IkonCari.BackgroundTransparency = 1
    IkonCari.Position = UDim2.new(0, 12, 0, 0)
    IkonCari.Size = UDim2.new(0, 20, 1, 0)
    IkonCari.Font = Enum.Font.GothamBold
    IkonCari.TextSize = 14
    IkonCari.TextColor3 = WARNA.TeksSekunder
    IkonCari.Text = "🔍"
    IkonCari.ZIndex = 16
    IkonCari.Parent = BingkaiCari

    local KotakCari = Instance.new("TextBox")
    KotakCari.Name = "KotakCari"
    KotakCari.BackgroundTransparency = 1
    KotakCari.Position = UDim2.new(0, 36, 0, 0)
    KotakCari.Size = UDim2.new(1, -68, 1, 0)
    KotakCari.Font = Enum.Font.Gotham
    KotakCari.TextSize = 13
    KotakCari.TextColor3 = WARNA.TeksUtama
    KotakCari.PlaceholderColor3 = WARNA.TeksRedup
    KotakCari.PlaceholderText = "Cari nama emote / masukkan ID..."
    KotakCari.Text = ""
    KotakCari.ClearTextOnFocus = false
    KotakCari.TextXAlignment = Enum.TextXAlignment.Left
    KotakCari.ZIndex = 16
    KotakCari.Parent = BingkaiCari

    local TombolHapusCari = Instance.new("TextButton")
    TombolHapusCari.Name = "TombolHapusCari"
    TombolHapusCari.AnchorPoint = Vector2.new(1, 0.5)
    TombolHapusCari.Position = UDim2.new(1, -8, 0.5, 0)
    TombolHapusCari.Size = UDim2.new(0, 22, 0, 22)
    TombolHapusCari.BackgroundColor3 = Color3.fromRGB(45, 47, 56)
    TombolHapusCari.BackgroundTransparency = 0.3
    TombolHapusCari.Font = Enum.Font.GothamBold
    TombolHapusCari.TextSize = 12
    TombolHapusCari.TextColor3 = WARNA.TeksSekunder
    TombolHapusCari.Text = "×"
    TombolHapusCari.Visible = false
    TombolHapusCari.ZIndex = 17
    TombolHapusCari.Parent = BingkaiCari

    local SudutHapusCari = Instance.new("UICorner")
    SudutHapusCari.CornerRadius = UDim.new(1, 0)
    SudutHapusCari.Parent = TombolHapusCari

    local PanelKecepatan = Instance.new("Frame")
    PanelKecepatan.Name = "PanelKecepatan"
    PanelKecepatan.AnchorPoint = Vector2.new(1, 0.5)
    PanelKecepatan.Position = UDim2.new(0.5, -186, 0, 250)
    PanelKecepatan.Size = UDim2.new(0, 86, 0, 76)
    PanelKecepatan.BackgroundColor3 = WARNA.LatarPanel
    PanelKecepatan.BackgroundTransparency = 0.12
    PanelKecepatan.BorderSizePixel = 0
    PanelKecepatan.ZIndex = 15
    PanelKecepatan.Parent = WadahWheel

    local SudutPanelKecepatan = Instance.new("UICorner")
    SudutPanelKecepatan.CornerRadius = UDim.new(0, 14)
    SudutPanelKecepatan.Parent = PanelKecepatan

    local GarisPanelKecepatan = Instance.new("UIStroke")
    GarisPanelKecepatan.Color = WARNA.GarisPanel
    GarisPanelKecepatan.Thickness = 1.3
    GarisPanelKecepatan.Parent = PanelKecepatan

    local JudulKecepatan = Instance.new("TextLabel")
    JudulKecepatan.BackgroundTransparency = 1
    JudulKecepatan.Position = UDim2.new(0, 0, 0, 6)
    JudulKecepatan.Size = UDim2.new(1, 0, 0, 16)
    JudulKecepatan.Font = Enum.Font.GothamBold
    JudulKecepatan.TextSize = 10
    JudulKecepatan.TextColor3 = WARNA.TeksSekunder
    JudulKecepatan.Text = "KECEPATAN"
    JudulKecepatan.ZIndex = 16
    JudulKecepatan.Parent = PanelKecepatan

    local KotakKecepatan = Instance.new("TextBox")
    KotakKecepatan.Name = "KotakKecepatan"
    KotakKecepatan.AnchorPoint = Vector2.new(0.5, 0)
    KotakKecepatan.Position = UDim2.new(0.5, 0, 0, 24)
    KotakKecepatan.Size = UDim2.new(1, -18, 0, 28)
    KotakKecepatan.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
    KotakKecepatan.BorderSizePixel = 0
    KotakKecepatan.Font = Enum.Font.GothamBold
    KotakKecepatan.TextSize = 14
    KotakKecepatan.TextColor3 = WARNA.Aksen
    KotakKecepatan.PlaceholderColor3 = WARNA.TeksRedup
    KotakKecepatan.PlaceholderText = "1"
    KotakKecepatan.Text = tostring(KECEPATAN_DEFAULT)
    KotakKecepatan.ClearTextOnFocus = false
    KotakKecepatan.ZIndex = 16
    KotakKecepatan.Parent = PanelKecepatan

    local SudutKotakKecepatan = Instance.new("UICorner")
    SudutKotakKecepatan.CornerRadius = UDim.new(0, 8)
    SudutKotakKecepatan.Parent = KotakKecepatan

    local PetunjukKecepatan = Instance.new("TextLabel")
    PetunjukKecepatan.BackgroundTransparency = 1
    PetunjukKecepatan.Position = UDim2.new(0, 0, 1, -18)
    PetunjukKecepatan.Size = UDim2.new(1, 0, 0, 14)
    PetunjukKecepatan.Font = Enum.Font.Gotham
    PetunjukKecepatan.TextSize = 9
    PetunjukKecepatan.TextColor3 = WARNA.TeksRedup
    PetunjukKecepatan.Text = "0.05 - 10x"
    PetunjukKecepatan.ZIndex = 16
    PetunjukKecepatan.Parent = PanelKecepatan

    local PanelBintang = Instance.new("Frame")
    PanelBintang.Name = "PanelBintang"
    PanelBintang.AnchorPoint = Vector2.new(0, 0.5)
    PanelBintang.Position = UDim2.new(0.5, 186, 0, 250)
    PanelBintang.Size = UDim2.new(0, 74, 0, 76)
    PanelBintang.BackgroundTransparency = 1
    PanelBintang.ZIndex = 15
    PanelBintang.Parent = WadahWheel

    local TombolBintang = Instance.new("TextButton")
    TombolBintang.Name = "TombolBintang"
    TombolBintang.AnchorPoint = Vector2.new(0.5, 0)
    TombolBintang.Position = UDim2.new(0.5, 0, 0, 4)
    TombolBintang.Size = UDim2.new(0, 52, 0, 52)
    TombolBintang.BackgroundColor3 = WARNA.LatarPanel
    TombolBintang.BackgroundTransparency = 0.1
    TombolBintang.AutoButtonColor = false
    TombolBintang.Font = Enum.Font.GothamBold
    TombolBintang.TextSize = 26
    TombolBintang.TextColor3 = WARNA.TeksSekunder
    TombolBintang.Text = "★"
    TombolBintang.ZIndex = 16
    TombolBintang.Parent = PanelBintang

    local SudutTombolBintang = Instance.new("UICorner")
    SudutTombolBintang.CornerRadius = UDim.new(1, 0)
    SudutTombolBintang.Parent = TombolBintang

    local GarisTombolBintang = Instance.new("UIStroke")
    GarisTombolBintang.Color = WARNA.GarisPanel
    GarisTombolBintang.Thickness = 1.5
    GarisTombolBintang.Parent = TombolBintang

    local LabelBintang = Instance.new("TextLabel")
    LabelBintang.Name = "LabelBintang"
    LabelBintang.BackgroundTransparency = 1
    LabelBintang.Position = UDim2.new(0, 0, 1, -16)
    LabelBintang.Size = UDim2.new(1, 0, 0, 16)
    LabelBintang.Font = Enum.Font.GothamBold
    LabelBintang.TextSize = 10
    LabelBintang.TextColor3 = WARNA.TeksSekunder
    LabelBintang.Text = "FAVORIT"
    LabelBintang.ZIndex = 16
    LabelBintang.Parent = PanelBintang

    local UKURAN_WHEEL = 344
    local UKURAN_TENGAH = 148
    local JARAK_SLOT = 120

    local LingkaranWheel = Instance.new("Frame")
    LingkaranWheel.Name = "LingkaranWheel"
    LingkaranWheel.AnchorPoint = Vector2.new(0.5, 0.5)
    LingkaranWheel.Position = UDim2.new(0.5, 0, 0, 250)
    LingkaranWheel.Size = UDim2.new(0, UKURAN_WHEEL, 0, UKURAN_WHEEL)
    LingkaranWheel.BackgroundColor3 = WARNA.LatarWheel
    LingkaranWheel.BackgroundTransparency = 0.14
    LingkaranWheel.BorderSizePixel = 0
    LingkaranWheel.ZIndex = 11
    LingkaranWheel.Parent = WadahWheel

    local SudutWheel = Instance.new("UICorner")
    SudutWheel.CornerRadius = UDim.new(1, 0)
    SudutWheel.Parent = LingkaranWheel

    local GarisWheel = Instance.new("UIStroke")
    GarisWheel.Color = WARNA.GarisWheel
    GarisWheel.Thickness = 2
    GarisWheel.Parent = LingkaranWheel

    local panjangGaris = (UKURAN_WHEEL - UKURAN_TENGAH) / 2 - 4
    local jarakTengahGaris = (UKURAN_TENGAH / 2) + (panjangGaris / 2)

    for i = 0, 7 do
        local sudutDerajat = 22.5 + (i * 45)
        local radian = math.rad(sudutDerajat - 90)
        local posX = (UKURAN_WHEEL / 2) + math.cos(radian) * jarakTengahGaris
        local posY = (UKURAN_WHEEL / 2) + math.sin(radian) * jarakTengahGaris

        local garis = Instance.new("Frame")
        garis.Name = "Pembagi_" .. tostring(i + 1)
        garis.AnchorPoint = Vector2.new(0.5, 0.5)
        garis.Position = UDim2.new(0, posX, 0, posY)
        garis.Size = UDim2.new(0, 1.5, 0, panjangGaris)
        garis.Rotation = sudutDerajat
        garis.BackgroundColor3 = WARNA.GarisPembagi
        garis.BackgroundTransparency = 0.25
        garis.BorderSizePixel = 0
        garis.ZIndex = 12
        garis.Parent = LingkaranWheel

        local gradasi = Instance.new("UIGradient")
        gradasi.Rotation = 90
        gradasi.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.75),
            NumberSequenceKeypoint.new(0.45, 0.15),
            NumberSequenceKeypoint.new(1, 0.05),
        })
        gradasi.Parent = garis
    end

    local DaftarTombolSlot = {}
    local IndeksSlotHover = nil

    for i = 1, SLOT_PER_HALAMAN do
        local sudutDerajat = (i - 1) * 45
        local radian = math.rad(sudutDerajat - 90)
        local sx = (UKURAN_WHEEL / 2) + math.cos(radian) * JARAK_SLOT
        local sy = (UKURAN_WHEEL / 2) + math.sin(radian) * JARAK_SLOT

        local tombolSlot = Instance.new("TextButton")
        tombolSlot.Name = "Slot_" .. tostring(i)
        tombolSlot.AnchorPoint = Vector2.new(0.5, 0.5)
        tombolSlot.Position = UDim2.new(0, sx, 0, sy)
        tombolSlot.Size = UDim2.new(0, 74, 0, 74)
        tombolSlot.BackgroundColor3 = WARNA.SlotNormal
        tombolSlot.BackgroundTransparency = 0.55
        tombolSlot.BorderSizePixel = 0
        tombolSlot.AutoButtonColor = false
        tombolSlot.Text = ""
        tombolSlot.ZIndex = 14
        tombolSlot.Parent = LingkaranWheel

        local sudutSlot = Instance.new("UICorner")
        sudutSlot.CornerRadius = UDim.new(1, 0)
        sudutSlot.Parent = tombolSlot

        local garisSlot = Instance.new("UIStroke")
        garisSlot.Color = WARNA.Aksen
        garisSlot.Thickness = 2
        garisSlot.Transparency = 1
        garisSlot.Parent = tombolSlot

        local gambarThumb = Instance.new("ImageLabel")
        gambarThumb.Name = "Thumbnail"
        gambarThumb.AnchorPoint = Vector2.new(0.5, 0.5)
        gambarThumb.Position = UDim2.new(0.5, 0, 0.44, 0)
        gambarThumb.Size = UDim2.new(0, 50, 0, 50)
        gambarThumb.BackgroundTransparency = 1
        gambarThumb.ScaleType = Enum.ScaleType.Fit
        gambarThumb.Image = ""
        gambarThumb.ZIndex = 15
        gambarThumb.Parent = tombolSlot

        local namaSlot = Instance.new("TextLabel")
        namaSlot.Name = "NamaSlot"
        namaSlot.AnchorPoint = Vector2.new(0.5, 1)
        namaSlot.Position = UDim2.new(0.5, 0, 1, -4)
        namaSlot.Size = UDim2.new(1, -8, 0, 14)
        namaSlot.BackgroundTransparency = 1
        namaSlot.Font = Enum.Font.GothamMedium
        namaSlot.TextSize = 9
        namaSlot.TextColor3 = WARNA.TeksUtama
        namaSlot.TextTruncate = Enum.TextTruncate.AtEnd
        namaSlot.Text = ""
        namaSlot.ZIndex = 16
        namaSlot.Parent = tombolSlot

        local lencanaFav = Instance.new("TextLabel")
        lencanaFav.Name = "LencanaFav"
        lencanaFav.AnchorPoint = Vector2.new(1, 0)
        lencanaFav.Position = UDim2.new(1, -2, 0, 2)
        lencanaFav.Size = UDim2.new(0, 18, 0, 18)
        lencanaFav.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
        lencanaFav.BackgroundTransparency = 0.2
        lencanaFav.Font = Enum.Font.GothamBold
        lencanaFav.TextSize = 11
        lencanaFav.TextColor3 = WARNA.Emas
        lencanaFav.Text = "★"
        lencanaFav.Visible = false
        lencanaFav.ZIndex = 17
        lencanaFav.Parent = tombolSlot

        local sudutLencana = Instance.new("UICorner")
        sudutLencana.CornerRadius = UDim.new(1, 0)
        sudutLencana.Parent = lencanaFav

        DaftarTombolSlot[i] = {
            Tombol     = tombolSlot,
            Garis      = garisSlot,
            Thumbnail  = gambarThumb,
            LabelNama  = namaSlot,
            LencanaFav = lencanaFav,
            DataEmote  = nil,
        }
    end

    local LingkaranTengah = Instance.new("Frame")
    LingkaranTengah.Name = "LingkaranTengah"
    LingkaranTengah.AnchorPoint = Vector2.new(0.5, 0.5)
    LingkaranTengah.Position = UDim2.new(0.5, 0, 0.5, 0)
    LingkaranTengah.Size = UDim2.new(0, UKURAN_TENGAH, 0, UKURAN_TENGAH)
    LingkaranTengah.BackgroundColor3 = WARNA.LatarTengah
    LingkaranTengah.BackgroundTransparency = 0.04
    LingkaranTengah.BorderSizePixel = 0
    LingkaranTengah.ZIndex = 18
    LingkaranTengah.Parent = LingkaranWheel

    local SudutTengah = Instance.new("UICorner")
    SudutTengah.CornerRadius = UDim.new(1, 0)
    SudutTengah.Parent = LingkaranTengah

    local GarisTengah = Instance.new("UIStroke")
    GarisTengah.Color = WARNA.GarisTengah
    GarisTengah.Thickness = 1.6
    GarisTengah.Parent = LingkaranTengah

    local LabelModeTengah = Instance.new("TextLabel")
    LabelModeTengah.Name = "LabelMode"
    LabelModeTengah.AnchorPoint = Vector2.new(0.5, 0)
    LabelModeTengah.Position = UDim2.new(0.5, 0, 0, 20)
    LabelModeTengah.Size = UDim2.new(1, -24, 0, 14)
    LabelModeTengah.BackgroundTransparency = 1
    LabelModeTengah.Font = Enum.Font.GothamBold
    LabelModeTengah.TextSize = 10
    LabelModeTengah.TextColor3 = WARNA.Aksen
    LabelModeTengah.Text = "SEMUA EMOTE"
    LabelModeTengah.ZIndex = 19
    LabelModeTengah.Parent = LingkaranTengah

    local LabelNamaTengah = Instance.new("TextLabel")
    LabelNamaTengah.Name = "LabelNamaEmote"
    LabelNamaTengah.AnchorPoint = Vector2.new(0.5, 0.5)
    LabelNamaTengah.Position = UDim2.new(0.5, 0, 0.5, 0)
    LabelNamaTengah.Size = UDim2.new(1, -22, 0, 52)
    LabelNamaTengah.BackgroundTransparency = 1
    LabelNamaTengah.Font = Enum.Font.GothamBold
    LabelNamaTengah.TextSize = 13
    LabelNamaTengah.TextWrapped = true
    LabelNamaTengah.TextColor3 = WARNA.TeksUtama
    LabelNamaTengah.Text = "Pilih Emote"
    LabelNamaTengah.ZIndex = 19
    LabelNamaTengah.Parent = LingkaranTengah

    local LabelHalaman = Instance.new("TextLabel")
    LabelHalaman.Name = "LabelHalaman"
    LabelHalaman.AnchorPoint = Vector2.new(0.5, 1)
    LabelHalaman.Position = UDim2.new(0.5, 0, 1, -18)
    LabelHalaman.Size = UDim2.new(1, -26, 0, 18)
    LabelHalaman.BackgroundTransparency = 1
    LabelHalaman.Font = Enum.Font.GothamMedium
    LabelHalaman.TextSize = 11
    LabelHalaman.TextColor3 = WARNA.TeksSekunder
    LabelHalaman.Text = "1 / 1"
    LabelHalaman.ZIndex = 19
    LabelHalaman.Parent = LingkaranTengah

    local BarBawah = Instance.new("Frame")
    BarBawah.Name = "BarBawah"
    BarBawah.AnchorPoint = Vector2.new(0.5, 0)
    BarBawah.Position = UDim2.new(0.5, 0, 0, 434)
    BarBawah.Size = UDim2.new(0, 326, 0, 44)
    BarBawah.BackgroundTransparency = 1
    BarBawah.ZIndex = 15
    BarBawah.Parent = WadahWheel

    local TombolSebelumnya = Instance.new("TextButton")
    TombolSebelumnya.Name = "TombolSebelumnya"
    TombolSebelumnya.AnchorPoint = Vector2.new(0, 0.5)
    TombolSebelumnya.Position = UDim2.new(0, 0, 0.5, 0)
    TombolSebelumnya.Size = UDim2.new(0, 44, 0, 44)
    TombolSebelumnya.BackgroundColor3 = WARNA.TombolNav
    TombolSebelumnya.BackgroundTransparency = 0.08
    TombolSebelumnya.AutoButtonColor = false
    TombolSebelumnya.Font = Enum.Font.GothamBold
    TombolSebelumnya.TextSize = 20
    TombolSebelumnya.TextColor3 = WARNA.TeksUtama
    TombolSebelumnya.Text = "<"
    TombolSebelumnya.ZIndex = 16
    TombolSebelumnya.Parent = BarBawah

    local SudutSebelumnya = Instance.new("UICorner")
    SudutSebelumnya.CornerRadius = UDim.new(1, 0)
    SudutSebelumnya.Parent = TombolSebelumnya

    local GarisSebelumnya = Instance.new("UIStroke")
    GarisSebelumnya.Color = WARNA.GarisPanel
    GarisSebelumnya.Thickness = 1.4
    GarisSebelumnya.Parent = TombolSebelumnya

    local TombolDaftarFav = Instance.new("TextButton")
    TombolDaftarFav.Name = "TombolDaftarFav"
    TombolDaftarFav.AnchorPoint = Vector2.new(0.5, 0.5)
    TombolDaftarFav.Position = UDim2.new(0.5, 0, 0.5, 0)
    TombolDaftarFav.Size = UDim2.new(0, 214, 0, 40)
    TombolDaftarFav.BackgroundColor3 = WARNA.LatarPanel
    TombolDaftarFav.BackgroundTransparency = 0.08
    TombolDaftarFav.AutoButtonColor = false
    TombolDaftarFav.Font = Enum.Font.GothamBold
    TombolDaftarFav.TextSize = 13
    TombolDaftarFav.TextColor3 = WARNA.Emas
    TombolDaftarFav.Text = "★  Favorit (0)"
    TombolDaftarFav.ZIndex = 16
    TombolDaftarFav.Parent = BarBawah

    local SudutDaftarFav = Instance.new("UICorner")
    SudutDaftarFav.CornerRadius = UDim.new(0, 20)
    SudutDaftarFav.Parent = TombolDaftarFav

    local GarisDaftarFav = Instance.new("UIStroke")
    GarisDaftarFav.Color = WARNA.Emas
    GarisDaftarFav.Thickness = 1.4
    GarisDaftarFav.Transparency = 0.35
    GarisDaftarFav.Parent = TombolDaftarFav

    local TombolBerikutnya = Instance.new("TextButton")
    TombolBerikutnya.Name = "TombolBerikutnya"
    TombolBerikutnya.AnchorPoint = Vector2.new(1, 0.5)
    TombolBerikutnya.Position = UDim2.new(1, 0, 0.5, 0)
    TombolBerikutnya.Size = UDim2.new(0, 44, 0, 44)
    TombolBerikutnya.BackgroundColor3 = WARNA.TombolNav
    TombolBerikutnya.BackgroundTransparency = 0.08
    TombolBerikutnya.AutoButtonColor = false
    TombolBerikutnya.Font = Enum.Font.GothamBold
    TombolBerikutnya.TextSize = 20
    TombolBerikutnya.TextColor3 = WARNA.TeksUtama
    TombolBerikutnya.Text = ">"
    TombolBerikutnya.ZIndex = 16
    TombolBerikutnya.Parent = BarBawah

    local SudutBerikutnya = Instance.new("UICorner")
    SudutBerikutnya.CornerRadius = UDim.new(1, 0)
    SudutBerikutnya.Parent = TombolBerikutnya

    local GarisBerikutnya = Instance.new("UIStroke")
    GarisBerikutnya.Color = WARNA.GarisPanel
    GarisBerikutnya.Thickness = 1.4
    GarisBerikutnya.Parent = TombolBerikutnya

    local LabelStatus = Instance.new("TextLabel")
    LabelStatus.Name = "LabelStatus"
    LabelStatus.AnchorPoint = Vector2.new(0.5, 0)
    LabelStatus.Position = UDim2.new(0.5, 0, 0, 482)
    LabelStatus.Size = UDim2.new(0, 360, 0, 16)
    LabelStatus.BackgroundTransparency = 1
    LabelStatus.Font = Enum.Font.Gotham
    LabelStatus.TextSize = 10
    LabelStatus.TextColor3 = WARNA.TeksRedup
    LabelStatus.Text = ""
    LabelStatus.ZIndex = 15
    LabelStatus.Parent = WadahWheel

    local function jagaPosisiIkonDalamLayar()
        local kamera = ambilKamera()
        local ukuranLayar = kamera and kamera.ViewportSize or Vector2.new(1280, 720)
        local lebarTombol = TombolIkonEmote.Size.X.Offset
        local tinggiTombol = TombolIkonEmote.Size.Y.Offset
        local posX = math.clamp(TombolIkonEmote.Position.X.Offset, 6, math.max(6, ukuranLayar.X - lebarTombol - 6))
        local posY = math.clamp(TombolIkonEmote.Position.Y.Offset, 6, math.max(6, ukuranLayar.Y - tinggiTombol - 6))
        TombolIkonEmote.Position = UDim2.new(0, posX, 0, posY)
    end

    local function perbaruiTataLetakResponsif()
        local kamera = ambilKamera()
        local ukuranLayar = kamera and kamera.ViewportSize or Vector2.new(1280, 720)
        local modeMobile = apakahPerangkatMobile() or (ukuranLayar.X < 900)

        local skalaX = (ukuranLayar.X * 0.94) / 560
        local skalaY = (ukuranLayar.Y * 0.86) / 502
        SkalaWheel.Scale = math.clamp(math.min(skalaX, skalaY), 0.48, 1.05)

        if modeMobile then
            local ukuranTombol = math.clamp(math.floor(ukuranLayar.Y * 0.085), 36, 44)
            TombolIkonEmote.Size = UDim2.new(0, ukuranTombol, 0, ukuranTombol)
            LabelSenyum.TextSize = math.floor(ukuranTombol * 0.62)
            if not Status.PosisiIkonKustom then
                TombolIkonEmote.Position = UDim2.new(0, 184, 0, 10)
            end
        else
            TombolIkonEmote.Size = UDim2.new(0, 44, 0, 44)
            LabelSenyum.TextSize = 26
            if not Status.PosisiIkonKustom then
                TombolIkonEmote.Position = UDim2.new(0, 224, 0, 12)
            end
        end

        if Status.PosisiIkonKustom then
            jagaPosisiIkonDalamLayar()
        end
    end

    perbaruiTataLetakResponsif()

    local function pasangPantauUkuranLayar()
        local kamera = ambilKamera()
        if kamera then
            catatKoneksi(kamera:GetPropertyChangedSignal("ViewportSize"):Connect(perbaruiTataLetakResponsif))
        end
    end
    pasangPantauUkuranLayar()
    catatKoneksi(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        perbaruiTataLetakResponsif()
        pasangPantauUkuranLayar()
    end))

    local sedangTahanIkon = false
    local ikonBaruDigeser = false
    local posisiInputAwal = Vector3.new()
    local posisiTombolAwal = UDim2.new()

    catatKoneksi(TombolIkonEmote.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sedangTahanIkon = true
            ikonBaruDigeser = false
            posisiInputAwal = input.Position
            posisiTombolAwal = TombolIkonEmote.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    sedangTahanIkon = false
                end
            end)
        end
    end))

    catatKoneksi(UserInputService.InputChanged:Connect(function(input)
        if not sedangTahanIkon then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local selisih = input.Position - posisiInputAwal
            if selisih.Magnitude > 6 then
                ikonBaruDigeser = true
                Status.PosisiIkonKustom = true
            end

            if ikonBaruDigeser then
                local kamera = ambilKamera()
                local ukuranLayar = kamera and kamera.ViewportSize or Vector2.new(1280, 720)
                local lebarTombol = TombolIkonEmote.Size.X.Offset
                local tinggiTombol = TombolIkonEmote.Size.Y.Offset

                local baruX = math.clamp(posisiTombolAwal.X.Offset + selisih.X, 6, math.max(6, ukuranLayar.X - lebarTombol - 6))
                local baruY = math.clamp(posisiTombolAwal.Y.Offset + selisih.Y, 6, math.max(6, ukuranLayar.Y - tinggiTombol - 6))
                TombolIkonEmote.Position = UDim2.new(0, baruX, 0, baruY)
            end
        end
    end))

    local function perbaruiTampilanBintang()
        if Status.ModeTampilan == "Favorit" then
            LabelBintang.Text = "UNFAV"
            if Status.ModeBintang then
                TombolBintang.BackgroundColor3 = WARNA.Bahaya
                TombolBintang.TextColor3 = WARNA.TeksUtama
                GarisTombolBintang.Color = WARNA.Bahaya
                GarisWheel.Color = WARNA.Bahaya
                LabelModeTengah.Text = "★ KLIK UTK UNFAV"
                LabelModeTengah.TextColor3 = WARNA.Bahaya
            else
                TombolBintang.BackgroundColor3 = WARNA.LatarPanel
                TombolBintang.TextColor3 = WARNA.TeksSekunder
                GarisTombolBintang.Color = WARNA.GarisPanel
                GarisWheel.Color = WARNA.Emas
                LabelModeTengah.Text = "★ FAVORIT"
                LabelModeTengah.TextColor3 = WARNA.Emas
            end
        else
            LabelBintang.Text = "FAVORIT"
            if Status.ModeBintang then
                TombolBintang.BackgroundColor3 = WARNA.Emas
                TombolBintang.TextColor3 = Color3.fromRGB(20, 20, 24)
                GarisTombolBintang.Color = WARNA.Emas
                GarisWheel.Color = WARNA.Emas
                LabelModeTengah.Text = "★ KLIK UTK FAV"
                LabelModeTengah.TextColor3 = WARNA.Emas
            else
                TombolBintang.BackgroundColor3 = WARNA.LatarPanel
                TombolBintang.TextColor3 = WARNA.TeksSekunder
                GarisTombolBintang.Color = WARNA.GarisPanel
                GarisWheel.Color = WARNA.GarisWheel
                LabelModeTengah.Text = "SEMUA EMOTE"
                LabelModeTengah.TextColor3 = WARNA.Aksen
            end
        end
    end

    local function perbaruiTombolDaftarFav()
        if Status.ModeTampilan == "Favorit" then
            TombolDaftarFav.Text = "←  Semua Emote (" .. formatAngka(#Status.SemuaEmote) .. ")"
            TombolDaftarFav.TextColor3 = WARNA.Aksen
            GarisDaftarFav.Color = WARNA.Aksen
        else
            TombolDaftarFav.Text = "★  Favorit (" .. formatAngka(#Status.DaftarFavorit) .. ")"
            TombolDaftarFav.TextColor3 = WARNA.Emas
            GarisDaftarFav.Color = WARNA.Emas
        end
    end

    local function perbaruiTampilanTengah(itemEmote)
        if itemEmote then
            LabelNamaTengah.Text = itemEmote.name
            LabelNamaTengah.TextColor3 = WARNA.TeksUtama
        else
            if Status.ModeTampilan == "Favorit" and #Status.DaftarFavorit == 0 then
                LabelNamaTengah.Text = "Belum ada Favorit"
                LabelNamaTengah.TextColor3 = WARNA.TeksRedup
            elseif #Status.DaftarTampil == 0 then
                LabelNamaTengah.Text = "Tidak ditemukan"
                LabelNamaTengah.TextColor3 = WARNA.TeksRedup
            else
                LabelNamaTengah.Text = "Pilih Emote"
                LabelNamaTengah.TextColor3 = WARNA.TeksSekunder
            end
        end
    end

    local function gambarHalamanWheel()
        local totalItem = #Status.DaftarTampil
        Status.TotalHalaman = math.max(1, math.ceil(totalItem / SLOT_PER_HALAMAN))
        Status.HalamanSekarang = math.clamp(Status.HalamanSekarang, 1, Status.TotalHalaman)

        LabelHalaman.Text = formatAngka(Status.HalamanSekarang) .. " / " .. formatAngka(Status.TotalHalaman)

        local bisaSebelumnya = Status.HalamanSekarang > 1
        local bisaBerikutnya = Status.HalamanSekarang < Status.TotalHalaman
        TombolSebelumnya.TextTransparency = bisaSebelumnya and 0 or 0.65
        GarisSebelumnya.Transparency = bisaSebelumnya and 0.15 or 0.65
        TombolBerikutnya.TextTransparency = bisaBerikutnya and 0 or 0.65
        GarisBerikutnya.Transparency = bisaBerikutnya and 0.15 or 0.65

        local indeksAwal = (Status.HalamanSekarang - 1) * SLOT_PER_HALAMAN

        for i = 1, SLOT_PER_HALAMAN do
            local slot = DaftarTombolSlot[i]
            local item = Status.DaftarTampil[indeksAwal + i]
            slot.DataEmote = item

            if item then
                slot.Tombol.Visible = true
                slot.Thumbnail.Image = buatUrlThumbnail(item.id)
                slot.LabelNama.Text = item.name
                slot.LencanaFav.Visible = (Status.SetFavorit[item.id] == true)
                slot.Tombol.BackgroundColor3 = WARNA.SlotNormal
                slot.Garis.Transparency = 1
            else
                slot.Tombol.Visible = false
                slot.Thumbnail.Image = ""
                slot.LabelNama.Text = ""
                slot.LencanaFav.Visible = false
            end
        end

        IndeksSlotHover = nil
        perbaruiTampilanBintang()
        perbaruiTombolDaftarFav()
        perbaruiTampilanTengah(nil)
    end

    local function bangunUlangDaftarTampil(resetHalaman)
        local sumber = (Status.ModeTampilan == "Favorit") and Status.DaftarFavorit or Status.SemuaEmote
        local kataKunci = string.lower(string.gsub(Status.KataKunciCari or "", "^%s*(.-)%s*$", "%1"))

        if kataKunci == "" then
            Status.DaftarTampil = sumber
            if resetHalaman then
                Status.HalamanSekarang = 1
            end
            gambarHalamanWheel()
            return
        end

        local hasil = {}
        local sudahAda = {}

        local idAngka = tonumber(kataKunci)
        if idAngka and math.floor(idAngka) == idAngka and idAngka > 0 and Status.ModeTampilan == "Semua" then
            local namaKetemu = Status.CacheNamaId[idAngka]
            if not namaKetemu then
                for idx = 1, #sumber do
                    if sumber[idx].id == idAngka then
                        namaKetemu = sumber[idx].name
                        break
                    end
                end
            end

            sudahAda[idAngka] = true
            hasil[#hasil + 1] = {
                id   = idAngka,
                name = namaKetemu or ("Emote #" .. tostring(idAngka)),
                l    = string.lower(namaKetemu or tostring(idAngka)),
            }

            if not namaKetemu then
                task.spawn(function()
                    local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, idAngka)
                    if ok and type(info) == "table" and info.Name then
                        Status.CacheNamaId[idAngka] = info.Name
                        if not Status.SudahDihancurkan and tonumber(Status.KataKunciCari) == idAngka then
                            bangunUlangDaftarTampil(false)
                        end
                    end
                end)
            end
        end

        if Status.ModeTampilan == "Semua" and Status.KataKunciLive == kataKunci and #Status.HasilCariLive > 0 then
            for idx = 1, #Status.HasilCariLive do
                local item = Status.HasilCariLive[idx]
                if not sudahAda[item.id] then
                    sudahAda[item.id] = true
                    hasil[#hasil + 1] = item
                end
            end
        end

        local batasHasil = 400
        for idx = 1, #sumber do
            local item = sumber[idx]
            if not sudahAda[item.id] then
                if string.find(item.l, kataKunci, 1, true)
                    or (idAngka and string.find(tostring(item.id), kataKunci, 1, true))
                then
                    sudahAda[item.id] = true
                    hasil[#hasil + 1] = item
                    if #hasil >= batasHasil then break end
                end
            end
        end

        if #hasil < 16 and not idAngka then
            local daftarKata = {}
            for kata in string.gmatch(kataKunci, "%w+") do
                if #kata >= 2 then
                    daftarKata[#daftarKata + 1] = kata
                end
            end
            if #daftarKata >= 2 then
                local minimalCocok = math.max(2, #daftarKata - 1)
                for idx = 1, #sumber do
                    local item = sumber[idx]
                    if not sudahAda[item.id] then
                        local cocok = 0
                        for wi = 1, #daftarKata do
                            if string.find(item.l, daftarKata[wi], 1, true) then
                                cocok = cocok + 1
                            end
                        end
                        if cocok >= minimalCocok then
                            sudahAda[item.id] = true
                            hasil[#hasil + 1] = item
                            if #hasil >= 120 then break end
                        end
                    end
                end
            end
        end

        Status.DaftarTampil = hasil
        if resetHalaman then
            Status.HalamanSekarang = 1
        end
        gambarHalamanWheel()
    end

    local function aturBukaWheel(buka)
        if Status.SudahDihancurkan then return end
        Status.Terbuka = buka
        WadahWheel.Visible = buka

        if buka then
            matikanEmoteBawaan()
            GarisIkonEmote.Color = WARNA.Aksen
            GarisIkonEmote.Transparency = 0.05
            LabelSenyum.TextColor3 = WARNA.Aksen
            bangunUlangDaftarTampil(false)
        else
            GarisIkonEmote.Color = Color3.fromRGB(95, 100, 118)
            GarisIkonEmote.Transparency = 0.35
            LabelSenyum.TextColor3 = WARNA.TeksUtama
            if Status.ModeBintang then
                Status.ModeBintang = false
                perbaruiTampilanBintang()
            end
        end
    end

    catatKoneksi(TombolIkonEmote.MouseButton1Click:Connect(function()
        if ikonBaruDigeser then
            ikonBaruDigeser = false
            return
        end
        aturBukaWheel(not Status.Terbuka)
    end))

    catatKoneksi(UserInputService.InputBegan:Connect(function(input, sedangKetik)
        if sedangKetik then return end
        if input.KeyCode == Enum.KeyCode.Period then
            aturBukaWheel(not Status.Terbuka)
        elseif input.KeyCode == Enum.KeyCode.Escape and Status.Terbuka then
            aturBukaWheel(false)
        end
    end))

    catatKoneksi(LingkaranWheel.InputChanged:Connect(function(input)
        if not Status.Terbuka then return end
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            if input.Position.Z > 0 and Status.HalamanSekarang > 1 then
                Status.HalamanSekarang = Status.HalamanSekarang - 1
                gambarHalamanWheel()
            elseif input.Position.Z < 0 and Status.HalamanSekarang < Status.TotalHalaman then
                Status.HalamanSekarang = Status.HalamanSekarang + 1
                gambarHalamanWheel()
            end
        end
    end))

    catatKoneksi(TombolSebelumnya.MouseEnter:Connect(function()
        if Status.HalamanSekarang > 1 then
            TombolSebelumnya.BackgroundColor3 = WARNA.TombolNavHover
            GarisSebelumnya.Color = WARNA.Aksen
        end
    end))
    catatKoneksi(TombolSebelumnya.MouseLeave:Connect(function()
        TombolSebelumnya.BackgroundColor3 = WARNA.TombolNav
        GarisSebelumnya.Color = WARNA.GarisPanel
    end))
    catatKoneksi(TombolSebelumnya.MouseButton1Click:Connect(function()
        if Status.HalamanSekarang > 1 then
            Status.HalamanSekarang = Status.HalamanSekarang - 1
            gambarHalamanWheel()
        end
    end))

    catatKoneksi(TombolBerikutnya.MouseEnter:Connect(function()
        if Status.HalamanSekarang < Status.TotalHalaman then
            TombolBerikutnya.BackgroundColor3 = WARNA.TombolNavHover
            GarisBerikutnya.Color = WARNA.Aksen
        end
    end))
    catatKoneksi(TombolBerikutnya.MouseLeave:Connect(function()
        TombolBerikutnya.BackgroundColor3 = WARNA.TombolNav
        GarisBerikutnya.Color = WARNA.GarisPanel
    end))
    catatKoneksi(TombolBerikutnya.MouseButton1Click:Connect(function()
        if Status.HalamanSekarang < Status.TotalHalaman then
            Status.HalamanSekarang = Status.HalamanSekarang + 1
            gambarHalamanWheel()
        end
    end))

    local function terapkanKecepatanDariInput()
        local hasil = batasiKecepatan(KotakKecepatan.Text)
        Status.Kecepatan = hasil
        KotakKecepatan.Text = formatKecepatan(hasil)
        if Status.TrackAktif then
            pcall(function()
                Status.TrackAktif:AdjustSpeed(Status.Kecepatan)
            end)
        end
    end

    catatKoneksi(KotakKecepatan.FocusLost:Connect(function()
        terapkanKecepatanDariInput()
    end))

    catatKoneksi(TombolBintang.MouseButton1Click:Connect(function()
        Status.ModeBintang = not Status.ModeBintang
        perbaruiTampilanBintang()
        if Status.ModeBintang then
            if Status.ModeTampilan == "Favorit" then
                tampilkanNotif("Mode Unfav aktif — klik emote untuk menghapus dari Favorit.", WARNA.Bahaya)
            else
                tampilkanNotif("Mode Favorit aktif — klik emote yang ingin difavoritkan.", WARNA.Emas)
            end
        end
    end))

    catatKoneksi(TombolDaftarFav.MouseButton1Click:Connect(function()
        Status.ModeBintang = false
        if Status.ModeTampilan == "Semua" then
            Status.ModeTampilan = "Favorit"
        else
            Status.ModeTampilan = "Semua"
        end
        bangunUlangDaftarTampil(true)
    end))

    local function cariLiveMarketplace(kataKunci, idPermintaan)
        local kataNormal = string.lower(string.gsub(kataKunci or "", "^%s*(.-)%s*$", "%1"))
        if #kataNormal < 2 then return end

        local daftarKetemu = {}
        local setKetemu = {}

        pcall(function()
            local param = CatalogSearchParams.new()
            param.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
            param.SalesTypeFilter = Enum.SalesTypeFilter.All
            param.IncludeOffSale = true
            param.SearchKeyword = kataKunci
            param.Limit = 30

            local halaman = AvatarEditorService:SearchCatalog(param)
            if halaman then
                local isiHalaman = halaman:GetCurrentPage()
                if type(isiHalaman) == "table" then
                    for _, item in ipairs(isiHalaman) do
                        local id = tonumber(item.Id)
                        local nama = tostring(item.Name or ("Emote #" .. tostring(id)))
                        if id and not setKetemu[id] then
                            setKetemu[id] = true
                            daftarKetemu[#daftarKetemu + 1] = {
                                id   = id,
                                name = nama,
                                l    = string.lower(nama),
                            }
                            tambahEmoteKeDaftar(id, nama)
                        end
                    end
                end
            end
        end)

        if #daftarKetemu == 0 then
            local terencode = HttpService:UrlEncode(kataKunci)
            local daftarUrl = {
                "https://catalog.roproxy.com/v1/search/items/details?Category=12&Subcategory=39&Limit=30&Keyword=" .. terencode,
                "https://catalog.roblox.com/v1/search/items/details?Category=12&Subcategory=39&Limit=30&Keyword=" .. terencode,
            }
            for _, url in ipairs(daftarUrl) do
                local daftar = ambilDataKatalogHttp(url)
                if daftar and #daftar > 0 then
                    for _, item in ipairs(daftar) do
                        local id = tonumber(item.id)
                        local nama = tostring(item.name or ("Emote #" .. tostring(id)))
                        if id and not setKetemu[id] then
                            setKetemu[id] = true
                            daftarKetemu[#daftarKetemu + 1] = {
                                id   = id,
                                name = nama,
                                l    = string.lower(nama),
                            }
                            tambahEmoteKeDaftar(id, nama)
                        end
                    end
                    break
                end
            end
        end

        if not Status.SudahDihancurkan and Status.IdPermintaanCari == idPermintaan and #daftarKetemu > 0 then
            Status.KataKunciLive = kataNormal
            Status.HasilCariLive = daftarKetemu
            LabelStatus.Text = formatAngka(#Status.SemuaEmote) .. " Emote tersedia"
            bangunUlangDaftarTampil(true)
        end
    end

    catatKoneksi(KotakCari:GetPropertyChangedSignal("Text"):Connect(function()
        local teks = KotakCari.Text
        Status.KataKunciCari = teks
        TombolHapusCari.Visible = (#teks > 0)

        if teks == "" then
            Status.KataKunciLive = ""
            Status.HasilCariLive = {}
            bangunUlangDaftarTampil(true)
            return
        end

        Status.IdDebounceCari = Status.IdDebounceCari + 1
        local idDebounceIni = Status.IdDebounceCari
        task.delay(0.08, function()
            if not Status.SudahDihancurkan and Status.IdDebounceCari == idDebounceIni then
                bangunUlangDaftarTampil(true)
            end
        end)

        local teksRapih = string.gsub(teks, "^%s*(.-)%s*$", "%1")
        if Status.ModeTampilan == "Semua" and #teksRapih >= 2 and not tonumber(teksRapih) then
            Status.IdPermintaanCari = Status.IdPermintaanCari + 1
            local idPermintaanIni = Status.IdPermintaanCari
            task.delay(0.45, function()
                if not Status.SudahDihancurkan and Status.IdPermintaanCari == idPermintaanIni then
                    cariLiveMarketplace(teksRapih, idPermintaanIni)
                end
            end)
        end
    end))

    catatKoneksi(TombolHapusCari.MouseButton1Click:Connect(function()
        KotakCari.Text = ""
    end))

    for i = 1, SLOT_PER_HALAMAN do
        local slot = DaftarTombolSlot[i]

        catatKoneksi(slot.Tombol.MouseEnter:Connect(function()
            if not slot.DataEmote then return end
            IndeksSlotHover = i
            if Status.ModeBintang then
                if Status.ModeTampilan == "Favorit" then
                    slot.Tombol.BackgroundColor3 = WARNA.SlotModeUnfav
                    slot.Garis.Color = WARNA.Bahaya
                else
                    slot.Tombol.BackgroundColor3 = WARNA.SlotModeFav
                    slot.Garis.Color = WARNA.Emas
                end
            else
                slot.Tombol.BackgroundColor3 = WARNA.SlotHover
                slot.Garis.Color = WARNA.Aksen
            end
            slot.Garis.Transparency = 0.1
            perbaruiTampilanTengah(slot.DataEmote)
        end))

        catatKoneksi(slot.Tombol.MouseLeave:Connect(function()
            slot.Tombol.BackgroundColor3 = WARNA.SlotNormal
            slot.Garis.Transparency = 1
            if IndeksSlotHover == i then
                IndeksSlotHover = nil
                perbaruiTampilanTengah(nil)
            end
        end))

        catatKoneksi(slot.Tombol.MouseButton1Click:Connect(function()
            local item = slot.DataEmote
            if not item then return end

            perbaruiTampilanTengah(item)

            if Status.ModeBintang then
                if Status.ModeTampilan == "Favorit" then
                    if Status.SetFavorit[item.id] then
                        Status.SetFavorit[item.id] = nil
                        for idx, fav in ipairs(Status.DaftarFavorit) do
                            if fav.id == item.id then
                                table.remove(Status.DaftarFavorit, idx)
                                break
                            end
                        end
                        simpanFavorit()
                        tampilkanNotif('Emote "' .. item.name .. '" dihapus dari Favorit.', WARNA.Bahaya)
                        bangunUlangDaftarTampil(false)
                    end
                else
                    if Status.SetFavorit[item.id] then
                        tampilkanNotif('Emote "' .. item.name .. '" sudah ada di Favorit!', WARNA.Emas)
                    else
                        Status.SetFavorit[item.id] = true
                        table.insert(Status.DaftarFavorit, {
                            id   = item.id,
                            name = item.name,
                            l    = string.lower(item.name),
                        })
                        simpanFavorit()
                        slot.LencanaFav.Visible = true
                        perbaruiTombolDaftarFav()
                        tampilkanNotif('Emote "' .. item.name .. '" berhasil difavoritkan! ★', WARNA.Sukses)
                    end
                end
            else
                terapkanKecepatanDariInput()
                putarEmote(item)
                aturBukaWheel(false)
            end
        end))
    end

    local function muatLewatJsonRemote()
        for _, url in ipairs(URL_JSON_EMOTE_REMOTE) do
            if Status.SudahDihancurkan then return false end
            local mentah = ambilTeksHttp(url)
            if mentah and #mentah > 1000 then
                local daftar = uraiJsonKatalog(mentah)
                if daftar and #daftar >= MIN_CACHE_VALID then
                    LabelStatus.Text = "Memproses " .. formatAngka(#daftar) .. " emote Marketplace..."
                    masukkanArrayEmote(daftar, true)
                    simpanCacheMentah(mentah)
                    return true
                end
            end
        end
        return false
    end

    local function muatLewatAvatarEditorService()
        local daftarUrutan = {
            Enum.CatalogSortType.Relevance,
            Enum.CatalogSortType.BestSelling,
            Enum.CatalogSortType.MostFavorited,
            Enum.CatalogSortType.RecentlyCreated,
        }

        local berhasilDapat = false
        for _, urutan in ipairs(daftarUrutan) do
            if Status.SudahDihancurkan then break end
            pcall(function()
                local param = CatalogSearchParams.new()
                param.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
                param.SalesTypeFilter = Enum.SalesTypeFilter.All
                param.IncludeOffSale = true
                param.SortType = urutan
                param.Limit = 30

                local halaman = AvatarEditorService:SearchCatalog(param)
                local noHal = 0
                while halaman and noHal < 34 and not Status.SudahDihancurkan do
                    local isi = halaman:GetCurrentPage()
                    if type(isi) == "table" and #isi > 0 then
                        masukkanArrayEmote(isi, true)
                        berhasilDapat = true
                    else
                        break
                    end

                    noHal = noHal + 1
                    if noHal == 1 or noHal % 3 == 0 then
                        if not Status.SudahDihancurkan then
                            LabelStatus.Text = "Memuat katalog Roblox: " .. formatAngka(#Status.SemuaEmote) .. "..."
                            if Status.Terbuka and Status.ModeTampilan == "Semua" and Status.KataKunciCari == "" then
                                bangunUlangDaftarTampil(false)
                            end
                        end
                    end

                    if halaman.IsFinished then break end
                    local okLanjut = pcall(function()
                        halaman:AdvanceToNextPageAsync()
                    end)
                    if not okLanjut then break end
                    task.wait(0.18)
                end
            end)
        end

        if berhasilDapat then
            simpanCacheTabel()
        end
        return berhasilDapat
    end

    local function muatLewatCatalogApi()
        local daftarHost = {
            "https://catalog.roproxy.com/v1/search/items/details?Category=12&Subcategory=39&Limit=30",
            "https://catalog.roblox.com/v1/search/items/details?Category=12&Subcategory=39&Limit=30",
        }
        local daftarSort = { 0, 2, 1, 3 }
        local hostAktif = nil

        for _, host in ipairs(daftarHost) do
            local daftar = ambilDataKatalogHttp(host .. "&SortType=0")
            if daftar and #daftar > 0 then
                hostAktif = host
                break
            end
        end

        if not hostAktif then return false end

        local berhasilDapat = false
        for _, tipeSort in ipairs(daftarSort) do
            if Status.SudahDihancurkan then break end
            local cursor = ""
            local hal = 0
            local urlDasar = hostAktif .. "&SortType=" .. tostring(tipeSort)

            while hal < 34 and not Status.SudahDihancurkan do
                local url = (cursor ~= "") and (urlDasar .. "&Cursor=" .. HttpService:UrlEncode(cursor)) or urlDasar
                local daftar, nextCursor, kode = ambilDataKatalogHttp(url)
                if not daftar and kode == 429 then
                    task.wait(1.5)
                    daftar, nextCursor = ambilDataKatalogHttp(url)
                end
                if not daftar or #daftar == 0 then break end

                masukkanArrayEmote(daftar, true)
                berhasilDapat = true
                hal = hal + 1
                cursor = nextCursor or ""

                if hal == 1 or hal % 3 == 0 then
                    if not Status.SudahDihancurkan then
                        LabelStatus.Text = "Memuat Catalog API: " .. formatAngka(#Status.SemuaEmote) .. "..."
                        if Status.Terbuka and Status.ModeTampilan == "Semua" and Status.KataKunciCari == "" then
                            bangunUlangDaftarTampil(false)
                        end
                    end
                end

                if cursor == "" then break end
                task.wait(0.2)
            end
        end

        if berhasilDapat then
            simpanCacheTabel()
        end
        return berhasilDapat
    end

    local function muatKatalogMarketplaceAsync()
        if Status.SedangMuatKatalog then return end
        Status.SedangMuatKatalog = true

        task.spawn(function()
            if not Status.SudahDihancurkan then
                LabelStatus.Text = "Mengunduh database emote Marketplace..."
            end

            local berhasil = muatLewatJsonRemote()

            if not berhasil and not Status.SudahDihancurkan then
                LabelStatus.Text = "Memuat via Roblox AvatarEditorService..."
                berhasil = muatLewatAvatarEditorService()
            end

            if not berhasil and not Status.SudahDihancurkan then
                LabelStatus.Text = "Memuat via Catalog API..."
                berhasil = muatLewatCatalogApi()
            end

            Status.SedangMuatKatalog = false
            if not Status.SudahDihancurkan then
                LabelStatus.Text = formatAngka(#Status.SemuaEmote) .. " Emote tersedia"
                bangunUlangDaftarTampil(false)
                if berhasil and #Status.SemuaEmote >= MIN_CACHE_VALID then
                    tampilkanNotif("Berhasil memuat " .. formatAngka(#Status.SemuaEmote) .. " Emote Marketplace!", WARNA.Sukses)
                end
            end
        end)
    end

    muatFavorit()

    for _, item in ipairs(EMOTE_CADANGAN) do
        tambahEmoteKeDaftar(item.id, item.name)
    end
    bangunUlangDaftarTampil(true)

    task.spawn(function()
        local adaCache, masihSegar = muatCacheEmote()
        if adaCache and not Status.SudahDihancurkan then
            LabelStatus.Text = formatAngka(#Status.SemuaEmote) .. " Emote tersedia (cache)"
            bangunUlangDaftarTampil(true)
            if not masihSegar then
                muatKatalogMarketplaceAsync()
            end
        else
            muatKatalogMarketplaceAsync()
        end
    end)

    tampilkanNotif("DiiEmote v" .. VERSI .. " aktif! Tekan ( . ) atau geser/klik ikon ☺.", WARNA.Aksen)

    lingkungan.DiiEmoteCleanup = function()
        Status.SudahDihancurkan = true
        hentikanEmoteAktif(0)
        bersihkanKoneksiKarakter()
        for _, koneksi in ipairs(Status.DaftarKoneksi) do
            pcall(function() koneksi:Disconnect() end)
        end
        table.clear(Status.DaftarKoneksi)
        if LayarGui and LayarGui.Parent then
            LayarGui:Destroy()
        end
    end
end

Inv.diiEmoteLauncher = function()
    clearContent()
    label("🕺  DiiEmote")
    local info = label("Roda emote dengan 62.000+ emote Marketplace, favorit, pencarian, "
        .. "dan kecepatan animasi 0.05x - 10x.")
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextColor3 = GREY

    local status = label("")
    status.Font = Enum.Font.GothamSemibold
    status.TextSize = 12
    local function paint()
        if shared.DiiEmoteOn then
            status.Text = "Status: AKTIF ✅  (klik ikon ☺ di layar atau tekan tombol titik  .  )"
            status.TextColor3 = Color3.fromRGB(90, 220, 140)
        else
            status.Text = "Status: belum aktif"
            status.TextColor3 = GREY
        end
    end
    paint()

    button("▶  Jalankan DiiEmote", function()
        if shared.DiiEmoteOn then
            toast("DiiEmote sudah aktif")
            return
        end
        shared.DiiEmoteOn = true
        task.spawn(function()
            local ok, err = pcall(Inv.diiEmoteRun)
            if not ok then
                shared.DiiEmoteOn = false
                warn("[DiiUi HUB] DiiEmote error: " .. tostring(err))
                toast("DiiEmote error, lihat console (F9)")
            else
                toast("DiiEmote aktif!")
            end
            if status and status.Parent then paint() end
        end)
        paint()
    end)

    button("■  Matikan DiiEmote", function()
        local env = (type(getgenv) == "function" and getgenv()) or _G
        if type(env.DiiEmoteCleanup) == "function" then
            pcall(env.DiiEmoteCleanup)
        end
        pcall(function()
            game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
        end)
        shared.DiiEmoteOn = false
        paint()
        toast("DiiEmote dimatikan")
    end)

    label("Tips: klik ★ lalu pilih emote untuk memfavoritkan. Emote berhenti otomatis saat karakter bergerak. "
        .. "Emote Marketplace butuh avatar R15.").TextSize = 12
end

--====================================
-- MENU GABUNGAN: 1 menu di sidebar, di dalamnya ada pilihan sub-menu
--====================================
local function makeMergedTab(sections)
    local sel = 1
    local self
    local function header()
        for i, sec in ipairs(sections) do
            local b = button((i == sel and "▶  " or "◻  ") .. sec.name, function()
                if sel ~= i then
                    sel = i
                    self()
                end
            end)
            b.BackgroundColor3 = (i == sel) and Color3.fromRGB(40, 150, 90) or Color3.fromRGB(65, 39, 105)
        end
    end
    self = function()
        shared.DiiMergeHeader = header
        sections[sel].fn()
    end
    return self
end

Inv.tpSpecTab = makeMergedTab({
    {name = "📍  Teleport Pemain", fn = teleportTab},
    {name = "◉  Spectator", fn = spectatorTab},
})
Inv.antiMenuTab = makeMergedTab({
    {name = "🛡  Anti Lag / Crash", fn = antiLagTab},
    {name = "🛡  Anti AFK / Kick / Mic", fn = Inv.antiTab},
})
Inv.alatTab = makeMergedTab({
    {name = "🌊  Jalan di Air", fn = Inv.waterTab},
    {name = "🔒  Shift Lock", fn = Inv.shiftLockTab},
})

Inv.newEmoteTab = makeMergedTab({
    {name = "🕺  Roda Emote (DiiEmote)", fn = Inv.diiEmoteLauncher},
    {name = "🏃  Animasi (Idle / Walk / Run / dll)", fn = Inv.animTab},
})

-- CREATE TABS
shared.DiiMergeHeader = nil -- buang sisa header dari eksekusi sebelumnya
makeTab("⌂  Home", homeTab)
makeTab("☀  Graphics", graphicsTab)
makeTab("📍  TP,SPEC", Inv.tpSpecTab)
makeTab("🏠  Teleport Tempat", Inv.teleportTab)
makeTab("👻  Invisible", Inv.tab)
makeTab("💎  Limited Items", limitedItemTab)
makeTab("◎  Free Cam", freeCamTab)
makeTab("🎬  Cinematic Cam", Inv.cinemaTab)
makeTab("🕊  Fly / NoClip / Speed / Tornado", Inv.movementTab)
makeTab("🛠  Alat", Inv.alatTab)
makeTab("💥  Fling", Inv.flingTab)
makeTab("🎯  Target", Inv.targetTab)
makeTab("🛡  Menu Anti", Inv.antiMenuTab)
makeTab("🛒  Grobak", cartTab)
makeTab("🎯  Tempel", tempelTab)
makeTab("👤  Salin Avatar", avatarTab)
makeTab("🪙  Coin Hutan", coinHutanTab)
makeTab("🎭  Emote", Inv.emoteTab)
makeTab("🏃  Animasi", Inv.animTab)
makeTab("🕺  New Animation and Emote", Inv.newEmoteTab)
makeTab("🎵  Musik", Inv.musicTab)
makeTab("🌐  Server", Inv.serverTab)
makeTab("💾  Auto Save", Inv.saveTab)

-- AUTO SAVE: pulihkan pengaturan terakhir setelah karakter siap
task.spawn(function()
    local PS = shared.DiiUiPersist
    if not (PS and PS.Data.enabled and PS.CanSave) then return end
    local t = 0
    while not (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")) and t < 15 do
        task.wait(0.3)
        t = t + 0.3
    end
    task.wait(0.8)
    local prev = ActiveTab
    -- render tab-tab pengaturan sekali supaya semua toggle/slider terdaftar, lalu terapkan nilai tersimpan
    for _, fn in ipairs({Inv.shiftLockTab, Inv.movementTab, antiLagTab, Inv.antiTab, tempelTab, Inv.waterTab}) do
        if fn then
            ActiveTab = fn
            pcall(fn)
        end
    end
    pcall(PS.Replay)
    ActiveTab = prev or homeTab
    pcall(ActiveTab)
    if PS.Data.preset then
        pcall(preset, PS.Data.preset)
    end
    pcall(Inv.RestoreAnim)
end)

homeTab()

print("DiiUi HUB V3.9 loaded successfully!")
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification",
        {Title = "DiiUi HUB", Text = "V3.9 berhasil dimuat ✨", Duration = 5})
end)

end, function(e)
    return debug.traceback(tostring(e), 2)
end)

if not __DiiUiOk then
    warn("[DiiUi HUB] ERROR SAAT LOAD:\n" .. tostring(__DiiUiErr))
    pcall(function()
        local exec = "unknown"
        pcall(function() exec = (identifyexecutor and select(1, identifyexecutor())) or "unknown" end)
        local sg = Instance.new("ScreenGui")
        sg.Name = "DiiUiHUBError"
        sg.ResetOnSpawn = false
        local parent
        pcall(function() parent = (gethui and gethui()) or game:GetService("CoreGui") end)
        if not parent then parent = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui") end
        sg.Parent = parent
        local box = Instance.new("TextLabel")
        box.Size = UDim2.new(0.9, 0, 0, 150)
        box.Position = UDim2.new(0.05, 0, 0.05, 0)
        box.BackgroundColor3 = Color3.fromRGB(40, 10, 20)
        box.TextColor3 = Color3.fromRGB(255, 220, 230)
        box.TextWrapped = true
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.TextYAlignment = Enum.TextYAlignment.Top
        box.Font = Enum.Font.Code
        box.TextSize = 13
        box.Text = "DiiUi HUB gagal load (executor: " .. tostring(exec) .. ")\n" .. string.sub(tostring(__DiiUiErr), 1, 600)
        box.Parent = sg
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
        task.delay(30, function() sg:Destroy() end)
    end)
end
