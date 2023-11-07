# What is it
MeshDeformer is a Godot plugin that provides a node that takes a target Polygon2D so it can be deformed using a grid of movable points.

# How does it work
The node generates a Skeleton2D and a set of Bones and calculates the weights. The future version might use a custom vertex shader to achieve this, but I have to look into how this would be compatible with custom shaders.

![Alt text](/example.jpg?raw=true "Example for the MeshDeformer")
