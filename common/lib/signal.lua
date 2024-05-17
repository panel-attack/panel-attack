local util = require("util")
local logger = require("logger")
local Signal = {}

function Signal.turnIntoEmitter(t)
  t.emitsSignals = true
  t.signalSubscriptions = {}
  t.emitSignal = Signal.emitSignal
  t.createSignal = Signal.createSignal
  t.connectSignal = Signal.connectSignal
  t.disconnectSignal = Signal.disconnectSignal
end

-- adds a signal to the table that can be subscribed to via Signal.connectSignal
function Signal.createSignal(t, signalName)
  if not t.emitsSignals or not t.signalSubscriptions then
    error("Trying to create a signal on a table that is not marked as emitting Signals")
  elseif t[signalName] and not t.signalSubscriptions[signalName] then
    error("Trying to create signal " .. signalName .. ", but the field already exists on the table\n" .. table_to_string(t))
  end

  if t[signalName] and t.signalSubscriptions[signalName] then
    logger.info("Trying to create a signal that already exists")
    -- if we continued here, it would basically clear all existing subscriptions
    return
  end

  -- subscriptions are weakly keyed to make sure that there is no memory leaking from subscribers going out of scope but remaining subscribed somewhere
  t.signalSubscriptions[signalName] = util.getWeaklyKeyedTable()
end

function Signal.emitSignal(emitter, signalName, ...)
  for subscriber, array in pairs(emitter.signalSubscriptions[signalName]) do
    for _, callback in ipairs(array) do
      callback(subscriber, ...)
    end
  end
end

-- connects to a signal so the callback is executed with the data and arguments passed to the signal whenever the signal emits
-- technically you can pass any data for the subscriber argument, but the entry will get immediately garbage collected if the data is not also referenced elsewhere
-- this is to make sure that there is no memory leaking from subscribers going out of scope but remaining subscribed somewhere, implemented via weak tables
function Signal.connectSignal(emitter, signalName, subscriber, callback)
  assert(emitter.emitsSignals and emitter.signalSubscriptions, "trying to connect to a table that does not emit signals")
  assert(emitter.signalSubscriptions[signalName], "trying to connect to undefined signal " .. signalName)

  local t
  if not emitter.signalSubscriptions[signalName][subscriber] then
    emitter.signalSubscriptions[signalName][subscriber] = {}
  end
  t = emitter.signalSubscriptions[signalName][subscriber]
  t[#t+1] = callback
end

-- normally we don't need to actively disconnect from a signal as subscriptions automatically get removed when their subscriber is garbage collected
-- but in some scenarios we may want to actively unsubscribe
 function Signal.disconnectSignal(emitter, signalName, subscriber)
   emitter.signalSubscriptions[signalName][subscriber] = nil
 end

return Signal