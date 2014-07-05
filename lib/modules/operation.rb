module Operation

  # Remove the partition from device/disk
  def delete
    #TODO: remove fstab entry if disk is permanently mounted
    unmount if mountpoint
    Diskwz.delete_partition self
  end

  # Mount the partition with the given label, if no label is given kname will be used as default label
  def mount label
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

  module ClassMethods
    def find disk
      data_hash = Diskwz.find disk
      if data_hash['type'].eql? 'part'
        return Partition.new data_hash
      else
        return Device.new data_hash
      end
    end
  end
end