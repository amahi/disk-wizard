class DiskServiceController < ApplicationController
  before_filter :admin_required
  def get_all_devices
    # probe_kernal
    #mounted_disks = Device.mounts
    DiskUtils.probe_kernal
    DiskUtils.clear_multipath
    Kernel.sleep 0.8
    @new_disks = Device.new_disks
  end

  def check_label
    render text: "check_label"
  end
end
