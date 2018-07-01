# plugin initialization
unless t = Tab.find("disks")
    t = Tab.new("disks", "disks", "/tab/disks")
end

t.add("disk_wizard", "Add")