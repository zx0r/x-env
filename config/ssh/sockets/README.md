# OpenSSH Multiplexing Sockets Subsystem (`~/.ssh/sockets/`)

## Purpose
Dedicated subcontainer for active OpenSSH `ControlMaster` UNIX domain sockets (`ControlPath ~/.ssh/sockets/%C`).

## Security Architecture
- **Isolation Guarantee:** Separates transient, live IPC multiplexing sockets (`srw-------`) from static identities (`~/.ssh/identities/`) and configs (`~/.ssh/conf.d/`).
- **Session Hijacking Defense (arXiv:2603.00195):** Eliminates unprivileged local enumeration and unauthorized connection hijacking.
- **Darwin Kernel Headroom:** Fixed 40-character SHA-1 `%C` hash guarantees paths remain strictly under Darwin XNU's 104-byte `sun_path` bound (~64 bytes total, 39 bytes headroom).

## Permissions & Hygiene
- Directory permissions: `chmod 0700 ~/.ssh/sockets`
- Stale socket cleanup: `rm -f ~/.ssh/sockets/*` (or fish alias `ssh-cm-clean`)
