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

# DiskCommand class which act as a bridge between system level dsk-wzd.sh bash script and rails
# Named as 'DiskCommand' to prevent class name conflicts('Command' library), when intergrating disk-wizard as Amahi plugin app
class DiskCommand
  attr_reader :stdin, :stdout, :stderr
  # Initialize DiskCommand object
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
  def execute blocking = false
    root_folder = "/var/hda/apps/520ut3lo6w" #TODO: Replace with plugin.root_folder with bug 1368 fix
    check root_folder
    script_location = File.join(root_folder,"elevated/")
    begin
      if blocking
        Open3.popen3("sudo","./dsk-wz.sh",@command,@parameters,:chdir=>script_location) {|stdin, stdout, stderr, wait_thr|
          @stdout = stdout ;@stderr = stderr ;@wait_thr = wait_thr
        }
      else
        _, @stdout, @stderr, @wait_thr = Open3.popen3("sudo","./dsk-wz.sh",@command,@parameters,:chdir=>script_location)
      end
    rescue => error
      # Errno::ENOENT: No such file or directory `@command`
      @success = false
      raise error
    end
    @exit_status = @wait_thr.value.exitstatus
    if not(@exit_status.equal? 0 or not @success)
      @success = false
      raise @stderr.read
    end
    @pid = @wait_thr.pid
    @result = @stdout.read
    @success = @wait_thr.value.success?
  end
  
  def success?
    @success
  end
  
  def result
    return @result
  end
  private
  
  def check root_folder
    wrapper = File.join(root_folder,"/elevated/dsk-wz.sh")
    raise "Wrapper script does not appear to be available!" unless File.file?(wrapper)
  end
  
end