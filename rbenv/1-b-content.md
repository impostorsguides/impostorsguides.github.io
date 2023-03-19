This directory has the following structure:

<p style="text-align: center">
  <img src="/assets/images/github-workflows-dir-structure.png" width="70%" alt="The directory structure of .github/workflows"  style="border: 1px solid black; padding: 0.5em">
</p>

The fact that this directory starts with a “.” tells me it has something to do with configuration.  And I happen to know that Github offers a feature called Workflows, so I'm pretty sure this is the directory to store configuration files for RBENV's Github Workflow setup.

Looking more into Github's Workflows feature, I find [the docs page](https://web.archive.org/web/20220806092745/https://docs.github.com/en/actions/using-workflows):

About workflows

A workflow is a configurable automated process that will run one or more jobs. Workflows are defined by a YAML file checked in to your repository and will run when triggered by an event in your repository, or they can be triggered manually, or at a defined schedule.

Workflows are defined in the .github/workflows directory in a repository, and a repository can have multiple workflows, each of which can perform a different set of tasks. For example, you can have one workflow to build and test pull requests, another workflow to deploy your application every time a release is created, and still another workflow that adds a label every time someone opens a new issue.

At this point, I have a superficial understanding of what Github Workflows does, and what the purpose of the `.github/workflows` is.  I'm faced with the choice of either:


continuing to dive into things like the syntax used in each of the two YAML files, what specifically those files are set up to do, etc., or


Moving on to the next directory and perhaps coming back to the Workflows dir later.

I don't think there's any right or wrong choice for now, and I wager there's a higher-value directory ahead if I keep moving along, so that's what I'll do.


