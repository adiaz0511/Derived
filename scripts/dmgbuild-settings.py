import os


source_root = defines["source_root"]

format = "UDZO"
filesystem = "HFS+"

files = [
    (os.path.join(source_root, "Derived.app"), "Derived.app"),
    (os.path.join(source_root, "Derived Agent Tools.app"), "Derived Agent Tools.app"),
    (os.path.join(source_root, ".agent-tools"), ".agent-tools"),
]
symlinks = {"Applications": "/Applications"}
hide = [".agent-tools"]
hide_extensions = ["Derived.app", "Derived Agent Tools.app"]

icon = defines["volume_icon"]
background = defines["background"]

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 0
window_rect = ((120, 120), (948, 520))
default_view = "icon-view"
include_icon_view_settings = True

arrange_by = None
label_pos = "bottom"
text_size = 15
icon_size = 112
icon_locations = {
    "Derived.app": (279, 130),
    "Applications": (639, 130),
    "Derived Agent Tools.app": (459, 275),
}
