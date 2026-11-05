# Aichatboat

A local browser chatbot powered by the Qwen2.5 1.5B Instruct Q4_K_M GGUF model and `llama.cpp`. Application source can be pushed to Git. The model weights and `llama.cpp` source/build are excluded from Git and are created by `setup.sh` on the machine where you run the app.

## Requirements

The scripts target Linux and require Python 3, Git, `curl`, CMake, a C/C++ compiler/build tools, and `nproc`. Initial setup needs an internet connection to download the model and `llama.cpp` (and build assets). Allow about 1.1 GB for the model plus additional space for the source and compiled runtime.

## Run locally

```bash
./setup.sh
./start.sh
```

Open <http://127.0.0.1:8000>. Press Enter to send, Shift+Enter for a new line, and **New chat** to clear the in-page conversation. Stop the app with Ctrl+C in the terminal.

The browser UI and llama.cpp API bind to localhost only. Chat history is held in browser memory and sent to the local llama.cpp process. See [red.md](red.md) for the architecture, request flow, developer file map, limitations, and troubleshooting.

## Push the source to Git

Run these commands from the project directory. If this folder is not already a Git repository, initialize it first:

```bash
git init
git add .gitignore README.md red.md index.html server.py setup.sh start.sh
git commit -m "Add local llama.cpp chatbot"
git branch -M main
git remote add origin <YOUR_GIT_REPOSITORY_URL>
git push -u origin main
```

Replace `<YOUR_GIT_REPOSITORY_URL>` with the URL of a repository you own. If a remote is already configured, skip `git remote add origin ...`. Later source changes can be committed and pushed normally.

`.gitignore` excludes `/models/` and `/vendor/`. This keeps the 1.07 GB model file, third-party source, and compiled binaries out of Git; `setup.sh` recreates them. The ignore rules do not prevent Git from tracking the app source or documentation.

## Use it from a USB drive on another Linux system

### Option A: Clone the repository directly onto the USB drive

On the target system, mount the USB drive, open a terminal in its desired parent directory, and run:

```bash
git clone <YOUR_GIT_REPOSITORY_URL> local-chat
cd local-chat
./setup.sh
./start.sh
```

Open <http://127.0.0.1:8000> on that computer. For later source updates, stop the app, enter the cloned directory on the USB drive, and run:

```bash
git pull
```

Then restart with `./start.sh`. If a code update changes dependencies or build configuration, rerun `./setup.sh` as directed by that update.

### Option B: Set up once, then carry the complete runtime on USB

With internet access, clone the repo onto the USB drive and run `./setup.sh` there. This downloads the model and builds llama.cpp into the ignored `models/` and `vendor/` directories on that drive. After setup completes, those files remain on the USB drive and can be used without downloading the model again, as long as the target system can run the included binary.

`llama.cpp` is compiled for the system where setup runs. For a different CPU architecture or an incompatible CPU, plug in the drive on the target Linux system and rebuild there:

```bash
cd /path/to/USB/local-chat
FORCE_REBUILD=1 ./setup.sh
./start.sh
```

This removes only `vendor/llama.cpp/build` and recompiles from the source already on the drive. The model weights are retained. `FORCE_REBUILD=1` can also be used when the compiled binary is incompatible with the target CPU. If the USB was cloned fresh, run ordinary `./setup.sh` first; it needs internet access to download the ignored model and llama.cpp source.

### USB filesystem notes

- This project currently targets Linux; the Bash scripts and compiled llama.cpp binary do not run natively on Windows.
- A Linux filesystem such as ext4 is the most reliable choice because it preserves executable permissions. A USB mounted with `noexec` cannot run the compiled server until remounted with execution allowed.
- A shared filesystem such as exFAT may not preserve Linux executable bits. If needed, on Linux run `chmod +x setup.sh start.sh vendor/llama.cpp/build/bin/llama-server` and confirm the drive is not mounted with `noexec`.
- Setup and model files are large. Ensure the USB has enough free space; avoid FAT32 if a future model or artifact exceeds its 4 GB per-file limit.
- Do not unplug the drive while the app is running or while Git/build/download operations are in progress.

The app is designed for local, single-machine use. Do not expose it to a network without adding suitable access controls. See [red.md](red.md) for more operational and security details.
