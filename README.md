
# 🧟 Zoombie_killer (zkill.sh) 🧟‍♀️

**Version: 3.0**
**Author:** Adalberto Brant ([LinkedIn](https://linkedin.com/in/ilha))
**License:** The Unlicense (Public Domain)
**GitHub:** [https://github.com/adalbertobrant/zoombiekiller](https://github.com/adalbertobrant/zoombiekiller)

A robust Bash script to detect, analyze, and optionally eliminate zombie processes on Linux systems. It provides logging, cron-friendly operation, and aims for broad compatibility across distributions.

![](https://github.com/adalbertobrant/zoombiekiller/blob/main/Screenshot%20from%202025-06-05%2010-56-56.png)

## 🤔 What are Zombie Processes?

A zombie process (or "defunct" process) is a process that has completed execution but still has an entry in the process table. This entry is needed to allow the parent process to read its child's exit status. If a parent process doesn't "reap" its zombie children (by calling `wait()` or similar), they remain in the process table.

While zombies don't consume CPU or memory, they do take up a slot in the system's process table, which is a finite resource. A large number of zombies could potentially prevent new processes from starting.

## ✨ Features

* 👻 **Detect Zombies:** Accurately identifies zombie processes system-wide.
* 📊 **Detailed Analysis:** Shows Zombie PID, Parent PID (PPID), User, Status, and Command.
* 👀 **Verbose Mode (`--verbose`):** Displays additional details, including parent process commands.
* 🔪 **Kill Parent Processes (`--kill`):** Option to send `SIGTERM` (default) to the parent processes of zombies.
* 💥 **Force Kill (`--force`):** Option to send `SIGKILL` to parent processes (use with caution!).
* 🗣️ **Interactive Mode (`--interactive`):** Prompts for confirmation before killing each parent process when `--kill` is active.
* 📜 **Logging (`--log FILE`):** Comprehensive logging of actions with timestamps.
    * Defaults to `$HOME/.zkill/zkill.log` when `--cron` or `--verbose` is used without a specified log file.
* ⏰ **Cron Mode (`--cron`):** Enables quiet operation suitable for scheduled tasks, with mandatory logging.
* 🛡️ **Safe Guards:** Avoids attempting to kill critical processes like `init` (PID 1).
* ✅ **Post-Kill Verification:** Checks if zombies were cleared after a kill operation.
* 🎨 **Color-Coded Output:** For easy visual parsing (disabled in cron mode for stdout).
* 🌐 **Broad Compatibility:** Designed to run on most Linux distributions including:
    * Debian & Ubuntu
    * Red Hat, CentOS, Fedora
    * Arch Linux
    * Slackware
    * SUSE Linux
    * ...and other Linux systems using standard `bash`, `ps`, `awk`, `kill` etc.
* ❓ **Helpful Usage Info (`--help`):** Clear instructions on how to use the script.

## ⚙️ Prerequisites

* `bash` (version 4.0+ recommended for some syntaxes, but should be mostly compatible with older versions)
* Standard Linux utilities: `ps`, `awk`, `grep`, `kill`, `sort`, `date`, `mkdir`, `touch`, `dirname`, `read`. These are typically pre-installed on all Linux distributions.

## 🚀 Installation

1.  **Clone the repository or download the script:**
    ```bash
    git clone [https://github.com/adalbertobrant/zoombiekiller.git](https://github.com/adalbertobrant/zoombiekiller.git)
    cd zoombiekiller
    ```
    Or download `zkill.sh` directly.

2.  **Make the script executable:**
    ```bash
    chmod +x zkill.sh
    ```

3.  **(Optional) Place it in a directory in your PATH:**
    For system-wide access, you can move it to a directory like `/usr/local/bin/`:
    ```bash
    sudo mv zkill.sh /usr/local/bin/zkill
    ```
    Then you can run it as `zkill` instead of `./zkill.sh`.

## 🛠️ Usage

```bash
./zkill.sh [OPTIONS]
Available Options:

Option	Description
--kill	Enable killing parent processes of zombies (uses SIGTERM).
--force	Use SIGKILL instead of SIGTERM (requires --kill).
--interactive	Run in interactive mode, asking for confirmation before actions with --kill.
--verbose	Show detailed information and log to default file ($HOME/.zkill/zkill.log).
--log FILE	Specify a custom log file path. Enables logging.
--cron	Cron mode (minimal STDOUT, logs to --log file or default).
--help, -h	Display the help message.

Exportar para Sheets
Examples:

Analyze zombie processes (read-only):

Bash

./zkill.sh
Analyze with verbose output:

Bash

./zkill.sh --verbose
Attempt to kill parent processes using SIGTERM:

Bash

sudo ./zkill.sh --kill
(Use sudo if the parent processes are run by other users or root)

Attempt to kill parent processes interactively:

Bash

sudo ./zkill.sh --kill --interactive
Force kill parent processes using SIGKILL (use with extreme caution!):

Bash

sudo ./zkill.sh --kill --force
Run in cron mode, kill parents, and log to a custom file:

Bash

sudo ./zkill.sh --cron --kill --log /var/log/zkill.log
🕒 Setting up a Cron Job
To run zkill.sh periodically (e.g., hourly) to automatically clean up zombies:

Edit your crontab (usually as root for system-wide effect):

Bash

sudo crontab -e
Add a line like this (adjust path and options as needed):

Fragmento do código

# Run zkill hourly, attempt to kill zombie parents, and log results
0 * * * * /path/to/your/zkill.sh --cron --kill --log /var/log/zkill.log >/dev/null 2>&1
0 * * * *: Runs at the beginning of every hour.
/path/to/your/zkill.sh: Make sure this is the correct absolute path to the script.
--cron: Ensures minimal terminal output.
--kill: Enables killing parent processes.
--log /var/log/zkill.log: Specifies the log file. Ensure the directory exists and is writable by the cron user (usually root).
>/dev/null 2>&1: Silences any residual standard output/error from the cron job itself (script's internal logging handles important info).
⚠️ Disclaimer
Killing parent processes can be dangerous. If a parent process is a critical system service or an application holding unsaved data, terminating it can lead to system instability, data loss, or service interruption.
Always analyze the parent processes carefully before deciding to kill them. The --interactive mode is recommended for manual intervention. Use --force (SIGKILL) only as a last resort, as it doesn't allow the parent process to clean up gracefully.

The script attempts to avoid killing init (PID 1), but you are responsible for how you use this tool.

📜 License
This project is licensed under The Unlicense. This means it is in the public domain, and you are free to use, modify, distribute, and sublicense the code without any restrictions. See the LICENSE file or unlicense.org for more details.

Happy Zombie Hunting! 🏹
