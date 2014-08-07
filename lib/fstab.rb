class Fstab

  VERSION = "0.1.1"

  # if safe_mode true, non existing devices won't be added to fstab.
  # Adding a non existing device to fstab will raise an exception.
  # Trying to add a device without a filesystem will also rise an exception
  # since init params are mearly static , could be able to replace them with static class variables
  # ref. http://stackoverflow.com/questions/11523547/rails-and-class-variables
  #
  def initialize(file = '/etc/fstab', opts = {})
    @file = file
    @contents = File.read file
    @backup = opts[:backup].nil? ? true : opts[:backup]
    @safe_mode = opts[:safe_mode].nil? ? true : opts[:safe_mode]
    @backup_dir = opts[:backup_dir] || '/etc'
  end

  def entries
    parse
  end

  # :label => label or :uuid => uuid or :dev => dev_path
  # :mount_point => mp
  # :type => type 
  # :opts => opts 
  # :dump => dump
  # :pass => pass
  def add_entry(opts = {})
    raise ArgumentError.new(":dev key is required (fs_spec).") unless opts[:dev]
    dev = opts[:dev].strip.chomp
    uuid = nil
    label = nil
    case dev
      when /\/dev\// # device path
        pdev = dev
      when /^\/\/\w+(\.\w+)*((\/)|\w+|\.)*/ #smbfs/cifs
      when /^(tmpfs|proc|usbfs|devpts|none|sysfs)/ #special FS
      when /^\w+:\/?\w*(\/\w+)*/ # NFS
      when /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/i # UUID
        uuid = dev
      else # Asume FS label, rise exception if FS label does not exist
        if File.blockdev?("/dev/disk/by-label/#{dev}")
          label = dev
        else
          raise Exception.new "Unsupported filesystem #{dev}"
        end
    end

    if opts[:mount_point].nil? or opts[:type].nil? or \
       opts[:opts].nil? or opts[:dump].nil? or opts[:pass].nil?
      raise ArgumentError.new("Missing :mount_point, :type, :opts, :dump or :pass options")
    end

    if @safe_mode and not CommandsExecutor.debug_mode
      if label
        raise ArgumentError.new("Invalid device label #{label}") unless \
                  File.blockdev?("/dev/disk/by-label/#{opts[:label]}")
        opts[:uuid] = Fstab.get_uuid_from_label(label)
      elsif uuid
        raise ArgumentError.new("Invalid device UUID #{uuid}") unless \
                  File.blockdev?("/dev/disk/by-uuid/#{uuid}")
        opts[:uuid] = uuid
      elsif pdev
        raise ArgumentError.new("Invalid device path #{pdev}") unless \
                  File.blockdev?("#{pdev}")
        opts[:uuid] = Fstab.get_uuid(pdev)
      else
        # Asume special device
        special = true
      end
      unless special
        raise ArgumentError.new("Duplicated entry found (safe_mode=on)") if has_device?(dev)
      end
    end

    backup_fstab
    #TODO: Append format_entry(dev, opts) to "/etc/fstab" by using "Command" library not using File.open
    command = "echo"
    params = "  #{@contents} ! sudo tee /etc/fstab"
    echo = CommandsExecutor.new command, params
    echo.execute
    raise "Command execution error: #{echo.stderr.read}" if not echo.success?
    command = "echo"
    params = " #{format_entry(dev, opts)} ! sudo tee -a /etc/fstab"
    echo = CommandsExecutor.new command, params
    echo.execute
    raise "Command execution error: #{echo.stderr.read}" if not echo.success?
    reload
  end

  def add_fs(dev, mpoint, type, opts, dump = 0, pass = 0)
    o = {}
    o[:dev] = dev
    o[:mount_point] = mpoint
    o[:type] = type
    o[:opts] = opts
    o[:dump] = dump
    o[:pass] = pass
    add_entry o
  end

  def line_count
    @lcount
  end

  def reload
    @contents = File.read @file
  end

  def parse
    raise Exception.new("/sbin/blkid not found") unless File.exist?('/sbin/blkid')
    fslist = {}
    ucount = 0
    @lcount = 0
    @contents.each_line do |l|
      next if l.strip.chomp.empty?
      @lcount += 1
      next if l =~ /\s*#/
      fs, mp, type, opts, dump, pass = l.split

      # FSTAB(5) states that pass and dump are optional, defaults to 0
      pass = "0" unless pass
      dump = "0" unless dump
      pdev = nil
      label = nil
      uuid = nil
      special = false
      if l =~ /^\s*LABEL=/
        # by LABEL
        label = fs.split("=").last.strip.chomp
        pdev = "/dev/" + File.readlink("/dev/disk/by-label/#{label}").split("/").last rescue "unknown_#{ucount}"
        uuid = Fstab.get_uuid pdev
      elsif l =~ /^\s*UUID=/
        # by UUID
        uuid = fs.split("=").last.strip.chomp
        pdev = "/dev/" + File.readlink("/dev/disk/by-uuid/#{uuid}").split("/").last rescue "unknown_#{ucount}"
        label = Fstab.get_label pdev rescue nil
      elsif l =~ /^\s*\/dev/
        # by dev path
        pdev = fs
        blkid = `/sbin/blkid #{pdev}`
        label = blkid.match(/LABEL="(.*?)"/)[1] rescue nil
        uuid = blkid.match(/UUID="(.*?)"/)[1] rescue nil
      else
        # FIXME: somewhat risky to assume that everything else
        # can be considered a special device, but validating this
        # is really tricky.
        special = true
        pdev = fs
      end
      # Fstab entries not matching real devices have pdev unknown
      invalid = (l.split.count != 6) # invalid entry if < 6 columns
      if (uuid.nil? and label.nil? and !special) or
          pdev =~ /^unknown_/ or \
         (!File.exist?(pdev) and !special)
        invalid = true
        ucount += 1
      end

      invalid = true unless (dump =~ /0|1|2/ and pass =~ /0|1|2/)

      fslist[pdev] = {
          :label => label,
          :uuid => uuid,
          :mount_point => mp,
          :type => type,
          :opts => opts,
          :dump => dump,
          :pass => pass,
          :special => special,
          :line_number => @lcount,
          :invalid => invalid,
      }
    end
    fslist
  end

  def valid_entries
    Hash[parse.find_all { |k, v| !v[:invalid] }]
  end

  def auto_header
    @header ||= "#\n" +
        "# This file was autogenerated at #{Time.now.to_s}\n" +
        "#\n"
  end

  # 
  # May rise exception 
  #
  def remove_invalid_entries
    return false if invalid_entries.empty?
    backup_fstab
    File.open @file, 'w' do |f|
      f.puts auto_header
      valid_entries.each do |k, v|
        f.puts format_entry(k, v)
      end
    end
    reload
    true
  end

  def invalid_entries
    Hash[parse.find_all { |k, v| v[:invalid] }]
  end

  #
  # Accepts UUID/LABEL/dev
  #
  def find_device(dev)
    # get canonical device_name
    begin
      dev = Fstab.get_blockdev(dev)
      parse.each do |k, v|
        return {k => v} if k == dev
      end
    rescue
    end
    nil
  end

  def has_device?(dev)
    !find_device(dev).nil?
  end

  # returns 
  # {
  #   :uuid   => UUID,
  #   :label  => LABEL,
  #   :fstype => FSTYPE,
  #   :dev    => DEVICE
  # }
  #
  # All the attributes except dev may be nil at any given time since
  # device may not have a valid filesystem or label.
  def self.get_blkdev_fs_attrs(dev)
    raise ArgumentError.new("Invalid device path #{dev}") unless File.blockdev?(dev) and not CommandsExecutor.debug_mode
    # For reference, TODO: remove later
    # blkid = `/sbin/blkid #{dev}`
    # attrs = {}
    # attrs[:uuid] = blkid.match(/UUID="(.*?)"/)[1] rescue nil
    # attrs[:label] = blkid.match(/LABEL="(.*?)"/)[1] rescue nil
    # attrs[:fstype] = blkid.match(/TYPE="(.*?)"/)[1] rescue nil
    # attrs[:dev] = blkid.match(/\/dev\/(.*):/)[1] rescue nil
    # attrs
    attrs = {}
    command = 'blkid'
    params = " #{dev} -o export -c /dev/null"
    blkid = CommandsExecutor.new command, params
    DebugLogger.info "|Fstab|>|#{__method__}|:device = #{dev}"
    blkid.execute
    raise "Command execution error:blkid error: #{blkid.stderr.read}" if not blkid.success?
    blkid.result.each_line do |line|
      line.strip!.chomp!
      key, value = line.split('=')
      case key
        when 'DEVNAME'
          attrs[:dev] = value
        when 'UUID'
          attrs[:uuid] = value
        when 'LABEL'
          attrs[:label] = value
        when 'TYPE'
          attrs[:fstype] = value
      end
    end
    attrs
  end

  # 
  # Get block device from UUID/Label
  def self.get_blockdev(id)
    if File.blockdev?(id) and !File.symlink?(id)
      return id
    end
    path = nil
    # Try to get blockdev from UUID first, then label
    begin
      path = File.readlink("/dev/disk/by-uuid/#{id}")
    rescue
      path = File.readlink("/dev/disk/by-label/#{id}")
    end
    "/dev/#{path.split('/').last}"
  end

  def self.get_uuid(dev)
    #`/sbin/blkid #{dev}`.match(/UUID="(.*?)"/)[1] rescue nil
    Fstab.get_blkdev_fs_attrs(dev)[:uuid]
  end

  def self.get_uuid_from_label(label)
    Fstab.get_blkdev_fs_attrs("/dev/disk/by-label/#{label}")[:uuid]
  end

  def self.get_label(dev)
    Fstab.get_blkdev_fs_attrs(dev)[:label]
  end

  private
  def format_entry(dev, values)
    if values[:special]
      "#{dev} #{values[:mount_point]} #{values[:type]} " +
          "#{values[:opts]} #{values[:dump]} #{values[:pass]}"
    else
      if values[:uuid]
        "UUID=#{values[:uuid]} #{values[:mount_point]} #{values[:type]} " +
            "#{values[:opts]} #{values[:dump]} #{values[:pass]}"
      else
        "#{dev} #{values[:mount_point]} #{values[:type]} " +
            "#{values[:opts]} #{values[:dump]} #{values[:pass]}"
      end
    end
  end

  def backup_fstab
    return unless @backup
    #sh -c "echo 'something' >> /etc/privilegedfile"
    command = "echo"
    params = " #{@contents} ! sudo tee  #{@backup_dir}/fstab.#{Time.now.to_f}.bak"

    echo = CommandsExecutor.new command, params
    echo.execute
    raise "Command execution error: #{echo.stderr.read}" if not echo.success?
    # File.open("#{@backup_dir}/fstab.#{Time.now.to_f}.bak", 'w') do |f|
    # f.puts @contents
    # end
  end

end

