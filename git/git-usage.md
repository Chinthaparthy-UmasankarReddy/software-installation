Since you are managing a microservices architecture on AWS EKS, your Git workflow needs to be sharp—especially when handling multiple services or complex deployments.

Here is a categorized list of essential Git commands and the real-world DevOps scenarios where you'll actually use them.

---

## 1. Setup & Configuration
Used when setting up a new workstation or starting a new microservice.

| Command | Use Case |
| :--- | :--- |
| `git init` | Initialize a new local repository for a project. |
| `git clone <url>` | Download an existing project (like your e-commerce app) to your machine. |
| `git config --global user.name "Your Name"` | Set your identity for all commits on your Windows 11 machine. |
| `git remote add <name> <url>` | Link your local folder to a remote repo (e.g., adding `k8s` as a remote). |

---

## 2. The Daily Workflow (Stage & Commit)
The bread and butter of saving your progress.

| Command | Use Case |
| :--- | :--- |
| `git status` | **Check this constantly.** See which files are changed, staged, or untracked. |
| `git add <file>` | Move a specific file to the "staging area" (preparing it for a commit). |
| `git add .` | Stage **all** changes in the current directory. |
| `git commit -m "message"` | Save your staged changes with a descriptive note. |
| `git commit --amend` | Fix the message of your *very last* commit (if you haven't pushed yet). |

---

## 3. Branching & Merging
Essential for working on features (like a "cart" service) without breaking the `main` code.

| Command | Use Case |
| :--- | :--- |
| `git branch <name>` | Create a new feature branch. |
| `git checkout -b <name>` | Create a new branch and switch to it immediately. |
| `git checkout <branch>` | Switch back to another branch (e.g., back to `main`). |
| `git merge <branch>` | Join a feature branch back into your current branch. |
| `git branch -d <name>` | Delete a branch after the feature is merged. |

---

## 4. Remote Syncing
Moving code between your local machine and GitHub.

| Command | Use Case |
| :--- | :--- |
| `git push <remote> <branch>` | Upload your local commits to GitHub. |
| `git pull <remote> <branch>` | Fetch changes from GitHub and merge them into your local code. |
| `git fetch <remote>` | Download changes from GitHub **without** merging them (safe way to check updates). |
| `git remote -v` | See all remote connections (origin, k8s, etc.) and their URLs. |

---

## 5. Troubleshooting & "Time Travel"
Used when something goes wrong (like the "unrelated histories" error you saw).

| Command | Use Case |
| :--- | :--- |
| `git log --oneline` | See a condensed history of your commits. |
| `git diff` | See exactly what lines of code changed since your last commit. |
| `git reset --hard HEAD` | **The "Panic Button."** Discard all local changes and go back to the last commit. |
| `git revert <hash>` | Create a new commit that undoes a previous mistake (safe for shared repos). |
| `git stash` | Temporarily "hide" your uncommitted changes so you can switch branches quickly. |
| `git stash pop` | Bring your hidden changes back. |

---

## 6. Pro-Level DevOps Commands
Commands you'll likely use as your EKS project grows.

* **`git cherry-pick <hash>`**: Grab one specific commit from a different branch and apply it to your current one.
* **`git rebase main`**: Re-write your branch history to start from the latest `main` commit (keeps history clean).
* **`git clean -fd`**: Remove all untracked files and folders from your directory (careful, this is permanent).
To round out your Git toolkit, these are the "heavy lifting" commands. As you scale your e-commerce project on EKS, these will help you manage complex debugging, clean up history, and handle sub-modules.

---

## 1. Inspection & Debugging
When you need to find out *who* changed a line of code or *when* a bug was introduced.

| Command | Use Case |
| :--- | :--- |
| **`git blame <file>`** | See line-by-line who last modified a file and in which commit. Great for microservices when you need to ask a teammate why a specific environment variable was changed. |
| **`git show <hash>`** | See the full details (metadata and content changes) of a specific commit. |
| **`git grep "text"`** | Search for a specific string (like an AWS Access Key or a service name) across your entire repository history. |
| **`git reflog`** | The "Safety Net." It shows a log of every time the HEAD changed. If you accidentally `reset --hard` and lost work, you can find the lost commit hash here. |

---

## 2. Advanced History Management
Used to keep your GitHub commit graph looking professional and linear.

| Command | Use Case |
| :--- | :--- |
| **`git rebase -i HEAD~n`** | **Interactive Rebase.** Allows you to "squash" multiple messy commits into one clean one before pushing to `main`. |
| **`git tag -a v1.0 -m "msg"`** | Mark a specific point in history as important. In DevOps, tags are often used to trigger **Jenkins pipelines** to deploy a specific version to Production. |
| **`git log --graph --oneline`** | Visualizes the branch structure in your terminal so you can see where branches diverged and merged. |



---

## 3. Dealing with Sub-projects
Since you are working on a **5-microservice e-commerce app**, you might eventually split services into their own repos or use shared libraries.

* **`git submodule add <url>`**: Include another repository inside your current one as a subdirectory. Useful if you have a shared "Common-Logging" library used by all 5 services.
* **`git submodule update --init`**: If you clone a project that has submodules, you run this to actually download the contents of those submodules.

---

## 4. Maintenance & Cleanup
Over time, Git databases can get bulky.

* **`git gc`**: "Garbage Collect." It compresses your file revisions and removes unreachable objects to speed up your local repo.
* **`git remote prune origin`**: If branches were deleted on GitHub by a teammate, this command removes the "stale" tracking branches from your local machine.

---

## 5. The "I'm Stuck" Commands
Specific to the environment you're using (Windows 11 + EKS/Microservices).

* **`git config --global credential.helper wincred`**: Tells Windows to remember your GitHub password/token so you don't have to type it every time you push.
* **`git archive --format=zip HEAD > project.zip`**: Creates a clean zip file of your current code without the `.git` folder—perfect for sending a quick snapshot of your code to someone else.



### Pro Tip for your EKS Project:
Since you are deploying to **AWS EKS**, ensure you have a `.gitignore` file that includes:
* `.terraform/` (Infrastructure files)
* `*.tfstate` (Sensitive state files)
* `node_modules/` or target folders (Language-specific build artifacts)
* `.env` (Secrets/Credentials)
To clone a specific branch without downloading the entire history of every other branch, you have two main options depending on whether you want just that branch or the ability to switch to others later.

---

## 1. The Standard Way (Get the branch + everything else)
This is the most common method. It clones the whole repository but automatically "checks out" the specific branch you want so you can start working immediately.

```bash
git clone -b <branch_name> <repository_url>
```
* **Example:** `git clone -b feature-shopping-cart https://github.com/Chinthaparthy-UmasankarReddy/k8s-5microservices-ecommerce-app.git`

---

## 2. The "Lightweight" Way (Single Branch Only)
If you are working on a massive project (like a microservices repo with huge history) and you **only** care about one branch, use the `--single-branch` flag. This saves disk space and download time because it ignores all other branches.

```bash
git clone -b <branch_name> --single-branch <repository_url>
```
* **Use Case:** Perfect for **CI/CD pipelines** (like your Jenkins setup) where you only need the code for a specific deployment and don't want to waste 8GB of RAM or bandwidth on the rest.

---

## 3. What if you already cloned the repo?
If you've already run `git clone` and realized you're on `main` but need to be on a different branch that exists on GitHub:

1.  **Fetch the updates**: 
    `git fetch origin`
2.  **Switch to the branch**: 
    `git checkout <branch_name>`

---

## ⚠️ A Note for your EKS Project
Since you are dealing with **5 microservices**, you might have branches named after environments (e.g., `dev`, `staging`, `prod`) or specific services (e.g., `auth-service`, `payment-service`). 



If you are setting up a Jenkins agent to deploy just the **Payment Service**, using the `--single-branch` method is the most efficient way to keep your Jenkins workspace clean and fast.

