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


class Parted
  
  def initialize disk
    puts "DEBUG:********** initialize Parted disk =  #{disk}"
    if disk =~ /(\/\w+\/).+/
      @kname = disk.split('/')[-1]
    else
      @kname = disk
    end
    @path = Disk.path @kname
    puts "DEBUG:********** initialize Parted path =  #{@path}"
  end

  def partition_table
    puts "DEBUG:************************* partition_table = #{@path}"
    command = "parted --script #{@path} print"
    puts "DEBUG:************************* partition_table.command = #{command}"
    result = disk_command command
    puts "DEBUG:************************* partition_table.result = #{result}"
    result.each_line do |line|
      if line.strip =~ /^Error:/
        puts "DEBUG:************no disk line = #{line}"
        return false
      elsif line.strip =~ /^Partition Table:/
        #TODO: Need to test for all the types of partition tables
        table_type = line.match(/^Partition Table:(.*)/i).captures[0].strip
        puts "DEBUG:************line#{table_type}"
        return table_type
      end
    end
  end
  
  def format fs_type
    #Creating new filesystem also format the partition with new FS type
    return self.create_fs fs_type
  end
  
  def create_partition_table type = 'msdos'
    command = "parted --script #{@path} mklabel #{type}"
    puts "DEBUG:************************************ create_partition_table.command = #{command}"
    result = disk_command command
    result.each_line do |line|
      if line.strip =~ /^Error:/
        puts "DEBUG:************no disk line#{line}"
        return false
      end
    end
    return true
  end
  
  def create_fs fs_type
    partition_table = self.partition_table
    unless partition_table
      self.create_partition_table
      command = "parted -s -a optimal #{@path} mkpart primary 1 -- -1"
      disk_command(command)
      @kname = @kname + 1.to_s
      @path = "/dev/#{@kname}"
    end

    #can't use parted 'mkfs' command because after version 2.4, the following commands were removed: check, cp, mkfs, mkpartfs, move, resize
    fs_type = "vfat" if fs_type == "fat32"
    command = "mkfs.#{fs_type} -q -F #{@path}" #-F parameter to ignore warning and -q for quiet execution
    puts "DEBUG:************************************ create_fs.command = #{command}"
    blocking = true
    #TODO: Validation befor executing command , since none-blocking call returns nil result
    result = disk_command(command , !blocking) # none-blocking call ,since formatting would take quit long time
    puts "DEBUG:************************************ check for blank result result.blank?= #{result.blank?}"
    puts "DEBUG:************************************ print result = #{result}"
    return @kname if result.blank? # if everything went well result should be blank (in mkfs.* -q quite mode)
    return false
  end
  
  private

  def disk_command command, blocking = true
    #forward the result(stdio and stderror) to temp file default location for temp file is /var/hda/tmp
    puts "DEBUG:****************** disk_command.command = #{command} blocking = #{blocking}"
    if blocking # default mode is blocking call, because other commands down the line depend on the result of the previous command(i.e. format after partitioning)
      puts "DEBUG:****************** disk_command.full command => #{command} > /tmp/disk_wizard.tmp 2>&1"
      Command.new("#{command} > /tmp/disk_wizard.tmp 2>&1").run_now #.execute is kind of none-blocking call and  run_now is a blocking call
      #TODO: Close opend file,rescue on no file, clear the file after reading to prevent dirty reads
      result = File.open("/tmp/disk_wizard.tmp", "r").read
      puts "DEBUG:************************************* result = #{result}"
    else
      puts "DEBUG:####### checkup disk_command.else "
      Command.new("#{command} > /tmp/disk_wizard.tmp 2>&1").execute
      result = nil
    end
    puts "DEBUG:************************************* result = #{result}"
    return result
  end
      
end