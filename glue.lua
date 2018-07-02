#!/usr/bin/env tarantool
local inspect = require 'libs/inspect'
local box = box

local scripts = require 'scripts'

local http_system = require 'http_system'
local scripts_drivers = require 'scripts_drivers'
local scripts_webevents = require 'scripts_webevents'
local bus = require 'bus'
local system = require "system"
local logger = require "logger"
local config = require 'config'
local backup_restore = require 'backup_restore'


local function box_config()
   box.cfg { listen = 3313, log_level = 4, memtx_dir = config.dir.DATABASE, vinyl_dir = config.dir.DATABASE, wal_dir = config.dir.DATABASE, log = "pipe: ./http_pipe_logger.lua" }
   box.schema.user.grant('guest', 'read,write,execute', 'universe', nil, {if_not_exists = true})
end


system.dir_check(config.dir.DATABASE)
box_config()

logger.init()
logger.add_entry(logger.INFO, "Main system", "-----------------------------------------------------------------------")
logger.add_entry(logger.INFO, "Main system", "GLUE System, "..system.git_version()..", tarantool version "..require('tarantool').version..", pid "..require('tarantool').pid())

http_system.init_server()
http_system.init_client()
logger.http_init()
logger.add_entry(logger.INFO, "Main system", "HTTP subsystem initialized")


bus.init()
logger.add_entry(logger.INFO, "Main system", "Common bus and FIFO worker initialized")


logger.add_entry(logger.INFO, "Main system", "Starting script system...")
scripts.init()
scripts.start()

--logger.add_entry(logger.INFO, "Main system", "Configuring web-events...")
--scripts_webevents.init()
--scripts_webevents.init()

--logger.add_entry(logger.INFO, "Main system", "Starting drivers...")
--scripts_drivers.init()
--scripts_drivers.start()


backup_restore.create_backup()
backup_restore.remove_old_files()
logger.add_entry(logger.INFO, "Main system", "Backup created")


logger.add_entry(logger.INFO, "Main system", "System started")

if tonumber(os.getenv('TARANTOOL_CONSOLE')) == 1 then
   logger.add_entry(logger.INFO, "Main system", "Console active")
    if pcall(require('console').start) then
        os.exit(0)
    end
end
