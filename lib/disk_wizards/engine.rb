module DiskWizards
  class Engine < ::Rails::Engine
    # NOTE: do not isolate the namespace unless you really really
    # want to adjust all your controllers views, etc., making Amahi's
    # platform hard to reach from here
    # isolate_namespace DiskWizard
  end
  class ApplicationController < ActionController::Base
    # Prevent CSRF attacks by raising an exception.
    # For APIs, you may want to use :null_session instead.
    rescue_from Exception, :with => :dw_excepton_handler

    protected
    def dw_excepton_handler(exception)
      session[:exception] = exception.inspect
      redirect_to(defined?(disk_wizards_engine) ? disk_wizards_engine.error_path : error_path)
    end

  end

end
