DiskWizards::Engine.routes.draw do

# The priority is based upon order of creation: first created -> highest priority.
# See how all your routes lay out with "rake routes".

# You can have the root of your site routed with "root"
# root 'welcome#index'
# root :to =>  "welcome#index"
# scope 'tab/' do
  root :to => 'disk_wizard#select_device'
  
  get "get_all_devices" => 'disk_service#get_all_devices'
  get "check_label" => 'disk_service#check_label'
  get 'debug_info' => 'disk_service#debug_info'
  post 'process' => 'disk_service#progress'
  get 'get_progress' => 'disk_service#operations_progress'

  match 'select' => 'disk_wizard#select_device',via: [:get,:post]
  match 'file_system' => 'disk_wizard#select_fs',via: [:get,:post]
  match 'manage' => 'disk_wizard#manage_disk',via: [:get,:post]
  match 'confirmation' => 'disk_wizard#confirmation',via: [:get,:post]
  get 'complete' => 'disk_wizard#done'
  # get 'get_progress' => 'disk_wizard#operations_progress'
  get 'error' => 'disk_wizard#error'
  # get 'debug_info' => 'disk_wizard#debug_info'
  # post 'process' => 'disk_wizard#progress'
  post 'ajax_process' => 'disk_wizard#process_disk'


  resources :disks

# end

end
