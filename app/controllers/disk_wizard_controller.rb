class DiskWizardController < ApplicationController
  before_filter :admin_required
  # TODO: Clear mode(debug mode flag) only once at the beginning, not in every action
  before_filter :clear_mode, except: [:process_disk]

  layout 'wizard'

  # @return [Device Array] : Return array of Device objects, which are mounted(permanent or temporary) in the HDA.
  # Render the first step of the Disk-Wizard(DW)
  def select_device
    DebugLogger.info "--disk_wizard_start--"
    @mounted_disks = Device.mounts
  end

  # Expected key:values in @params:
  #   :device => Device path(Device.path) of the selected device from step 1
  # if no device is selected and the request type is HTTP POST, redirect to same step with flash error message
  # (HTTP GET method is used in 'back' event, when select to go back in a step)
  # else find the selected device and render second step of the Disk-Wizard(DW)
  def select_fs
    device = params[:device]
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Device = #{device}"
    if not (device and request.post?)
      redirect_to disk_wizards_engine.select_path, :flash => {:error => "Please select a device to continue."}
      return false
    end
    if request.post?
      self.user_selections = {path: device}
      @selected_disk = Device.find(device)
    else
      @selected_disk = Device.find(user_selections['path'])
    end
  end

  # Expected key:values in @params:
  #   :fs_type => An integer value which mapped to a supported filesystem type in Partition.PartitionType HashMap.
  #   :partition => System path of the selected partition(Device node)
  #   :format => A boolean value, if true selected partition will be formatted in to given filesystem type(fs_type)
  # Render third step of the wizard(options).
  def manage_disk
    format = params[:format]
    partition = params[:partition]
    fs_type = params[:fs_type].to_i
    if (partition and not fs_type)
      redirect_to defined?(disk_wizards_engine) ? disk_wizards_engine.file_system_path : file_system_path, :flash => {:error => "Please select a filesystem type to continue."}
      return false
    end
    if request.post?
      self.user_selections = {fs_type: fs_type, format: format, path: partition}
    end
  end

  # Expected key:values in @params:
  #   :options => An integer value which maps to the type of option, selected in step 3
  #   i.e if mount options is selected , :options value will be 1
  #     TODO: Improve structure of storing 'options' information, instead of simple number mapping
  #     TODO: i.e {mount: {label: 'label_name', mount_point: 'mount_point_name'} ,option2: {data_hash}}
  def confirmation
    option = params[:option]
    label = params[:label].blank? ? nil : params[:label]
    self.user_selections = {option: option, label: label}
    @selected_disk = Device.find(user_selections['path'])
  end

  # An AJAX call is made to this action, from process.html.erb to start processing the queue
  # Create operation queue according to user selections(user_selections), and enqueue operations
  def process_disk
    path = user_selections['path']
    label = user_selections['label']
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Selected disk/partition = #{path}"
    disk = Device.find path

    CommandsExecutor.debug_mode = !!(self.user_selections['debug'])

    jobs_queue = JobQueue.new(user_selections.length)
    jobs_queue.enqueue({job_name: :pre_checks_job, job_para: {path: path}})
    Device.progress = 0

    if user_selections['format']
      para = {path: path, fs_type: user_selections['fs_type'], label: label}
      job_name = :format_job
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Job_name = #{job_name}, para = #{para}"
      jobs_queue.enqueue({job_name: job_name, job_para: para})
    end

    if user_selections['option']
      para = {path: path, label: label}
      job_name = :mount_job
      DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Job_name = #{job_name}, para = #{para}"
      jobs_queue.enqueue({job_name: job_name, job_para: para})
    end

    jobs_queue.enqueue({job_name: :post_checks_job, job_para: {path: path}})
    result = jobs_queue.process_queue disk
    if result == true
      Device.progress = 100
      redirect_to(disk_wizards_engine.complete_path)
    else
      Device.progress = -1
      session[:exception] = result.inspect
      redirect_to(disk_wizards_engine.error_path)
    end
  end

  # Render progress page when click on apply button in 'confirmation' step
  #  Implicitly send HTTP POST request to process_disk action to start processing the operations
  # Expected key:values in @params:
  #   :debug => Integer value(1) if debug mode has selected in fourth step(confirmation), else nil
  def progress
    debug_mode = params[:debug]
    self.user_selections = {debug: debug_mode}
  end

  # process_disk action redirects here if all operations are completed successfully
  def done
    @operations = CommandsExecutor.operations_log
    flash[:success] = 'All disks operations have been completed successfully!'
    @user_selections = self.user_selections
  end

  # A helper method to return the user selections in the wizard
  # @return Hash
  def user_selections
    return JSON.parse session[:user_selections] rescue nil
  end

  helper_method :user_selections

  # Save user selections in a Rails session variable(Implicitly save data in browser cookie)
  # Accept @param [Hash] hash
  # Overwrite current user selection information with passed values.
  # Encode Hash object to JSON format(flatten the object,enabling store in a SESSION) and store in a session variable.
  def user_selections=(hash)
    current_user_selections = user_selections
    unless current_user_selections
      session[:user_selections] = hash.to_json and return
    end
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:New hash= #{hash}"
    hash.each do |key, value|
      current_user_selections[key] = value
    end
    session[:user_selections] = current_user_selections.to_json
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Updated session[:user_selections] #{session[:user_selections]}"
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

  # Show errors/exceptions to the user  if an error occurred while processing the operations.
  # Show the exceptions raised from the operating system level(stderr) via open3.
  def error
    @exception = session[:exception]
  end

  # Clear the debug_mode flag.
  # TODO: This is used as a before_filter with exceptions,this might cause redundant calls to this method(reset the flag which has been already cleared)
  def clear_mode
    CommandsExecutor.debug_mode = nil
  end

  # Generate fpaste URL which contains required information to debug an error.
  # Directly calling system tools via open3 library not using CommandsExecutor library(Still able to generate debug URL even CommandsExecutor library fails).
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

end
