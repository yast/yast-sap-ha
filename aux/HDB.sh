#!/bin/bash

VERB=$1

case $VERB in
    version )
        cat <<-END
HDB version info:
version:             2.00.010.00.1491294693
branch:              fa/hana2sp01
git hash:            b894936912f4caf63f40c33746bc63102cdb3ff3
git merge time:      2017-04-04 10:31:33
weekstone:           0000.00.0
compile date:        2017-04-04 10:37:36
compile host:        ld7270
compile type:        rel
END
        ;;
    start )
        sleep 3
        exit 0
        ;;
    stop )
        sleep 3
        exit 0
        ;;
esac