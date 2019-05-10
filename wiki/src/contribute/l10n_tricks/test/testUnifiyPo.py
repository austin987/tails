#!/usb/bin/env python3
import glob
import importlib.machinery
import os
import unittest
import tempfile
import shutil
import yaml


unifyPo = importlib.machinery.SourceFileLoader('unifyPo', 'unifyPo').load_module()


DIRNAME = os.path.dirname(__file__)

class TestCheckPo(unittest.TestCase):
    def test_checkPo(self):
        with open(os.path.join(DIRNAME, "checkPo.yml")) as f:
            expected = yaml.load(f)

        with tempfile.TemporaryDirectory() as tmpdir:
            for fpath in glob.glob(os.path.join(DIRNAME, "checkPo/*")):
                name = os.path.basename(fpath)
                newPath = os.path.join(tmpdir, name + ".en.po")
                os.symlink(os.path.abspath(fpath), newPath)
                path, issues = unifyPo.checkPoFile(newPath, extended=False)
                self.assertEqual(path, newPath)
                self.assertEqual(issues, expected[name], msg="{name}".format(name=name))

    def test_checkPoExtended(self):
        with open(os.path.join(DIRNAME, "checkPoExtended.yml")) as f:
            expected = yaml.load(f)

        with tempfile.TemporaryDirectory() as tmpdir:
            for fpath in glob.glob(os.path.join(DIRNAME, "checkPo/*")):
                name = os.path.basename(fpath)
                newPath = os.path.join(tmpdir, name + ".en.po")
                os.symlink(os.path.abspath(fpath), newPath)
                path, issues = unifyPo.checkPoFile(newPath, extended=True)
                self.assertEqual(path, newPath)
                self.assertEqual(issues, expected[name], msg="{name}".format(name=name))

    def test_unifyPo(self):
        self.maxDiff = None
        with tempfile.TemporaryDirectory() as tmpdir:
            for fpath in glob.glob(os.path.join(DIRNAME, "unifyPo/*")):
                with open(fpath) as f:
                    expectedContent = f.read()
                name = os.path.basename(fpath)
                newPath = os.path.join(tmpdir, name + ".en.po")
                shutil.copy(os.path.join(DIRNAME, "checkPo", name), newPath)
                unifyPo.unifyPoFile(newPath)
                with open(newPath) as f:
                    self.assertEqual(f.read(), expectedContent, msg=name)
                _, issues = unifyPo.checkPoFile(newPath, extended=True)
                self.assertEqual(issues, [], msg=name)



if __name__ == '__main__':
    unittest.main()

