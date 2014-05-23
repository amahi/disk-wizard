DiskWizards::Engine.routes.draw do
  root :to => 'disk_wizards#select_device'
  match 'select' => 'disk_wizards#select_device',via: [:get,:post]
  match 'file_system' => 'disk_wizards#select_fs',via: [:get,:post]
  match 'manage' => 'disk_wizards#manage_disk',via: [:get,:post]
  match 'confirmation' => 'disk_wizards#confirmation',via: [:get,:post]
  get 'complete' => 'disk_wizards#done'
  get 'get_progress' => 'disk_wizards#operations_progress'
  get 'error' => 'disk_wizards#error'
  post 'process' => 'disk_wizards#progress'
  post 'ajax_process' => 'disk_wizards#process_disk'
end
