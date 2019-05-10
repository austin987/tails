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
                path, issues = unifyPo.check_po_file(newPath, extended=False)
                self.assertEqual(path, newPath)
                self.assertEqual(issues, expected[name], msg=name)

    def test_checkPoExtended(self):
        with open(os.path.join(DIRNAME, "checkPoExtended.yml")) as f:
            expected = yaml.load(f)

        with tempfile.TemporaryDirectory() as tmpdir:
            for fpath in glob.glob(os.path.join(DIRNAME, "checkPo/*")):
                name = os.path.basename(fpath)
                newPath = os.path.join(tmpdir, name + ".en.po")
                os.symlink(os.path.abspath(fpath), newPath)
                path, issues = unifyPo.check_po_file(newPath, extended=True)
                self.assertEqual(path, newPath)
                self.assertEqual(issues, expected[name], msg=name)

    def test_unifyPo(self):
        self.maxDiff = None
        with tempfile.TemporaryDirectory() as tmpdir:
            for fpath in glob.glob(os.path.join(DIRNAME, "unifyPo/*")):
                with open(fpath) as f:
                    expectedContent = f.read()
                name = os.path.basename(fpath)
                newPath = os.path.join(tmpdir, name + ".en.po")
                shutil.copy(os.path.join(DIRNAME, "checkPo", name), newPath)
                unifyPo.unify_po_file(newPath)
                with open(newPath) as f:
                    self.assertEqual(f.read(), expectedContent, msg=name)
                _, issues = unifyPo.check_po_file(newPath, extended=True)
                self.assertEqual(issues, [], msg=name)

    def test_lang(self):
        self.assertEqual(unifyPo.PoFile("index.de.po").lang(), "de")
        self.assertEqual(unifyPo.PoFile("x/a/a.fb.xx.po").lang(), "xx")

        _p = unifyPo.PoFile(".de.po")
        with self.assertRaises(unifyPo.NoLanguageError, msg=_p.fname) as e:
            _p.lang()

        self.assertEqual(str(e.exception), "Can't detect expect file suffix .XX.po for '.de.po'.")

        _p = unifyPo.PoFile(".a.d.de.po")
        with self.assertRaises(unifyPo.NoLanguageError, msg=_p.fname):
            _p.lang()

        _p = unifyPo.PoFile("a.po")
        with self.assertRaises(unifyPo.NoLanguageError, msg=_p.fname):
            _p.lang()

        _p = unifyPo.PoFile("/a/d/d..po")
        with self.assertRaises(unifyPo.NoLanguageError, msg=_p.fname):
            _p.lang()


if __name__ == '__main__':
    unittest.main()

