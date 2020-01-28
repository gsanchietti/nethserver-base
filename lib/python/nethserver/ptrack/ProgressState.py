#
# Copyright (C) 2014 Nethesis S.r.l.
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
# along with NethServer.  If not, see .
#

import time

class StateException(Exception): pass

class Task:

    def __init__(self, identifier, parent=None, weight = 10., title=None):
        self.weight = weight
        self.children_weight = 0.0
        self.progress = 0.0
        self.children = []
        self.message = ""
        self.title = title
        self.code = None
        self.identifier = identifier
        self.ts_created = time.time()
        self.ts_started = None
        self.ts_updated = None

        if(parent is not None):
            parent.add_children(self)

    def add_children(self, child):
        child.parent = self
        self.children_weight += child.weight
        self.children.append(child)

    def set_code(self, c):
        self.code = c
        return self

    def set_message(self, m):
        self.message = m
        return self

    def set_progress(self, p):
        if(self.progress < p and p <= 1.0):
            if(self.progress == 0.0):
                self.ts_started = self.ts_updated = time.time()
            else:
                self.ts_updated = time.time()
            self.progress = p
        return self

    def update_progress(self):
        current = 0.0
        for child in self.children:            
            current += child.get_progress() \
                       * (child.weight / self.children_weight)
        self.set_progress(current)
        return self        

    def get_progress(self):
        if(self.progress == 1.0):
            return 1.0

        self.update_progress()
        return self.progress

    def get_message(self):
        return self.message

    def get_title(self):
        if(self.title is None):
            return "Task#%d" % self.identifier
        return self.title
        
    def get_code(self):
        return self.code

    def get_identifier(self):
        return self.identifier

class ProgressState:
    
    def __init__(self, task_title='Root task'):
        self.tasks = [Task(0, None, 10., task_title)]
        self.last_taskid = 0
    
    def declare_task(self, parent_id=0, weight=10., title=None):
        parent_id = int(parent_id)
        weight = float(weight)
        identifier = len(self.tasks)
        task = Task(identifier, self.__get_task_by_id(parent_id), weight, title)
        self.tasks.append(task)
        return identifier

    def set_task_done(self, task_id, message=None, code=None):
        return self.set_task_progress(task_id, 1.0, message, code)

    def set_task_progress(self, task_id, p=0.0, message=None, code=None):
        try:
            self.tasks[task_id].set_progress(p)
            if(message is not None):
                self.tasks[task_id].set_message(message)
            if(code is not None):
                self.tasks[task_id].set_code(code)
            self.last_taskid = task_id
        except:
            pass
        return task_id

    def __get_task_by_id(self, task_id):
        try:
            return self.tasks[task_id]
        except IndexError:
            return self.tasks[0]

    def __get_task_map(self, task, recursive):
        return {
            'id':       task.get_identifier(),
            'title':    task.get_title(), 
            'message':  task.get_message(), 
            'progress': task.get_progress(),
            'code':     task.get_code(),
            'ts_created': task.ts_created,
            'ts_started': task.ts_started,
            'ts_updated': task.ts_updated,
            'children': map(
                lambda t: self.__get_task_map(t, recursive), 
                task.children if recursive else []
            )
        }    

    def query(self, subject='progress'):
        if(subject == 'progress'):
            root_task = self.__get_task_map(self.tasks[0], False)
            root_task['last'] = self.__get_task_map(self.tasks[self.last_taskid], False)
            return root_task
        elif(subject == 'tasks'):
            return self.__get_task_map(self.tasks[0], True)
        else:
            raise Exception("Unknown query subject")
        
        

