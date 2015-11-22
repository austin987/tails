#!/usr/bin/python

# The MIT License
# 
# Copyright (c) 2011 Christopher Pound
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# lc.py -- language confluxer (http://www.ruf.rice.edu/~pound/lc.py)
#
# - Written by Christopher Pound (pound@rice.edu), July 1993.
# - Loren Miller suggested I make sure lc starts by picking a
#   letter pair that was at the beginning of a data word, Oct 95.
# - Cleaned it up a little bit, March 95; more, September 01
# - Python version, Jul 09
#
# The datafile should be a bunch of words from some language
# with minimal punctuation or garbage (# starts a comment). 

from __future__ import with_statement
from optparse import OptionParser
import random
import re
import sys

class Pseudolanguage:

    def __init__(self, **dict):
        """Set up a new pseudolanguage"""
        dict.setdefault('name', '')
        self.name = dict['name']
        self.parsed = False
        self.data = {}
        self.inits = {}
        self.pairs = {}

    def incorporate(self, files):
        """Load list of files for this pseudolanguage into self.data"""
        self.parsed = False
        for f in files:
            words = []
            with open(f) as text:
                for line in text:
                    line = line.strip()
                    line = re.sub(r"#.*", "", line)
                    words.extend(re.split(r"\s+", line))
                self.data[f] = words

    def delete(self, files):
        """Delete a list of languages from self.data"""
        self.parsed = False
        for f in files:
            del self.data[f]

    def parse(self):
        """Parse pseudolanguage's data into self.inits and self.pairs"""
        if not self.parsed:
            self.inits.clear()
            self.pairs.clear()
            for f in self.data:
                for word in self.data[f]:
                    word += ' '
                    if len(word) > 3:
                        if self.inits.has_key(word[0:2]):
                            self.inits[word[0:2]].append(word[2:3])
                        else:
                            self.inits[word[0:2]] = [word[2:3]]
                    pos = 0
                    while pos < len(word)-2:
                        if self.pairs.has_key(word[pos:pos+2]):
                            self.pairs[word[pos:pos+2]].append(word[pos+2])
                        else:
                            self.pairs[word[pos:pos+2]] = [word[pos+2]]
                        pos = pos + 1
            self.parsed = True
 
    def dump(self):
        """Print the current parsed data; use pickle for inflatable dumps"""
        self.parse()
        print 'name = """', self.name, '"""'
        print "dump = { 'inits': ", self.inits, ","
        print "'pairs': ", self.pairs, " }"

    def generate(self, number, min, max):
        """Generate list of words of min and max lengths"""
        self.parse()
        wordlist = []
        while len(wordlist) < number:
            word = random.choice(self.inits.keys())
            while word.find(' ') == -1:
                word += random.choice(self.pairs[word[-2:]])
            word = word.strip()
            if len(word) >= min and len(word) <= max:
                wordlist.append(word)
        return wordlist

if __name__ == '__main__':

    usage = "usage: %prog [options] datafile1 [datafile2 ...]"
    parser = OptionParser(usage=usage, version="%prog 1.0")
    parser.add_option("-d", "--dump", action="store_true", 
                     dest="dump", default=False,
                     help="Dump internal representation of the pseudolanguage")
    parser.add_option("-g", "--generate", type="int", dest="num",
                     help="Generate specified number of words")
    parser.add_option("--min", type="int", dest="min", default=3,
                     help="Set the minimum length of each word")
    parser.add_option("--max", type="int", dest="max", default=9,
                     help="Set the maximum length of each word")
    parser.add_option("--name", dest="name", default=' ',
                     help="Set the name of the pseudolanguage")
    (options, args) = parser.parse_args()

    aLanguage = Pseudolanguage(name=options.name)
    aLanguage.incorporate(args)
    if options.dump:
        aLanguage.dump()
    else:
        results = aLanguage.generate(options.num, options.min, options.max)
        for word in results:
            print word
