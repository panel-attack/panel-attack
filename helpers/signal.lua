local util = require("util")
local logger = require("logger")
local Signal = {}

function Signal.emitsSignals(t)
  t.emitsSignals = true
  t.signalSubscriptions = {}
end

-- adds a signal to the table that can be subscribed to via Signal.connectSignal
-- if the table already has a function with the signal's name it is replaced and afterwards subscribed to the signal
function Signal.addSignal(t, signalName)
  if t[signalName] then
    if t.emitsSignals and t.signalSubscriptions[signalName] then
      logger.info("Trying to create a signal that already exists")
      return
    else
      error("Trying to create signal " .. signalName .. ", but the field already exists on the table\n" .. table_to_string(t))
    end
  end

  if not t.emitsSignals or not t.signalSubscriptions then
    Signal.emitsSignals(t)
  end

  t.signalSubscriptions[signalName] = {}
  local emissionFunc = function(...)
    for subscriber, callback in pairs(t.signalSubscriptions[signalName]) do
      callback(subscriber, ...)
    end
  end


  -- check for an existing func and save it
  local normalFunc
  if t[signalName] then
    assert(type(t[signalName]) == "function", "Trying to add a signal on a field that is not a function")
    normalFunc = t[signalName]
  end

  -- override it with the emission func
  t[signalName] = emissionFunc

  if normalFunc then
    -- then subscribe it to get executed on emission anyway
    Signal.connectSignal(t, signalName, t, normalFunc)
  end
end

-- connects to a signal so the callback is executed with the data and arguments passed to the signal whenever the signal emits
function Signal.connectSignal(emitter, signalName, subscriber, callback)
  assert(emitter.emitsSignals and emitter.signalSubscriptions, "trying to connect to a table that does not emit signals")
  assert(emitter[signalName], "trying to connect to undefined signal " .. signalName)

  emitter.signalSubscriptions[signalName][subscriber] = callback
end

-- we don't need to actively disconnect from a signal as subscriptions automatically get removed when their subscriber is collected
 function Signal.disconnectSignal(emitter, signalName, subscriber)
   emitter.signalSubscriptions[signalName][subscriber] = nil
 end

return Signal