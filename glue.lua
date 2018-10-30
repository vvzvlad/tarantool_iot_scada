#!/usr/bin/env tarantool
local inspect = require 'libs/inspect'
local box = box

local scripts = require 'scripts'

local http_system = require 'http_system'
local scripts_drivers = require 'scripts_drivers' --TODO: переименовать в соотвествии с официальной семантикой
local scripts_webevents = require 'scripts_webevents'
local scripts_busevents = require 'scripts_busevents'
local scripts_timerevents = require 'scripts_timerevents'
local scripts_sheduleevents = require 'scripts_sheduleevents'

local bus = require 'bus'
local system = require "system"
local logger = require "logger"
local config = require 'config'
local backup_restore = require 'backup_restore'
local settings = require 'settings'

local function box_config()
   local tarantool_bin_port = tonumber(os.getenv('TARANTOOL_BIN_PORT'))

   box.cfg {
      listen = tarantool_bin_port,
      log_level = 4,
      memtx_dir = config.dir.DATABASE,
      vinyl_dir = config.dir.DATABASE,
      wal_dir = config.dir.DATABASE,
      log = "pipe: ./http_pipe_logger.lua"
   }

   if (tarantool_bin_port ~= nil) then
      print("Tarantool server runned on "..tarantool_bin_port.." port")
   end

   box.schema.user.grant('guest', 'read,write,execute', 'universe', nil, {if_not_exists = true})
end

system.dir_check(config.dir.DATABASE)
system.dir_check(config.dir.BACKUP)
system.dir_check(config.dir.DUMP_FILES)
box_config()

logger.storage_init()
local msg_reboot = "GLUE, "..system.git_version()..", tarantool "..require('tarantool').version
logger.add_entry(logger.REBOOT, "------------", msg_reboot, nil, "Tarantool pid "..require('tarantool').pid())

http_system.init(os.getenv('HTTP_PORT'))
logger.http_init()
logger.add_entry(logger.INFO, "System", "HTTP subsystem initialized")

require('system_webevent').init()

settings.init()
logger.add_entry(logger.INFO, "System", "Settings database initialized")

bus.init()
logger.add_entry(logger.INFO, "System", "Bus and FIFO worker initialized")

logger.add_entry(logger.INFO, "System", "Starting script subsystem...")
scripts.init()

if (tonumber(os.getenv('GLUE_SAFEMODE')) == 1 and tonumber(os.getenv('TARANTOOL_CONSOLE')) ~= 1) then
   scripts.safe_mode_error_all()
else
   logger.add_entry(logger.INFO, "System", "Starting web-events...")
   scripts_webevents.init()

   logger.add_entry(logger.INFO, "System", "Starting bus-events...")
   scripts_busevents.init()

   logger.add_entry(logger.INFO, "System", "Starting timer-events...")
   scripts_timerevents.init()

   logger.add_entry(logger.INFO, "System", "Starting shedule-events...")
   scripts_sheduleevents.init()

   logger.add_entry(logger.INFO, "System", "Starting drivers...")
   scripts_drivers.init()
end


backup_restore.init()
backup_restore.create_backup("Backup after start")
logger.add_entry(logger.INFO, "System", "Backup created")
backup_restore.remove_old_files()

logger.add_entry(logger.INFO, "System", "System started")

if (tonumber(os.getenv('TARANTOOL_CONSOLE')) == 1) then
   logger.add_entry(logger.INFO, "System", "Console active")
    if pcall(require('console').start) then
        os.exit(0)
    end
end
