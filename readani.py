# Accepts a .ani file from stdin
# Prints it as an array (lua syntax) to stdout.
#
# Brandon, why did you make these retarded .ani files????
from sys import stdin as S
print "{"+(", ".join(map(str,[ord(x) for x in S.read()])))+"}"
