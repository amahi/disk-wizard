class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  include Chartkick::Helper
  rescue_from Exception, :with => :dw_excepton_handler

  protected

  def dw_excepton_handler(exception)
    session[:exception] = exception.inspect
    redirect_to(defined?(disk_wizards_engine) ? disk_wizards_engine.error_path : error_path)
  end

end
