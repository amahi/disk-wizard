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
  attr_reader  :fstype,:size, :mountpoint, :used, :available
  attr_accessor :kname

  def initialize partition
    partition.each do |key,value|
      instance_variable_set("@#{key}", value) unless value.nil?
    end
  end
  
  def disk
    # `@disk` is a Disk object
    # Partition has_one Disk relationship
    @disk ||= get_disk
    return @disk
  end
  
  def path
    return "/dev/#{@kname}"
  end
  
  private
  
  def get_disk
    #Strip partition number
    puts "@kname = #{@kname}"
    disk_kname = @kname.gsub(/[0-9]/, "")
    puts "disk_kname = #{disk_kname}"
    disk = Disk.find disk_kname
    return disk
  end
end