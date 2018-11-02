from os import path

APP_NAME = "unlock-veracrypt-volumes"
DATA_DIR = "/usr/share/%s/" % APP_NAME
UI_DIR = path.join(DATA_DIR, "ui")
MAIN_UI_FILE = path.join(UI_DIR, "main.ui")
VOLUME_UI_FILE = path.join(UI_DIR, "volume.ui")
