class Setting < ActiveRecord::Base

  KINDS = [GENERAL = "general", NETWORK = "network", SHARES = "shares"]

  scope :by_name, lambda{|name| where(:name => name)}
  scope :by_kind, lambda{|kind| where(:kind => kind)}

  class << self
    def value_by_name(name)
      get_by_name(name).try(:value)
    end

    def get_by_name(name)
      by_name(name).first
    end

    def get(name)
      s = by_name(name).first
      s && s.value
    end

    def set(name, value, kind=GENERAL)
      self.find_or_create_by_name(:name => name).update_attributes(value: value, kind: kind)
    end

    def get_kind(kind, name)
      by_kind(kind).by_name(name).first
    end

    def set_kind(kind, name, value)
      setting = get_kind(kind, name)
      if setting
        s.update_attribute!(:value, value)
      else
        setting = create(:kind => kind, :name => name, :value => value)
      end
      setting
    end

    def find_or_create_by(kind, name, value)
      get_kind(kind, name) || create(kind: kind, name: name, value: value)
    end
  end

  def set?
    value == '1' || value == 'true'
  end

end