lath = { --Main object
    updates = {}, --List of updates
    timer = {
        stack = {},
        stackSize = 0,
    },
    rvParse = {
        DELIM = '|',

    },
    persist = {
        CONTROL = 'lathPersist',
        BASE_PATH = 'plugins/lath/persist/',
        EXT = '.lua'
    },
    store = {},
    ltn = {},
    event = {
        events = {},
    },
};


--Grab the Update function.
function Update(dt)
    lath.update(dt); --Provide an update function that happens every tick

    --Handle the variable rate updates
    for _, timerData in ipairs(lath.updates) do
        -- Increment the timer
        timerData.timer = timerData.timer + dt;
        if timerData.timer >= timerData.interval then
            -- Call the associated update function
            timerData.Update(timerData.timer);
            timerData.timer = 0;
        end
    end

    --Handle timer stack
    for name, timerData in pairs(lath.timer.stack) do
        local t = timerData;

        if (t.current < t.target) then
            t.current = t.current + (dt * t.speedMultiplier);
            if ( t.current >= t.target) then
                t.current = t.target;
            end
        else
            t.current = t.current - (dt * t.speedMultiplier);
            if ( t.current <= t.target) then
                t.current = t.target;
            end
        end
        
        (t.updateCallback or stub)(t.current);
        if t.current == t.target then
            (t.completionCallback or stub)(t.current);
            lath.timer.pop(name);
        end
    end
end

--Register an update
function lath.registerUpdate(interval, callback)
    table.insert(lath.updates, { ['Update'] = callback, ['timer'] = 0, ['interval'] = interval} );
end


------------------

--  TIMER SECTION

------------------


--Pushes a timer onto the stack
lath.timer.push = function (name, current, target, speedMultiplier, completionCallback, updateCallback)
    local timer = {
        current = current,
        target = target,
        speedMultiplier = speedMultiplier,
        completionCallback = completionCallback,
        updateCallback = updateCallback,
    }
    lath.timer.stack[name] = timer;
    lath.timer.stackSize = lath.timer.stackSize + 1 
end

--Pop the timer off the stack, return a copy of the timer
lath.timer.pop = function(name)
    local temp = lath.timer.stack[name]
    if temp then
        lath.timer.stack[name] = nil
        lath.timer.stackSize = lath.timer.stackSize - 1
    end
    return temp
end

--This is just a getter, you don't have to use it.
lath.timer.get = function (name)
    return lath.timer.stack[name];
end

--Facade the timer push to provide a simpler timeout function
lath.timer.setTimeout = function (name, timeout, callback, updateCallback)
    lath.timer.push(name, 0, timeout, 1, callback, updateCallback);
end


------------------

--  CLOCK SECTION

------------------

--Allows you to get a formatted version of the current game time (similar in concept to the Date() function in PHP)
lath.Time = function (formatter)
    local timeOfDay = SysCall("ScenarioManager:GetTimeOfDay")
    local hours = math.floor(timeOfDay / 3600)
    local minutes = math.floor(lath.modulo(timeOfDay, 3600) / 60)
    local seconds = lath.modulo(timeOfDay, 60)

    formatter = string.gsub(formatter, "H", string.format("%02d", hours))
    formatter = string.gsub(formatter, "M", string.format("%02d", minutes))
    formatter = string.gsub(formatter, "S", string.format("%02d", seconds))

    return formatter
end


------------------

--  RV NUMBER PARSING SECTION

------------------

--Pulls the RV number and returns a table of the arguments in the RV number
lath.rvParse.parse = function ()
    local inputString = Call('GetRVNumber')
    local result = {}
    local startIdx = 1

    while true do
        --find where the delimiter is
        local delimIdx = string.find(inputString, lath.rvParse.DELIM, startIdx, true)

        if delimIdx then
            --pull this substring and find the equals
            local pair = string.sub(inputString, startIdx, delimIdx - 1)
            local eqIdx = string.find(pair, "=", 1, true)

            --On successful = parse, pull the substrings
            if eqIdx then
                local key = string.sub(pair, 1, eqIdx - 1)
                local value = string.sub(pair, eqIdx + 1)
                --Store and convert to number where possible
                result[key] = tonumber(value) or value
            end
            --Move along le string
            startIdx = delimIdx + 1
        else

            --As above
            local pair = string.sub(inputString, startIdx)
            local eqIdx = string.find(pair, "=", 1, true)

            if eqIdx then
                local key = string.sub(pair, 1, eqIdx - 1)
                local value = string.sub(pair, eqIdx + 1)
                result[key] = tonumber(value) or value
            end

            break
        end
    end
    return result
