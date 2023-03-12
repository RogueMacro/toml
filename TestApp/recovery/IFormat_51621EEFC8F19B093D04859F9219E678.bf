using System;
using Serialize;

namespace Serialize.Implementation
{
	interface IFormat
	{
		ISerializer CreateSerializer();
		IDeserializer CreateDeserializer();

		void Serialize<T>(ISerializer serializer, T value)
			where T : ISerializable;

		Result<void> Deserialize<T>(IDeserializer deserializer, T* value)
			where T : ISerializable;
	}
}