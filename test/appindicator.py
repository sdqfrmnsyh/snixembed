#!/usr/bin/env python3

import pathlib

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk
from gi.repository import AppIndicator3 as ai

ICONNAME = "edit-undo" # Usually available
ICONPATH = str((pathlib.Path(__file__).parent / "test.png").resolve())

indicator = ai.Indicator.new("appindicator-test",
                             ICONNAME,
                             ai.IndicatorCategory.APPLICATION_STATUS)

menu = Gtk.Menu()
menu_items = map(lambda l: [Gtk.MenuItem(label=l[0]), l[1]], [
    ["Set IconName",         lambda _: indicator.set_icon(ICONNAME)],
    ["Set bogus IconName",   lambda _: indicator.set_icon("!@#$")],
    ["Set path as IconName", lambda _: indicator.set_icon(ICONPATH)],
    ["Quit",                 Gtk.main_quit],
])
for i in menu_items:
    i[0].connect("activate", i[1])
    menu.append(i[0])
menu.show_all()

indicator.set_title("AppIndicator test")
indicator.set_menu(menu)

Gtk.main()
