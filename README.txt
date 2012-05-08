:title: README

= flare-tools

http://labs.gree.jp/Top/OpenSource/Flare-en.html

Flare-tools is a collection of command line tools to maintain a flare cluster.

* flare-stats
  * flare-stats is a command used for aquring statistics of nodes in a flare cluster.

* flare-admin
  * flare-admin is a command used for maintaining your flare clusters.

== DESCRIPTION:

Management Tools for Flare

Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
Copyright:: Copyright (C) GREE, Inc. 2011.
License::   MIT-style

== SYNOPSIS:

=== flare-stats

 $ flare-stats [options] [hostname:port] ...

=== flare-admin

 $ flare-admin [subcommand] [options] [arguments]

== REQUIREMENTS:

* Flare >= 1.0.14

== INSTALL:

* Install Flare

Please see the web pages about {Flare}[http://labs.gree.jp/Top/OpenSource/Flare-en.html] in GREE Labs.

* Install flare-tools
 # gem install flare-tools

== AUTHORS:

* Kiyoshi Ikehara

== USAGE:

=== SPECIFYING YOUR INDEX SERVER

All the commands in flare-tools have common ways to specify an index server.

If your flare index server doesn't listen to the defalut port (12120), you have to specify 
its hostname (or IP address) and port of your index node specifically.

This is done by setting options, --index-server and --index-server-port.
(other tools can also accept these two options.)

 $ flare-stats --index-server=your.index.server --index-server-port=13130

You can also set or FLARE_INDEX_SERVER and FLARE_INDEX_SERVER_PORT environment variables.
These variables dosen't override the index node specified by options.

 $ export FLARE_INDEX_SERVER=your.index.server
 $ export FLARE_INDEX_SERVER_PORT=13130
 $ flare-stats

or 

 $ export FLARE_INDEX_SERVER=your.index.server:13130
 $ flare-stats

=== flare-stats

Flare-stats is a dedicated command line tool used for aquiring statistics of flare nodes.
This tool shows a list of nodes in a flare cluster and their summarized information.

 $ flare-stats --index-server=flare1.example.com
   hostname:port             state   role partition balance    items conn behind hit size uptime version
   flare1.example.com:12121 active master         0       1    10000  111      0 100   10    12d  1.0.10
   flare2.example.com:12121 active  slave         0       1    10000  111      0 100   10    12d  1.0.10
   flare3.example.com:12121 active master         1       1    10001  111      0 100   10    12d  1.0.10
   flare4.example.com:12121 active  slave         1       1    10001  111      0 100   10    12d  1.0.10

Flare-stats is a short-cut version of stats subcommand of flare-admin.
Please see the stats subcommand section of flare-admin for further detail.

==== flare-stats's options

 Usage: flare-stats [options]
     -h, --help                       shows this message
     -d, --debug                      enables debug mode
     -w, --warn                       turns on warnings
     -i, --index-server=[HOSTNAME]    index server hostname(default:127.0.0.1)
     -p, --index-server-port=[PORT]   index server port(default:12120)
     -q, --qps                        show qps
         --wait=[SECOND]              wait time for repeat(second)
     -c, --count=[REPEATTIME]         repeat count
         --delimiter=[CHAR]           delimiter

=== flare-stdmin

Flare-admin consists of a battery of subcommands used for maintaining a flare cluster.
You must specify the hostname and port number of the index node by telling them as options 
or environment variables.

==== MASTER subcommand

'master' subcommand is used for creating a new partition in a cluster.
You must specify a hostname, a port number, an intitial balance and a partition number 
for each partition in "hostname:port:balance:partition" format. The specified node will 
be changed from 'proxy' state to 'master' state and given the specified balance after 
the construction.

If the node isn't a proxy or the partition already exists, this subcommand fails.

 $ flare-admin master newmaster1:12131:1:1
 (confirmation)
 (construction)

This subcommand asks you before committing the change to make sure that you know the 
result. If you're convinced of the effect of this subcommand and doesn't want to be
bothered, you can specify --force option to skip the confirmation steps.

 $ flare-admin master --force newmaster:12131:1:1

==== RECONSTRUCT subcommand

'reconstruct' subcommand flushes the existing data and reconstruct new database from 
another node. This subcommand can be applied to both slaves and masters. 
If you reconstruct a master, the node will be turned down and one of slave nodes will 
take over master's role.

 $ flare-admin reconstruct node1:12121
 (confirmation)
 (construction)

If you want to reconstruct all nodes in a cluster, you can specify --all option.

 $ flare-admin reconstruct --all
 (confirmation)
 (construction)
 ...

This subcommand asks you before committing the change to make sure that you know the 
result. If you're convinced of the effect of this subcommand and doesn't want to be
bothered, you can specify --force option to skip the confirmation steps.

 $ flare-admin reconstruct --force node1:12121
 (construction)

==== PING subcommand

'ping' subcommand checks if the nodes specified as arguments are alive or not by
connecting each node and sending a ping request. If the response is positive (OK),
flare-admin exits with a status code 0 (otherwise 1). You can check the soundness
of a node by this subcommand in scripts.

 $ flare-admin ping
 alive

If you want to wait for a node to start up, you should specify --wait option and 
the command repeatedly sends ping requests until the node is available.

 $ flare-admin ping --wait

==== DEPLOY subcommand (experimental)

'deploy' subcommand generates node settings with control scripts.
This subcommand is mainly used for experiments.

==== SLAVE subcommand

'slave' subcommand makes a node a slave state and construct the slave database.
Before changing the state, this confirms the current state and the resulted state.
After that, duplication of data starts and the progress is put on your console.

 $ flare-admin slave newslave1:12132:1:0 newslave2:12132:1:0
 (confirmation)
 (construction)

==== BALANCE subcommand

'balance' subcommand sets balance parameters of nodes.

 $ flare-admin balance node1:12131:3 node2:12131:2
 (confirmation)
 (setting balance)

==== LIST subcommand

'list' subcommand shows a node list in a cluster. 

 $ flare-admin list
 node                             partition   role  state balance
 server1:12121                            -  proxy active       0

This subcommand just refers the cluster information the index node in a cluster.
If 'stats' subcommand fails, please check the node status by this subcommand.

==== THREADS subcommand (experimental)

'threads' subcommand shows the thread status of the specified node.

 $ flare-admin threads node1:12121

==== STATS subcommand

'stats' subcommand shows the status of nodes in a cluster.

 $ flare-admin stats
 hostname:port               state   role partition balance    items conn behind hit size uptime version
 server1:12121              active master         0       1       30   11      0  70    0     1d  1.0.14
 server2:12121              active  slave         0       1       35   19      0  68    0     1h  1.0.14

This subcommand also display qps (query per second) statistics of each node.

 $ flare-admin stats --qps --count=100
 ...
 hostname:port               state   role partition balance    items conn behind hit size uptime version   qps qps-r qps-w
 server1:12121              active master         0       1       30   11      0  70    0     1d  1.0.14 100.3  50.1  50.2
 server2:12121              active  slave         0       1       35   19      0  68    0     1h  1.0.14  52.1     0  52.1
 ...

==== INDEX subcommand (experimental)

'index' subcommand generates the index file of a cluster.

 $ flare-admin index
 <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
 <!DOCTYPE boost_serialization>
 <boost_serialization signature="serialization::archive" version="4">
 <node_map class_id='0' tracking_level='0' version='0'> ... </node_map>

==== DOWN subcommand

'down' subcommand turn nodes down.

 $ flare-admin down node1:12121 node2:12121

==== flare-admin's options

Usage: flare-admin [subcommand] [options] [arguments]
    -h, --help                       show this message
    -d, --debug                      enable debug mode
    -w, --warn                       turn on warnings
    -n, --dry-run                    dry run
    -i, --index-server=[HOSTNAME]    index server hostname(default:)
    -p, --index-server-port=[PORT]   index server port(default:)
        --log-file=[LOGFILE]         output log to LOGFILE
subcommands:

[dumpkey] dump key from nodes.
  Usage: flare-admin dumpkey [hostname:port] ...
    -o, --output=[FILE]              output to file
    -f, --format=[FORMAT]            output format [csv]
    -p, --partition=[NUMBER]         partition number
    -s, --partition-size=[SIZE]      partition size
        --bwlimit=[BANDWIDTH]        bandwidth limit (bps)
        --all                        dump form all partitions

[master] construct a partition with a proxy node for master role.
  Usage: flare-admin master [hostname:port:balance:partition] ...
        --force                      commit changes without confirmation
        --retry=[COUNT]              specify retry count (default:10)
        --activate                   change node's state from ready to active

[balance] set the balance values of nodes.
  Usage: flare-admin balance [hostname:port:balance] ...
        --force                      commit changes without confirmation

[down] turn down nodes and move them to proxy state.
  Usage: flare-admin down [hostname:port] ...
        --force                      commit changes without confirmation

[restore] restore data to nodes. (experimental)
  Usage: flare-admin restore [hostname:port]
    -i, --input=[FILE]               input from file
    -f, --format=[FORMAT]            input format [tch]
        --bwlimit=[BANDWIDTH]        bandwidth limit (bps)
        --include=[PATTERN]          include pattern
        --prefix-include=[STRING]    prefix string
        --exclude=[PATTERN]          exclude pattern
        --print-keys                 enables key dump to console

[stats] show the statistics of a flare cluster.
  Usage: flare-admin stats [hostname:port] ...
    -q, --qps                        show qps
    -w, --wait=[SECOND]              specify wait time for repeat(second)
    -c, --count=[REPEATTIME]         specify repeat count
    -d, --delimiter=[CHAR]           spedify delimiter

[verify] verify the cluster. (experimental)
  Usage: flare-admin verify
        --key-hash-algorithm=[TYPE]  key hash algorithm
        --use-test-data              store test data
        --debug                      use debug mode
        --64bit                      (experimental) 64bit mode
        --verbose                    use verbose mode
        --meta                       use meta command
        --quiet                      use quiet mode

[remove] remove a node. (experimental)
  Usage: flare-admin remove
        --force                      commit changes without confirmation
        --wait=[SECOND]              specify the time to wait node for getting ready (default:30)
        --retry=[COUNT]              retry count(default:5)
        --connection-threshold=[COUNT]
                                     specify connection threashold (default:2)

[dump] dump data from nodes. (experimental)
  Usage: flare-admin dump [hostname:port] ...
    -o, --output=[FILE]              output to file
    -f, --format=[FORMAT]            specify output format [default,csv,tch]
        --bwlimit=[BANDWIDTH]        specify bandwidth limit (bps)
        --all                        dump from all master nodes
        --raw                        raw dump mode (for debugging)

[threads] show the list of threads in a flare cluster.
  Usage: flare-admin threads [hostname:port]

[slave] construct slaves from proxy nodes.
  Usage: flare-admin slave [hostname:port:balance:partition] ...
        --force                      commit changes without confirmation
        --retry=[COUNT]              specify retry count(default:10)
        --clean                      clear datastore before construction

[list] show the list of nodes in a flare cluster.
  Usage: flare-admin list
        --numeric-hosts              show numerical host addresses

[activate] activate 
  Usage: flare-admin down [hostname:port] ...
        --force                      commit changes without confirmation

[ping] ping
  Usage: flare-admin ping [hostname:port] ...
        --wait                       wait for OK responses from nodes

[index] print the index XML document from a cluster information.
  Usage: flare-admin index
        --output=[FILE]              output index to a file

[reconstruct] reconstruct the database of nodes by copying.
  Usage: flare-admin reconstruct [hostname:port] ...
        --force                      commit changes without confirmation
        --safe                       reconstruct a node safely
        --retry=[COUNT]              specify retry count (default:10)
        --all                        reconstruct all nodes

== THANKS:
* Masaki FUJIMOTO  (the author of Flare)
* kgws[http://d.hatena.ne.jp/kgws] (the author of old flare-tools)
