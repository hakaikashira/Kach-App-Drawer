local index = 1
local hovered = 0
local apps = {}
local visible = 5
local maxApps = 64

local priorities = {}
local usage = {}

------------------------------------------------------------
-- Helpers
------------------------------------------------------------

local function n(name, default)

    local v = SKIN:GetVariable(name)
    local x = tonumber(v)

    if x == nil then
        return default
    end

    return x

end

local function clamp(v, lo, hi)

    if v < lo then return lo end
    if v > hi then return hi end

    return v

end

local function trim(s)

    if not s then
        return ''
    end

    return s:match('^%s*(.-)%s*$') or ''

end

------------------------------------------------------------
-- Load Apps.inc
------------------------------------------------------------

local function loadApps()

    apps = {}

    local root =
        SKIN:GetVariable('@')

    if not root then
        return
    end

    local path =
        root .. 'Data\\Apps.inc'

    local f =
        io.open(path, 'r')

    if not f then
        return
    end

    for line in f:lines() do

        local idx, value

        ----------------------------------------------------
        -- Name
        ----------------------------------------------------

        idx, value =
            line:match(
                '^App(%d+)Name=(.*)$'
            )

        if idx then

            idx = tonumber(idx)

            apps[idx] =
                apps[idx] or {}

            apps[idx].Name =
                value

        end

        ----------------------------------------------------
        -- Path
        ----------------------------------------------------

        idx, value =
            line:match(
                '^App(%d+)Path=(.*)$'
            )

        if idx then

            idx = tonumber(idx)

            apps[idx] =
                apps[idx] or {}

            apps[idx].Path =
                value

        end

        ----------------------------------------------------
        -- Type
        ----------------------------------------------------

        idx, value =
            line:match(
                '^App(%d+)Type=(.*)$'
            )

        if idx then

            idx = tonumber(idx)

            apps[idx] =
                apps[idx] or {}

            apps[idx].Type =
                value

        end

        ----------------------------------------------------
        -- Icon
        ----------------------------------------------------

        idx, value =
            line:match(
                '^App(%d+)Icon=(.*)$'
            )

        if idx then

            idx = tonumber(idx)

            apps[idx] =
                apps[idx] or {}

            apps[idx].Icon =
                value

        end

        ----------------------------------------------------
        -- Desktop flag
        ----------------------------------------------------

        idx, value =
            line:match(
                '^App(%d+)Desktop=(.*)$'
            )

        if idx then

            idx = tonumber(idx)

            apps[idx] =
                apps[idx] or {}

            apps[idx].Desktop =
                tonumber(value) or 0

        end

    end

    f:close()

end

------------------------------------------------------------
-- Load AppPriority.inc
------------------------------------------------------------

local function loadPriorities()

    priorities = {}

    local root =
        SKIN:GetVariable('@')

    if not root then
        return
    end

    local path =
        root .. 'Data\\AppPriority.inc'

    local f =
        io.open(path, 'r')

    if not f then
        return
    end

    for line in f:lines() do

        local name, score =
            line:match(
                '^([^=]+)=(%-?%d+)%s*$'
            )

        if name and score then

            name =
                trim(name)

            score =
                tonumber(score) or 0

            if name ~= '' then

                priorities[
                    name:lower()
                ] = score

            end

        end

    end

    f:close()

end

------------------------------------------------------------
-- Automatically add newly discovered apps
-- to AppPriority.inc
------------------------------------------------------------

