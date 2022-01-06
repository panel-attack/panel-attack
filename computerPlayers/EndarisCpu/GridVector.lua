GridVector = class(function(vector, row, column)
    vector.row = row
    vector.column = column
end)

function GridVector.distance(self, otherVec)
    --since this is a grid where diagonal movement is not possible 
    --it's just the sum of both directions instead of a diagonal
    return math.abs(self.row - otherVec.row) + math.abs(self.column - otherVec.column)
end

function GridVector.difference(self, otherVec)
    return GridVector(self.row - otherVec.row, self.column - otherVec.column)
end

function GridVector.add(self, otherVec)
    return GridVector(self.row + otherVec.row, self.column + otherVec.column)
end

function GridVector.substract(self, otherVec)
    return GridVector(self.row - otherVec.row, self.column - otherVec.column)
end

function GridVector.equals(self, otherVec)
    return self.row == otherVec.row and self.column == otherVec.column
end

function GridVector.toString(self)
    return self.row .. "|" .. self.column
end

function GridVector.inRectangle(self, bottomLeft, topRight)
    return self.row >= bottomLeft.row and self.column >= bottomLeft.column and self.row <= topRight.row 
            and self.column <= topRight.column
end

--special meaning of adjacent:
--  -----------
-- x|x x x x x|x
-- x|x       x|x
-- x|x       x|x
--  -----------
-- both inside and outside but not on top
-- technically catches things inside the box too but is not realistic for the usecase
-- maybe a better name would be "safe from rain" as it characterises better which spots are meant
function GridVector.adjacentToRectangle(self, bottomLeft, topRight)
    return self.row <= topRight.row and self.column - 1 <= topRight.column and self.column + 1 >= bottomLeft.column
end

function GridVector.scalarMultiply(self, scalar)
    return GridVector(self.row * scalar, self.column * scalar)
end

function GridVector.isAdjacent(self, vector)
    return self:difference(vector):distance(GridVector(0, 0)) == 1
end

function GridVector.IsInAdjacentRow(self, vector)
    return math.abs(self:difference(vector).row) == 1
end