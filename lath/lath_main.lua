lath = { --Main object
    updates = {}, --List of updates
    timer = {
        stack = {},
        stackSize = 0,
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

--  LIBRARY SECTION

------------------

lath.modulo = function (a, b)
    return a - math.floor(a / b) * b
end

function stub()
end

