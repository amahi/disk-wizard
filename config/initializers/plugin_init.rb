# plugin initialization
t = Tab.new("disk_wizards", "disk_wizards", "/tab/disk_wizards")
# add any subtabs with what you need. params are controller and the label, for example
t.add("index", "details")
t.add("settings", "settings")
t.add("advanced", "advanced")