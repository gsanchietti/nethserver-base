#!/usr/bin/python2

import unittest
import logging
from nethserver.ptrack import ProgressState

class TestProgressState(unittest.TestCase):

    sut = None

    def setUp(self):
        self.sut = ProgressState()
        self.p = 0.0

    def test_declare_task(self):
        r = self.sut.declare_task()
        self.assertEqual(r, 1)

    def test_subtask_check_standard_weights(self):
        r = self.sut.declare_task()

        a = self.sut.declare_task(r)
        b = self.sut.declare_task(r)
        c = self.sut.declare_task(r)

        aa = self.sut.declare_task(a)
        ab = self.sut.declare_task(a)
        ac = self.sut.declare_task(a)

        ca = self.sut.declare_task(c)
        cb = self.sut.declare_task(c)

        self.sut.set_task_done(ca)
        self.assertEqual(self.sut.get_progress(), 1./6.)

        self.sut.set_task_done(ab)
        self.assertEqual(self.sut.get_progress(), 1./6. + 1./9.)
        

    def test_subtask_check_custom_weights(self):
        r = self.sut.declare_task()

        a = self.sut.declare_task(r, 1)
        b = self.sut.declare_task(r, 1)
        c = self.sut.declare_task(r, 1)

        aa = self.sut.declare_task(a, 1)
        ab = self.sut.declare_task(a, 1)
        ac = self.sut.declare_task(a, 2)

        self.sut.set_task_done(ac)
        self.assertEqual(self.sut.get_progress(), 1./3.*1./2.)


    def test_subtask_check_never_come_back(self):
        r = self.sut.declare_task()

        a = self.sut.declare_task(r, 1)
        b = self.sut.declare_task(r, 1)
        c = self.sut.declare_task(r, 1)

        self.sut.set_task_done(a)
        self.sut.set_task_progress(b, 0.5)
        self.assertEqual(self.sut.get_progress(), 1./3 + 1./6)

        # Decrease task b progress:
        self.sut.set_task_progress(b, 0.1)

        # Result must not be decreased:
        self.assertEqual(self.sut.get_progress(), 1./3 + 1./6)




if __name__ == '__main__':
    unittest.main()





