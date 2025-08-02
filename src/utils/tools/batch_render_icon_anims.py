import bpy

collection_name = "Collection"
collection = bpy.data.collections.get(collection_name)
if not collection:
    raise Exception(f"Collection '{collection_name}' not found.")

for i in range(3):
    obj = collection.objects[i]
    print(f"Selected object: {obj.name}")


