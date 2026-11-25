# Monitoring application deployment

Ansible project that deploys the [cursor monitoring application](https://github.com/fairozb/cursor_monitoring_application.git) (`main`) onto one AWS EC2 Linux server.

The playbook installs Git and Python, clones the repository into `/opt/monitoring_application`, creates a virtual environment, installs `requirements.txt`, writes `.env` mode `0600` owned by the `monitoring` user, and runs the app as that user under systemd. The process listens on `0.0.0.0:5000` and starts again after reboot. Open it in a browser at [http://98.93.201.202:5000](http://98.93.201.202:5000).

| File | Purpose |
|---|---|
| `ansible.cfg` | Project defaults. Inventory is `inventory.ini`. Host key checking stays on. Privilege escalation is off unless a task asks for it. Root module temp files use `~/.ansible/tmp`. |
| `inventory.ini` | Group `monitoring`, host `98.93.201.202`, SSH user `root`. |
| `playbook.yaml` | Idempotent deployment. |
| `templates/monitoring-app.service.j2` | `monitoring-app` systemd unit. |
| `.gitignore` | Keeps secrets, keys, and local inventory overrides out of Git. |

## Control node

Run the playbook from this directory on a machine with:

- Ansible 2.14 or newer
- OpenSSH client
- `sshpass` (required by `--ask-pass`)

The target must already have Python 3 so Ansible can connect. The play then installs Git, pip, venv, and build packages. Flask 3.1 needs Python 3.9 or newer. Debian-family and Red Hat-family distributions are supported (Ubuntu, Debian, Amazon Linux, RHEL, Rocky, AlmaLinux, CentOS, Fedora).

## Inventory

`inventory.ini` points at the EC2 instance:

- Group: `monitoring`
- Host: `98.93.201.202`
- User: `root`

The SSH password is not stored in the inventory. Enter it when Ansible prompts. A commented `ansible_password=CHANGE_ME` line is only an example; leaving it active would override `--ask-pass`.

The instance must allow root SSH with password authentication (`PermitRootLogin` and `PasswordAuthentication`). No sudo password is requested, because the SSH user is root.

Before the first connection, add the server host key (host key checking is enabled):

```bash
mkdir -p ~/.ssh
ssh-keyscan -H 98.93.201.202 >> ~/.ssh/known_hosts
```

## Deploy

From this directory:

```bash
ansible-playbook playbook.yaml --ask-pass
```

Ansible prompts, in order:

1. SSH password for `root` (`--ask-pass`)
2. `SECRET_KEY`, entered twice
3. `ADMIN_PASSWORD`, entered twice

Both application prompts hide what you type. On the first run, enter both values. The playbook writes `/opt/monitoring_application/.env` as mode `0600`, owned by `monitoring`. The file sets:

- `SECRET_KEY`
- `ADMIN_PASSWORD`
- `FLASK_HOST=0.0.0.0`
- `FLASK_PORT=5000`
- `DEMO_MODE=false`

Values are double-quoted. Newlines in a pasted secret are removed. `"` and `\` are escaped.

A later run uses the same command. Press Enter at both application prompts to keep `SECRET_KEY` and `ADMIN_PASSWORD`. The playbook still sets `FLASK_HOST=0.0.0.0` and `FLASK_PORT=5000` in the existing file. Entering only one of the two secrets fails the play before `.env` is changed. Entering both values replaces `.env` and restarts the service.

The application resets the `admin` password hash from `ADMIN_PASSWORD` on every start. After a restart, sign in as `admin` with the password currently in `.env`.

When the bind address or port changes, `monitoring-app` restarts before the health checks. The play checks that the service is `active`, that `http://127.0.0.1:5000/login` returns HTTP 200, and that a socket is listening on `0.0.0.0:5000`.

A second run with unchanged Git, packages, dependencies, `.env`, and unit file should not restart the service.

## Open the application

Allow inbound TCP port 5000 to `98.93.201.202` in the EC2 security group, then open this URL in a browser:

```text
http://98.93.201.202:5000
```

Sign in as `admin`.

## Directories

| Path | Purpose |
|---|---|
| `/var/lib/monitoring` | Home directory of the `monitoring` service user |
| `/var/lib/monitoring/.ansible/tmp` | Ansible module temp files for tasks that run as `monitoring` |
| `/opt/monitoring_application` | Git checkout, virtual environment, `.env`, and SQLite data |

The service user's home is separate from the Git destination. Ansible's default temp path is `~/.ansible/tmp`. When the home directory was `/opt/monitoring_application`, that temp directory made `git clone` fail because the destination was not empty.

An existing `monitoring` account is updated in place. Its home field is set to `/var/lib/monitoring`. `move_home` is off, so `/opt/monitoring_application` is not moved or deleted. The playbook removes only `/opt/monitoring_application/.ansible` when that leftover temp directory is present. A Git checkout, `.env`, `.venv`, and files under `instance/` stay in place.

Clone, virtualenv, and pip tasks run as `monitoring` with `ansible_remote_tmp` set to `/var/lib/monitoring/.ansible/tmp`.

## What the playbook changes on the server

- Packages for Git, Python 3, pip, venv, CA certificates, and builds
- System user and group `monitoring` (`/usr/sbin/nologin`, home `/var/lib/monitoring`)
- Clone of `https://github.com/fairozb/cursor_monitoring_application.git` at `/opt/monitoring_application`
- Virtual environment at `/opt/monitoring_application/.venv`
- `/opt/monitoring_application/.env`
- `/etc/systemd/system/monitoring-app.service`, enabled and started

`monitoring-app` runs `/opt/monitoring_application/.venv/bin/python /opt/monitoring_application/run.py` as `monitoring`. systemd sets `HOME` from the account record (`/var/lib/monitoring`). The process working directory remains `/opt/monitoring_application`.

## Secrets and Git

Do not put the SSH password, `SECRET_KEY`, or `ADMIN_PASSWORD` in this repository. Passwords are prompted. Tasks that write `.env` use `no_log`.

`.gitignore` excludes `.env`, `inventory.local.ini`, key material (`*.pem`, `*.key`), vault password files, Ansible retry files, and logs. Keep `ansible_password` commented in `inventory.ini`.

## Troubleshooting

**SSH password or permission denied.** Confirm `98.93.201.202`, user `root`, and that the AMI allows root password login. Run with `--ask-pass`. Do not uncomment `ansible_password`.

**Host key verification failed.** Run the `ssh-keyscan` command above, or connect once with `ssh root@98.93.201.202` and accept the key.

**Python is older than 3.9.** The play stops before creating the virtual environment. Use an AMI whose `python3` is 3.9 or newer.

**`python3` is missing entirely.** Ansible cannot gather facts until a Python 3 interpreter exists at `/usr/bin/python3`. Install it on the instance, then re-run.

**`python3-venv` or pip build errors.** Re-run the playbook. Debian installs `python3-venv`; Red Hat installs `python3-pip` and the compiler packages used when wheels are unavailable.

**Git clone failed because the destination is not empty.** Confirm `getent passwd monitoring` shows home `/var/lib/monitoring`. The playbook deletes only `/opt/monitoring_application/.ansible`. If the directory still has other files and no `.git` directory, the play stops before clone and leaves those files in place. Move only unexpected leftovers aside, then re-run.

**Git clone failed to reach GitHub.** The instance needs outbound HTTPS. `ca-certificates` is installed before the clone. The clone runs as `monitoring`.

**Port 5000 is already in use.** `wait_for` fails and `monitoring-app` may restart-loop. On the server: `ss -ltnp | grep 5000`. Stop the other listener and re-run. This playbook keeps the application port at 5000.

**The browser cannot open http://98.93.201.202:5000.** On the server, `ss -ltn sport = :5000` should show `0.0.0.0:5000`. If it does, allow inbound TCP 5000 in the EC2 security group. Confirm `FLASK_HOST=0.0.0.0` and `FLASK_PORT=5000` in `/opt/monitoring_application/.env`.

**Service is not active.** On the server:

```bash
systemctl status monitoring-app
journalctl -u monitoring-app -e
```

A bad `.env` line or a missing virtualenv shows up there. On SELinux-enforcing Red Hat images, a denial can stop the unit even when the files are present; check the same journal and the audit log.

**Login page check failed.** The health check calls `http://127.0.0.1:5000/login` from the EC2 instance. A connection refused result means the process is down. The play also requires a listening socket on `0.0.0.0:5000`. Confirm `FLASK_HOST` and `FLASK_PORT` in `.env`.

**Admin password does not work.** It is whatever `ADMIN_PASSWORD` was the last time the service started. Re-run the playbook and enter a new `SECRET_KEY` and `ADMIN_PASSWORD` together, then sign in again.

**Sudo password prompt.** This project does not ask for one. Tasks that drop to `monitoring` use sudo from root, which does not need a password. If a task fails because `sudo` is not installed, install `sudo` and re-run.

**Updating the monitoring account fails because the user is in use.** Stop the service, then re-run: `systemctl stop monitoring-app`. This happens only while the account home is still `/opt/monitoring_application`. Later runs leave the home directory unchanged.
