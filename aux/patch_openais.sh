HOSTS="nhana1 nhana2"

for host in $HOSTS; do
    ssh $host 'zypper --non-interactive ar  http://openqa.suse.de/assets/repo/SLE-15-Module-Development-Tools-POOL-x86_64-Build486.4-Media1/ DevTools'
    ssh $host 'zypper --non-interactive in patch'
    scp ag_openais.diff $host:/usr/lib/YaST2/servers_non_y2
    ssh $host 'cd /usr/lib/YaST2/servers_non_y2; patch < ag_openais.diff'
done
