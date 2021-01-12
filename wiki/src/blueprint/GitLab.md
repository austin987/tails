This is about migrating our data and workflow from Redmine to GitLab,
which is tracked as [[!tails_ticket 15878]].

[[!toc levels=3]]

<a id="access-control"></a>

# Access control

## Objects

 - _Canonical Git repo_: the authoritative `tails.git` repository
   hosted on GitLab

 - _Major branches_: `master`, `stable`, `testing`, `devel`,
   and possibly `feature/bullseye`

 - _Release tags_: a signed Git tag that identifies the source code
   used to build a specific Tails release; currently all tags
   in the authoritative `tails.git` repository are release tags;
   the tag name is a version number, with '~' replaced by '-'.

 - _Particularly sensitive data_: confidential data that specific teams
   like Fundraising and Accounting need to handle, but that other
   contributors generally don't need direct access to. This definitely
   include issues; this might include Git repositories at some point.

   Note that as of 2019-11-20, it is undefined:

    - What subset of this data can go to a web-based issue tracker or not.<br/>
      This is already a problem with Redmine.<br/>
      Fixing this will require discussions between various stakeholders.

    - What subset of this data could live in a cleartext Git
      repository hosted here or there, as opposed to requiring
      end-to-end encryption between members of these teams.
      This is a hypothetical problem for now.

## Subjects

 - An _admin_ can do anything that other roles can, and:
   - can delete issues
   - can edit team membership
   - MUST comply with our "Level 3" security policy
   - can view issues that contain particularly sensitive data
   - can create new groups and projects that are not forks

 - A _committer_:
   - can push and force-push to any ref in the canonical Git repo,
     including major branches and release tags;<br/>
     incidentally, this ensures the following requirement is met:
   - their branches are picked up by Jenkins; it follows that they
     MUST comply with our "Infrastructure" security policy
   - can merge MRs into major branches
   - can modify issues metadata
   - MAY be allowed to view confidential issues in the main GitLab
     project; if it's the case, then particularly sensitive data MUST
     live somewhere else with stricter access control
   - can edit other users' comments
   - MAY be allowed to add new team members
   - MUST comply with our "Level 3" security policy

 - A _regular, particularly trusted contributor_:
   - can push and force-push to a subset of refs in the canonical Git repo;
     this subset MUST NOT include any major branch nor release tag;<br/>
     this is required to ensure the following requirement is met:
   - their branches are picked up by Jenkins; it follows that they
     MUST comply with our "Infrastructure" security policy
   - can modify issues metadata
   - MAY be allowed to view confidential issues in the main GitLab
     project; if it's the case, then particularly sensitive data MUST
     live somewhere else with stricter access control

 - A _regular contributor_:
   - can fork the Git repositories and push changes to their own fork
   - can modify issues metadata
   - MAY be allowed to view confidential issues in the main GitLab
     project; if it's the case, then particularly sensitive data MUST
     live somewhere else with stricter access control

 - _Anybody with a GitLab account_ on the instance we use:
   - can submit issues
   - can submit MRs

## Implementation