end


------------------

--  LIBRARY SECTION

------------------

-- replacement for the missing % operator
lath.modulo = function (a, b)
    return a - math.floor(a / b) * b
end

--Stub function used to or functions that may be nil
function stub()
end

------------------

--  STORE PERSIST SECTION

------------------

--Adopt the TS functions and provide an api
function OnSave()
    (lath.onSave or stub)()
    lath.persist.dump()
end

function OnResume()
    (lath.onResume or stub)()
    lath.persist.load()
end

lath.persist.dump = function ()
    ltnString = lath.ltn.stringify(lath.store);
    local filename = os.time()
    file = io.open( lath.persist.BASE_PATH .. filename .. lath.persist.EXT, 'w');
    if (not file) then
        SysCall("ScenarioManager:ShowAlertMessageExt", "Lath Error", 'Failed to open file for writing', 5, 0);
        return
    end
    Call("SetControlValue", lath.persist.CONTROL, 0, filename)
    file:write(ltnString);
    file:close();
end

--Function to load the store from the file as saved
lath.persist.load = function ()
    local filename = Call("GetControlValue", lath.persist.CONTROL, 0)
    file = io.open( lath.persist.BASE_PATH .. filename .. lath.persist.EXT, 'r');
    if (not file) then
        SysCall("ScenarioManager:ShowAlertMessageExt", "Lath Error", 'Failed to open file for reading', 5, 0);
        return
    end
    local readData = file:read("*all");
    file:close();
    local f = loadstring(readData)
    lath.store = f();
end

--Pass in a table to be stringified
function lath.ltn.stringify(tbl)
    local result = {}
    local index = 1  -- To keep track of the current index in the 'result' table

    local function serializeInternal(tbl, indent)
        --Loop through the stuff where we are
        for k, v in pairs(tbl) do
            --Some stuff
            local key = type(k) == "number" and "[" .. k .. "]" or "['" .. tostring(k) .. "']"
            local valueType = type(v)
            
            --Handle types
            if valueType == "table" then
                --Store the thing and recurse for tables
                result[index] = string.rep(" ", indent) .. key .. " = {"
                index = index + 1
                serializeInternal(v, indent + 2)
                result[index] = string.rep(" ", indent) .. "},"
            elseif valueType == "string" then
                result[index] = string.rep(" ", indent) .. key .. " = '" .. v .. "',"
            else
                result[index] = string.rep(" ", indent) .. key .. " = " .. tostring(v) .. ","
            end
            index = index + 1
        end
    end
    
    result[index] = "return {"
    index = index + 1
    serializeInternal(tbl, 2)
    result[index] = "}"
    
    return table.concat(result, "\n") --Join that lot together
end

------------------

--  C TRUTHINESS SECTION

------------------

--Provide a simple C truthiness function
lath.cTruth = function(value)

    map = {
        [0] = true,
        [''] = true
    }
    return not map['value'];
end

------------------

--  OCVC EVENT HANDLER SECTION

------------------

--Register a named event to a control value
lath.event.register = function (control, event, handler)
    if not lath.event.events[control] then
        lath.event.events[control] = {};
    end

    lath.event.events[control][event] = handler;
end

--Deregister an event from a CV
lath.event.deregister = function (control, event)

    lath.event.events[control][event] = nil;

    if (getn(lath.event.events[control]) < 1) then
        lath.event.events[control] = nil;
    end
end

--Deregister all events on a CV
lath.event.deregisterAll = function (control)

    lath.event.events[control] = nil;
end

--Adopted OCVC
function OnControlValueChange(name, index, value)

    Call('SetControlValue', name, index, value);

    if (not lath.event.events[name]) then
        return;
    end

    for k, v in pairs(lath.event.events[name]) do
        v(value, name)
    end
end
