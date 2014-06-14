class DiskWizardsController < ApplicationController
  layout 'disk_wizard'

  def select_device
    @mounted_disks = Disk.mounts
    @new_disks = Disk.new_disks
  end

  def select_fs
    device = params[:device]
    self.user_selections = {kname: device} if device
    puts device
    if not(device and request.post?)
      redirect_to defined?(disk_wizards_engine) ? disk_wizards_engine.select_path : select_path, :flash => { :error => "Please select a device to continue." }
      return false
    end
    @selected_disk = Disk.find(device || user_selections['kname'])
  end

  def manage_disk
    device = params[:device]
    format = params[:format]
    partition = params[:partition]
    fs_type = params[:fs_type]
    if (not(fs_type or user_selections['fs_type']) and not user_selections['kname'])
      redirect_to defined?(disk_wizards_engine) ? disk_wizards_engine.file_system_path : file_system_path , :flash => { :error => "Please select a filesystem type to continue." }
      return false
    end
    self.user_selections = {fs_type: fs_type,format: format,kname: partition}
  end

  def confirmation
    option = params[:option]
    self.user_selections = {option: option}
    @selected_disk = Disk.find(user_selections['kname'])
  end

  def process_disk
    kname = user_selections['kname']
    disk = Disk.find kname

    jobs_queue = JobQueue.new(user_selections.length)
    Disk.progress = 0

    if user_selections['format']
      para = {kname: kname,fs_type: user_selections['fs_type']}
      job_name = :format_job
      puts "DEBUG:******** {job_name: job_name,para: para} = #{{job_name: job_name,para: para}}"
      jobs_queue.enqueue({job_name: job_name,job_para: para})
    end

    if user_selections["option"]
      para = {kname: kname}
      job_name = :mount_job
      puts "DEBUG:******** {job_name: job_name,para: para} = #{{job_name: job_name,para: para}}"
      jobs_queue.enqueue({job_name: job_name,job_para: para})
    end
    success = jobs_queue.process_queue disk
    if success
      Disk.progress = 100
      redirect_to(defined?(disk_wizards_engine) ? disk_wizards_engine.complete_path : complete_path)
    else
      Disk.progress = -1
      redirect_to(defined?(disk_wizards_engine) ? disk_wizards_engine.error_path : error_path)
    end
  end

  def progress
    debug_mode = params[:debug]
    self.user_selections = {debug: debug_mode}
  end

  def done
    flash[:success] = "All disks operations has been completed successfully!"
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
    puts "DEBUG *********************** hash{hash}"
    hash.each do |key,value|
      current_user_selections[key] = value
    end
    session[:user_selections] = current_user_selections.to_json
    puts "DEBUG ************************** session[:user_selections] #{session[:user_selections]}"
  end

  def operations_progress
    message = Disk.progress_message(Disk.progress)
    render json: {percentage: Disk.progress, message: message}
  end

  def error
    render text: "Somthing went wrong!"
  end

end
