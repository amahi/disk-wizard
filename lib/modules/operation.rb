module Operation
  DRIVE_MOUNT_ROOT = "/var/hda/files/drives"
  # Remove the partition from device/disk
  def delete
    #TODO: remove fstab entry if disk is permanently mounted
    #unmount if mountpoint
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Delete #{self.path}"
    DiskUtils.delete_partition self
  end

  # Mount the partition with the given label, if no label is given kname will be used as default label
  def mount label
    # TODO: Check if there is any device mounted with same mount_point
    self.reload
    label ||= self.kname
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:mount partition with label #{label} it's mountpoint is #{self.mountpoint}"
    self.label_partition label
    mount_point = File.join DRIVE_MOUNT_ROOT, label
    DiskUtils.mount mount_point, self
  end

  # Unmount the partition
  def unmount
    DiskUtils.umount self
  end

  # Add label to partition
  def label_partition label
    raise "Cannot add label to a #{self.class.name} device" unless instance_of? Partition
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Add '#{label}' label to #{self.kname} partition"
    DiskUtils.label_partition self.kname, label
  end

  # Format the partition to given file system type
  def format fstype
    if not Partition.FilesystemType.has_value?(fstype)
      raise "Unsupported filesystem type #{fstype}"
    end
    DiskUtils.format self, fstype
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  def pre_checks_job params_hash
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Params_hash #{params_hash}"
    # TODO: Implement rollback mechanism, if something went wrong bring back the system to original state,where it was before stating DW
    # TODO/Suggestion: Acquire a lock through 'flock()',for the device/partition involved.
    selected_element = Device.find params_hash[:path]
    if selected_element.instance_of? Partition
      #umount if the partition is mounted
      if selected_element.mountpoint
        selected_element.unmount
        DebugLogger.info "|#{self.class.name}|>|#{__method__}|:umount partition from #{@mountpoint}"
      end
    else
      #unmount all device partitions
      #TODO: determind if the operation need to umount all partitions or not
      selected_element.partitions.each do|partition|
        if partition.mountpoint
          DebugLogger.info "|#{self.class.name}|>|#{__method__}|: unmount partion dev/#{partition.kname}"
          partition.unmount
        end
      end
    end
    DiskUtils.clear_multipath
  end

  def create_new_partition_job params_hash
    device = Device.find params_hash[:path]
    raise "We don't support GPT yet" if device.partition_table != "msdos"
    raise "We don't support extended partitions yet, The number of partitions >= 3" if device.partition_count > 2
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Params_hash #{params_hash}"

    device = Device.find_with_unallocated params_hash[:path]
    partition = device.partitions.select { |part| part.identifier == params_hash[:identifier] }.first
    partition_divider = params_hash[:partition_divider].to_i
    raise "Unknown partition size" unless [1, 2, 4].include? partition_divider

    # calculate the position of the end sector
    new_end_sector = partition.start_sector.to_i + ( (partition.end_sector.to_i - partition.start_sector.to_i) / partition_divider)
    partition_size =  {start_sector: partition.start_sector, end_sector: new_end_sector}
    partition = device.create_partition partition_size
    filesystem = {fs_type: params_hash[:fs_type].to_i || 3 }
    partition.format_job filesystem
  end

  def delete_partition_job params_hash
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Params_hash #{params_hash}"
    if self.instance_of? Partition
      partition = self
    else
      self.partition.each do |part|
        partition = part if part.path = params_hash['partition']
      end
      unless partition
         partition = Device.find params_hash['partition']
      end
    end
    partition.unmount if partition.mountpoint
    partition.delete
  end

  def post_checks_job params_hash
    # TODO: Only revert the changes which was done by DW itself.
  end


  # Absolute path to filesystem representation of devices your system understands
  def path
    # Get path by UUID
    return DiskUtils.get_path self
  end

  # Reload the device/partition attribute from system.
  def reload
    dev_path = "/dev/#{self.kname}"
    if self.instance_of? Device
      DiskUtils.probe_kernal dev_path
    else
      #TODO: Reloading a partitions, hdparm need its parent device path in -z option.no the path of the partition itself (man hdparm)
      DiskUtils.probe_kernal
    end
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Device Kname #{self.kname}"
    node = (Device.find dev_path).as_json
    if node['type'].eql? 'part'
      node.each do |key, value|
        instance_variable_set("@#{key}", value) unless value.nil?
      end
    else
      node.each do |key, value|
        if key.eql? 'partitions' and value
          @partitions = []
          for partition in value
            @partitions.push Partition.new partition
          end
          next
        end
        instance_variable_set("@#{key}", value) unless value.nil?
      end
    end

  end

  module ClassMethods
    def find node
      data_hash = DiskUtils.all_devices node
      if data_hash['type'].eql? 'part'
        return Partition.new data_hash
      else
        return Device.new data_hash
      end
    end
  end
end
