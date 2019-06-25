#!/usb/bin/env python3
import glob
import importlib.machinery
import os
import unittest
import tempfile
import shutil
import yaml


lint_po = importlib.machinery.SourceFileLoader('lint_po', 'lint_po').load_module()


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
                path, issues = lint_po.check_po_file(newPath, extended=False)
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
                path, issues = lint_po.check_po_file(newPath, extended=True)
                self.assertEqual(path, newPath)
                self.assertEqual(issues, expected[name], msg=name)

    def test_nonexistingPo(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            newPath = os.path.join(tmpdir, "nonexisting.en.po")
            with self.assertRaises(FileNotFoundError, msg=newPath):
                path, issues = lint_po.check_po_file(newPath, extended=False)
            with self.assertRaises(FileNotFoundError, msg=newPath):
                path, issues = lint_po.check_po_file(newPath, extended=True)

    def test_lint_po(self):
        self.maxDiff = None
        with tempfile.TemporaryDirectory() as tmpdir:
            for fpath in glob.glob(os.path.join(DIRNAME, "lint_po/*")):
                with open(fpath) as f:
                    expectedContent = f.read()
                name = os.path.basename(fpath)
                newPath = os.path.join(tmpdir, name + ".en.po")
                shutil.copy(os.path.join(DIRNAME, "checkPo", name), newPath)
                lint_po.unify_po_file(newPath)
                with open(newPath) as f:
                    self.assertEqual(f.read(), expectedContent, msg=name)
                _, issues = lint_po.check_po_file(newPath, extended=True)
                self.assertEqual(issues, [], msg=name)

    def test_lang(self):
        self.assertEqual(lint_po.PoFile("index.de.po").lang(), "de")
        self.assertEqual(lint_po.PoFile("x/a/a.fb.xx.po").lang(), "xx")

        _p = lint_po.PoFile(".de.po")
        with self.assertRaises(lint_po.NoLanguageError, msg=_p.fname) as e:
            _p.lang()

        self.assertEqual(str(e.exception), "Can't detect expect file suffix .XX.po for '.de.po'.")

        _p = lint_po.PoFile(".a.d.de.po")
        with self.assertRaises(lint_po.NoLanguageError, msg=_p.fname):
            _p.lang()

        _p = lint_po.PoFile("a.po")
        with self.assertRaises(lint_po.NoLanguageError, msg=_p.fname):
            _p.lang()

        _p = lint_po.PoFile("/a/d/d..po")
        with self.assertRaises(lint_po.NoLanguageError, msg=_p.fname):
            _p.lang()

    def test_needs_rewrap(self):
        with lint_po.pofile_readonly(os.path.join(DIRNAME, "checkPo/length")) as poFile:
            self.assertEqual(poFile.needs_rewrap(), True)
        with lint_po.pofile_readonly(os.path.join(DIRNAME, "unifyPo/length")) as poFile:
            self.assertEqual(poFile.needs_rewrap(), False)


if __name__ == '__main__':
    unittest.main()

