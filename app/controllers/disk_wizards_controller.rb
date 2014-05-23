class DiskWizardsController < ApplicationController
  layout 'disk_wizard'

  def select_device
    @mounted_disks = Disk.mounts
    @new_disks = Disk.new_disks
  end

  def select_fs
    device = params[:device]
    format = params[:format]
    self.user_selections = {kname: device,format: format} if device or format
    puts device
    if not(device and request.post?)
      redirect_to select_path || "/tab/disk_wizards/select", :flash => { :error => "You should select a Device or a Partition to continue with the Disk-Wizard" }
      return false
    elsif (not format and request.post?)
      redirect_to manage_path || "/tab/disk_wizards/manage" and return
    end
    flash[:error] = "This will completely erase this new drive! Make sure the selected hard drive is the drive you'd like to erase."
    @selected_disk = Disk.find(device || user_selections['kname'])
    # puts "DEBUG *************************************#{device}"

  end

  def manage_disk
    device = params[:device]
    fs_type = params[:fs_type]
    if (not(fs_type or user_selections['fs_type']) and not user_selections['kname'])
      redirect_to file_system_path || "/tab/disk_wizards/file_system", :flash => { :error => "You should select a filesystem to continue with the Disk-Wizard" }
      return false
    end
    self.user_selections = {fs_type: fs_type}
    # render text: "params = #{params} and  user_selections #{user_selections}"
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
      redirect_to complete_path || "/tab/disk_wizards/complete"
    else
      Disk.progress = -1
      redirect_to error_path || "/tab/disk_wizards/error"
    end
  end

  def progress

  end

  def done

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
