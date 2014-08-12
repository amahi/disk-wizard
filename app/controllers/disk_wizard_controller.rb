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

  # Create operation queue according to user selections(user_selections), and enqueue operations
  # Execute
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

  def progress
    debug_mode = params[:debug]
    self.user_selections = {debug: debug_mode}
  end

  def done
    @operations = CommandsExecutor.operations_log
    flash[:success] = 'All disks operations have been completed successfully!'
    @user_selections = self.user_selections
  end

  def user_selections
    return JSON.parse session[:user_selections] rescue nil
  end

  helper_method :user_selections

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

  def operations_progress
    message = Device.progress_message(Device.progress)
    render json: {percentage: Device.progress, message: message}
  end

  def error
    @exception = session[:exception]
  end

  def clear_mode
    CommandsExecutor.debug_mode = nil
  end

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
