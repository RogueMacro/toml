using System;
using Serialize;
using Serialize.Implementation;
using Toml.Internal;

namespace Toml
{
	class Toml : IFormat
	{
		public ISerializer CreateSerializer() => new TomlSerializer();
		public IDeserializer CreateDeserializer() => new TomlDeserializer();

		public void Serialize<T>(ISerializer serializer, T value)
			where T : ISerializable
		{
			value.Serialize<TomlSerializer>((.)serializer);
		}

		public Result<T> Deserialize<T>(IDeserializer deserializer)
			where T : ISerializable
		{
			return T.Deserialize<TomlDeserializer>((.)deserializer);
		}

		public static void Serialize<T>(T value, String buffer)
			where T : ISerializable
		{
			Serialize<Toml> serializer = scope .();
			serializer.Serialize(value, buffer);
		}

		public static Result<T> Deserialize<T>(StringView str)
			where T : ISerializable
		{
			Serialize<Toml> serializer = scope .();
			return serializer.Deserialize<T>(str);
		}
	}
}