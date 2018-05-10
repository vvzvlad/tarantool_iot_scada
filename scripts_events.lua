#!/usr/bin/env tarantool
local log = require 'log'
local ts_storage = require 'ts_storage'
local logger = require 'logger'
local system = require "system"

local scripts_events = {}
scripts_events.types = {HTTP = 1, TOPIC = 2}

scripts_events.vaisala_event = {}
scripts_events.vaisala_event.type = scripts_events.types.TOPIC
scripts_events.vaisala_event.topic = "/vaisala/H2S"
function scripts_events.vaisala_event.event_function(topic, value)
   --local bus = require 'bus'
   --bus.update_value(topic.."_x100", value*100)
end


scripts_events.mqtt_events = {}
scripts_events.mqtt_events.type = scripts_events.types.HTTP
scripts_events.mqtt_events.endpoint = "/action"
scripts_events.mqtt_events.name = "mqtt_events"
scripts_events.mqtt_events.event_function = function(req) --обернуть в универсальную функицю, подумать
   local params = req:param()
   local mqtt_local = require 'mqtt'
   local config_local = require 'config'


   if (params["action"] ~= nil) then
      local result, emessage
      --print(require('inspect')(params["action"]))
      local mqtt_object = mqtt_local.new(config_local.MQTT_WIRENBOARD_ID.."_action_driver", true)
      mqtt_object:connect({host=config_local.MQTT_WIRENBOARD_HOST,port=config_local.MQTT_WIRENBOARD_PORT,keepalive=60,log_mask=mqtt_local.LOG_ALL})

      if (params["action"] == "on_light_1") then
         result, emessage = mqtt_object:publish("/devices/noolite_tx_0x290/controls/state/on", "1", mqtt_local.QOS_1, mqtt_local.NON_RETAIN)
      elseif (params["action"] == "off_light_1") then
         result, emessage = mqtt_object:publish("/devices/noolite_tx_0x290/controls/state/on", "0", mqtt_local.QOS_1, mqtt_local.NON_RETAIN)
      elseif (params["action"] == "on_light_2") then
         result, emessage = mqtt_object:publish("/devices/noolite_tx_0x291/controls/state/on", "1", mqtt_local.QOS_1, mqtt_local.NON_RETAIN)
      elseif (params["action"] == "off_light_2") then
         result, emessage = mqtt_object:publish("/devices/noolite_tx_0x291/controls/state/on", "0", mqtt_local.QOS_1, mqtt_local.NON_RETAIN)
      elseif (params["action"] == "on_ac") then
         result, emessage = mqtt_object:publish("/devices/wb-mr6c_105/controls/K4/on", "1", mqtt_local.QOS_1, mqtt_local.NON_RETAIN)
      elseif (params["action"] == "off_ac") then
         result, emessage = mqtt_object:publish("/devices/wb-mr6c_105/controls/K4/on", "0", mqtt_local.QOS_1, mqtt_local.NON_RETAIN)
      elseif (params["action"] == "on_fan") then
         result, emessage = mqtt_object:publish("/devices/wb-mr6c_105/controls/K5/on", "1", mqtt_local.QOS_1, mqtt_local.NON_RETAIN)
      elseif (params["action"] == "off_fan") then
         result, emessage = mqtt_object:publish("/devices/wb-mr6c_105/controls/K5/on", "0", mqtt_local.QOS_1, mqtt_local.NON_RETAIN)
      elseif (params["action"] == "tarantool_stop") then
         os.exit()
      elseif (params["action"] == "wipe_storage") then
         result, emessage = os.execute("rm -rf ./db/*")
         os.exit()
      end
      log.info("Action: "..tostring(result).."/"..(emessage or "nil"))
      return req:render{ json = { result = result } }
   end
end


scripts_events.test_http_event = {}
scripts_events.test_http_event.type = scripts_events.types.HTTP
scripts_events.test_http_event.endpoint = "/action2"
scripts_events.test_http_event.name = "test_http_event"
scripts_events.test_http_event.event_function = function(req)
   local func_name = scripts_events.test_http_event.name
   local inspect = require 'inspect'
   local params = req:param()
   logger.add_entry(logger.INFO, func_name, inspect(params))
