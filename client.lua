-- Las RPM se estiman a partir de la velocidad y la marcha del vehiculo.
local CFG = {
    command = 'nfsu2', -- Comando para activar/desactivar el velocimetro.
    width = 360,
    marginRight = 24,
    marginBottom = 24,
    maxRPM = 10000
}

local LAYOUT = {
    width = 400,
    height = 330,
    mainX = 252,
    mainY = 188,
    boostX = 88,
    boostY = 260,
    boostSize = 110,
    nosOffsetX = -8,
    nosSize = 348,
    nosBackgroundAlpha = 210,
    nosPivotX = 130,
    nosPivotY = 129 -- Eje del arco dentro de la imagen de 256x256.
}

local textures, shaders = {}, {}
local enabled = true -- Cada jugador empieza con el velocimetro activado.
local ready = false
local renderAttached = false
local updateRenderState
local currentVehicle, rpm, nitro, boost = nil, 0, 0, 0
local lastTick = getTickCount()
local white = tocolor(240, 245, 242)
local cyan = tocolor(0, 191, 240)
local red = tocolor(218, 76, 79)

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function smooth(value, target, rate, dt)
    return value + (target - value) * (1 - math.exp(-rate * dt))
end

local function reset()
    currentVehicle, rpm, nitro, boost = nil, 0, 0, 0
end

