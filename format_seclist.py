#!/usr/bin/env python

"""
Given output from seclist, print it in a suitable format for the squidlog parsing stuff
"""

import sys
import socket
import os

import functools

from collections import defaultdict

def gethostbyname(host):
    try:
        ip = socket.gethostbyname(host)
    except socket.gaierror:
        return host
    return ip

"""
An Entry is a log line

type is either LOGIN, LOGOUT or, where we have matched up the lines SESSION

"""
class Entry(object):
    months = {
           "01": "Jan",
           "02": "Feb",
           "03": "Mar",
           "04": "Apr",
           "05": "May",
           "06": "Jun",
           "07": "Jul",
           "08": "Aug",
           "09": "Sep",
           "10": "Oct",
           "11": "Nov",
           "12": "Dec"
           }

    def __init__(self, l):
        (user, host, date, time, _, inout) = l.split()
        self.user = user
        self.host = host
        self.type = inout
        if self.type == "LOGIN":
            self.starttime = self._format_time(date, time)
            self.endtime = ""
        else:
            self.endtime = self._format_time(date, time)
            self.starttime = ""

    def __str__(self):
        if self.type == "LOGIN":
            return "%s %s LOGIN" % (self.ip, self.starttime)
        if self.type == "LOGOUT":
            return "%s %s LOGOUT" % (self.ip, self.endtime)
        return "%s %s %s" % (self.ip, self.starttime, self.endtime)

    def _format_time(self, datestr, timestr):
        (day, mth, yr) = datestr.split("/")
        return "%s %s %s %s" % (day, self.months[mth], yr, timestr)

    @property
    def ip(self):
        return gethostbyname(self.host)

"""
Pull apart an input line, then add to a dict keyed by host ip (entries_by_host)
Returns a list of lists where each list is a list of log items for a single host
"""
def parse_and_match(f):
    entries = []
    entries_by_host = defaultdict(list)
    def groupFn(x):
        entries_by_host[x.ip] = entries_by_host[x.ip] + [x]
    for l in f:
        if l.rstrip() == "":
            continue
        entries.append(Entry(l))
    map (groupFn, entries)
    return entries_by_host.values()

"""
Takes a list of lines, where the list has already been filtered to so
each line is for the same host.

Matches login/logout pairs and returns a list of Events with both startime and
endtime
"""
def match_entries(lines):
    results = []
    matched_lines = []
    to_ignore = False
    ignored_lines = set()
    # filter the list of events to deal with missing data
    for index, item in enumerate(lines):
        if to_ignore:
            ignored_lines.add(item)
            to_ignore = False
            continue
        if index < len(lines) - 1:
            if item.type != lines[index+1].type:
                matched_lines.append(item)
                continue
            if item.type == "LOGIN":  # 2 LOGIN records. Ignore the first one
                ignored_lines.add(item)
                continue
            else:                     # 2 LOGOUT records. Take the first, ignore the second
                matched_lines.append(item)
                to_ignore = True
                continue
        else: # last item
            if lines[index-1].type == item.type:
                # Either last two entries don't pair up or only one item
                ignored_lines.add(lines[index-1])
                ignored_lines.add(item)
                if matched_lines:
                    matched_lines.pop()
            elif item.type == "LOGIN":
                # lonely LOGIN, ignore
                ignored_lines.add(item)
            else:
                matched_lines.append(item)
    for item in ignored_lines:
        print "Ignored line: ", item
    for (lin, lout) in zip(matched_lines[::2], matched_lines[1::2]):
        lin.endtime = lout.endtime
        lin.type = "SESSION"
        results.append(lin)
    return results

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print "Usage: format_seclist.py <file>"
        sys.exit(1)
    try:
        f = open(sys.argv[1])
    except Exception, e:
        print "Can't open file %s: %s" % (sys.argv[1], e)
    for e in map(match_entries, parse_and_match(f)):
        for x in e:
            print x

