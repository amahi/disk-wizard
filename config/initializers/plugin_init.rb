# plugin initialization
t = Tab.new("disk_wizards", "New Disk Wizard", "/tab/disk_wizards")
# add any subtabs with what you need. params are controller and the label, for example
t.add("index", "devices")
t.add("mounts", "partitions")
