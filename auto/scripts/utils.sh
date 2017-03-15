# This library is meant to be used in bash, with "set -e" and "set -u".

# Returns "" if in undetached head
git_current_branch() {
	local git_ref
	if git_ref="$(git symbolic-ref HEAD)"; then
	    echo "${git_ref#refs/heads/}"
	else
	    echo ""
	fi
}

git_in_detached_head() {
	[ -z "${git_current_branch}" ]
}

git_commit_from_ref() {
	git rev-parse --verify "${@}"
}

git_current_commit() {
	git_commit_from_ref "${@}" HEAD
}

# Returns "" if not a tag
git_tag_from_commit() {
	git describe --tags --exact-match "${1}" 2>/dev/null || :
}

# Returns "" if not on a tag
git_current_tag() {
	git_tag_from_commit $(git_current_commit)
}

git_on_a_tag() {
	[ -n "$(git_current_tag)" ]
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

if [ -n "${@}" ]; then
	eval "${@}"
fi
