#!/usr/bin/env python3

import pathlib

from PySide6.QtGui import QAction, QIcon
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

ICONNAME = "firefox" # Usually available
ICONPATH = str((pathlib.Path(__file__).parent / "test.png").resolve())

QIcon.setThemeSearchPaths([".local/share/icons", "/usr/share/icons"])

app = QApplication([])

name_icon = QIcon.fromTheme(ICONNAME)
file_icon = QIcon(ICONPATH)

sni = QSystemTrayIcon()

menu = QMenu()
menu_items = list(map(lambda l: [QAction(l[0]), l[1]], [
    ["Set IconName",         lambda : sni.setIcon(name_icon)],
    ["Set Pixmap",           lambda : sni.setIcon(file_icon)],
    ["Quit",                 app.quit],
]))
for i in menu_items:
    i[0].triggered.connect(i[1])
    menu.addAction(i[0])

sni.setIcon(file_icon)
sni.setContextMenu(menu)
sni.show();

app.exec()
