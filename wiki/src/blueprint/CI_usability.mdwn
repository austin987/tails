[[!meta title="CI usability issues"]]

Here, we collect CI usability issues.

This effort started with [[!tails_ticket 16959]], in order to have a better
understanding of how our current setup feels to its users.

This data will help us define our strategy for the future of our CI (e.g.
switching to GitLab CI, switching to Jenkins pipelines, or merely removing some
UX stumbling blocks without changing the big picture of our setup).

[[!toc levels=2]]

# Cumbersome navigation

* Finding the Jenkins jobs corresponding to a given branch or MR is cumbersome, because:

  - Jenkins does not readily expose the full CI pipeline progress & outcome
    ⇒ developers and reviewers need to track/check the result of 3 different jobs.
    ([[!tails_gitlab tails/sysadmin/-/issues/17071]])

  - CI results are not visible on GitLab MRs
    ([[!tails_gitlab tails/sysadmin/-/issues/17070]])

# Misleading output

* The _Revision: $COMMIT_ information, that's displayed on the page of
  a `test_Tails_ISO_*` job run, may be incorrect. In order to determine what
  commit the test suite was run from, look for `git reset --hard` in the console
  output of the job run.

* The success/failure of the `keep_node_busy_during_cleanup` job does
  not matter.

# Missing information

* When a Jenkins build aborts due to a timeout, no summary of the scenarios
  that did run is generated. ([[!tails_ticket 17678]])

# Suboptimal jobs prioritizing

* The fact all jobs are treated equally causes trouble during our release
  process: the RM sometimes has to wait a long time for the builds they care
  about to run, while our CI resources are kept busy by other builds that
  arguably could wait a bit longer. ([[!tails_gitlab
  tails/sysadmin/-/issues/9760]])

# Very long feedback loop

As of August 2020, a full CI pipeline takes almost 7 hours to run.

This problem is tracked on [[!tails_gitlab tails/sysadmin/-/issues/16960]] and
[[a dedicated blueprint|blueprint/hardware_for_automated_tests_take3]], which
focuses on the hard facts.

Here we focus on feelings and human perception.

## Release Managers

Several CI jobs are on the critical path of our release process, which forces
the RM to wait. In a situation that can already be stressful, this can be tough
on their patience.

## Developers

Some developers have adapted their workflow around this constraint. They feel
that making the CI loop twice shorter would not make a significant difference to
them: they would anyway come back to it the next day.

Another developer, who routinely use a replica of our CI setup that's twice
faster, instead feels that this allows them to iterate faster, complete work on
a given task earlier, and limit context-switching. With a 3.5 hours feedback
loop, it becomes possible _in a single day_ to:

1. do some work
2. wait for CI results
3. fix bugs found by this first iteration
4. send the second iteration to CI
5. check the CI results for the second iteration the next day

# Robustness problems

Note: this is not about robustness problems inherent to our test suite,
that don't depend much on _how_ we run the test suite.

* When GitLab is down or connectivity between lizard and GitLab is poor, many
  Jenkins jobs — if not all — fail. ([[!tails_gitlab
  tails/sysadmin/-/issues/17715]])

