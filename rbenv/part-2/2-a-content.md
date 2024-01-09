Having finished reading [the code for RBENV's shims](https://docs.google.com/document/d/1xG_UdRde-lPnQI7ETjOHPwN1hGu0KqtBRrdCLBGJoU8/edit), we need to decide what's next.

I see the following directories in the Github repo:


<center>
  <a target="_blank" href="/assets/images/screenshot-19mar2023-237pm.png">
    <img src="/assets/images/screenshot-19mar2023-237pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

When I look inside each of these directories, I see that `libexec/` has the most files in it.  While this doesn't *necessarily* mean that it's the most important directory, it does indicate that a lot of development has taken place in that directory.  It also means that, if we were to finish reading through all the files in that directory, we will have taken a big step toward understanding the codebase as a whole.

Additionally, the last line in the shim file we just examined was the following:

```
exec "/usr/local/bin/rbenv" exec "$program" "$@"
```

This essentially boils down to `exec`'ing the `/usr/local/bin/rbenv` command.  The file `/usr/local/bin/rbenv` is a [symlink](https://web.archive.org/web/20221126123116/https://devdojo.com/devdojo/what-is-a-symlink){:target="_blank" rel="noopener"} to `/usr/local/Cellar/rbenv/1.2.0/bin`, which in turn is just a symlink to `/usr/local/Cellar/rbenv/1.2.0/libexec/rbenv`:

```
$ ls -la /usr/local/bin/rbenv

lrwxr-xr-x  1 myusername  admin  31 Apr 12 09:44 /usr/local/bin/rbenv -> ../Cellar/rbenv/1.2.0/bin/rbenv

$ ls -la /usr/local/Cellar/rbenv/1.2.0/bin

total 0
drwxr-xr-x   3 myusername  admin   96 Sep 29  2021 .
drwxr-xr-x  10 myusername  admin  320 Apr 12 09:44 ..
lrwxr-xr-x   1 myusername  admin   16 Sep 29  2021 rbenv -> ../libexec/rbenv

$ ls -la /usr/local/Cellar/rbenv/1.2.0/libexec/rbenv

-rwxr-xr-x  1 myusername  admin  2901 Apr 12 09:44 /usr/local/Cellar/rbenv/1.2.0/libexec/rbenv
```

So the `libexec/rbenv` command would be a logical next step in our analysis.  Coincidentally, this is also the first file in the `libexec/` directory, so it's already the file we'd start with if we were to work our way through the files in that directory.

For all of these reasons, I decide to start there.
