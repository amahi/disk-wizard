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
    def all_devices
      partitions = []
      disks = []
      disk = nil
      if DEBUG_MODE or Platform.ubuntu? or Platform.fedora?
        command = "lsblk"
        params = "-b -P -o MODEL,TYPE,SIZE,KNAME,UUID,LABEL,MOUNTPOINT,FSTYPE,RM"
      end
      lsblk = DiskCommand.new command, params
      lsblk.execute
      raise "Command execution error: #{lsblk.stderr.read}" if not lsblk.success?

      lsblk.result.each_line do |line|
        data_hash = {}
        line.squish!
        line_data = line.gsub!(/"(.*?)"/,'\1,').split ","
        for data in line_data
          data.strip!
          key , value = data.split "="
          data_hash[key.downcase] = value
        end
        data_hash['rm'] = data_hash['rm'].to_i
        if data_hash['type'] == "disk"
          data_hash.except!('uuid','label','mountpoint','fstype')
          unless disk.nil?
            disks.push disk
            disk = nil # cleanup the variable
          end
        disk = data_hash
        next
        end
        if data_hash['type'] == "part"
          data_hash.except!('model')
          data_hash.merge! self.usage data_hash['kname']
          disk["partitions"].nil? ?  disk["partitions"] = [data_hash] : disk["partitions"].push(data_hash)
        end
      end
      disks.push disk
      return disks
    end

    def usage disk
      kname = get_kname disk
      if DEBUG_MODE or Platform.ubuntu? or Platform.fedora?
        command = "df"
        params = "--block-size=1 /dev/#{kname}"
      end

      df = DiskCommand.new command, params
      df.execute
      raise "Command execution error: #{df.stderr.read}" if not df.success?
      line = df.result.lines.pop
      line.gsub!(/"/, '')
      df_data =  line.split(" ")
      return {'used'=> df_data[2].to_i,'available'=> df_data[3].to_i}
    end

    def find kname
      kname =~ /[0-9]\z/ ? partition = true : partition = false
      if DEBUG_MODE or Platform.ubuntu? or Platform.fedora?
        command = "lsblk"
        params = "/dev/#{kname} -bPo MODEL,TYPE,SIZE,KNAME,UUID,LABEL,MOUNTPOINT,FSTYPE,RM"
      end
      #partition
      lsblk = DiskCommand.new command, params
      lsblk.execute
      raise "Command execution error: #{lsblk.stderr.read}" if not lsblk.success?
      partitions = []
      disk = nil
      lsblk.result.each_line do |line|
        data_hash = {}
        line.squish!
        line_data = line.gsub!(/"(.*?)"/,'\1,').split ","
        for data in line_data
          data.strip!
          key , value = data.split "="
          data_hash[key.downcase] = value
        end
        data_hash['rm'] = data_hash['rm'].to_i
        if data_hash['type'] == "disk"
          data_hash.except!('uuid','label','mountpoint','fstype')
        disk = data_hash
        next
        end
        if data_hash['type'] == "part"
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
        params = "--script /dev/#{kname} print"
      end
      parted = DiskCommand.new command,params
      parted.execute
      return false if not parted.success?

      parted.result.each_line do |line|
        if line.strip =~ /^Partition Table:/
          #TODO: Need to test for all the types of partition tables
          table_type = line.match(/^Partition Table:(.*)/i).captures[0].strip
          return table_type
        end    
      end
    end

    def umount disk
      kname = get_kname disk
      command = "umount"
      params = "/dev/#{kname}"
      umount = DiskCommand.new command,params
      umount.execute
      raise "Command execution error: #{umount.stderr.read}" if not umount.success?
    end
    
    def mount mount_point, disk
      fstab = Fstab.new
      fstab.add_fs(disk.path,mount_point,'auto','auto,rw,exec',0,0)
      
      #remount all
      command = "mount"
      params = "#{disk.path} #{mount_point}"
      mount = DiskCommand.new command,params
      mount.execute
      raise "Command execution error: #{mount.stderr.read}" if not mount.success?
    end

    def format disk, fstype
      fstype = "vfat" if fstype == "fat32"
      fstype == "ntfs" ? quick_format = "-f" : quick_format = nil
      command = "mkfs.#{fstype} "
      params = "-q #{quick_format} -F #{disk.path}" #-F parameter to ignore warning and -q for quiet execution
      
      mkfs = DiskCommand.new command, params
      mkfs.execute
      raise "Command execution error: #{mkfs.stderr.read}" if not mkfs.success?
    end
    
    #TODO: For no this method only support new devices
    def create_partition device
      command = 'parted'
      params = "-s -a optimal #{device.path} mkpart primary 1 -- -1"
      parted = DiskCommand.new command, params
      parted.execute
      raise "Command execution error: #{parted.stderr.read}" if not parted.success?
      new_partition_kname = device.kname + "1"
      return new_partition_kname
    end
    
    def create_mount_point mount_point
      command = 'mkdir'
      params = "-p #{mount_point}"
      mkdir = DiskCommand.new command, params
      mkdir.execute
      raise "Command execution error: #{mkdir.stderr.read}" if not mkdir.success?
    end

    def create_partition_table device,type = 'msdos'
      command = 'parted'
      params = "--script #{device.path} mklabel #{type}"
      parted = DiskCommand.new command, params
      parted.execute
      raise "Command execution error: #{parted.stderr.read}" if not parted.success?
    end
    private

    def get_kname disk
      if disk.kind_of? Disk or disk.kind_of? Partition
      kname = disk.kname
      else
      kname = disk
      end
      return kname
    end

  end

end
