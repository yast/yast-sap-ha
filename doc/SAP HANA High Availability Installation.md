SAP HANA High Availability Installation

List of parameters:

| # | Parameter name      | Description                      |
|---|---------------------|----------------------------------|
| 1 | SITE_NAME_PRIMARY   | Site name of the primary system  |
| 2 | SITE_NAME_SECONDARY | Site name of the secondary system|
| 3 | HOSTNAME_PRIMARY    | Host name of the primary system  |
| 4 | HOSTNAME_SECONDARY  | Host name of the secondary system|
| 5 | INSTANCE_NUMBER     | SAP Instance number              |


HANA Preparation

1. Back up the primary system
    `# hdbsql -u system -i 00 "BACKUP DATA USING FILE ('backup')"`
2. Enable SR on the primary node
    `hdbnsutil -sr_enable –-name=$SITE_NAME_PRIMARY`
    Check by executing `hdbnsutil -sr_state`
3. Enable SR on the secondary node
    `hdbnsutil -sr_register --remoteHost=$HOSTNAME_PRIMARY --remoteInstance=$INSTANCE_NUMBER --mode=sync --name=$SITE_NAME_SECONDARY`

Cluster setup

4. Make sure that the `ha_sles` pattern is installed. This includes both the `ha-cluster-bootstrap` and the `yast2-cluster` packages we need.
5. Generate the SSH keys
6. Set up the csync2
7. Set up the SBD with at least one device
8. Set up the corosync (unicast or multicast) with at least one ring


# Joining the cluster

## Steps

### 1. Set NTP
We can simply call `yast2 ntp-client`. **TODO:** include in dependencies.

```ruby
Yast::WFM.ClientExists('ntp-client')

```

### 2. Set Watchdog

Kernel modules configuration:

(03:57:17 PM) imobach: ilyaman: maybe this agent? https://github.com/yast/yast-core/blob/master/agent-modules/conf/modules.scr
(03:58:08 PM) imobach: ilyaman: or better https://github.com/yast/yast-yast2/blob/master/library/system/src/modules/Kernel.rb
(03:58:19 PM) imobach: ilyaman: https://github.com/yast/yast-yast2/blob/master/library/system/src/modules/Kernel.rb#L759
(03:59:11 PM) imobach: ilyaman: I've never used it, but it could be a good starting point

### 3. SSH

1. To check if the host can access the other host without a password:
`ha-cluster-join -c 192.168.103.12 ssh_test`
RC==0 if ok.


