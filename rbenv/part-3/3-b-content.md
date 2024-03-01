The `.github/` dot directory contains just one sub-directory (named `workflows/`) with two files in it:

 - `ci.yml`
 - `release.yml`

Along with the project's root directory, the `.github/` directory is one location where Github will check for configuration and other files for features that Github implements, such as:

 - [Actions](https://web.archive.org/web/20230620152502/https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions){:target="_blank" rel="noopener" }
 - [Organizations](https://web.archive.org/web/20230614124248/https://docs.github.com/en/organizations/collaborating-with-groups-in-organizations/customizing-your-organizations-profile){:target="_blank" rel="noopener" }
 - [Code Owners](https://web.archive.org/web/20230627031710/https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners){:target="_blank" rel="noopener" }
 - [Community health files](https://web.archive.org/web/20230627023817/https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file){:target="_blank" rel="noopener" }
 - [Displaying a sponsor button](https://web.archive.org/web/20230614131530/https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/displaying-a-sponsor-button-in-your-repository){:target="_blank" rel="noopener" } in your repository
 - [README files](https://web.archive.org/web/20230523143525/https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes)
 - Displaying your repo's [Security Policy](https://web.archive.org/web/20230625103450/https://docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository)

Looking more into Github's Workflows feature, I find [the docs page](https://web.archive.org/web/20230620152502/https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions#workflows){:target="_blank" rel="noopener" }:

> ### Workflows
>
> A workflow is a configurable automated process that will run one or more jobs. Workflows are defined by a YAML file checked in to your repository and will run when triggered by an event in your repository, or they can be triggered manually, or at a defined schedule.
>
> Workflows are defined in the .github/workflows directory in a repository, and a repository can have multiple workflows, each of which can perform a different set of tasks. For example, you can have one workflow to build and test pull requests, another workflow to deploy your application every time a release is created, and still another workflow that adds a label every time someone opens a new issue.

So workflows are any actions that Github can take on your behalf.  They can be kicked off manually by you (the code owner), or automatically, either on a regular schedule or in response to things like the creation of a pull request or when someone pushes a new commit to the repository.

Github Workflows uses a file format called [YAML](https://yaml.org/spec/1.2.2/){:target="_blank" rel="noopener" }.

Let's look at the `ci.yml` file first, and then we'll look at `release.yml`.

## `ci.yml`

The file looks like so:

```
name: CI
on: [push, pull_request]

jobs:
  build:
    runs-on: ${ { matrix.os } }
    strategy:
      matrix:
        native_ext: ['', '1']
        os: [ubuntu-latest, macOS-latest]

    steps:
    - uses: actions/checkout@v2
    - name: Install bats
      run: git clone --depth 1 https://github.com/sstephenson/bats.git
    - name: Run tests
      env:
        RBENV_NATIVE_EXT: ${ { matrix.native_ext } }
      run: PATH="./bats/bin:$PATH" test/run
```

Let's break this down.

### The workflow's metadata

```
name: CI
on: [push, pull_request]
```

This workflow's name is `CI`, and it runs when a user pushes code, or when a user creates a pull request.

### Defining the workflow's jobs

```
jobs:
  build:
```

According to [the Workflow docs](https://web.archive.org/web/20230614021117/https://docs.github.com/en/actions/using-jobs/using-jobs-in-a-workflow){:target="_blank" rel="noopener" }:

> A workflow run is made up of one or more jobs, which run in parallel by default.

This workflow has just one job, named `build`.  The word `build` is not a special keyword in the YAML file, the way `jobs` is.  It's just the name that RBENV's core team has chosen for the one and only job in this file.  [The Github docs](https://web.archive.org/web/20230614021117/https://docs.github.com/en/actions/using-jobs/using-jobs-in-a-workflow){:target="_blank" rel="noopener" } give this example of the YAML structure for a workflow:

```
jobs:
  my_first_job:
    name: My first job
  my_second_job:
    name: My second job
```

Here, `my_first_job` and `my_second_job` (which clearly aren't protected keywords in the Github Workflows universe) have the same level of nesting that `build` does in our Workflow.

Later on, we'll see what the steps for the `build` job are.  Before we get to that, there's some metadata for the job itself that we have to define.

### Defining the job's run environment

`runs-on: ${ { matrix.os } }`

Again according to [the docs](https://web.archive.org/web/20230521062254/https://docs.github.com/en/actions/using-jobs/using-jobs-in-a-workflow){:target="_blank" rel="noopener" }:

> Each job runs in a runner environment specified by `runs-on`.

So we're defining the "runner environment" that the `build` job will run on.  What's the "runner environment"?

From [this page of docs](https://web.archive.org/web/20230621115414/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idruns-on){:target="_blank" rel="noopener" }:

> ### jobs.\<job_id\>.runs-on
>
> Use jobs.<job_id>.runs-on to define the type of machine to run the job on.
>
> - The destination machine can be either a [GitHub-hosted runner](https://web.archive.org/web/20230621115414/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#choosing-github-hosted-runners){:target="_blank" rel="noopener" }, [larger runner](https://web.archive.org/web/20230621115414/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#choosing-runners-in-a-group), or a [self-hosted runner](https://web.archive.org/web/20230621115414/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#choosing-self-hosted-runners){:target="_blank" rel="noopener" }.

So by "runner environment", we mean the actual machine that the workflow will run on.  You can specify a machine owned by Github, or a machine sitting on your infrastructure (i.e. self-hosted).  If you choose a self-hosted runner, you have more granular control over the execution environment.

Which option are we choosing here?  The syntax `${{ matrix.os }}` comes from Github Actions, not from YAML.  It represents a variable, which in this case resolves to the value specified below, in `strategy.matrix.os`.  In our case, the value is `[ubuntu-latest, macOS-latest]`.  According to [these docs](https://web.archive.org/web/20230621115414/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#choosing-github-hosted-runners){:target="_blank" rel="noopener" }, these values imply that we're using *Github-hosted* runners.

More info on variables from [the Github Action docs](https://web.archive.org/web/20230621100902/https://docs.github.com/en/actions/learn-github-actions/variables){:target="_blank" rel="noopener" }:

> Variables are interpolated on the runner machine that runs your workflow. Commands that run in actions or workflow steps can create, read, and modify variables.

### Defining a matrix

```
strategy:
  matrix:
    native_ext: ['', '1']
    os: [ubuntu-latest, macOS-latest]
```

Here we're creating a [matrix strategy](https://web.archive.org/web/20230620063502/https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs){:target="_blank" rel="noopener" }.

In Github Actions, a matrix strategy is a way to run a job on a combination of values from your YAML file.  [The docs](https://web.archive.org/web/20230620063502/https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs){:target="_blank" rel="noopener" } provide the following example:

> For example, the following matrix has a variable called version with the value [10, 12, 14] and a variable called os with the value [ubuntu-latest, windows-latest]:
>
> ```
jobs:
  example_matrix:
    strategy:
      matrix:
        version: [10, 12, 14]
        os: [ubuntu-latest, windows-latest]
```
>
> A job will run for each possible combination of the variables. In this example, the workflow will run six jobs, one for each combination of the os and version variables.
>
> ...
>
> For example, the above matrix will create the jobs in the following order:
>
> - {version: 10, os: ubuntu-latest}
> - {version: 10, os: windows-latest}
> - {version: 12, os: ubuntu-latest}
> - {version: 12, os: windows-latest}
> - {version: 14, os: ubuntu-latest}
> - {version: 14, os: windows-latest}

So in our case, our matrix is of size 4:

 - `ubuntu-latest`, with `native_ext` set to the empty string
 - `ubuntu-latest`, with `native_ext` set to `1`
 - `windows-latest`, with `native_ext` set to the empty string
 - `windows-latest`, with `native_ext` set to `1`

A little later, we'll find out what `native_ext` does.

### Defining our first step- checking out the code

```
steps:
    - uses: actions/checkout@v2
```

The leading `-` character in front of the `uses` directive means that `steps` is an array, of which the `uses:` key-value pair is the first item.

[The docs](https://web.archive.org/web/20230621115414/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsuses){:target="_blank" rel="noopener" } tell us that the `uses` directive:

> Selects an action to run as part of a step in your job. An action is a reusable unit of code. You can use an action defined in the same repository as the workflow, a public repository, or in a published Docker container image.
>
> We strongly recommend that you include the version of the action you are using by specifying a Git ref, SHA, or Docker tag. If you don't specify a version, it could break your workflows or cause unexpected behavior when the action owner publishes an update.
>
> ...
>
> Actions are either JavaScript files or Docker containers.

The docs also show several examples of invoking different types of actions, including:

 - Using versioned actions
 - Using a publicly-available action
 - Using an action from a private repo (note- you need to provide credentials)
 - Using an action located on Docker Hub

This [StackOverflow link](https://stackoverflow.com/questions/62045478/what-is-uses-directive-in-github-actions-used-for){:target="_blank" rel="noopener" } gives us some additional info:

> ```
jobs:
  build:
    name: Build
    steps:
      - name: Set up JDK
        uses: actions/setup-java@v1
```
>
> When you see the above config for a GitHub action, it means it uses the v1 version of GitHub action defined in the repository [setup-java](https://github.com/actions/setup-java){:target="_blank" rel="noopener" }.

So in our case, we're running version 2 of [`actions/checkout`](https://github.com/actions/checkout){:target="_blank" rel="noopener" }.  This action checks out the RBENV codebase, so the workflow can run the subsequent steps on it.

The `actions/checkout` docs mention that the `$GITHUB_WORKSPACE` environment variable is used to tell the action which codebase to check out.  This environment variable doesn't appear in the RBENV codebase itself, so presumably it's set in the repo's settings UI, and fetched by Github when the action begins to execute.

### Installing BATS so we can run our tests

```
- name: Install bats
  run: git clone --depth 1 https://github.com/sstephenson/bats.git
```

Again, we can tell by the leading `-` character that this is a new entry in the `steps` array, i.e. the 2nd step in our job.  The docs [tell us](https://web.archive.org/web/20230621115414/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsname){:target="_blank" rel="noopener" } that the `name` directive specifies "A name for your step to display on GitHub."  The name for this step is `Install bats`.

What does this step do?  That's what the `run` directive is for.  From [the docs](https://web.archive.org/web/20230621115414/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsrun){:target="_blank" rel="noopener" }:

> Runs command-line programs using the operating system's shell.

The command that we're running is:

```
git clone --depth 1 https://github.com/sstephenson/bats.git
```

We're pulling down the code for the BATS test runner, which we encountered extensively while looking at the test files for the various RBENV commands.  The `--depth 1` argument creates a shallow clone of the repo, with history truncated to the specified number of commits (in this case, 1 commit).  This is probably for performance reasons, since we don't care about the git history for the purposes of running the tests in CI.

### Actually running the tests

```
- name: Run tests
  env:
    RBENV_NATIVE_EXT: ${{ matrix.native_ext }}
  run: PATH="./bats/bin:$PATH" test/run
```

This is the 3rd and final step in our `build` job.  We name it `Run tests`, and it runs the shell command `PATH="./bats/bin:$PATH" test/run`.  This command:

 - updates `PATH` to include `./bats/bin` so that we have access to [the `bats` executable](https://github.com/sstephenson/bats/tree/master/bin){:target="_blank" rel="noopener" }
 - runs [the `test/run` command](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/run){:target="_blank" rel="noopener" } inside the RBENV codebase, which calls the aforementioned `bats` executable.

 This last step also uses [the `env` directive](https://web.archive.org/web/20230621115414/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsenv){:target="_blank" rel="noopener" }, which sets an environment variable to use in the runner environment.  Here we're setting the `RBENV_NATIVE_EXT` equal to the current value of `native_ext` in our matrix strategy.  If you recall, we run this job in both the `ubuntu-latest` and `windows-latest` environments, and for each of those, we run the job once with `native_ext` (and therefore, `RBENV_NATIVE_EXT`)  set to the empty string, and again with the same variable set to `1`.

 Where is `RBENV_NATIVE_EXT` used?  We saw it several times in the commands which live in `libexec/`, for example [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L30){:target="_blank" rel="noopener" } in the `rbenv` command itself.  If we were unsuccessful in overriding the `realpath` command with our own, more performant version, we continue on with defining our own implementation.  That is, unless `RBENV_NATIVE_EXT` is set to `1`.  If it is, we abort this job and move on to the next one.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's it for `ci.yml`.  Let's move on to `release.yml`.

## `release.yml`

This is the code for `release.yml`:

```
name: Release
on:
  push:
    tags: 'v*'

jobs:
  homebrew:
    name: Bump Homebrew formula
    runs-on: ubuntu-latest
    steps:
      - uses: mislav/bump-homebrew-formula-action@v1.4
        if: "!contains(github.ref, '-')" # skip prereleases
        with:
          formula-name: rbenv
        env:
          COMMITTER_TOKEN: ${{ secrets.COMMITTER_TOKEN }}
```

Most of the syntax here is the same:

### Naming the workflow

```
name: Release
```

We create a workflow named `Release`, which is executed when a commit is pushed.

### Specifying when to run this workflow

```
on:
  push:
    tags: 'v*'
```

[According to the docs](https://web.archive.org/web/20230629043911/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onpushbranchestagsbranches-ignoretags-ignore){:target="_blank" rel="noopener" }, the `tags` directive is used to run the workflow only when the commit has a tag which matches the specified pattern.  In this case, we run the workflow whenever a commit has a tag which starts with the letter `v`.

### Defining the workflow's jobs

```
jobs:
  homebrew:
    name: Bump Homebrew formula
```

The workflow contains one job, named `homebrew`.  The name says the job is intended to increment the version number (a.k.a. the "formula") when a new version is released.  This implies that part of releasing a new formula is tagging a commit with a tag that begins with `v`.  And if we look at [the list of tags on RBENV's Github page](https://github.com/rbenv/rbenv/tags){:target="_blank" rel="noopener" }, we can see that they all start with `v`.

### Defining the job's execution strategy

```
runs-on: ubuntu-latest
```

The `runs-on` strategy for the `Release` workflow differs from the `CI` workflow.  Instead of a matrix strategy, where we ran the workflow on various runner environments and with the `native_ext` option either turned on or off, we only run this workflow once.  That makes sense- the purpose of running `CI` as a matrix was to test RBENV in many different environments.  We don't need to do that here- we just need to bump the version number once.

### Defining the job's steps

```
steps:
  - uses: mislav/bump-homebrew-formula-action@v1.4
```

With the `CI` workflow, we used Github's public `checkout@v2` action to kick things off.  This time, we're using [the `bump-homebrew-formula-action` action](https://github.com/mislav/bump-homebrew-formula-action){:target="_blank" rel="noopener" }, written by a member of the RBENV core team.

Rather than read through the Github repo for this action, we'll move forward assuming that it does what it says on the tin.  This action's README page includes [a "How It Works" section](https://github.com/mislav/bump-homebrew-formula-action#how-it-works){:target="_blank" rel="noopener" }, for those curious.  To learn more about Github Actions, a great exercise would be to build your own.  The Github docs include a "Creating Actions" section [here](https://docs.github.com/en/actions/creating-actions){:target="_blank" rel="noopener" }.

### Specifying when the step should be run

```
if: "!contains(github.ref, '-')" # skip prereleases
```

#### The `if` directive

This step uses [the `if` directive](https://web.archive.org/web/20230629043911/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsif){:target="_blank" rel="noopener" } to specify when the job should be run.

The examples in the docs contain expressions like:

```
if: ${ { github.event_name == 'pull_request' && github.event.action == 'unassigned' }}
```

...and:

```
if: ${ { failure() }}
```

These expressions are wrapped in `${ { } }` syntax.  However, [the docs also state](https://web.archive.org/web/20230629043438/https://docs.github.com/en/actions/learn-github-actions/expressions){:target="_blank" rel="noopener" }:

> When you use expressions in an `if` conditional, you may omit the expression syntax:
>
> `${ { } }`
>
> ...because GitHub automatically evaluates the `if` conditional as an expression.

What is the condition that allows this step to run?

```
"!contains(github.ref, '-')"
```

#### Contexts in Github Actions

The `github.ref` syntax is [a context](https://web.archive.org/web/20230620070702/https://docs.github.com/en/actions/learn-github-actions/contexts){:target="_blank" rel="noopener" }.  According to the docs:

> Contexts are a way to access information about workflow runs, variables, runner environments, jobs, and steps. Each context is an object that contains properties, which can be strings or other objects.

This particular context is `github.ref`.  [Scrolling down in the docs](https://web.archive.org/web/20230620070702/https://docs.github.com/en/actions/learn-github-actions/contexts#github-context){:target="_blank" rel="noopener" } to the "`github` context" section, we see that this refers to:

> The fully-formed ref of the branch or tag that triggered the workflow run. For workflows triggered by push, this is the branch or tag ref that was pushed.

What's a "ref" in `git`?

#### `git` refs

[The `git` docs](https://git-scm.com/book/en/v2/Git-Internals-Git-References){:target="_blank" rel="noopener" } spell it out for us:

> If you were interested in seeing the history of your repository reachable from commit, say, 1a410e, you could run something like git log 1a410e to display that history, but you would still have to remember that 1a410e is the commit you want to use as the starting point for that history. Instead, it would be easier if you had a file in which you could store that SHA-1 value under a simple name so you could use that simple name rather than the raw SHA-1 value.
>
> In Git, these simple names are called "references" or "refs"; you can find the files that contain those SHA-1 values in the `.git/refs` directory.

So "git refs" are the way we use human-friendly strings to refer to computer-friendly SHAs.  The `git` docs say that the refs are stored in the `.git/refs` of any project that's been initialized with `git`.  I navigate into my RBENV directory and run `ls .git/refs`, and I see:

```
$ ls -la .git/refs
total 0
drwxr-xr-x   5 myusername  staff  160 Jun  2 19:09 .
drwxr-xr-x  13 myusername  staff  416 Jun 28 03:56 ..
drwxr-xr-x   4 myusername  staff  128 Jun  2 19:05 heads
drwxr-xr-x   3 myusername  staff   96 May 30 13:28 remotes
drwxr-xr-x   2 myusername  staff   64 May 30 13:28 tags
```

I do the same for `.git/refs/heads`, and I see:

```
$ ls -la .git/refs/heads
total 16
drwxr-xr-x  4 myusername  staff  128 Jun  2 19:05 .
drwxr-xr-x  5 myusername  staff  160 Jun  2 19:09 ..
-rw-r--r--  1 myusername  staff   41 May 31 11:25 impostorsguides
-rw-r--r--  1 myusername  staff   41 May 30 13:28 master
```

I happen to know that `master` and `impostorsguides` are the two branches I currently have in this repo.  I see `impostorsguides` is a file (because its line in the output starts with `-rw`, not with `drw`), so I try to print it with the `cat` command:

```
$ cat .git/refs/heads/impostorsguides

c4395e58201966d9f90c12bd6b7342e389e7a4cb
```

I happen to know that this is the SHA of the version of RBENV that we're reviewing now.

#### The `contains()` function

Back to the original `if` condition:

```
"!contains(github.ref, '-')" # skip prereleases
```

The `contains()` function is a Github Actions expression (docs [here](https://web.archive.org/web/20230629043438/https://docs.github.com/en/actions/learn-github-actions/expressions#contains){:target="_blank" rel="noopener" }).  If our git ref (in our case, the branch or tag name) contains a hyphen, then the expression returns true.  And the `!` at the beginning negates the expression.

#### Summary

So we run this step if the branch or tag name does **not** contain a hyphen.  The comment at the end specifies that this is to avoid running this step on pre-releases.  In the version numbering standard known as "Semantic Versioning" (or "SemVer" for short), [pre-releases are indicated](https://web.archive.org/web/20230629101035/https://semver.org/#spec-item-9){:target="_blank" rel="noopener" } when the version number (i.e. the tag, in the case of RBENV) contains a hyphen:

> 9 . A pre-release version MAY be denoted by appending a hyphen and a series of dot separated identifiers immediately following the patch version... Examples: 1.0.0-alpha, 1.0.0-alpha.1, 1.0.0-0.3.7, 1.0.0-x.7.z.92, 1.0.0-x-y-z.--.

### Defining parameters for the Github Action

```
with:
  formula-name: rbenv
```

Some Github actions require you to pass in values.  The way you do that is via the `with` directive.  Per [the docs](https://web.archive.org/web/20230629043911/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepswith){:target="_blank" rel="noopener" }, the `with` directive defines:

> ...A map of the input parameters defined by the action. Each input parameter is a key/value pair. Input parameters are set as environment variables. The variable is prefixed with `INPUT_` and converted to upper case.

In our case, we're defining one parameter, which will be accessible inside the `bump-homebrew-formula-action@v1.4` action.

### Specifying environment variables

```
env:
  COMMITTER_TOKEN: ${{ secrets.COMMITTER_TOKEN }}
```

According to [the docs for this directive](https://web.archive.org/web/20230629043911/https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsenv){:target="_blank" rel="noopener" }, `env` lets you define environment variables for a step.  You can also use the same directive at the job or workflow levels, depending on the scope you want to give that variable.

Here we're adding an env var called `COMMITTER_TOKEN`, and setting it equal to the value of the `COMMITTER_TOKEN` property of our `secrets` context.  Per [the docs](https://web.archive.org/web/20230620070702/https://docs.github.com/en/actions/learn-github-actions/contexts#secrets-context){:target="_blank" rel="noopener" }, this context "...contains the names and values of secrets that are available to a workflow run."  Per the "Minimal Usage Example" from the action's README file:

> ```
> env:
>          # the personal access token should have "repo" & "workflow" scopes
>          COMMITTER_TOKEN: ${{ secrets.COMMITTER_TOKEN }}
> ```

We can infer that the name `COMMITTER_TOKEN` refers to the committer's [personal access token from Github](https://web.archive.org/web/20230623175505/https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens){:target="_blank" rel="noopener" }.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's the end of the files inside the `.github/` directory and its `workflows/` subdirectory.  Let's move on.
