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

		public Result<void> Deserialize<T>(IDeserializer deserializer, T* value)
			where T : ISerializable
		{
			return T.Deserialize<TomlDeserializer>((.)deserializer, (.)value);
		}
	}
}