local function ensurePriorityFile()

    local root =
        SKIN:GetVariable('@')

    if not root then
        return
    end

    local path =
        root .. 'Data\\AppPriority.inc'

    local existing = {}
    local lines = {}

    local f =
        io.open(path, 'r')

    if f then

        for line in f:lines() do

            table.insert(
                lines,
                line
            )

            local name, score =
                line:match(
                    '^([^=]+)=(%-?%d+)%s*$'
                )

            if name and score then

                existing[
                    trim(name):lower()
                ] = true

            end

        end

        f:close()

    else

        lines = {
            '[Priority]'
        }

    end

    --------------------------------------------------------
    -- Ensure header
    --------------------------------------------------------

    local hasHeader = false

    for _, line in ipairs(lines) do

        if trim(line):lower() == '[priority]' then

            hasHeader = true
            break

        end

    end

    if not hasHeader then

        table.insert(
            lines,
            1,
            '[Priority]'
        )

    end

    --------------------------------------------------------
    -- Find missing apps
    --------------------------------------------------------

    local missing = {}

    for _, app in pairs(apps) do

        if app.Name and app.Path then

            local name =
                trim(app.Name)

            if name ~= '' then

                local key =
                    name:lower()

                if not existing[key] then

                    table.insert(
                        missing,
                        name
                    )

                    existing[key] = true

                end

            end

        end

    end

    table.sort(
        missing,
        function(a, b)
            return a:lower() < b:lower()
        end
    )

    --------------------------------------------------------
    -- Append new applications
    --------------------------------------------------------

    if #missing == 0 then
        return
    end

    local lastLine =
        lines[#lines]

    if lastLine and trim(lastLine) ~= '' then
        table.insert(lines, '')
    end

    for _, name in ipairs(missing) do

        table.insert(
            lines,
            name .. '=0'
        )

    end

    --------------------------------------------------------
    -- Save
    --------------------------------------------------------

    f =
        io.open(path, 'w')

    if not f then
        return
    end

    for _, line in ipairs(lines) do
        f:write(line .. '\n')
    end

    f:close()

end

------------------------------------------------------------
-- Load Usage.inc
------------------------------------------------------------

local function loadUsage()

    usage = {}

    local root =
        SKIN:GetVariable('@')

    if not root then
        return
    end

    local path =
        root .. 'Data\\Usage.inc'

    local f =
        io.open(path, 'r')

    if not f then
        return
    end

    for line in f:lines() do

        local name, count =
            line:match(
                '^([^=]+)=(%d+)%s*$'
            )

        if name and count then

            name =
                trim(name)

            count =
                tonumber(count) or 0

            if name ~= '' then

                usage[
                    name:lower()
                ] = count

            end

        end

    end

    f:close()

end

------------------------------------------------------------
-- Save Usage.inc
------------------------------------------------------------

local function saveUsage()

    local root =
        SKIN:GetVariable('@')

    if not root then
        return
    end

    local path =
        root .. 'Data\\Usage.inc'

    local entries = {}

    for name, count in pairs(usage) do

        table.insert(
            entries,
            {
                name = name,
                count = count
            }
        )

    end

    table.sort(
        entries,
        function(a, b)
            return a.name < b.name
        end
    )

    local f =
        io.open(path, 'w')

    if not f then
        return
    end

    f:write('[Usage]\n')

    for _, entry in ipairs(entries) do

        f:write(
            entry.name ..
            '=' ..
            tostring(entry.count) ..
            '\n'
        )

    end

    f:close()

end

------------------------------------------------------------
-- Get manual priority
------------------------------------------------------------

local function getPriority(app)

    if not app or not app.Name then
        return 0
    end

    return priorities[
        app.Name:lower()
    ] or 0

end

------------------------------------------------------------
-- Get usage
------------------------------------------------------------

local function getUsage(app)

    if not app or not app.Name then
        return 0
    end

    return usage[
        app.Name:lower()
    ] or 0

end

------------------------------------------------------------
-- Get desktop bonus
------------------------------------------------------------

local function getDesktopBonus(app)

    if not app then
        return 0
    end

    if tonumber(app.Desktop) == 1 then

        return n(
            'DesktopBonus',
            100
        )

    end

    return 0

end

------------------------------------------------------------
-- Calculate final score
------------------------------------------------------------

local function getScore(app)

    local priority =
        getPriority(app)

    local count =
        getUsage(app)

    local desktop =
        getDesktopBonus(app)

    return
        priority +
        count +
        desktop

end

------------------------------------------------------------
-- Sort applications
------------------------------------------------------------

local function sortApps()

    local sorted = {}

    for _, app in pairs(apps) do

        if app.Name and app.Path then

            table.insert(
                sorted,
                app
            )

        end

    end

    table.sort(
        sorted,
        function(a, b)

            local scoreA =
                getScore(a)

            local scoreB =
                getScore(b)

            if scoreA ~= scoreB then

                return scoreA > scoreB

            end

            ------------------------------------------------
            -- Same score:
            -- desktop apps first
            ------------------------------------------------

            local desktopA =
                tonumber(a.Desktop) or 0

            local desktopB =
                tonumber(b.Desktop) or 0

            if desktopA ~= desktopB then

                return desktopA > desktopB

            end

            ------------------------------------------------
            -- Final tie breaker: alphabetical
            ------------------------------------------------

            local nameA =
                (a.Name or ''):lower()

            local nameB =
                (b.Name or ''):lower()

            return nameA < nameB

        end
    )

    apps = {}

    for i, app in ipairs(sorted) do

        apps[i] =
            app

    end

end

------------------------------------------------------------
-- Count apps
------------------------------------------------------------

local function appCount()

    local count = 0

    for i, app in pairs(apps) do

        if app.Name and app.Path then

            count =
                math.max(
                    count,
                    i
                )

        end

    end

    return count

end

------------------------------------------------------------
-- Rainmeter helpers
------------------------------------------------------------

local function setMeter(
    name,
    option,
    value
)

    SKIN:Bang(
        '!SetOption',
        name,
        option,
        value
    )

end

local function updateMeter(name)

    SKIN:Bang(
        '!UpdateMeter',
        name
    )

end

------------------------------------------------------------
-- Initialize
------------------------------------------------------------

function Initialize()

    visible =
        n(
            'VisibleApps',
            5
        )

    index = 1
    hovered = 0

    loadApps()

    ensurePriorityFile()

    loadPriorities()
    loadUsage()

    sortApps()

    UpdateDrawer()

end

------------------------------------------------------------
-- Reload applications
------------------------------------------------------------

function ReloadApps()

    loadApps()

    ensurePriorityFile()

    loadPriorities()
    loadUsage()

    sortApps()

    index = 1
    hovered = 0

    UpdateDrawer()

end

------------------------------------------------------------
-- Update
------------------------------------------------------------

function Update()
end

------------------------------------------------------------
-- Draw drawer
------------------------------------------------------------

function UpdateDrawer()

    visible =
        n(
            'VisibleApps',
            5
        )

    maxApps =
        math.floor(
            clamp(
                n('MaxApps', 64),
                1,
                64
            )
        )

    -- VisibleApps is user-configurable, but it can never
    -- exceed the number of physical Rainmeter icon slots
    -- provided by AppDrawer.ini.
    visible =
        math.floor(
            clamp(
                visible,
                1,
                maxApps
            )
        )

    local total =
        appCount()

    local maxIndex =
        math.max(
            1,
            total - visible + 1
        )

    index =
        clamp(
            index,
            1,
            maxIndex
        )

    local icon =
        n(
            'IconSize',
            36
        )

    local gap =
        n(
            'IconGap',
            14
        )

    local width =
        n(
            'DrawerWidth',
            72
        )

    local normalAlpha =
        n(
            'NormalAlpha',
            105
        )

    local cornerRadius =
        n(
            'CornerRadius',
            18
        )

    -- Calculate the drawer height from VisibleApps.
    -- This removes the need for a manually maintained
    -- DrawerHeight variable.
    local drawerHeight =
        20 +
        (visible * icon) +
        ((visible - 1) * gap)

    --------------------------------------------------------
    -- Resize the glass background
    --------------------------------------------------------

    local shape =
        'Rectangle 0,0,' ..
        tostring(width) .. ',' ..
        tostring(drawerHeight) .. ',' ..
        tostring(cornerRadius) ..
        ' | Fill Color 18,18,22,46 | StrokeWidth 1 | Stroke Color 255,255,255,32'

    setMeter(
        'MeterGlass',
        'Shape',
        shape
    )

    updateMeter('MeterGlass')

    setMeter(
        'MeterHint',
        'Y',
        tostring(drawerHeight - 20)
    )

    updateMeter('MeterHint')

    --------------------------------------------------------
    -- Draw every available slot.
    -- Slots above VisibleApps are explicitly hidden so
    -- changing VisibleApps downward never leaves stale icons.
    --------------------------------------------------------

    for slot = 1, maxApps do

        local meter =
            'MeterIcon' ..
            tostring(slot)

        if slot <= visible then

            local appIndex =
                index + slot - 1

            local y =
                10 +
                (slot - 1) *
                (icon + gap)

            local size =
                icon

            local x =
                math.floor(
                    (width - icon) / 2
                )

            local alpha =
                normalAlpha

            local app =
                apps[appIndex]

            if app and app.Path then

                setMeter(
                    meter,
                    'ImageName',
                    app.Icon or
                    '#@#Icons\\placeholder.png'
                )

                setMeter(
                    meter,
                    'ToolTipText',
                    app.Name or ''
                )

                setMeter(
                    meter,
                    'Hidden',
                    '0'
                )

                setMeter(
                    meter,
                    'LeftMouseUpAction',
                    '[!CommandMeasure MeasureScript "Launch(' ..
                    tostring(slot) ..
                    ')"]'
                )

            else

                setMeter(
                    meter,
                    'Hidden',
                    '1'
                )

                setMeter(
                    meter,
                    'ToolTipText',
                    ''
                )

                setMeter(
                    meter,
                    'LeftMouseUpAction',
                    ''
                )

            end

            ----------------------------------------------------
            -- Hover
            ----------------------------------------------------

            if hovered == slot and app then

                size =
                    n(
                        'IconHoverSize',
                        44
                    )

                x =
                    math.floor(
                        (width - size) / 2
                    )

                y =
                    y -
                    math.floor(
                        (size - icon) / 2
                    )

                alpha =
                    n(
                        'HoverAlpha',
                        255
                    )

            end

            setMeter(
                meter,
                'X',
                tostring(x)
            )

            setMeter(
                meter,
                'Y',
                tostring(y)
            )

            setMeter(
                meter,
                'W',
                tostring(size)
            )

            setMeter(
                meter,
                'H',
                tostring(size)
            )

            setMeter(
                meter,
                'ImageAlpha',
                tostring(alpha)
            )

            updateMeter(meter)

        else

            -- Hide and collapse unused slots. Collapsing them
            -- also prevents DynamicWindowSize from reserving
            -- space for all MaxApps slots.
            setMeter(meter, 'Hidden', '1')
            setMeter(meter, 'X', '0')
            setMeter(meter, 'Y', '0')
            setMeter(meter, 'W', '1')
            setMeter(meter, 'H', '1')
            setMeter(meter, 'ToolTipText', '')
            setMeter(meter, 'LeftMouseUpAction', '')
            updateMeter(meter)

        end

    end

    --------------------------------------------------------
    -- Label
    --------------------------------------------------------

    local labelMeter =
        'MeterLabel'

    if
        n('ShowLabels', 0) == 1
        and hovered > 0
        and apps[index + hovered - 1]
    then

        local app =
            apps[index + hovered - 1]

        setMeter(
            labelMeter,
            'Text',
            app.Name or ''
        )

        setMeter(
            labelMeter,
            'Y',
            tostring(
                10 +
                (hovered - 1) *
                (icon + gap)
            )
        )

        setMeter(
            labelMeter,
            'Hidden',
            '0'
        )

    else

        setMeter(
            labelMeter,
            'Hidden',
            '1'
        )

    end

    updateMeter(labelMeter)

    SKIN:Bang(
        '!Redraw'
    )

end

------------------------------------------------------------
-- Scroll
------------------------------------------------------------

function Scroll(delta)

    local total =
        appCount()

    visible =
        math.floor(
            clamp(
                n('VisibleApps', 5),
                1,
                n('MaxApps', 64)
            )
        )

    local maxIndex =
        math.max(
            1,
            total - visible + 1
        )

    local old =
        index

    index =
        clamp(
            index +
            (tonumber(delta) or 0),
            1,
            maxIndex
        )

    hovered = 0

    if index ~= old then
        UpdateDrawer()
    end

end

------------------------------------------------------------
-- Hover
------------------------------------------------------------

function Hover(slot)

    hovered =
        tonumber(slot) or 0

    UpdateDrawer()

end

------------------------------------------------------------
-- Leave
------------------------------------------------------------

function Leave(slot)

    if hovered == tonumber(slot) then

        hovered = 0

        UpdateDrawer()

    end

end

------------------------------------------------------------
-- Leave all
------------------------------------------------------------

function LeaveAll()

    hovered = 0

    UpdateDrawer()

end

------------------------------------------------------------
-- Launch application from Windows AppsFolder
------------------------------------------------------------

local function launchAppID(appID)

    if not appID or appID == '' then
        return false
    end

    local ok, result =
        pcall(
            function()

                local shell =
                    luacom.CreateObject('Shell.Application')

                local folder =
                    shell:NameSpace(
                        'shell:::{4234d49b-0245-4df3-b780-3893943456e1}'
                    )

                if not folder then
                    return false
                end

                local items =
                    folder:Items()

                for i = 0, items.Count - 1 do

                    local item =
                        items:Item(i)

                    if item and item.Path == appID then

                        item:InvokeVerb()

                        return true

                    end

                end

                return false

            end
        )

    return ok and result == true

end

------------------------------------------------------------
-- Launch + usage tracking
------------------------------------------------------------

function Launch(slot)

    slot =
        tonumber(slot)

    if not slot then
        return
    end

    local appIndex =
        index + slot - 1

    local app =
        apps[appIndex]

    if not app or not app.Path then
        return
    end

    --------------------------------------------------------
    -- Increase usage
    --------------------------------------------------------

    local key =
        (app.Name or ''):lower()

    usage[key] =
        (usage[key] or 0) + 1

    saveUsage()

    --------------------------------------------------------
    -- Launch application
    --------------------------------------------------------

    if app.Type == 'AppID' then

        launchAppID(
            app.Path
        )

    else

        SKIN:Bang(
            '["' .. app.Path .. '"]'
        )

    end

    --------------------------------------------------------
    -- Re-sort
    --------------------------------------------------------

    sortApps()

    UpdateDrawer()

end

------------------------------------------------------------
-- Refresh apps
------------------------------------------------------------

function RefreshApps()

    SKIN:Bang(
        '!CommandMeasure',
        'MeasureDiscovery',
        'Run'
    )

end
