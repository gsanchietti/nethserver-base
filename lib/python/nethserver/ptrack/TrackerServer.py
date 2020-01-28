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

import asyncore
import socket
import struct
import json
import logging
import os
import traceback

class TrackerServer (asyncore.dispatcher):
    
    backlog = 5

    def __init__(self, path, state):
        self.sockets = {}
        self.path = path
        self.state = state

        asyncore.dispatcher.__init__(self, None, self.sockets)
        logging.debug('Starting listener at %s' % path)

        self.create_socket(socket.AF_UNIX, socket.SOCK_STREAM)

        try:
            os.unlink(self.path)
        except:
            pass

        self.bind(self.path)
        self.listen(TrackerServer.backlog)

    def writable(self):
        return False

    def handle_accept(self):
        pair = self.accept()
        if pair is not None:
            sock, addr = pair
            logging.debug('Incoming connection from %s' % repr(addr))
            handler = TaskHandler(sock, self.state, self.sockets)

    def loop(self):
        asyncore.loop(None, True, self.sockets)

    def close(self):
        try:
            os.unlink(self.path)
        except:
            pass            
        asyncore.dispatcher.close(self)
        for sock in self.sockets.values():
            try:
                sock.close()
            except Exception as e:
                logging.exception(traceback.format_exc())
        self.sockets.clear()

    def log(self, message):
        logging.debug(message)

    def log_info(self, message, type='info'):
        logging.info("%s: %s" % (type, message))


class TaskHandler(asyncore.dispatcher_with_send):

    TY_DECLARE  = 0x01
    TY_DONE     = 0x02
    TY_QUERY    = 0x03
    TY_PROGRESS = 0x04
    TY_ERROR    = 0x40
    TY_RESPONSE = 0x80

    def __init__(self, sock, state, map):
        asyncore.dispatcher_with_send.__init__(self, sock, map)
        self.state = state
        self.methods = {
            self.TY_DECLARE: getattr(self.state, 'declare_task'),
            self.TY_DONE: getattr(self.state, 'set_task_done'),
            self.TY_QUERY: getattr(self.state, 'query'),
            self.TY_PROGRESS: getattr(self.state, 'set_task_progress')
        }

    def handle_read(self):
        header = self.recv(3)

        if(len(header) == 0):
            return

        req_type, size  = struct.unpack('>BH', header)
        req = json.loads(self.recv(size))
        
        if(req is None):
            req = ()

        try:
            if(not req_type in self.methods):
                raise Exception("Unknown request type: 0x%02x" % req_type)

            logging.debug("> Request 0x%02x > %s" % (req_type, json.dumps(req)))
            rep = self.methods[req_type](*req)
            
        except Exception as e:
            rep = e.args
            req_type |= self.TY_ERROR
            logging.error(traceback.format_exc())
            
        buf = json.dumps(rep)

        logging.debug("< Response 0x%02x < %s" % (req_type, buf))

        self.send(struct.pack('>BH', req_type | self.TY_RESPONSE, len(buf)))
        self.send(buf)