local function render()

    local now = getTickCount()
    local dt = clamp((now - lastTick) / 1000, 0, 0.1)
    lastTick = now
    local vehicle = getPedOccupiedVehicle(localPlayer)

    if not vehicle or isPedDead(localPlayer) then
        updateRenderState()
        return
    end

    if isPlayerMapVisible() then
        reset()
        return
    end

    local vx, vy, vz = getElementVelocity(vehicle)
    local speed = math.sqrt(vx * vx + vy * vy + vz * vz) * 180
    local gear = getVehicleCurrentGear(vehicle) or 0
    local rawHealth = getElementHealth(vehicle)
    local health = clamp((rawHealth - 250) / 750, 0, 1)
    local engine = getVehicleEngineState(vehicle) and rawHealth > 0
    local level = getVehicleNitroLevel(vehicle)
    local hasNitro = type(level) == 'number'
    level = hasNitro and clamp(level, 0, 1) or 0
    local targetRPM = engine and clamp(speed / math.max(gear, 1) * 155, 850, CFG.maxRPM - 200) or 0
    if vehicle ~= currentVehicle then
        currentVehicle, rpm, nitro, boost = vehicle, targetRPM, level, 0
    end
    rpm = smooth(rpm, targetRPM, 10, dt)
    nitro = hasNitro and smooth(nitro, level, 12, dt) or 0

    local matrix = getElementMatrix(vehicle)
    local forwardSpeed = matrix and (vx * matrix[2][1] + vy * matrix[2][2] + vz * matrix[2][3]) * 180 or 0
    local reverse = forwardSpeed < -0.9
    local driver = getVehicleController(vehicle)
    local accelerating = driver and getPedControlState(driver, 'accelerate')
    local targetBoost = 0
    if engine then
        if reverse then
            targetBoost = -clamp(-forwardSpeed / 30, 0.25, 1)
        elseif accelerating then
            targetBoost = 1
        end
    end
    boost = smooth(boost, targetBoost, targetBoost == 0 and 3 or 1.2, dt)
    local gearText = reverse and 'R' or (speed < 1 and 'N' or tostring(gear))

    local sw, sh = guiGetScreenSize()
    local screenScale = math.min(sw / 1920, sh / 1080)
    local scale = math.min(CFG.width / LAYOUT.width * screenScale, (sw - 16) / LAYOUT.width, (sh - 16) / LAYOUT.height)
    local x = sw - CFG.marginRight * screenScale - LAYOUT.width * scale
    local y = sh - CFG.marginBottom * screenScale - LAYOUT.height * scale
    local cx, cy = LAYOUT.mainX, LAYOUT.mainY
    local bx, by, boostSize = LAYOUT.boostX, LAYOUT.boostY, LAYOUT.boostSize

    local function image(name, px, py, w, h, tint, rotation, pivotX, pivotY)
        dxDrawImage(x + px * scale, y + py * scale, w * scale, h * scale, textures[name], rotation or 0, (pivotX or 0) * scale, (pivotY or 0) * scale, tint or white)
    end

    local function text(value, px, py, w, h, size, tint)
        dxDrawText(value, x + px * scale, y + py * scale, x + (px + w) * scale, y + (py + h) * scale, tint or white, size * scale, 'default', 'right', 'center')
    end

    local function arc(radius, startAngle, sweep, width, tint)
        local count = math.max(1, math.ceil(math.abs(sweep) / 3))
        local prevX, prevY
        for i = 0, count do
            local angle = math.rad(startAngle + sweep * i / count)
            local px = x + (cx + math.sin(angle) * radius) * scale
            local py = y + (cy - math.cos(angle) * radius) * scale
            if prevX then
                dxDrawLine(prevX, prevY, px, py, tint, width * scale)
            end
            prevX, prevY = px, py
        end
    end

    local function fill(name, px, py, w, h, amount, tint)
        if amount <= 0.0002 then
            return
        end
        if isElement(shaders[name]) then
            dxSetShaderValue(shaders[name], 'gLevel', amount)
            dxDrawImage(x + px * scale, y + py * scale, w * scale, h * scale, shaders[name], 0, 0, 0, tint)
        elseif name == 'nos-filled' then
            dxDrawImageSection(x + px * scale, y + py * scale, w * amount * scale, h * scale, 0, 0, 256 * amount, 256, textures[name], 0, 0, 0, tint)
        elseif name == 'speedbreak-background' then
            arc(46, -176, 226 * amount, 25, tint)
        elseif name == 'tach-redline' then
            arc(116, -20, 62, 8, tint)
        end
    end

    local dialBackground = tocolor(8, 15, 22, 235)
    dxDrawCircle(x + cx * scale, y + cy * scale, 123 * scale, 0, 360, dialBackground, dialBackground, 64)
    image('tach-background', cx - 128, cy - 128, 256, 256)
    fill('tach-redline', cx - 128, cy - 128, 256, 256, 1, red)
    local nosSize = LAYOUT.nosSize
    local nosX = cx + LAYOUT.nosOffsetX - LAYOUT.nosPivotX * nosSize / 256
    local nosY = cy - LAYOUT.nosPivotY * nosSize / 256
    image('nos-background', nosX, nosY, nosSize, nosSize, tocolor(255, 255, 255, LAYOUT.nosBackgroundAlpha))
    fill('nos-filled', nosX, nosY, nosSize, nosSize, nitro, cyan)
    image('speedbreak-background', cx - 128, cy - 128, 256, 256, tocolor(102, 114, 113, 75))
    local healthColor = health <= 0.3 and tocolor(225, 69, 60, 185) or (health <= 0.6 and tocolor(229, 169, 45, 170) or tocolor(24, 148, 43, 170))
    fill('speedbreak-background', cx - 128, cy - 128, 256, 256, health, healthColor)
    image('tach-numbers', cx - 128, cy - 128, 256, 256)

    dxDrawCircle(x + bx * scale, y + by * scale, (boostSize / 2 - 2) * scale, 0, 360, dialBackground, dialBackground, 48)
    image('boost-background', bx - boostSize / 2, by - boostSize / 2, boostSize, boostSize)
    image('boost-numbers', bx - boostSize / 2, by - boostSize / 2, boostSize, boostSize)
    local boostAngle = boost >= 0 and boost * 140 or boost * 90
    local boostNeedleScale, tachNeedleScale = 0.32 * boostSize / 128, 0.65
    image('boost-arrow', bx - 224 * boostNeedleScale, by - 64 * boostNeedleScale, 256 * boostNeedleScale, 128 * boostNeedleScale, white, boostAngle, 96 * boostNeedleScale, 0)
    image('tach-arrow', cx - 204 * tachNeedleScale, cy - 64 * tachNeedleScale, 256 * tachNeedleScale, 128 * tachNeedleScale, white, -90 + 220 * rpm / CFG.maxRPM, 76 * tachNeedleScale, 0)

    text(gearText, cx + 60, cy - 39, 34, 32, 2.05)
    text(tostring(clamp(math.floor(speed + 0.5), 0, 999)), cx - 13, cy + 3, 112, 52, 3.3)
    text('KM/H', cx + 31, cy + 48, 60, 22, 1.3)
    if engine and rpm >= 8500 and now % 600 < 400 then
        image('shift', cx + 55, cy - 30, 10, 10, red)
    end
