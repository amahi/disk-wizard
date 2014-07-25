module Operation

  # Remove the partition from device/disk
  def delete
    #TODO: remove fstab entry if disk is permanently mounted
    #unmount if mountpoint
    Diskwz.delete_partition self
  end

  # Mount the partition with the given label, if no label is given kname will be used as default label
  def mount label
    self.reload
    label ||= self.kname
    mount_point = File.join '/var/hda/files/drives/', label
    Diskwz.mount mount_point, self
  end

  # Unmount the partition
  def unmount
    Diskwz.umount self
  end

  # Format the partition to given file system type
  def format fstype
    if not Partition.FilesystemType.has_value?(fstype)
      raise "Unsupported filesystem type #{fstype}"
    end
    Diskwz.format self, fstype
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  def pre_checks_job params_hash
    # TODO: Implement rollback mechanism, if something went wrong bring back the system to original state,where it was before stating DW
    # TODO/Suggestion: Acquire a lock through 'flock()',for the device/partition involved.
    selected_element = Device.find params_hash[:path]
    selected_element.unmount if (selected_element.instance_of? Partition and selected_element.mountpoint)
    multipathd_status = Diskwz.check_service 'multipathd'
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Params_hash #{params_hash}"
    if not multipathd_status[:pid].equal? 0
      Diskwz.stop_service 'multipathd'
    end
  end

  def post_checks_job params_hash
    # TODO: Only revert the changes which was done by DW itself.
    multipathd_status = Diskwz.check_service 'multipathd'
    if multipathd_status[:pid].equal? 0
      Diskwz.start_service 'multipathd'
    end
  end


  # Absolute path to filesystem representation of devices your system understands
  def path
    # Get path by UUID
    return Diskwz.get_path self
  end

  # Reload the device/partition attribute from system.
  def reload
    dev_path = "/dev/#{self.kname}"
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Device Kname #{self.kname}"
    Diskwz.probe_kernal dev_path
    node = Diskwz.find dev_path
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
      data_hash = Diskwz.all_devices node
      if data_hash['type'].eql? 'part'
        return Partition.new data_hash
      else
        return Device.new data_hash
      end
    end
  end
end
