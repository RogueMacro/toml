# TOML

TOML implementation for the [Serialize](https://github.com/RogueMacro/serialize) framework for Beef.

## Usage

```cs
using Serialize;
using Toml;

[Serializable]
struct Point
{
    public int x;
    public int y;
}

static void Main()
{
    Point point = .() { x = 1, y = 2 };

    // Create a serializer with specified format.
    Serialize<Toml> serializer = scope .();

    // Serialize to a TOML string.
    String serialized = serializer.Serialize(point, .. scope String());

    // Prints
    // x = 1
    // y = 2
    Console.WriteLine(serialized);

    // Deserialize the string back to a Point.
    Point deserialized = serializer.Deserialize<Point>(serialized);

    // Prints
    // x = 1
    // y = 2
    Console.WriteLine("x: {}", deserialized.x);
    Console.WriteLine("y: {}", deserialized.y);
}
```