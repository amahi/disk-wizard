#Since no database involvement in the model, data is fetch on the fly by parsing the result of system calls
# inheriting ActiveRecord::Base is not necessary
class Device #< ActiveRecord::Base
  include Operation
  attr_reader :model, :size, :rm, :mkname, :multipath, :vendor
  attr_accessor :kname, :partitions

  def initialize disk
=begin
	std::vector<Partition> partitions ;
	Sector length;
	Sector heads ;
	Sector sectors ;
	Sector cylinders ; Number of cylinder
	Sector cylsize ;# Cylinder size
	Glib::ustring model;
 	Glib::ustring disktype;
	int sector_size ;
	bool readonly ;
=end
    disk.each do |key, value|
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

  def self.all
    # return array of Disk objects
    devices= []
    raw_devices = DiskUtils.all_devices
    for device in raw_devices
      device = Device.new device
      devices.append device
    end
    return devices
  end

  def partition_table
    return DiskUtils.partition_table self
  end

  def removable?
    return self.rm.eql? 1
  end

  def self.mounts
    return PartitionUtils.new.info
  end

  def self.new_disks
    fstab = Fstab.new
    all_devices = Device.all
    unmounted_devices = []
    for device in all_devices
      if device.partitions.blank?
        unmounted_devices.push device
        next
      end
      device.partitions.delete_if { |partition| (fstab.has_device? partition.path or partition.mountpoint) }
      unmounted_devices.push device if not device.partitions.blank?
    end
    return unmounted_devices
  end

  def Device.progress
    current_progress = Setting.find_by_kind_and_name('disk_wizard', 'operation_progress')
    return 0 unless current_progress
    current_progress.value.to_i
  end

  def Device.progress_message(percent)
    case percent
      when 0 then
        "Preparing to partitioning ..."
      when 10 then
        "Looking for partition table ..."
      when 20 then
        "Partition table created ..."
      when 40 then
        "Formating the partition ..."
      when 60 then
        "Creating mount point ..."
      when 80 then
        "Mounting the partition ..."
      when 100 then
        "Disk operations completed."
      when -1 then
        "Fail (check /var/log/amahi-app-installer.log)."
      else
        "Unknown status at #{percent}% ."
    end
  end

  # class methods for retrive information about the disks attached to the HDA

  def Device.progress=(percentage)
    #TODO: if user runs disk_wizard in two browsers concurrently,identifier should set to unique kname of the disk
    current_progress = Setting.find_or_create_by('disk_wizard', 'operation_progress', percentage)
    if percentage.nil?
      current_progress && current_progress.destroy
      return nil
    end
    current_progress.update_attribute(:value, percentage.to_s)
    percentage
  end

  def self.removables
    # return an array of removable (Disk objects) device absolute paths
    DiskUtils.removables
  end

  # Delete all excisting partitions and create one partition from entire device/disk
  def full_format fstype, label = nil
    DebugLogger.info "class = #{self.class.name}, method = #{__method__}"
    delete_all_partitions unless partitions.blank?
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Creating partition #{self.kname}"
    DiskUtils.create_partition self, 1, -1
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Find partition #{@kname}"
    self.reload
    new_partition = self.partitions.last # Assuming new partition to be at the last index
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Formating #{@kname} to #{fstype}"
    new_partition.format fstype and reload
  end

  #TODO: extend to create new partitions on unallocated spaces
  def create_partition(size = nil, type = Partition.PartitionType[:TYPE_PRIMARY])
    DiskUtils.create_partition self, size[:start_block], size[:end_block]
    partitions = Device.find(self).partitions
    return partitions.last
  end

  def create_partition_table
    DiskUtils.create_partition_table self
  end

  def format_job params_hash
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Params_hash #{params_hash}"
    new_fstype = params_hash[:fs_type]
    Device.progress = 10
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Create partition_table #{partition_table}"
    #TODO: check the disk size and pass the relevent partition table type (i.e. if device size >= 3TB create GPT table else MSDOS(MBR))
    create_partition_table unless partition_table
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Full format label #{params_hash[:label]}"
    full_format new_fstype, params_hash[:label]
    Device.progress = 40
  end

  def mount_job params_hash
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Params_hash #{params_hash}"
    Device.progress = 60
    kname = @kname
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:New partition Label #{params_hash[:label]}"
    new_partition = self.partitions.last
    new_partition.mount params_hash[:label]
    Device.progress = 80
  end

  def delete_all_partitions
    for partition in self.partitions
      partition.delete
    end
  end
end
