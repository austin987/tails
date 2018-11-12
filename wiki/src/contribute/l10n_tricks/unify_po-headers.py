#!/usr/bin/env python3

"""Checks and Unifies PO headers and rewraps PO files to 79 chars.

Usage:
./unify_po-headers.py --help

Default is check mode where the error are listed but not fixed.
With --modify the files get changed and unified.

Run with a list of files:
./unify_po-headers.py file1.de.po file2.fr.po

or unify all po files that are staged for git commit:
./unify_po-headers.py --cached

or unify all po files of one language in the current directory and all
subdirectories:
./unify_po-headers.py --lang de

When modifying unify_po (this script), you should check if the current type
annotations match, using `mypy` (`apt install mypy`):

mypy unify_po-headers.py
"""

import glob
import multiprocessing
import re
import subprocess
import sys
from typing import Dict, List, Pattern

MSGCAT_OPTIONS = ["-w", "79"] # wrap to 79 width

# i18nspector issues, that we accept
I18NSPECTOR_ACCEPT = [
        "boilerplate-in-date",
        "boilerplate-in-initial-comments",
        "boilerplate-in-language-team",
        "boilerplate-in-last-translator",
        "boilerplate-in-project-id-version",
        "codomain-error-in-plural-forms",
        "codomain-error-in-unused-plural-forms",
        "conflict-marker-in-header-entry",
        "fuzzy-header-entry",
        "incorrect-plural-forms",
        "invalid-content-transfer-encoding",
        "invalid-date",
        "invalid-language",
        "invalid-last-translator",
        "language-team-equal-to-last-translator",
        "no-language-header-field",
        "no-package-name-in-project-id-version",
        "no-plural-forms-header-field",
        "no-report-msgid-bugs-to-header-field",
        "no-version-in-project-id-version",
        "stray-previous-msgid",
        "unable-to-determine-language",
        "unknown-poedit-language",
        "unusual-plural-forms",
        "unusual-unused-plural-forms",
        ]

class PoFile:
    def regexKey(self, key: str) -> Pattern:
        """returns a regex to match a key: value pair in po header"""
        return re.compile('^\s*"{key}\s*:\s*(?P<value>(.*\n)*?.*)\\\\n"\s*?$'.format(key=key), flags=re.M)

    def __init__(self, fname: str) -> None:
        self.fname = fname

    def __enter__(self) -> 'PoFile':
        """magic method for with statement. @returns self so it can be used with "as" """
        self.open()
        return self

    def __exit__(self, type, value, traceback) -> None:
        """magic method for with statement"""
        if type is None and value is None and traceback is None:
            self.write()

    def fixedHeaders(self) -> Dict[str, str]:
        """@returns: a dict of key,value parts that should be fixed within the po file"""
        return {"Language": self.lang(),
                "Content-Type": "text/plain; charset=UTF-8",
                "Project-Id-Version": "",
                "Language-Team": "Tails translators <tails-l10n@boum.org>",
                "Last-Translator": "Tails translators",
                }

    def open(self) -> None:
        """read po file content"""
        with open(self.fname, 'r') as f:
            self.content = f.read()
        self.__changed = False

    def lang(self) -> str:
        """@returns: language of filename"""
        exts = self.fname.split(".")
        if len(exts) < 3:
            raise Exception("po file should have a language in his name.", self.fname)
        return exts[-2]

    def check(self, key: str, value: str) -> bool:
        """check if there is "key: value\\n" in PO header"""
        m = self.regexKey(key).search(self.content)
        if not m:
            return False
        # Remove po file soft line breaks, as line length is handled outside this
        fileValue = m.group("value").replace('"\n"',"")
        return (fileValue == value)

    def unifyKey(self, key: str, value: str) -> None:
        """ set value of PO header key to "key: value\\n" """
        if not self.check(key, value):
            self.content = self.regexKey(key).sub('"{key}: {value}\\\\n"'.format(key=key, value=value),
                   self.content
            )
            self.__changed = True

    def write(self) -> None:
        """write file, if content was changed"""
        if self.__changed:
            with open(self.fname, 'w') as f:
                f.write(self.content)

    def msgcat(self, modify=False) -> bool:
        """runs msgcat over file, only the opened copy is modified.
        @modify: if True, the file content gets updated, otherwise only checked.
        @returns: if the content has/needs to be changed
        """
        cmd = ["msgcat",] + MSGCAT_OPTIONS
        if hasattr(self, "content"):
            cmd.append("-") # use stdin as input
            content = self.content.encode()
            process = subprocess.run(cmd,
                    input=content,
                    stdout=subprocess.PIPE,
                    check=True)
            if process.stdout != content:
                if modify:
                    self.content = process.stdout.decode()
                    self.__changed = True
                return True
            else:
                return False

        raise Exception("please run obj.open() before using this method.")

    def i18nspector(self) -> List[str]:
        """@returns a list of issues raised by i18nspector removes allowed issues from @I18NINSPECTOR_ALLOWED_ISSUES.
        """
        cmd = ["i18nspector", "-l", self.lang(), self.fname]
        process = subprocess.run(cmd,
                stdout=subprocess.PIPE,
                check=True)
        issues = []
        for line in process.stdout.decode().strip().split("\n"):
            severity, fname, issue, *content = line.split(" ")
            if issue not in I18NSPECTOR_ACCEPT:
                issues.append(" ".join([severity, issue, *content]))

        return issues

