# software-installation

Generating SSH keys for Git on an AWS Ubuntu instance (like EC2) enables secure, passwordless authentication to repositories such as GitHub. Use Ed25519 keys for modern security or RSA as a fallback. [docs.github](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

## Prerequisites
Ensure you're connected to your AWS Ubuntu EC2 instance via SSH as a user like `ubuntu` (e.g., `ssh -i your-key.pem ubuntu@your-ec2-ip`). Update packages first: `sudo apt update && sudo apt install git -y`. [dev](https://dev.to/aanis434/how-to-set-up-ssh-keys-for-github-on-ubuntu-ec2-instance-d2p)

## Generate SSH Key
Run this command in the terminal, replacing `your_email@example.com` with your Git provider email:
```
ssh-keygen -t ed25519 -C "your_email@example.com"
```
- Press Enter to save to default `~/.ssh/id_ed25519`.
- Optionally set a passphrase for extra security (or leave blank). [docs.github](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

For older systems without Ed25519 support, use RSA: `ssh-keygen -t rsa -b 4096 -C "your_email@example.com"`. [youtube](https://www.youtube.com/watch?v=Z-HNfaYZ4Dc)

## Add to SSH Agent
Start the agent and add the key:
```
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```
This loads your private key for use. [youtube](https://www.youtube.com/watch?v=Z-HNfaYZ4Dc)

## Copy Public Key
Display and copy the public key:
```
cat ~/.ssh/id_ed25519.pub
```
Copy the output (starts with `ssh-ed25519`). On Ubuntu, pipe to clipboard if `xclip` is installed: `cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard` (install via `sudo apt install xclip`). [youtube](https://www.youtube.com/watch?v=Z-HNfaYZ4Dc)

## Add to GitHub (or Similar)
1. Log into GitHub > Settings > SSH and GPG keys > New SSH key.
2. Paste the public key, add a title (e.g., "AWS Ubuntu EC2"), and save. [docs.github](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account)

## Configure Git
Set your Git identity:
```
git config --global user.name "Your Name"
git config --global user.email "your_email@example.com"
```

## Test Connection
Verify with:
```
ssh -T git@github.com
```
Expect: "Hi username! You've successfully authenticated..." [youtube](https://www.youtube.com/watch?v=Z-HNfaYZ4Dc)

## Set Permissions
Ensure SSH directory security:
```
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```
Now clone repos via SSH: `git clone git@github.com:username/repo.git`. [theserverside](https://www.theserverside.com/blog/Coffee-Talk-Java-News-Stories-and-Opinions/GitHub-SSH-Key-Setup-Config-Ubuntu-Linux)