end

local function detachRender()
    if renderAttached then
        removeEventHandler('onClientRender', root, render)
        renderAttached = false
    end
    reset()
end

updateRenderState = function()
    local active = ready and enabled and not isPedDead(localPlayer) and isElement(getPedOccupiedVehicle(localPlayer))
    if not active then
        detachRender()
    elseif not renderAttached then
        lastTick = getTickCount()
        addEventHandler('onClientRender', root, render)
        renderAttached = true
    end
end

addCommandHandler(CFG.command, function()
    enabled = not enabled
    updateRenderState()
    outputChatBox('[NFSU2_Speedo] Velocimetro ' .. (enabled and 'activado.' or 'desactivado.'), 0, 191, 240)
end)
addEventHandler('onClientPlayerVehicleEnter', localPlayer, updateRenderState, false)
addEventHandler('onClientPlayerVehicleExit', localPlayer, detachRender, false)
addEventHandler('onClientPlayerWasted', localPlayer, detachRender, false)
addEventHandler('onClientPlayerSpawn', localPlayer, updateRenderState, false)

addEventHandler('onClientResourceStart', resourceRoot, function()
    ready = true
    for _, name in ipairs({'boost-arrow', 'boost-background', 'boost-numbers', 'nos-background', 'nos-filled', 'shift', 'speedbreak-background', 'tach-arrow', 'tach-background', 'tach-numbers', 'tach-redline'}) do
        textures[name] = dxCreateTexture('img/' .. name .. '.png', 'argb', true, 'clamp')
        if not isElement(textures[name]) then
            ready = false
            outputDebugString('[NFSU2_Speedo] No se pudo cargar img/' .. name .. '.png', 1)
        end
    end
    for name, angles in pairs({
        ['nos-filled'] = {-92, 156},
        ['speedbreak-background'] = {-176, 226},
        ['tach-redline'] = {-20, 62}
    }) do
        shaders[name] = dxCreateShader('radial_fill.fx')
        if isElement(shaders[name]) then
            dxSetShaderValue(shaders[name], 'gTexture', textures[name])
            dxSetShaderValue(shaders[name], 'gStartAngle', math.rad(angles[1]))
            dxSetShaderValue(shaders[name], 'gSweepAngle', math.rad(angles[2]))
            local nos = name == 'nos-filled'
            dxSetShaderValue(shaders[name], 'gPivot', nos and LAYOUT.nosPivotX / 256 or 0.5, nos and LAYOUT.nosPivotY / 256 or 0.5)
            dxSetShaderValue(shaders[name], 'gFullTextureAtMax', name == 'tach-redline' and 0 or 1)
        else
            outputDebugString('[NFSU2_Speedo] Shader radial no disponible; usando dibujo alternativo.', 2)
        end
    end
    updateRenderState()
end)

addEventHandler('onClientResourceStop', resourceRoot, function()
    detachRender()
    for _, elements in ipairs({shaders, textures}) do
        for _, element in pairs(elements) do
            if isElement(element) then
                destroyElement(element)
            end
        end
    end
end)
