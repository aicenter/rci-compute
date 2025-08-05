# RCI-COMPUTE
Set of bash scripts to easily spawn slurm compute node with given parameters and establish ssh tunnel for subsequent use.

## Under the hood

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
# Listen only on the loopback interface
ListenAddress 127.0.0.1
Port        2222

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

Values to modify
- `IDENTITY_FILE` with your key used for passwordless authentication in your `.ssh/config`
- `RCI_LOGIN_HOST` name of rci host given in your `.ssh/config`

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
rci_compute start [-u|--user USER] [-p|--partition PART] [-t|--time TIME] [-m|--mem MEM] [-r|--cpus CPUS]"
```

## Known issues
- force users to setup their default user to the one they use remotely -> there is no need for -u flag in the 
- jobname identification will fail if there are more jobs but different users - critical if used by more people
- currently does not support gpu partititions because they require `--gres=gpu:1`
- logs from `rci_start_sshd.sh` are stored inside home directory - anoying
- allow user to specify if they want to forward the agent to the remote session 