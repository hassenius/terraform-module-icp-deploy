import os, json, ConfigParser

hgfile = '/tmp/icp-host-groups.json'
hostfile = '/opt/ibm/cluster/hosts'
ipfile = '/tmp/cluster-ips.txt'

# Exit if we don't need to do anything
if os.stat(hgfile).st_size == 0:
  exit(1)

# Load the hostgroup info from file if provided
with open(hgfile, 'r') as stream:
  hostgroups = json.load(stream)

# Create the hostfile
hf = open(hostfile, 'w')
h = ConfigParser.ConfigParser(allow_no_value=True)

ips = []
for group in hostgroups.keys():
  h.add_section(group)
  for host in hostgroups[group]:
    ips.append(host)
    h.set(group, host)

h.write(hf)
hf.close()

# Write a list of ip addresses, removing duplicates
i = open(ipfile, 'w')
i.write(",".join(list(set(ips))))
i.close()
