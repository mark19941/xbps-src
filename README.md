### Dear User,

We moved our Github organisation to https://github.com/void-linux. Please move
your local repositories and your forks to the new organisation:

#### Change the remote of your clone

```bash
cd /path/to/xbps-src
sed -i 's#/voidlinux/#/void-linux/#g' .git/config
```

#### change your fork on GitHub

Please consider one of the two following methods:

##### remove and fork

1. Go to `https://github.com/<YOUR ACCOUNT NAME>/xbps-src/settings`

2. Scroll down to the *Danger Zone*.

3. Press `Delete this repository`

4. Confirm by entering `xbps-src`.

5. Go to https://github.com/void-linux/xbps-src

6. Press the `fork` button

7. Open a terminal.

8. Go to your local repository:
   `cd /path/to/xbps-src`

9. Force push to the new fork
   `git push -f --all git@github.com:<YOUR ACCOUNT NAME>/${NAME}.git`
