class WelcomeController < ApplicationController
  layout 'basic'

  def index
    @page_title = "Amahi Disk Wizad"
  end
end
