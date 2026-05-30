How It Works
SSD Mount: /mnt/data is mounted directly from your host → /workspace/data in the container (fast, native speed).
SSHFS Mount: The container itself runs sshfs to mount the remote server into /workspace/ssh — bypassing Windows’ /mnt/localhost overhead.
Security: You can use SSH keys stored in your host and forwarded into the container.