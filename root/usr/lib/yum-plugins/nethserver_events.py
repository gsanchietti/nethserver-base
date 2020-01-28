#
# Copyright (C) 2012 Nethesis S.r.l.
# http://www.nethesis.it - support@nethesis.it
# 
# This script is part of NethServer.
# 
# NethServer is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License,
# or any later version.
# 
# NethServer is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with NethServer.  If not, see <http://www.gnu.org/licenses/>.
#

from yum.plugins import TYPE_CORE
import os.path
import os
import rpm
import nethserver.ptrack

requires_api_version = '2.1'
plugin_type = (TYPE_CORE,)

signal_event = '/sbin/e-smith/signal-event'
events_dir = '/etc/e-smith/events'

def has_update_event(x):
    """
    Determine if the given x has a corresponding e-smith *-update event
    x can be either a package name (string) or an rpm.hdr object
    """
    if(isinstance(x, rpm.hdr)):
        o = x
        n = x['name']
    elif(isinstance(x, str)):
        n = x
        o = None
    else:
        raise Exception("invalid object type %s" % str(x.__class__))

    if n not in has_update_event.cache:
        if o is None:
            try:
                o = rpm.TransactionSet().dbMatch('name', n).next()
            except StopIteration:
                o = {'FILENAMES': []}
        has_update_event.cache[n] = '%s/%s%s' % (events_dir, n, '-update') in o['FILENAMES']

    return has_update_event.cache[n]


has_update_event.cache = {}

def read_package_list():
    """
    Query RPM db for any nethserver* package and return the list of
    package names, preserving the dependency order. RPM 'Require' tags
    are parsed.
    """

    ts = rpm.TransactionSet()
    mi = ts.dbMatch()
    packages = []
    touples = []

    for h in mi:
        if not has_update_event(h['name']):
            continue

        deps = []

        for dep in h[rpm.RPMTAG_REQUIRENAME]:
            if has_update_event(dep):
                deps.append(dep)

        if len(deps) == 0:
            touples.append(['$root',h['name']])
        else:
            map(lambda x: touples.append([x,h['name']]), deps)

    packages = topological_sort(touples)
    packages.remove('$root')
    return packages

class GraphError(Exception):
    pass

def topological_sort(edges):
    """topologically sort vertices in edges.
    edges: list of pairs of vertices. Edges must form a DAG.
           If the graph has a cycle, then GraphError is raised.
    returns: topologically sorted list of vertices.
    see http://en.wikipedia.org/wiki/Topological_sorting

    thanks to https://github.com/tengu/py-tsort
    """
    # resulting list
    L=[]

    # maintain forward and backward edge maps in parallel.
    st,ts={},{}

    def prune(s,t):
        del st[s][t]
        del ts[t][s]

    def add(s,t):
        try:
            st.setdefault(s,{})[t]=1
        except Exception, e:
            raise RuntimeError(e, (s,t))
        ts.setdefault(t,{})[s]=1

    for s,t in edges:
        add(s,t)

    # frontier
    S=set(st.keys()).difference(ts.keys())

    while S:
        s=S.pop()
        L.append(s)
        for t in st.get(s,{}).keys():
            prune(s,t)
            if not ts[t]:       # new frontier
                S.add(t)

    if filter(None, st.values()): # we have a cycle. report the cycle.
        def traverse(vs, seen):
            for s in vs:
                if s in seen:
                    raise GraphError('contains cycle: ', seen)
                seen.append(s) # xx use ordered set..
                traverse(st[s].keys(), seen)
        traverse(st.keys(), list())
        assert False, 'should not reach..'

    return L

def list_unique(l):
    s = set()
    return filter(lambda x: x not in s and not s.add(x) , l) 

# Deprecated method (used by system-adjust action)
def filter_update_events(packages):
    return pkgs2events(packages)

def pkgs2events(packages):
    return map(lambda p: "%s-update" % p, packages)

def postverifytrans_hook(conduit):
    """ The yum post-RPM-transaction hook """

    installed = []
    trigger_uninstall = False
    events = []
    # NethServer packages are those with *-update event defined:
    nethserver_packages = read_package_list()

    if conduit.confBool("main", "verbose", default=0): #if verbose
        conduit.info(2, "Signaling NethServer update events")

    ts = conduit.getTsInfo()

    for tsmem in ts.getMembers():
        if tsmem.ts_state == 'i' or tsmem.ts_state == 'u':
            installed.append(tsmem.name)
        elif tsmem.ts_state == 'e' \
             and not trigger_uninstall \
             and tsmem.name.startswith("nethserver-"):
            trigger_uninstall = True

    if trigger_uninstall:
        # If a NethServer package was removed add ALL remaining
        # NethServer packages to the event list:
        events = pkgs2events(nethserver_packages)
    elif len(installed) > 0:
        # Get the list of installed/updated packages respecting the
        # dependency sorting:
        events = pkgs2events(filter(lambda x: x in installed, nethserver_packages))

    if len(events) > 0:
        # Adjust firewall and services if something was updated:
        if os.path.isdir(events_dir + "/runlevel-adjust"):
            events.append('runlevel-adjust')
        if os.path.isdir(events_dir + "/firewall-adjust"):
            events.append('firewall-adjust')

    conduit._base.nethserver_events = run_events(events)


def run_events(events):
    # Remove duplicate events, preserving order:
    events = list_unique(events)

    tasks = {}
    penv = os.environ.copy()
    tracker = nethserver.ptrack.TrackerClient()
    success = True

    for event in events:
        tasks[event] = tracker.declare_task("Event %s" % event)

    # Execute the event list:
    for event in events:
        if(event in tasks):
            penv['PTRACK_TASKID'] = str(tasks[event])
        elif('PTRACK_TASKID' in penv):
            del penv['PTRACK_TASKID']
        event_exit_code = os.spawnle(os.P_WAIT, signal_event, signal_event, event, penv)
        tracker.set_task_done(tasks[event], "", event_exit_code)
        if(event_exit_code != 0):
            success = False

    return success

