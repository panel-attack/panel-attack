import random

from twisted.internet.protocol import Protocol, Factory
from twisted.internet import reactor

VERSION = "003"
type_to_length = {"H":4, "P":8, "I":2, "L":2, "Q":8}

class PanelServ(Protocol):
    def connectionMade(self):
        self.index = self.factory.index
        self.factory.index += 1
        self.factory.conns[self.index] = self
        self.leftovers = ""
        self.vs_mode = False
        self.metal = False
        self.rows_left = 14+random.randint(1,8)
        self.prev_metal_col = None
        self.metal_col = None
        print("connected! %s"%self.index)

    def dataReceived(self, data):
        data = self.leftovers + data
        idx = 0
        datalen = len(data)
        erryet = False
        while idx < datalen:
            type = data[idx]
            if datalen < idx + type_to_length[type]:
                break
            goo = data[idx+1:idx+type_to_length[type]]
            if type == "H":
                self.handshake(goo)
            elif type == "P":
                self.panels(goo)
            elif type == "I":
                self.neighbor.transport.write("I"+goo)
            elif type == "Q":
                self.garbage_panels(goo)
            elif type == "L":
                self.neighbor.transport.write("L"+goo)
            else:
                if not erryet:
                    erryet = True
                    print "Something weird happened: %s" % type
                idx += 1
            idx += type_to_length[type]
        self.leftovers = data[idx:]

    def handshake(self, version):
        if version != VERSION:
            self.transport.write("N")
        elif self.factory.wait_index is not None:
            self.neighbor = self.factory.conns[self.factory.wait_index]
            self.factory.wait_index = None
            self.neighbor.neighbor = self
            self.transport.write("G")
            self.neighbor.transport.write("G")
        else:
            self.factory.wait_index = self.index
            self.transport.write("H")

    def panels(self, data):
        ncolors = int(data[:1])
        if ncolors < 2:
            return
        prev_panels = data[1:]
        cut_panels = False
        ret = list(map(int,prev_panels))
        if prev_panels == "000000":
            first_seven = getattr(self, "first_seven", None)
            if first_seven and self.op_ncolors == ncolors:
                ret = first_seven
                self.rows_left -= 7
            else:
                cut_panels = True
        for x in xrange(21-len(ret)/6):
            if self.metal:
                nogood = True
                while nogood:
                    self.metal_col = random.randint(0,5)
                    nogood = (self.metal_col == self.prev_metal_col)
            for y in xrange(6):
                prevtwo = y>1 and ret[-1]==ret[-2]
                nogood = True
                while nogood:
                    color = 8 if y == self.metal_col else random.randint(1,ncolors)
                    nogood = (prevtwo and color == ret[-1]) or color == ret[-6]
                ret.append(color)
            self.prev_metal_col = self.metal_col
            self.metal_col = None
            self.rows_left -= 1
            if self.rows_left == 0:
                if self.vs_mode:
                    self.metal = not self.metal
                if self.metal:
                    self.rows_left = random.randint(1,4)
                else:
                    self.rows_left = random.randint(1,8)
        if cut_panels:
            height = [7]*6
            to_remove = 12
            while to_remove:
                idx = random.randint(0,5)
                if height[idx]:
                    #          v 7->1, 6->2, etc
                    ret[6*(-height[idx]+8) + idx] = "0"
                    height[idx] -= 1
                    to_remove -= 1
            self.neighbor.first_seven = ret[:48]
            self.neighbor.op_ncolors = ncolors

        ret = "".join(map(str,ret[6:]))
        print ret
        self.transport.write("P"+ret)
        self.neighbor.transport.write("O"+ret)

    def garbage_panels(self, data):
        self.vs_mode = True
        ncolors = int(data[:1])
        if ncolors < 2:
            return
        ret = list(map(int,data[1:]))
        for x in xrange(20):
            for y in xrange(6):
                nogood = True
                while nogood:
                    color = random.randint(1,ncolors)
                    nogood = (y>0 and color == ret[-1]) or color == ret[-6]
                ret.append(color)
        ret = "".join(map(str,ret[6:]))
        self.transport.write("Q"+ret)
        self.neighbor.transport.write("R"+ret)

    def connectionLost(self, reason):
        del self.factory.conns[self.index]
        if self.factory.wait_index == self.index:
            self.factory.wait_index = None
        print("disconnected! %s"%self.index)

class PanelServFactory(Factory):
    protocol = PanelServ
    def __init__(self):
        self.conns = {}
        self.index = 0
        self.wait_index = None

reactor.listenTCP(49569, PanelServFactory())
reactor.run()
