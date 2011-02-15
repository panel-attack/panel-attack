import random

from twisted.internet.protocol import Protocol, Factory
from twisted.internet import reactor

type_to_length = {"H": 4, "P": 8, "I": 23}

class PanelServ(Protocol):
    def connectionMade(self):
        self.index = len(self.factory.conns)
        self.factory.conns.append(self)
        self.leftovers = ""
        print("connected!")

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
        if self.index % 2 == 1:
            self.neighbor = self.factory.conns[self.index-1]
            self.neighbor.neighbor = self
            self.transport.write("G")
            self.neighbor.transport.write("G")
        else:
            self.transport.write("H")

    def forward_input(self, data):
        self.neighbor.transport.write("I"+data)

    def panels(self, data):
        ncolors = int(data[:1])
        if ncolors < 2:
            return
        ret = list(data[1:])
        for x in xrange(20):
            for y in xrange(2):
                nogood = True
                while nogood:
                    color = random.randint(1,ncolors)
                    nogood = color == ret[-6]
                ret.append(color)
            for y in xrange(4):
                prevtwo = ret[-1]==ret[-2]
                nogood = True
                while nogood:
                    color = random.randint(1,ncolors)
                    nogood = (prevtwo and color == ret[-1]) or color == ret[-6]
                ret.append(color)
        ret = "".join([str(x) for x in ret[6:]])
        self.transport.write("P"+ret)
        self.neighbor.transport.write("O"+ret)

    def connectionLost(self, reason):
        self.factory.conns.remove(self)
        print("disconnected!")

class PanelServFactory(Factory):
    protocol = PanelServ
    def __init__(self):
        self.conns = []

reactor.listenTCP(49569, PanelServFactory())
reactor.run()
