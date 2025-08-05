# RCI-COMPUTE
Set of bash scripts to easily spawn slurm compute node with given parameters and establish ssh tunnel for subsequent use.

## Under the hood

The tool automates the following workflow:

1. **Job Management**: Checks for existing Slurm jobs with the name "VSCodeSSH" to avoid creating duplicates
2. **Resource Allocation**: Submits a Slurm job with specified resources (CPU, memory, time, partition) that runs `rci_start_sshd.sh`
3. **SSH Server Setup**: The remote script starts an unprivileged SSH server on the allocated compute node using user-generated host keys
4. **Port Assignment**: Uses a random port (20000-30000) for the SSH server to avoid conflicts
5. **Network Tunneling**: Creates a local SSH tunnel from your machine through the login node to the compute node's SSH server
6. **Configuration Management**: Automatically updates your `~/.ssh/config` with a "rci-compute" host entry for easy access

The tunnel allows direct SSH access to the compute node as if it were running locally, enabling tools like VS Code Remote SSH to work seamlessly with allocated Slurm resources.

## Setup

### Prerequisites
Having setup passwordless login to RCI. Tested on Ubuntu 24.04.2 LTS.

### Remote machine
On the remote machine we have to setup an ssh server configuration, which allows us to run `/usr/bin/sshd` without priviliges.

1. generate HostKeys
```bash
export SSHD_HOME=~/.sshd_user
mkdir -p $SSHD_HOME

ssh-keygen -t rsa -b 2048 -f $SSHD_HOME/ssh_host_rsa_key -N '' -q
ssh-keygen -t ed25519 -f $SSHD_HOME/ssh_host_ed25519_key -N '' -q
```

2. create the following config in `~/.sshd_user/sshd_config`
```~/.sshd_user/sshd_config
# point at your newly generated HostKeys
HostKey     ~/.sshd_user/ssh_host_rsa_key
HostKey     ~/.sshd_user/ssh_host_ed25519_key

# where to look for your authorized_keys
AuthorizedKeysFile   ~/.ssh/authorized_keys

# allow publickey auth
PubkeyAuthentication yes

# don't load any PAM or other system hooks
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin no

# allow only your user to connect
AllowUsers $USER
```

3. copy remote script `rci_start_sshd.sh` to your home directory on rci and make it executable (`chmod +x rci_start_sshd.sh`)

### Local machine
Modify the default values in `rci_compute.sh` and either source it from or add it to your `.bashrc` (or your prefered shell counterparts). 

Values to modify:
- `USER_DEFAULT`: defaults to `$USER` (current user)
- `PARTITION_DEFAULT`: defaults to `"cpufast"`
- `TIME_DEFAULT`: defaults to `"04:00:00"`
- `MEM_DEFAULT`: defaults to `"32G"`
- `CPUS_DEFAULT`: defaults to `8`
- `JOB_NAME`: defaults to `"VSCodeSSH"`
- `IDENTITY_FILE`: defaults to `"$HOME/.ssh/rci"` - update with your key used for passwordless authentication
- `RCI_LOGIN_HOST`: defaults to `"rci"` - update with the name of your RCI host as configured in your `.ssh/config`

## Usage
If default values of the job suit your needs, then establishing the connection is simple:
```bash
rci_compute start
```
Leave the shell open. If the connection is broken (network change, local machine suspend) use the same command to reconnect to existing job. 
To stop the job run:
```bash
rci_compute stop
```
Exiting the shell with an established tunnel is not enough.

For more detailed configuration of job resources use:
```bash
rci_compute start [-u|--user USER] [-p|--partition PART] [-t|--time TIME] [-m|--mem MEM] [-r|--cpus CPUS]
```

After establishing the tunnel you can use `ssh rci-compute` to connect directly to the running job or use VSCode (and other tools) to connect to the newly created host in `.ssh/config`.

SSH server logs for each job are stored in `~/sshd-<JOBID>.log` on the remote machine for debugging purposes.

## Known issues
- Force users to setup their default user to the one they use remotely -> there is no need for -u flag in most cases
- Job name identification will fail if there are multiple jobs with the same name but different users - critical if used by multiple people
- Currently does not support GPU partitions because they require additional argument `--gres=gpu:1`
- Allow user to specify if they want to forward the agent to the remote session 
- Fingerprints for each node are different, user has to accept it before establishing the tunnel (VSCode requires this as well)