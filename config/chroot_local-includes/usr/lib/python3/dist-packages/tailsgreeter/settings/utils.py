import os
from typing import Dict


def write_settings(filename: str, settings: Dict[str, str]):
    with open(filename, 'w') as f:
        os.chmod(filename, 0o600)
        for key, value in settings.items():
            f.write('%s=%s\n' % (key, value))


def read_settings(filename: str) -> Dict[str, str]:
    with open(filename) as f:
        lines = f.readlines()

    settings = dict()
    for line in lines:
        try:
            key, value = line.split('=', 1)
        except ValueError:
            continue
        settings[key] = value.rstrip()
    return settings
