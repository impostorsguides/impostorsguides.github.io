This one is just 3 lines of code with no test file.  I'm mostly including this post for the sake of completeness.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-root){:target="_blank" rel="noopener"}

```
#!/usr/bin/env bash
# Summary: Display the root directory where versions and shims are kept
echo "$RBENV_ROOT"
```

The shebang and summary are unsurprising.  The only actual line of code just `echo`s the value of an environment variable.  When I run `rbenv root` on my terminal to see what this value is, I get `/Users/myusername/.rbenv`.  Easy-peasy, no need to complicate things.

Next file.
