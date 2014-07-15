#!/bin/bash

LANG=C

git status | \
	grep -E "modified:\s.+.pot?$" | \
	cut -d ' ' -f 4 | \
	while read po ; do
		git checkout "$po" ;
	done
