class DiskServiceController < ApplicationController
  before_action :admin_required
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

  # Generate fpaste URL which contains required information to debug an error.
  # Directly calling system tools via open3 library not using CommandExecutor library(Still able to generate debug URL even CommandExecutor library fails).
  def debug_info
    require "open3"
    script_location = "/var/hda/apps/520ut3lo6w/elevated/"
    Open3.popen3("sudo", "./debug_info.sh", :chdir => script_location) { |stdin, stdout, stderr, wait_thr|
      exit_status = wait_thr.value.exitstatus
      if not (exit_status.equal? 0)
        error = stderr.read
        render json: {error: error}
        return false
      end
      result = stdout.read
      valid_url = /https?:\/\/[\S]+/
      url = urls = nil
      result.each_line do |line|
        urls = line.split.grep(valid_url) if line.match valid_url
      end
      url = urls.group_by(&:size).max.last[0] if urls
      render json: {url: url}
    }
  end

  # Return JSON encoded progress message to view layer.
  # This action is used by progress.html.erb to notify user about currently executing operation.
  # From view layer, use pooling method(send AJAX request to here in every 1 second) to fetch the information from backend.
  # TODO: Push data to front-end via a websocket instead of pooling(wast of bandwidth)
  # Use current progress(percentage in Integer) to get the associated progress_message. TODO: change percentage to number of operations(i.e instead of 45% complete, show 4/10 operations completed)
  def operations_progress
    message = Device.progress_message(Device.progress)
    render json: {percentage: Device.progress, message: message}
  end

  # Render progress page when click on apply button in 'confirmation' step
  #  Implicitly send HTTP POST request to process_disk action to start processing the operations
  # Expected key:values in @params:
  #   :debug => Integer value(1) if debug mode has selected in fourth step(confirmation), else nil
  def progress
    debug_mode = params[:debug]
    self.user_selections = {debug: debug_mode}
  end

end
