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
class Partition

  # @fstype: Filesystem type of the partition, currently supported FS types are Ext3,Ext4,NTFS,FAT32
  # Size: Size of the partition/Unallocated(free) space in kilobytes(KB)
  # mountpoint: Location in the file system where the partition is mounted
  # used: Used space of the partition in kilobytes(KB)
  # available: Available free space in the partition in kilobytes(KB)
  # type: One of the types in @@types Hash
  # kname: Kernal name, name given by linux kernal (i.e. sda1, hda1 etc..)
  attr_reader  :fstype,:label,:size, :mountpoint, :used, :available, :type
  attr_accessor :kname

  # @@types Globally accessible Hash constant holds the type of partitions which are supported by disk-wizard
  # TODO: bit masking can be used to, make the values more machine friendly (i.e. {primary: 0, logical: 1, ....})
  @@types = {primary: 'primary', logical: 'logical', extended: 'extended', free: 'free'}
  cattr_reader :types

  # partition: Hash value which having keys defined in Partition class attr_*
  def initialize partition
    partition.each do |key,value|
      instance_variable_set("@#{key}", value) unless value.nil?
    end
  end

  # `@disk` is a Disk object
  # Partition has_one Disk
  def disk
    @disk ||= get_disk
    return @disk
  end

  # Remove the partition from device/disk
  def delete
    #TODO: remove fstab entry if disk is permanently mounted
    unmount if mountpoint
    Diskwz.delete_partition self
  end

  # Absolute path to filesystem representation of devices your system understands
  def path
    return "/dev/#{@kname}"
  end

  # Mount the partition with the given label, if no label is given kname will be used as default label
  def mount label
    label ||= self.kname
    mount_point = File.join "/var/hda/files/drives/", label
    Diskwz.mount mount_point, self
  end

  # Unmount the partition
  def unmount
    Diskwz.umount self
  end

  # Format the partition to given file system type
  def format fstype
      Diskwz.format self, fstype
  end

  def format_job params_hash
    Disk.progress = 10
    unmount if mountpoint
    new_fstype = params_hash[:fs_type]
    format new_fstype
    Disk.progress = 40
    return true
  end

  def mount_job params_hash
    Disk.progress = 60
    mount params_hash['label']
    Disk.progress = 80
  end

  # Number after that signifies the partition on the device(i.e. /dev/sda9 means the ninth partition on the first drive.)
  # Return partition number as an integer value
  def partition_number
    partition_number_string = self.kname.match(/[0-9]*$/)
    return partition_number_string[0].to_i
  end

  private

  # Return the `Disk` object of which this Partition belongs to
  def get_disk
    #Strip partition number
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:@Kname = #{@kname}"
    disk_kname = @kname.gsub(/[0-9]/, "")
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Disk_kname = #{disk_kname}"
    disk = Disk.find disk_kname
    return disk
  end
end
