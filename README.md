# funkypitt apt repository

A small apt repository on GitHub Pages for the Reader's desktop apps
(https://gallaz.ch/eink): https://funkypitt.github.io/apt-repo

```
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://funkypitt.github.io/apt-repo/funkypitt.gpg | sudo tee /etc/apt/keyrings/funkypitt.gpg >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/funkypitt.gpg] https://funkypitt.github.io/apt-repo stable main" | sudo tee /etc/apt/sources.list.d/funkypitt.list
sudo apt update && sudo apt install readers-calendar readers-tasks
```

## How it works

- `repos.txt` lists the GitHub repositories whose latest release carries `.deb` files.
- `build.sh` downloads them into `pool/`, writes `dists/stable/main/binary-{amd64,arm64}/Packages`
  (the packages are architecture-independent, listed for both), and signs the `Release`
  file (`InRelease`, `Release.gpg`).
- The `update` workflow runs it every day and on demand (`gh workflow run update.yml`),
  and commits the result; GitHub Pages serves the branch as is.
- The signing key is the `APT_SIGNING_KEY` secret (ASCII-armored private key, no passphrase);
  the public key is `funkypitt.gpg` / `funkypitt.asc`.

To add an app: put its repository name in `repos.txt` (its releases must attach a `.deb`),
push, and the workflow rebuilds.
