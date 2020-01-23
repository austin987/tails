import os


def write_settings(filename: str, settings: dict):
    with open(filename, 'w') as f:
        os.chmod(filename, 0o600)
        for key, value in settings.items():
            f.write('%s=%s\n' % (key, value))
