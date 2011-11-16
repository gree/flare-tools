0m1;32mflare-toolsm

Flare-tools is a set of command line tools to maintain a flare cluster.

* flare-stats
  * flare-stats is a command used for aquring statistics of nodes in a flare
    cluster.

* flare-admin
  * flare-admin is a command used for maintaining your flare clusters.

4;32mDESCRIPTION:m

Management Tools for Flare

4;32mSYNOPSIS:m

32mflare-statsm

  $ flare-stats --index-server=flare1.example.com
    hostname:port	      state   role partition balance	items conn behind hit size uptime version
    flare1.example.com:12121 active master	   0	   1	10000  111	0 100	10    12d  1.0.10
    flare2.example.com:12121 active  slave	   0	   1	10000  111	0 100	10    12d  1.0.10
    flare3.example.com:12121 active master	   1	   1	10001  111	0 100	10    12d  1.0.10
    flare4.example.com:12121 active  slave	   1	   1	10001  111	0 100	10    12d  1.0.10

32mflare-adminm

  $ flare-admin [subcommand] [options] [arguments]

4;32mREQUIREMENTS:m

* Flare >= 1.0.14

4;32mINSTALL:m

* Install Flare

Please see the web pages about
{Flare}[http://labs.gree.jp/Top/OpenSource/Flare-en.html] in GREE Labs.

* Install flare-tools
  # gem install flare-tools

4;32mAUTHORS:m

* Kiyoshi Ikehara

4;32mUSAGE:m

32mSPECIFYING YOUR INDEX SERVERm

All the commands in flare-tools have common ways to specifying an index
server.

If your flare index server doesn't have the defalut port (12120), you have to
specify  the hostname (or IP address) and the port of your index node
specifically.

This is done by setting options, --index-server and --index-server-port.
(other tools can also accept these two options.)

  $ flare-stats --index-server=your.index.server --index-server-port=13130

You can also set or FLARE_INDEX_SERVER and FLARE_INDEX_SERVER_PORT environment
 variables. These variables dosen't override the index node specified by
options.

  $ export FLARE_INDEX_SERVER=your.index.server
  $ export FLARE_INDEX_SERVER_PORT=13130
  $ flare-stats

or

  $ export FLARE_INDEX_SERVER=your.index.server:13130
  $ flare-stats

32mflare-statsm

Flare-stats is a dedicated command line tool used for aquiring statistics of
flare nodes. This tool shows a list of nodes in a flare cluster and their
summarized information.

  $ flare-stats

Flare-stats is a short-cut version of stats subcommand of flare-admin. Please
see the section of stats subcommand of flare-admin for farther detail.

flare-stats's options

  Usage: flare-stats [options]
      -h, --help		       shows this message
      -d, --debug		       enables debug mode
      -w, --warn		       turns on warnings
      -i, --index-server=[HOSTNAME]    index server hostname(default:127.0.0.1)
      -p, --index-server-port=[PORT]   index server port(default:12120)
      -q, --qps 		       show qps
	  --wait=[SECOND]	       wait time for repeat(second)
      -c, --count=[REPEATTIME]	       repeat count
	  --delimiter=[CHAR]	       delimiter

32mflare-adminm

Flare-admin consists of a battery of subcommands used for maintaining a flare
cluster. You must specify the hostname and port number of the index node by
telling them as options  or environment variables.

MASTER subcommand

'master' subcommand is used for creating a new partition in a cluster. You
must specify a hostname, a port number, an intitial balance and a partition
number	for each partition in "hostname:port:balance:partition" format. The
specified node will  be changed from 'proxy' state to 'master' state and given
the specified balance after  the construction.

If the node isn't a proxy or the partition already exists, this subcommand
fails.

  $ flare-admin master newmaster1:12131:1:1
  (confirmation)
  (construction)

This subcommand asks you before committing the change to make sure that you
know the  result. If you're convinced of the effect of this subcommand and
doesn't want to be bothered, you can specify --force option to skip the
confirmation steps.

  $ flare-admin master --force newmaster:12131:1:1

RECONSTRUCT subcommand

'reconstruct' subcommand flushes the existing data and reconstruct new
database  from another node.

  $ flare-damin reconstruct node1:12121

PING subcommand

'ping' subcommand checks if the nodes specified as arguments are alive or not
by connecting each node and sending a ping request. If the response is
positive (OK), flare-admin exits with a status code 0 (otherwise 1). You can
check the soundness of a node by this subcommand in scripts.

  $ flare-admin ping

If you want to wait for a node to start up, you should specify --wait option
and  the command repeatedly sends ping requests until the node is available.

  $ flare-admin ping --wait

DEPLOY subcommand (experimental)

'deploy' subcommand generates node settings with control scripts. This
subcommand is mainly used for experiments.

SLAVE subcommand

'slave' subcommand makes a node a slave state and construct the slave
database. Before changing the state, this confirms the current state and the
resulted state. After that, duplication of data starts and the progress is put
on your console.

  $ flare-admin slave newslave1:12132:1:0 newslave2:12132:1:0
  (confirmation)
  (construction)

BALANCE subcommand

'balance' subcommand sets balance parameters of nodes.

  $ flare-admin balance node1:12131:3

LIST subcommand

'list' subcommand shows a node list in a cluater.

  $ flare-admin list

THREADS subcommand (experimental)

'threads' subcommand shows the thread status of the specified node.

  $ flare-admin threads node1:12121

STATS subcommand

'stats' subcommand shows the status of nodes in a cluster.

INDEX subcommand (experimental)

'index' subcommand generates the index file of a cluster.

DOWN subcommand

'down' subcommand turn nodes down.

  $ flare-admin down node1:12121 node2:12121

flare-admin's options

  Usage: flare-admin [subcommand] [options] [arguments]
      -h, --help		       shows this message
      -d, --debug		       enables debug mode
      -w, --warn		       turns on warnings
      -n, --dry-run		       dry run
      -i, --index-server=[HOSTNAME]    index server hostname(default:127.0.0.1)
      -p, --index-server-port=[PORT]   index server port(default:12120)
  subcommands:
  [master] set the master of a partition.
    Usage: flare-admin master [hostname:port:balance:partition] ...
	  --force		       commits changes without confirmation
  [reconstruct] reconstruct the database of nodes by copying.
    Usage: flare-admin reconstruct [hostname:port] ...
	  --force		       commits changes without confirmation
	  --safe		       reconstructs a node safely
  [ping] ping
    Usage: flare-admin ping [hostname:port] ...
	  --wait		       waits for alive
  [deploy] deploy.
    Usage: flare-admin deploy hostname:port:balance:partition ...
	  --proxy-concurrency=[CONC]   proxy concurrency
	  --noreply-window-limit=[WINLIMIT]
				       noreply window limit
	  --thread-pool-size=[SIZE]    thread pool size
	  --deploy-index	       deploys index
	  --delete		       deletes existing contents before deploying
  [slave] make proxy nodes slaves.
    Usage: flare-admin slave [hostname:port:balance:partition] ...
	  --force		       commits changes without confirmation
	  --retry=[COUNT]	       retry count(default:5)
  [balance] set the balance values of nodes.
    Usage: flare-admin balance [hostname:port:balance] ...
	  --force		       commits changes without confirmation
  [list] show the list of nodes in a flare cluster.
    Usage: flare-admin list
	  --numeric-hosts	       shows numerical host addresses
  [threads] show the list of threads in a flare cluster.
    Usage: flare-admin threads
  [stats] show the statistics of a flare cluster.
    Usage: flare-admin stats [hostname:port] ...
      -q, --qps 		       show qps
      -w, --wait=[SECOND]	       wait time for repeat(second)
      -c, --count=[REPEATTIME]	       repeat count
      -d, --delimiter=[CHAR]	       delimiter
  [index] print the index XML document from a cluster information.
    Usage: flare-admin index
      -t, --transitive		       outputs transitive xml
  [down] turn down nodes and destroy their data.
    Usage: flare-admin down [hostname:port] ...
	  --force		       commits changes without confirmation

4;32mLICENSE:m
* NOTYET
* This version is for the internal use of GREE, Inc.

4;32mTHANKS:m
* Masaki FUJIMOTO  (the author of Flare)
* kgws[http://d.hatena.ne.jp/kgws] (the author of old flare-tools)
