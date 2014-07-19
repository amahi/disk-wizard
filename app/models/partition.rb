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
  include Operation

  # @fstype: Filesystem type of the partition, currently supported FS types are Ext3,Ext4,NTFS,FAT32
  # Size: Size of the partition/Unallocated(free) space in kilobytes(KB)
  # mountpoint: Location in the file system where the partition is mounted
  # used: Used space of the partition in kilobytes(KB)
  # available: Available free space in the partition in kilobytes(KB)
  # type: One of the types in @@types Hash
  # kname: Kernal name, name given by linux kernal (i.e. sda1, hda1 etc..)
  attr_reader :fstype, :label, :size, :mountpoint, :used, :available, :type, :uuid
  attr_accessor :kname

  # PartitionType Globally accessible Hash constant holds the type of partitions which are supported by disk-wizard
  def self.PartitionType
    {
        TYPE_PRIMARY: 0,
        TYPE_LOGICAL: 1,
        TYPE_EXTENDED: 2,
        TYPE_UNALLOCATED: 3
    }
  end

  def self.FilesystemType
    {
        TYPE_EXT4: 0,
        TYPE_EXT3: 1,
        TYPE_NTFS: 2,
        TYPE_FAT32: 3,
        TYPE_XFS: 4 #About XFS http://en.wikipedia.org/wiki/XFS
    }
  end

  def self.PartitionAlignment
    {
        ALIGN_CYLINDER: 0, #Align to nearest cylinder
        ALIGN_MEBIBYTE: 1, #Align to nearest mebibyte
        ALIGN_STRICT: 2 #Strict alignment - no rounding
        #Indicator if start and end sectors must remain unchanged
    }
  end

  def self.PartitionStatus
    {
        STAT_REAL: 0,
        STAT_NEW: 1,
        STAT_COPY: 2,
        STAT_FORMATTED: 3
    }
  end

  # partition: Hash value which having keys defined in Partition class attr_*
  def initialize partition
=begin
  #Inpired from Gparted Partition module(https://github.com/GNOME/gparted/blob/master/src/Partition.cc)
	this ->partition_number = partition_number;
	this ->type = type; #(PartitionType) not available
	this ->filesystem = filesystem;
	this ->sector_start = sector_start;#currently not available
	this ->sector_end = sector_end;#currently not available
	this ->sector_size = sector_size;#currently not available
	this ->inside_extended = inside_extended;#currently not available
=end
    partition.each do |key, value|
      instance_variable_set("@#{key}", value) unless value.nil?
    end
  end

  # `@disk` is a Disk object
  # Partition has_one Disk
  def disk
    @disk ||= get_disk
    return @disk
  end

  def format_job params_hash
    Device.progress = 10
    unmount if mountpoint
    new_fstype = params_hash[:fs_type]
    format new_fstype
    Device.progress = 40
    return true
  end

  def mount_job params_hash
    unmount if mountpoint #Unmount from previous mount point
    Device.progress = 60
    mount params_hash[:label]
    Device.progress = 80
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
    path = self.path.gsub(/[0-9]/, "")
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Disk_kname = #{path}"
    disk = Device.find path
    return disk
  end
end
