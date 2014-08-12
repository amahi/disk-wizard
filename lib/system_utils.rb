# Amahi Home Server
# Copyright (C) 2007-2011 Amahi
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
class SystemUtils
  class << self
    DEBUG_MODE = true #TODO: Allow dynamically set value

    def umount disk
      #un-mounting not guaranteed, remain mounted if device is busy
      kname = get_kname disk
      command = "umount"
      params = " -fl /dev/#{kname}"
      umount = CommandsExecutor.new command, params
      #TODO: This should be a none-blocking call, until unmount the disk/device successfully, can't proceed with other works
      umount.execute
      raise "Command execution error: #{umount.stderr.read}" if not umount.success?
    end

    def mount mount_point, disk
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Init Fstab disk.path = #{disk.path}"
      fstab = Fstab.new
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Add_fs mount_point #{mount_point}"
      fstab.add_fs(disk.path, mount_point, 'auto', 'auto,rw,exec', 0, 0)
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Create directory mount_point = #{mount_point}"
      create_directory mount_point unless File.directory?(mount_point)

      #remount all
      command = "mount"
      params = "#{disk.path} #{mount_point}"
      mount = CommandsExecutor.new command, params
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Mount executing"
      mount.execute
      raise "Command execution error: #{mount.stderr.read}" if not mount.success?
    end

    def probe_kernal device_path = nil
      if device_path.instance_of? Partition or device_path.instance_of? Device #TODO: pass only string path value no Partition or Device object
        device_path = device_path.path
      end
      commands = {'partprobe' => '', 'udevadm' => ' trigger'}
      commands['hdparm'] = " -z #{device_path}" if not device_path.nil? # Do not execute 'hdparm' when device/partition is not given.
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Commands = #{commands}"
      commands.each do |command, args|
        executor = CommandsExecutor.new(command, args)
        executor.execute()
        DebugLogger.info "Command execution error: #{executor.stderr.read}" if not executor.success? # Suppress warnings and errors,don't re-raise the exception.only do notify the kernel,Warnings and errors are out of the DW scope
      end
    end

    def check_service serive_name
      # TODO: Before starting a service check service availability.
      return systemctl_wrapper serive_name, 'show'
    end

    def start_service serive_name
      systemctl_wrapper serive_name, 'start'
    end

    def stop_service serive_name
      systemctl_wrapper serive_name, 'stop'
    end

    #Flush all unused multipath device maps
    def clear_multipath
      command = 'multipath'
      params = ' -F'
      multipath = CommandsExecutor.new command, params
      if which command
        multipath.execute
        raise "Command execution error: #{multipath.stderr.read}" if not multipath.success?
      else
        return false
      end
    end

    private

    def create_directory location
      command = "mkdir"
      params = "-p -m 757 #{location}"
      mkdir = CommandsExecutor.new command, params
      mkdir.execute
      raise "Command execution error: #{mkdir.stderr.read}" if not mkdir.success?
    end

    def systemctl_wrapper systemd_name, action
      pid = nil
      active = nil
      command = "systemctl"
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:systemd_name = #{systemd_name}, action = #{action}"
      case action
        when 'show'
          params = " --property=Description,MainPID,ActiveState,SubState #{action} #{systemd_name}"
        else
          params = " #{action} #{systemd_name}"
      end
      systemctl = CommandsExecutor.new command, params
      systemctl.execute
      raise "Command execution error: #{systemctl.stderr.read}" if not systemctl.success?
      if action == 'show'
        _, description = systemctl.result.lines[0].squish!.split('=')
        _, active = systemctl.result.lines[1].squish!.split('=')
        _, state = systemctl.result.lines[2].squish!.split('=')
        _, pid = systemctl.result.lines[3].squish!.split('=')
        return {description: description, pid: pid.to_i, active_state: active, state: state}
      end
    end

    #Quick `open3` wrapper for check availability of a system command, shows the full path of (shell) commands.Wrapper for linux 'which' command
    def which command
      require 'open3'
      Open3.popen3("which #{command}") do |stdin, stdout, stderr, wait_thr|
        if wait_thr.value.to_i == 0
          availability = true
        else
          availability = false
        end
        return availability
      end
    end


  end
end

