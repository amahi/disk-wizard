# Amahi Home Server
# Copyright (C) 2007-2013 Amahi
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License v3
# (29 June 2007), as published in the COPYING file.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# file COPYING for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Amahi
# team at http://www.amahi.org/ under "Contact Us."

require "open3"

# CommandsExecutor class which act as a bridge between system level dsk-wzd.sh bash script and rails
# Named as 'CommandsExecutor' to prevent class name conflicts('Command' library), when intergrating disk-wizard as Amahi plugin app
class CommandsExecutor
  attr_reader :stdin, :stdout, :stderr, :success
  cattr_accessor :operations_log
  # `debug_mode` class variable which hold the current executing mode of the commands,if true, commands will not be executed on the system level instead command(operation) will be loged(in @@operations_log) for future use
  @@debug_mode = false
  # `operations_log` class variable,an array of operations which executed during debug mode (while @@debug_mode flag is up)
  # TODO: write to system log concurrently
  @@operations_log = []

  def self.debug_mode
    return @@debug_mode
  end

  # Set/Re-set @@debug_mode flag,flag should be a boolean value
  def self.debug_mode=(flag)
    # Set `debug_mode` class variable
    @@debug_mode = flag
    #Flush previous debug operation logs,when flag is true(re-enter to debug mode)
    @@operations_log = [] if flag
  end

  def self.operations_log
    return @@operations_log
  end

  # Initialize CommandsExecutor object
  # == Parameters:
  #     command
  #     parameters Default set to `nil` to allow execution of commands, with no arguments i.e. pwd
  def initialize command, parameters = nil
    @command = command
    @parameters = parameters
  end

  # Execute the command with assigned parameters when initializing the object
  # == Parameters:
  #     blocking is true  =~ Command.run_now or blocking is not true  =~ command.execute
  def execute blocking = false, debug = @@debug_mode
    #If user select debug mode
    #1. push current command(command name and parameters) to `operations_log` array, where it will be used to list all the operations took place during the debug mode
    #2. Return from the method immediately,to prevent executing further
    if @@debug_mode
      command = {name: @command, parameters: @parameters}
      @@operations_log.push command
    end

    if debug
      self.success = -1
      return
    end

    root_folder = "/var/hda/apps/520ut3lo6w" #TODO: Replace with plugin.root_folder with bug 1368 fix
    check root_folder
    script_location = File.join(root_folder, "elevated/")
    begin
      if blocking
        Open3.popen3("sudo", "./dsk-wz.sh", @command, @parameters, :chdir => script_location) do |stdin, stdout, stderr, wait_thr|
          @stdout = stdout; @stderr = stderr; @wait_thr = wait_thr
        end
      else
        _, @stdout, @stderr, @wait_thr = Open3.popen3("sudo", "./dsk-wz.sh", @command, @parameters, :chdir => script_location)
      end
    rescue => error
      @success = false
      raise error
    end
    @exit_status = @wait_thr.value.exitstatus
    @pid = @wait_thr.pid
    @result = @stdout.read
    @success = @wait_thr.value.success?
  end

  def success?
    !!(@success)
  end

  def success=(status)
    self.instance_variable_set(:@success, status)
  end

  def result
    return @result
  end

  private

  def check root_folder
    wrapper = File.join(root_folder, "/elevated/dsk-wz.sh")
    raise "Wrapper script does not appear to be available!" unless File.file?(wrapper)
  end

end
