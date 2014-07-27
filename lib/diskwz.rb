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
class Diskwz
  class << self
    DEBUG_MODE = true #TODO: Allow dynamically set value
    # Return an array of all the attached devices, including hard disks,flash/removable/external devices etc.
    # If search is given only search for the given path.
    def all_devices search = nil
      partitions = []
      devices = []
      device = nil
      has_extended = false
      if DEBUG_MODE or Platform.ubuntu? or Platform.fedora?
        command = "lsblk"
        params = " #{search} -b -P -o VENDOR,MODEL,TYPE,SIZE,KNAME,UUID,LABEL,MOUNTPOINT,FSTYPE,RM"
      end
      lsblk = DiskCommand.new command, params
      lsblk.execute
      raise "Command execution error: #{lsblk.stderr.read}" if not lsblk.success?

      lsblk.result.each_line do |line|
        data_hash = {}
        line.squish!
        line_data = line.gsub!(/"(.*?)"/, '\1#').split "#"
        line_data.each do |data|
          data.strip!
          key, value = data.split "="
          data_hash[key.downcase] = value
        end
        data_hash['rm'] = data_hash['rm'].to_i # rm = 1 if device is a removable/flash device, otherwise 0
        if data_hash['type'] == 'mpath'
          data_hash.except!('uuid', 'label', 'mountpoint', 'fstype')
          if device
            multipath_info = {'mkname' => data_hash['kname'], 'multipath' => true, 'size' => data_hash['size']}
            device.merge! multipath_info
          else
            data_hash['multipath'] = true
            device = data_hash
            devices.push device
          end
          next
        end
        if data_hash['type'] == 'disk'
          data_hash.except!('uuid', 'label', 'mountpoint', 'fstype')
          unless device.nil?
            device['partitions'] = partitions
            partitions = []
            devices.push device
            device = nil # cleanup the variable
          end
          device = data_hash
          next
        end
        if data_hash['type'] == 'part'
          data_hash.except!('model', 'vendor')
          data_hash.merge! self.usage data_hash['kname']

          partition_number = get_partition_number "/dev/#{data_hash['kname']}" # For reference: data_hash['kname'].match(/[0-9]*$/)[0].to_i
          extended_partition_types = ['0x05'.hex, '0x0F'.hex]
          if partition_type_hex(data_hash['kname']).in? extended_partition_types
            has_extended = true
            next
          end
          if has_extended and partition_number > 4
            data_hash['logical'] = true
          end
          # device['partitions'].nil? ? device['partitions'] = [data_hash] : device['partitions'].push(data_hash)
          partitions.push(data_hash)
        end
      end
      device['partitions'] = partitions if device
      devices.push device
      if search
        return devices.first || partitions.first
      else
        return devices
      end
    end

    # TODO: move to private methods section
    def partition_type_hex kname
      # Return Hex value of the partition type.Reliable compared to pure tex comparison.
      # Reference: https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/5/html/Installation_Guide/ch-partitions-x86.html#tb-partitions-types-x86
      if DEBUG_MODE or Platform.ubuntu? or Platform.fedora?
        command = "udevadm"
        params = " info  --query=property --name=#{kname}"
      end
      udevadm = DiskCommand.new command, params
      udevadm.execute false, false # None blocking and not debug mode
      raise "Command execution error: #{udevadm.stderr.read}" if not udevadm.success?
      udevadm.result.each_line do |line|
        line.squish!
        key = 'ID_PART_ENTRY_TYPE'
        _key, value = line.split '='
        return value.hex if _key.eql? key
      end
    end

    def usage disk
      kname = get_kname disk
      if DEBUG_MODE or Platform.ubuntu? or Platform.fedora?
        command = "df"
        params = "--block-size=1 /dev/#{kname}"
      end

      df = DiskCommand.new command, params
      df.execute false, false # None blocking and not debug mode
      raise "Command execution error: #{df.stderr.read}" if not df.success?
      line = df.result.lines.pop
      line.gsub!(/"/, '')
      df_data = line.split(" ")
      return {'used' => df_data[2].to_i, 'available' => df_data[3].to_i}
    end

    # Deprecated only for reference
    def find path
      # TODO: Not a reliable way of identifying a partition, use OOP kind_of 'Partition' or 'Device' method instead
      partition = path =~ /[0-9]\z/ ? true : false
      if DEBUG_MODE or Platform.ubuntu? or Platform.fedora?
        command = "lsblk"
        params = "#{path} -bPo VENDOR,MODEL,TYPE,SIZE,KNAME,UUID,LABEL,MOUNTPOINT,FSTYPE,RM"
      end
      lsblk = DiskCommand.new command, params
      lsblk.execute
      raise "Command execution error: #{lsblk.stderr.read}" if not lsblk.success?
      if lsblk.success == -1
        disk = {"model" => "N/A", "type" => "disk", "size" => nil, "kname" => "#{path}", "rm" => nil, "partitions" => []}
        partition = {"type" => "part", "size" => nil, "kname" => "#{path}", "uuid" => "N/A", "label" => nil, "mountpoint" => nil, "fstype" => nil, "rm" => nil, "used" => nil, "available" => nil}
        return partition ? partition : disk
      end
      partitions = []
      disk = nil
      has_extended = false
      lsblk.result.each_line do |line|
        data_hash = {}
        line.squish!
        line_data = line.gsub!(/"(.*?)"/, '\1#').split '#'
        for data in line_data
          data.strip!
          key, value = data.split '='
          data_hash[key.downcase] = value
        end
        data_hash['rm'] = data_hash['rm'].to_i
        if data_hash['type'] == 'disk'
          data_hash.except!('uuid', 'label', 'mountpoint', 'fstype')
          disk = data_hash
          next
        end
        if data_hash['type'] == 'mpath'
          multipath_info = {'mkname' => data_hash['kname'], 'multipath' => true}
          if disk
            disk.merge! multipath_info
          else
            disk = multipath_info
          end
          next
        end

        if data_hash['type'] == 'part'
          data_hash.except!('model')
          data_hash.merge! self.usage data_hash['kname']
          partitions.push(data_hash)
        end
      end

      disk['partitions'] = partitions if disk
      partitions = partitions[0] if partition
      return disk || partitions
    end

    def partition_table disk
      kname = get_kname disk
      if DEBUG_MODE or Platform.ubuntu? or Platform.fedora?
        command = "parted"
        params = "-sm /dev/#{kname} unit b  print free" # Use parted machine parseable output,independent from O/S language -s for --script and -m for --machine
      end
      parted = DiskCommand.new command, params
      parted.execute false, false # None blocking and not debug mode
      return false if not parted.success?

      # REFERENCE: http://lists.alioth.debian.org/pipermail/parted-devel/2006-December/000573.html
      # Output format "path":"size":"transport-type":"logical-sector-size":"physical-sector-size":"partition-table-type":"model-name";
      device_info = parted.result.lines[1].squish.split ':' # Remove trailing newline character(s)
      table_type = device_info[5]
      return table_type
    end

    def umount disk
      #un-mounting not guaranteed, remain mounted if device is busy
      kname = get_kname disk
      command = "umount"
      params = " -fl /dev/#{kname}"
      umount = DiskCommand.new command, params
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
      mount = DiskCommand.new command, params
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Mount executing"
      mount.execute
      raise "Command execution error: #{mount.stderr.read}" if not mount.success?
    end

    def format disk, fstype
      case fstype
        when Partition.FilesystemType[:TYPE_EXT4]
          params = " -q #{disk.path}"
          program_name = 'ext4'
        when Partition.FilesystemType[:TYPE_EXT3]
          params = " -q #{disk.path}"
          program_name = 'ext3'
        when Partition.FilesystemType[:TYPE_NTFS]
          params = " -q -f #{disk.path}" # Perform quick (fast) format and -q for quiet execution
          program_name = 'ntfs'
        when Partition.FilesystemType[:TYPE_FAT32]
          params = " #{disk.path}"
          program_name = 'vfat'
        else
          raise "#{fstype} Filesystem type not supported.Please re-try with diffrent filesystem."
      end
      command = "mkfs.#{program_name} "
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Disk.kname = #{disk.kname}, fstype = #{fstype} format params = #{params}"
      mkfs = DiskCommand.new command, params
      mkfs.execute
      raise "Command execution error: #{mkfs.stderr.read}" if not mkfs.success?
    end

    #TODO: Need more testing
    def create_partition device, partition_type = 'primary',start_unit, end_unit
      command = 'parted'
      params = "#{device.path} -s -a optimal unit MB mkpart #{partition_type} ext3 #{start_unit} -- #{end_unit}"
      parted = DiskCommand.new command, params
      parted.execute
      raise "Command execution error: #{parted.stderr.read}" if not parted.success?
      probe_kernal device
    end


    def create_partition_table device, type = 'msdos'
      command = 'parted'
      params = "--script #{device.path} mklabel #{type}"
      parted = DiskCommand.new command, params
      parted.execute
      raise "Command execution error: #{parted.stderr.read}" if not parted.success?
      probe_kernal device #inform the OS of partition table changes
    end

    def delete_partition partition
      raise "#{partition.path} is not a partition" if not partition.is_a? Partition
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:partition.partition_number = #{partition.partition_number} partition.device.path = #{partition.device.path}"
      if partition.logical
        # TODO:  Need to implement this(https://github.com/GNOME/gparted/blob/master/src/OperationDelete.cc#L50-L57) logic in ruby
        # Logical partition numbers change when deleting excising logical partition(s).Need to decrease partition numbers or reload partition table accordingly
        raise "Deleting logical partitions (#{partition.path}) not supported yet!"
      end
      device_path = partition.device.path
      command = 'parted'
      params = "--script #{device_path} rm #{partition.partition_number}"
      parted = DiskCommand.new command, params
      parted.execute
      raise "Command execution error: #{parted.stderr.read}" if not parted.success?
      probe_kernal device_path
    end

    def probe_kernal device_path = nil
      if device_path.instance_of? Partition or device_path.instance_of? Device #TODO: pass only string path value no Partition or Device object
        device_path = device_path.path
      end
      commands = {'partprobe' => '', 'udevadm' => ' trigger'}
      commands['hdparm'] = "trigger -z #{device_path}"  if not device_path.nil? # Do not execute 'hdparm' when device/partition is not given.
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Commands = #{commands}"
      commands.each do |command, args|
        executor = DiskCommand.new(command, args)
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

    def get_path device
      if device.kind_of? Partition and device.try :uuid
        uuid = device.uuid
        params = "-U #{uuid} -c /dev/null"
      else
        kname = device.kname || device.mkname
        # TODO: find path,devices who don't have UUID
        DebugLogger.info "|#{self.class.name}|>|#{__method__}|:device return value(if not object type Partition) = #{kname}"
        return "/dev/#{kname}"
      end
      command = "blkid"
      blkid = DiskCommand.new command, params
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:device = #{device.kname}, uuid = #{device.uuid}, params = #{params}"
      blkid.execute
      raise "Command execution error: #{blkid.stderr.read}" if not blkid.success?
      return blkid.result.lines.first.squish!
    end

    # Return parent path which can be used with Device.find method to find the device hash
    def get_parent child_path
      parent_maj_min = nil
      if DEBUG_MODE or Platform.ubuntu? or Platform.fedora?
        command = "udevadm"
        params = " info  --query=property --name=#{child_path}"
      end
      udevadm = DiskCommand.new command, params
      udevadm.execute false, false # None blocking and not debug mode
      raise "Command execution error: #{udevadm.stderr.read}" if not udevadm.success?
      udevadm.result.each_line do |line|
        line.squish!
        key = 'ID_PART_ENTRY_DISK'
        _key, value = line.split '='
        parent_maj_min = value and break if _key.eql? key
      end

      if DEBUG_MODE or Platform.ubuntu? or Platform.fedora?
        command = "lsblk"
        params = " -b -P -o VENDOR,MODEL,TYPE,SIZE,KNAME,UUID,LABEL,MOUNTPOINT,FSTYPE,RM,MAJ:MIN"
      end
      lsblk = DiskCommand.new command, params
      lsblk.execute
      raise "Command execution error: #{lsblk.stderr.read}" if not lsblk.success?
      lsblk.result.each_line do |line|
        data_hash = {}
        line.squish!
        line_data = line.gsub!(/"(.*?)"/, '\1#').split "#"
        line_data.each do |data|
          data.strip!
          key, value = data.split "="
          data_hash[key.downcase] = value
          return data_hash['kname'] if value == parent_maj_min
        end
      end
      raise "Unable to find parent device for #{child_path}"
    end

    #Flush all unused multipath device maps
    def clear_multipath
      #TODO: Check multipathd status
      command = 'multipath'
      params = ' -F'
      multipath = DiskCommand.new command, params
      multipath.execute
      raise "Command execution error: #{multipath.stderr.read}" if not multipath.success?
    end

    def get_partition_number partition_path
      # Get partition number from Udevadmn, instead of getting the last numeric value from kname from regex pattern
      command = "udevadm"
      params = " info  --query=property --name=#{partition_path}"
      udevadm = DiskCommand.new command, params
      udevadm.execute false, false # None blocking and not debug mode
      raise "Command execution error: #{udevadm.stderr.read}" if not udevadm.success?
      udevadm.result.each_line do |line|
        line.squish!
        key = 'ID_PART_ENTRY_NUMBER'
        _key, value = line.split '='
        return value.to_i if _key.eql? key
      end
    end
    private

    def get_kname device
      if device.kind_of? Device or device.kind_of? Partition
        kname = device.kname
      else
        kname = device
      end
      return kname
    end

    def create_directory location
      command = "mkdir"
      params = "-p -m 757 #{location}"
      mkdir = DiskCommand.new command, params
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
      systemctl = DiskCommand.new command, params
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
  end
end

