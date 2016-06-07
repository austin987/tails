# This library is meant to be used in bash, with "set -e" and "set -u".

current_branch() {
	git branch | awk '/^\* / { print $2 }'
}

on_a_tag() {
	git describe --tags --exact-match $(git rev-parse --verify HEAD 2>/dev/null) >/dev/null 2>/dev/null
}

base_branch() {
	cat config/base_branch | head -n1
}

branch_name_to_suite() {
	local branch="$1"

	echo "$branch" | sed -e 's,[^.a-z0-9-],-,ig'  | tr '[A-Z]' '[a-z]'
}

fatal() {
	echo "$*" >&2
	exit 1
}

git_tag_exists() {
	local tag="$1"

	test -n "$(git tag -l "$tag")"
}

version_was_released() {
	local version="$1"

	version="$(echo "$version" | tr '~' '-')"
	git_tag_exists "$version"
}

version_in_changelog() {
	dpkg-parsechangelog | awk '/^Version: / { print $2 }'
}

previous_version_in_changelog() {
	dpkg-parsechangelog --offset 1 --count 1 | awk '/^Version: / { print $2 }'
}