### Relevant GitLab doc

 - [Permissions](https://docs.gitlab.com/ee/user/permissions.html)
 - [Authorization for Merge requests](https://docs.gitlab.com/ce/user/project/merge_requests/authorization_for_merge_requests.html)
 - [Protected Branches](https://docs.gitlab.com/ce/user/project/protected_branches.html)
 - [Groups](https://docs.gitlab.com/ee/user/group/) and [Subgroups](https://docs.gitlab.com/ee/user/group/subgroups/)

### Common settings

 - pipelines: disabled
 - wiki: disabled

### The parent "tails" group

 - Visibility: Public
 - The `root` user has "Owner" access to this group.
 - Release managers have "Reporter" access to every project in this group
   (after releasing a new Tails, they need to postpone issues,
   including confidential ones, and manage group labels),
   until [[!tails_ticket 17589]] is done.
 - Nobody else is a member of this group.
 - Allow users to request access: disabled

### Most public projects

The following applies to each of our public project that
has no dedicated section below:

 - [Protected branch flow](https://docs.gitlab.com/ce/user/project/merge_requests/authorization_for_merge_requests.html#protected-branch-flow):
   it's the most adequate for regular contributors, since it's the
   least disruptive in terms of workflow and habits and requires no
   work to adjust our Jenkins CI setup.
 - We mark our major branches as "Protected".
 - Committers get "Maintainer" access.
 - Maintainers are allowed to merge and to push to
   protected branches.
 - The Git workflow remains unchanged for regular developers who are
   not granted full commit access but have access to our CI:
   they get "Developer" access, can
   push a topic branch to the canonical Git repository and our CI will
   pick it up. The only difference is that they are not restricted to
   pushing to their own `$nickname/*` namespace, which makes things
   simpler and has other advantages, e.g. they can use the `wip/`
   prefix (so our Jenkins CI ignores the branch) and collaborate with
   others on shared branches.
 - Other contributors get access strictly lower than "Developer".
   They push topic branches to their own fork of the repository and
   create merge requests.
 - Our current Jenkins CI jobs generation process remains unchanged.
   (Technically, we could adjust it so it generates CI jobs for _any_
   merge request (based on `refs/merge-requests/*/head`), but this
   would give arbitrary code execution on our CI to _anyone_.
   Our infrastructure is not currently equipped to cope with this.)
 - issues: disabled except for the `tails/tails` project
 - MRs: enabled
 - Allow users to request access: enabled

### rm

 - visibility: private
 - issues: disabled
 - MRs: disabled (gcrypt)
 - repository: enabled
 - Allow users to request access: disabled
 - Nobody has access except RMs

### Public sysadmin projects

Projects:

 - `bitcoin`
 - `bitcoin_libunivalue` → rename to `libunivalue`
 - public `puppet-*` (additional "Maintainer": role-lizard)
 - `jenkins-jobs` (additional "Maintainer": role-lizard)

Properties:

 - public
 - [forking workflow](https://docs.gitlab.com/ce/user/project/merge_requests/authorization_for_merge_requests.html#forking-workflow)
 - issues: disabled (tracked in tails/tails)
 - MRs: enabled
 - regular Tails contributors have "Reporter" access

### tails/accounting, tails/fundraising, tails/private

 - visibility: private
 - issues: enabled
 - MRs: disabled
 - repository: disabled (could be enabled later if these teams
   want their git-remote-gcrypt repo migrated)
 - Allow users to request access: disabled
 - Maintainer access given to:
    - accounting: accounting team
    - fundraising: fundraising team
    - private: tails@ members

### tails/sysadmin

 - visibility: public
 - issues: enabled
 - MRs: disabled
 - repository: disabled (contributors with "Guest" access would be allowed
   to clone it)
 - Allow users to request access: disabled
 - regular contributors have "Guest" access level (so they can create new issues
   but not see confidential ones)
 - Maintainer access given to: sysadmin team

### test-suite-shared-secrets

 - visibility: private
 - issues: disabled
 - MRs: enabled
 - repository: enabled
 - Allow users to request access: disabled
 - Nobody has access except committers

### mirror-pool

 - visibility: public
 - issues: disabled
 - MRs: enabled
 - repository: enabled
 - Allow users to request access: disabled
 - mirrors team members have "Maintainer" access
 - [forking workflow](https://docs.gitlab.com/ce/user/project/merge_requests/authorization_for_merge_requests.html#forking-workflow)
 - regular Tails contributors have "Reporter" access

## Management

With Redmine + Gitolite, we centrally manage, in 1-2 single places, team
membership and the corresponding access level. For example, when someone gets
commit access or joins a team, we add them to the corresponding Gitolite group
and Redmine role. That's very convenient.

If we don't do anything special, to implement the access control specified
above, we would need to:

* During the migration to GitLab: give dozens of users "Reporter", "Maintainer"
  or "Developer" access on dozens of project.
* Day-to-day operations: occasionally, give someone "Reporter", "Maintainer" or
  "Developer" access on dozens of project.

I don't think we want to do any of this manually.

It seems we could maintain user groups via the GitLab web interface and [share
the relevant projects with these user
groups](https://docs.gitlab.com/ce/user/project/members/share_project_with_groups.html).
These groups would not contain any project themselves: their primary purpose is to
manage access to projects in batch.

And in passing, such user groups would allow us to mention a team with one
single `@xyz-team` or `@xyz-group`. For example, `@sysadmins-team`.

Another option would be to use
[subgroups](https://docs.gitlab.com/ce/user/group/subgroups/), and have for
example `tails/accounting-team/accounting`, but references to issues etc.
become pretty long, e.g. "tails/accounting-team/accounting#1234", compared to
"tails/accounting#1234" in the current implementation. Unless there's a way
around this problem, that's a usability deal breaker and we should not use
subgroups merely to simplify access level management.

# Wiki

It's out of scope for the first iteration but at some point, we might
want to migrate our blueprints to GitLab's
[wiki](https://docs.gitlab.com/ce/user/project/wiki/):
[[!tails_ticket 9174]]).

<a id="git"></a>

# Git repositories

Migration includes preserving access rights, which are documented
for each repository below.

## Must be migrated

From `git.tails.boum.org` aka. `git-tails.immerda.ch`:

 - `bitcoin` (public; read-write: sysadmins)
 - `bitcoin_libunivalue` (public; read-write: sysadmins)
 - `chutney` (public; read-write: committers)
 - `htp` (public; read-write: committers)
 - `jenkins-tools` (public; read-write: committers)
 - `liveusb-creator` → rename to `installer` (public; read-write: committers)
 - `network-manager` (public; read-write: committers)
 - `onioncircuits` (public; read-write: committers)
 - `rm` (private; read-write: RMs)
 - `tails-workarounds` → rename to `workarounds` (public; read-write: committers)
 - `test-suite-shared-secrets` (private; read-write: committers)
 - `torbrowser-launcher` (public; read-write: committers)
 - `ux` (public; read-write: committers)
 - `verification-extension` (public; read-write: committers)
 - `whisperback` (public; read-write: committers)

From `puppet-git.lizard`:

 - `etcher-binary` (public; read-write: committers)
 - `mirror-pool` (public; read-write: mirrors team)
 - `mirror-pool-dispatcher` (public; read-write: committers)
 - `promotion-material` (public; read-write: committers)

Read-only mirrors to be migrated from `git.tails.boum.org` aka.
`git-tails.immerda.ch` (with a description that makes it clear
to people with commit access that it's a read-only mirror):

 - public `puppet-*` (public; read-write: role-lizard)
 - `jenkins-jobs` (public; read-write: role-lizard)

## Leave on immerda for now

 - `download-and-verify-extension`: obsolete
 - `iceweasel`: very big, unused since years
 - `thunderbird`: very big, hopefully obsolete soon
 - `uui-binary`: obsolete

<a id="interfaces"></a>

# Interfaces that will need adjustments

## Git repository → various mirrors

Our Git repository keeps a number of mirrors up-to-date:

 - <https://git.tails.boum.org/puppet-tails/tree/files/gitolite/install_remotes.sh>
 - <https://git.tails.boum.org/puppet-tails/tree/files/gitolite/install_hooks.sh>

In particular:

 - repositories that must now be mirrored on our GitLab
   (in addition to, or instead of, the current immerda remote):
    - public `puppet-*`
    - `jenkins-jobs`

## Git repositories → website

A refresh of our website is triggered by:

 - pushing to the master branch of our Git repository
 - pushing to a few "underlay" repositories

Current implementation:

 - <https://git.tails.boum.org/puppet-tails/tree/files/gitolite/install_hooks.sh>
 - <https://git.tails.boum.org/puppet-tails/tree/files/gitolite/hooks/www_website_ping-post-update.hook>
 - <https://git.tails.boum.org/puppet-tails/tree/files/gitolite/hooks/www_website_underlays-post-update.hook>
 - <https://git.tails.boum.org/puppet-tails/tree/templates/website/update-underlays.erb>

## Git repository → Jenkins

Pushing to our Git repository pings Jenkins so it can run jobs as needed:
<https://git.tails.boum.org/puppet-tails/tree/templates/gitolite/hooks/tails-post-receive.erb>

<a id="interfaces-jenkins-git"></a>

## Jenkins → Git

Jenkins jobs are generated on `jenkins.lizard`, from the list of
branches in our main Git repository. For details and pointers to the
corresponding code, see the corresponding
[[blueprint|automated_builds_and_tests/jenkins]].

Here are the kinds of jobs relevant in this discussion:

 - `check_PO_master` runs the `check_po` script on all PO files

    - this script comes from a Git submodule referenced by
      `tails.git`'s master branch (`tails::tester::check_po`)
    - in a Jenkins isobuilder
    - as a sudoer user

 - `build_website_master` runs `./build-website`

    - from `tails.git`'s master branch
    - in a Jenkins isobuilder
    - as a sudoer user

 - `build_Tails_ISO_*` and `reproducibly_build_Tails_ISO_*` run
   `rake build`

    - from the corresponding `tails.git` branch
    - in a Jenkins isobuilder
    - as a sudoer user

 - `test_Tails_ISO_*` run `./run_test_suite`

    - from the corresponding `tails.git` branch
    - in a Jenkins isotester
    - as root via sudo

Wrt. who can push to which branch in `tails.git`, see the "Access control"
section.

## Jenkins → Redmine

Tails images build reproducibility is tested if the corresponding
ticket has "Needs Validation" status:
<https://git.tails.boum.org/puppet-tails/tree/files/jenkins/slaves/isobuilders/decide_if_reproduce>

(Currently disabled:) Email notifications are sent on job status
change if the ticket has "Needs Validation" status:
<https://git.tails.boum.org/puppet-tails/tree/files/jenkins/slaves/isobuilders/output_ISO_builds_and_tests_notifications>

## Ticket triaging → Redmine

Our Redmine email reminder sends email to users who have at least one
ticket assigned to them, that satisfies at least one of these criteria:

 - "Stalled work-in-progress": status "In Progress", that were
   not updated since more than 6 months

 - "Reviews waiting for a long time": not been updated since 45 days
   or more

Current implementation:

 - <https://git.tails.boum.org/puppet-tails/tree/files/redmine/reminder/redmine-remind>
 - <https://git.tails.boum.org/puppet-tails/tree/files/redmine/reminder/email_body>
 - <https://git.tails.boum.org/puppet-tails/tree/manifests/redmine/reminder.pp>

With GitLab one can define policies (YAML) and have them applied automatically
to issues and merge requests:

  - <https://about.gitlab.com/handbook/engineering/quality/triage-operations/#triage-automation>
  - <https://gitlab.com/gitlab-org/quality/triage-ops>
  - <https://gitlab.com/gitlab-org/gitlab-triage>

Potential future work: [[!tails_ticket 17589]].

## Translation platform → Git

A hook ensures that Weblate only pushes changes to our main Git
repository that meet certain conditions:

<https://git.tails.boum.org/puppet-tails/tree/files/gitolite/hooks/tails-weblate-update.hook>

# GitLab hosting options

See <https://salsa.debian.org/tails-team/gitlab-migration/wikis/hosting/comparison>.

# Resources

* Tor's [migration plan](https://nc.torproject.net/s/3MpFApQ7cwfrPZE)
  from Trac to GitLab.
  - Their instance is <https://dip.torproject.org/>.
  - Converted issues: <https://dip.torproject.org/ahf-admin/legacy-20/issues/>
  - Migration problems: <https://pad.riseup.net/p/gitlab-migration-problems>
  - Timeline: none as of 2020-02-27
  - Older meetings:
    - [agenda and notes](https://pad.riseup.net/p/e-q1GP43W4gsY_tYUNxf)
    - 2019-10-15 meeting
      [logs](http://meetbot.debian.net/tor-meeting/2019/tor-meeting.2019-10-15-17.01.html)
    - 2019-10-01 meeting
      [logs](http://meetbot.debian.net/tor-meeting/2019/tor-meeting.2019-10-01-18.00.html)
* KDE migration to GitLab:
  - <https://gitlab.com/gitlab-org/gitlab-foss/issues/57338/designs>
  - <https://gitlab.com/gitlab-org/gitlab/issues/24900>
  - Wrt. workflow (e.g. does everyone push to their own fork or are some people
    allowed to push their topic branches to the main repo?), see:
    - <https://marc.info/?t=155298413600004&r=1&w=2>
    - <https://marc.info/?t=155091510600001&r=3&w=2>
    - <https://marc.info/?l=kde-devel&m=155095845826395&w=2>
    - <https://marc.info/?l=kde-devel&m=155094926223103&w=2>
* Project
  [import/export](https://docs.gitlab.com/ee/user/project/settings/import_export.html):
  successfully tested from Salsa to 0xacab (code, MRs, no issues).
  Notes are authored by the user who performs the import,
  but attributed in the comment itself to their original author.
  Commits are authored by the original author.
  Example: <https://0xacab.org/tails/test-import/>
