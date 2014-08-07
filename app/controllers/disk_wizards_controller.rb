class DiskWizardsController < ApplicationController
  before_filter :disk_wizard

  layout 'wizard'

  def disk_wizard
    defined?(disk_wizards_engine) ? admin_required : false
  end

  before_filter :clear_mode, except: [:process_disk]

  def select_device
    DebugLogger.info "--disk_wizard_start--"
    @mounted_disks = Device.mounts
  end

  def select_fs
    device = params[:device]
    self.user_selections = {path: device} if device
    DebugLogger.info "|#{self.class.name}|>|#{__method__}|:Device = #{device}"
    if not (device and request.post?)
      redirect_to defined?(disk_wizards_engine) ? disk_wizards_engine.select_path : select_path, :flash => {:error => "Please select a device to continue."}
      return false
    end
    @selected_disk = Device.find(device || user_selections['path'])
  end

  def manage_disk
    format = params[:format]
    partition = params[:partition]
    fs_type = params[:fs_type].to_i
    if (not (fs_type or user_selections['fs_type']) and not user_selections['path'])
      redirect_to defined?(disk_wizards_engine) ? disk_wizards_engine.file_system_path : file_system_path, :flash => {:error => "Please select a filesystem type to continue."}
      return false
    end
    if request.post?
      self.user_selections = {fs_type: fs_type, format: format, path: partition}
    end
  end

  def confirmation
    option = params[:option]
    label = params[:label].blank? ? nil : params[:label]
    self.user_selections = {option: option, label: label}
    @selected_disk = Device.find(user_selections['path'])
  end

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
      redirect_to(defined?(disk_wizards_engine) ? disk_wizards_engine.complete_path : complete_path)
    else
      Device.progress = -1
      session[:exception] = result.inspect
      redirect_to(defined?(disk_wizards_engine) ? disk_wizards_engine.error_path : error_path)
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