def checkPoFile(fname: str, extended: bool) -> List[str]:
    """check PO file for issues.
    @returns: nothing or a list of errors
    @extended: is used to check the header fields in more detail.
    """
    errors = list()
    with PoFile(fname) as poFile:
        issues = poFile.i18nspector()
        if issues:
            errors.append("i18nspector is not happy:\n\t"+"\n\t".join(issues))

        if poFile.msgcat():
            errors.append("Not rewrapped to 79 chars.")

        if extended:
            for key, value in poFile.fixedHeaders().items():
                if not poFile.check(key, value):
                    errors.append("{key} is not '{value}'.".format(key=key, value=value))

    return errors

def unifyPoFile(fname: str) -> None:
    """unify PO header and run msgcat for file named `fname`"""
    with PoFile(fname) as poFile:
        for key, value in poFile.fixedHeaders().items():
            poFile.unifyKey(key, value)
        poFile.msgcat(modify=True)

if __name__ == '__main__':
    import argparse
    import glob
    import os.path

    parser = argparse.ArgumentParser(description='Unify PO files')
    parser.add_argument('--modify', dest='modify', action='store_true',  help='Modify the PO headers, otherwise only check is done.')
    parser.add_argument('--check-extended', dest='extended', action='store_true',  help='Do extended checks of PO headers.')
    parser.add_argument('--lang', dest='lang', help='all files of a specific language.')
    parser.add_argument('--cached', dest='cached', action='store_true', help='all git staged PO files.')
    parser.add_argument('files', metavar='file', type=str, nargs='*',
        help='list of files to process')
    args = parser.parse_args()

    if args.lang:
        args.files += glob.glob("**/*.{lang}.po".format(lang=args.lang), recursive=True)

    if args.cached:
        # get top level directory of the current git repository
        # git diff returns always relative paths to the top level directory
        toplevel = subprocess.check_output(["git", "rev-parse", "--show-toplevel"])
        toplevel = toplevel.decode()[:-1] # get rid of tailing \n

        # get a list of changes and added files in stage for the next commit
        output = subprocess.check_output(["git", "diff", "--name-only", "--cached", "--ignore-submodules", "--diff-filter=d"])

        # add all po files to list to unify
        args.files += [os.path.join(toplevel,f) for f in output.decode().split("\n") if f.endswith(".po")]

    if not args.files:
        print("WARNING: no file to process :( You may want to add files to operate on. See --help for further information.")

    e = None
    try:
        if args.modify:
            # unify PO headers for a list of files
            pool = multiprocessing.Pool()
            list(pool.map(unifyPoFile, args.files))
        else:
            fine = True
            # check only the headers
            for fname in args.files:
                issues = checkPoFile(fname, extended=args.extended)
                if issues:
                    fine = False
                    issues = [i.replace("\n","\n\t") for i in issues] # indent subissues
                    print("Issues with {fname}:\n\t{issues}".format(fname=fname, issues="\n\t".join(issues)))

            if not fine:
                sys.exit("checked files are not clean.")
    except FileNotFoundError as err:
        if err.filename in ("i18nspector","msgcat"):
            sys.exit("{fname}: command not found\nYou need to install {fname} first. See /contribute/l10n_tricks.".format(fname=err.filename))
        else:
            raise
