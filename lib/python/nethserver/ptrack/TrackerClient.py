#
# Copyright (C) 2013 Nethesis S.r.l.
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


import socket
import json
import struct
from ..ptrack.TrackerServer import TaskHandler
import os

class TrackerClient:

    def __init__(self, path="", default_task_id=0):

        try:
            if(not path):
                path = os.environ['PTRACK_SOCKETPATH']
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.sock.connect(path)
            self.connected = True
        except:
            self.connected = False
        try:
            self.default_task_id = default_task_id or os.environ['PTRACK_TASKID']
        except:
            self.default_task_id = 0

    def isConnected(self):
        return self.connected == True

    def declare_task(self, title, parent_task_id=0, weight=1.0):
        parent_task_id = parent_task_id or self.default_task_id
        return self.__send(TaskHandler.TY_DECLARE, [parent_task_id, weight, title])

    def get_progress(self):
        return self.query()

    def query(self, subject="progress"):
        return self.__send(TaskHandler.TY_QUERY, [subject])

    def set_task_done(self, task_id, message=None, code=0):
        return self.__send(TaskHandler.TY_DONE, [task_id, message, code])

    def set_task_progress(self, task_id, progress, message="", code=None):
        return self.__send(TaskHandler.TY_PROGRESS, [task_id, progress, message, code])

    def __send(self, code, args=[]):
        if(not self.connected):
            return False

        payload = json.dumps(args)
        self.sock.send(struct.pack('>BH', code, len(payload)) + payload)
        rcode, rlen = struct.unpack(">BH", self.sock.recv(3))

        if(rcode & TaskHandler.TY_ERROR):
            return False

        rbuf = self.sock.recv(rlen)

        return json.loads(rbuf)
        
    def __del__(self):
        if(self.connected):
            self.sock.close()
