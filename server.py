import random

from twisted.internet.protocol import Protocol, Factory
from twisted.internet import reactor

type_to_length = {"H": 4, "P": 8, "I": 23}

class PanelServ(Protocol):
    def connectionMade(self):
        self.index = self.factory.index
        self.factory.index += 1
        self.factory.conns[self.index] = self
        self.leftovers = ""
        print("connected! %s"%self.index)

    def dataReceived(self, data):
        data = self.leftovers + data
        go = True
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
                self.forward_input(goo)
            else:
                if not erryet:
                    erryet = True
                    print "Something weird happened: %s" % type
                idx += 1
            idx += type_to_length[type]
        self.leftovers = data[idx:]

    def handshake(self, version):
        # TODO: care about the version number.
        if self.factory.wait_index is not None:
            self.neighbor = self.factory.conns[self.factory.wait_index]
            self.factory.wait_index = None
            self.neighbor.neighbor = self
            self.transport.write("G")
            self.neighbor.transport.write("G")
        else:
            self.factory.wait_index = self.index
            self.transport.write("H")

    def forward_input(self, data):
        self.neighbor.transport.write("I"+data)

    def panels(self, data):
        ncolors = int(data[:1])
        if ncolors < 2:
            return
        ret = list(map(int,data[1:]))
        for x in xrange(20):
            for y in xrange(6):
                prevtwo = y>1 and ret[-1]==ret[-2]
                nogood = True
                while nogood:
                    color = random.randint(1,ncolors)
                    nogood = (prevtwo and color == ret[-1]) or color == ret[-6]
                ret.append(color)
        ret = "".join(map(str,ret[6:]))
        self.transport.write("P"+ret)
        self.neighbor.transport.write("O"+ret)

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
