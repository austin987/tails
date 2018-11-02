#!/usr/bin/env python3

"""unifies PO headers and rewraps PO files to 79 chars.
You can run it with --help to see the usage.

./unify_po-headers.py --help

run with a list of files:

./unify_po-headers.py file1.de.po file2.fr.po

or unifies all po file that are in git stage:

./unify_po-headers.py --cached

or unify all po files of one language in the current directory and all sub directories:

./unify_po-headers.py --lang de

To check if the current type annotations matches use mypy:

mypy unify_po-headers.py
"""

import glob
import multiprocessing
import re
import subprocess
from typing import List, Pattern

MSGCAT_OPTIONS = ["-w", "79"] # wrap to 79 width

class PoFile:
    def regexKey(self, key: str) -> Pattern:
        """returns a regex to match a key: value pair in po header"""
        return re.compile('^\s*"{key}\s*:\s*(?P<value>(.*\n)*?.*)\\\\n"\s*?$'.format(key=key), flags=re.M)

    def __init__(self, fname: str) -> None:
        self.fname = fname

    def __enter__(self) -> 'PoFile':
        """magic method for with statement returns self so it can be used with "as" """
        self.open()
        return self

    def __exit__(self, type, value, traceback) -> None:
        """magic method for with statement"""
        if type is None and value is None and traceback is None:
            self.write()

    def open(self) -> None:
        """read the po file"""
        with open(self.fname, 'r') as f:
            self.content = f.read()
        self.__changed = False

    def lang(self) -> str:
        """retun the language of the filename"""
        exts = self.fname.split(".")
        if len(exts) < 3:
            raise Exception("po file should have a language in his name.", self.fname)
        return exts[-2]

    def check(self, key: str, value: str) -> bool:
        """check if there is "key: value\\n" in in PO header"""
        m = self.regexKey(key).search(self.content)
        if not m:
            return False
        # Remove po file soft line breaks, as line length is handled outside this
        fileValue = m.group("value").replace('"\n"',"")
        return (fileValue == value)

    def unifyKey(self, key: str, value: str) -> None:
        """ set value for PO header key to "key: value\\n" """
        if not self.check(key, value):
            self.content = self.regexKey(key).sub('"{key}: {value}\\\\n"'.format(key=key, value=value),
                   self.content
            )
            self.__changed = True

    def write(self) -> None:
        """writes file, if the content was changed"""
        if self.__changed:
            with open(self.fname, 'w') as f:
                f.write(self.content)

    def msgcat(self) -> None:
        """runs msgcat over file, if file is already opened, than just the opened copy is modified"""
        cmd = ["msgcat",] + MSGCAT_OPTIONS
        if hasattr(self, "content"):
            cmd.append("-") # use stdin as input
            content = self.content.encode()
            process = subprocess.run(cmd,
                    input=content,
                    stdout=subprocess.PIPE,
                    check=True)
            if process.stdout != content:
                self.content = process.stdout.decode()
                self.__changed = True
        else:
            cmd.extend(["-o", self.fname]) # output to file itself
            cmd.append(self.fname) # file as input
            subprocess.check_call(cmd)

def unifyPoFile(fname: str) -> None:
    """unify PO header and runs msgcat for file named fname"""
    with PoFile(fname) as poFile:
        poFile.unifyKey("Language", poFile.lang())
        poFile.unifyKey("Content-Type", "text/plain; charset=UTF-8")
        poFile.unifyKey("Project-Id-Version", "")
        poFile.unifyKey("Language-Team", "Tails translators <tails-l10n@boum.org>")
        poFile.unifyKey("Last-Translator", "Tails translators")
        poFile.msgcat()

def main(files: List[str]) -> None:
    """unifies PO header for a list of files"""
    pool = multiprocessing.Pool()
    list(pool.map(unifyPoFile,files))

if __name__ == '__main__':
    import argparse
    import glob
    import os.path

    parser = argparse.ArgumentParser(description='unify po files')
    parser.add_argument('--lang', dest='lang', help='all files for a specific language.')
    parser.add_argument('--cached', dest='cached', action='store_true', help='all po files within git stage.')
    parser.add_argument('files', metavar='file', type=str, nargs='*',
        help='list files to process')
    args = parser.parse_args()

    if args.lang:
        args.files += glob.glob("**/*.{lang}.po".format(lang=args.lang))

    if args.cached:
        # get toplevel directory of the current git repository
        # git diff returns always relative paths to the toplevel directory
        toplevel = subprocess.check_output(["git", "rev-parse", "--show-toplevel"])
        toplevel = toplevel.decode()[:-1] # get rid of tailing \n

        # get a list of changes and added files in stage for the next commit
        output = subprocess.check_output(["git", "diff", "--name-only", "--cached", "--ignore-submodules", "--diff-filter=d"])

        # add all po files to list to unify
        args.files += [os.path.join(toplevel,f) for f in output.decode().split("\n") if f.endswith(".po")]

    if not args.files:
        print("WARNING: no file to unify :( You may want to add files to operate on. See --help for further information.")

    main(args.files)