end


scripts_events.tarantool_web_graph = {}
scripts_events.tarantool_web_graph.type = scripts_events.types.HTTP
scripts_events.tarantool_web_graph.endpoint = "/tarantool-data"
scripts_events.tarantool_web_graph.name = "tarantool_web_graph"
scripts_events.tarantool_web_graph.event_function = function(req)
   local params = req:param()
   local data_object, i = {}, 0
   local table = ts_storage.object.index.primary:select(nil, {iterator = 'REQ'})
   table = system.reverse_table(table)

   for _, tuple in pairs(table) do
      local topic = tuple[2]
      local date = os.date("%Y-%m-%d, %H:%M:%S", tuple[3])
      local value = tuple[4]

      if (params["item"] == "ratios") then
         if (topic == "/tarantool/arena_used_ratio" or topic == "/tarantool/quota_used_ratio") then
            i = i + 1
            data_object[i] = {}
            data_object[i].date = date
            data_object[i][topic] = tonumber(value)
         end
      elseif (params["item"] == "mem") then
         if (topic == "/tarantool/arena_size" or topic == "/tarantool/arena_used") then
            i = i + 1
            data_object[i] = {}
            data_object[i].date = date
            data_object[i][topic] = tonumber(value)
         end
      elseif (params["item"] == "tscount") then
         if (topic == "/tarantool/ts_storage_count") then
            i = i + 1
            data_object[i] = {}
            data_object[i].date = date
            data_object[i][topic] = tonumber(value)
         end
      end
      if (params["limit"] ~= nil and params["limit"] <= i) then break end
   end
   return req:render{ json = data_object }
end


scripts_events.vaisala_web_graph = {}
scripts_events.vaisala_web_graph.type = scripts_events.types.HTTP
scripts_events.vaisala_web_graph.endpoint = "/vaisala-data"
scripts_events.vaisala_web_graph.name = "vaisala_web_graph"
scripts_events.vaisala_web_graph.event_function = function(req)
   local type_item, type_limit = req:param("item"), tonumber(req:param("limit"))
   local data_object, i = {}, 0
   local raw_table = ts_storage.object.index.primary:select(nil, {iterator = 'REQ'})
   local table = system.reverse_table(raw_table)

   for _, tuple in pairs(table) do
      local serialNumber = tuple[5]
      local date = os.date("%Y-%m-%d, %H:%M:%S", tuple[3])
      local value = tuple[4]

      if (type_item == "PM") then
         if (serialNumber == "PM25" or serialNumber == "PM10") then
            i = i + 1
            data_object[i] = {}
            data_object[i].date = date
            data_object[i][serialNumber] = tonumber(value)
         end
      end
      if (type_item == "PA") then
         if (serialNumber == "PAa" or serialNumber == "PAw") then
            i = i + 1
            data_object[i] = {}
            data_object[i].date = date
            data_object[i][serialNumber] = tonumber(value)
         end
      end
      if (type_item == "RH") then
         if (serialNumber == "RHa" or serialNumber == "RHw") then
            i = i + 1
            data_object[i] = {}
            data_object[i].date = date
            data_object[i][serialNumber] = tonumber(value)
         end
      end
      if (type_item == "T") then
         if (serialNumber == "Ta" or serialNumber == "Tw") then
            i = i + 1
            data_object[i] = {}
            data_object[i].date = date
            data_object[i][serialNumber] = tonumber(value)
         end
      end
      if (type_item == "Sall") then
         if (serialNumber == "SO2" or serialNumber == "NO2" or serialNumber == "CO" or serialNumber == "H2S") then
            i = i + 1
            data_object[i] = {}
            data_object[i].date = date
            data_object[i][serialNumber] = tonumber(value)
         end
      end
      if (type_limit ~= nil and type_limit <= i) then break end
   end
   return req:render{ json = data_object }
end

return scripts_events
