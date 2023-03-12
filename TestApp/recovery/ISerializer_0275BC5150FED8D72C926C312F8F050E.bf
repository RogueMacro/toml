using System;
using System.IO;
using System.Collections;

namespace Serialize.Implementation
{
	interface ISerializer
	{
		StreamWriter Writer { get; set; }

		SerializeOrder SerializeOrder { get; }

		void SerializeMapStart(int size);
		void SerializeMapEntry<T>(String key, T value, bool first)
			where T : ISerializable;
		void SerializeMapEnd();

		void SerializeList<T>(List<T> list)
			where T : ISerializable;

		void SerializeString(String string);

		void SerializeInt(int i);
		void SerializeInt8(int8 i) => SerializeInt(i);
		void SerializeInt16(int16 i) => SerializeInt(i);
		void SerializeInt32(int32 i) => SerializeInt(i);
		void SerializeInt64(int64 i) => SerializeInt(i);

		void SerializeUInt(uint i);
		void SerializeUInt8(uint8 i) => SerializeUInt(i);
		void SerializeUInt16(uint16 i) => SerializeUInt(i);
		void SerializeUInt32(uint32 i) => SerializeUInt(i);
		void SerializeUInt64(uint64 i) => SerializeUInt(i);

		void SerializeBool(bool b);

		void SerializeNull();
	}

	enum SerializeOrder
	{
		InOrder,             // Don't rearrange fields.
		PrimitivesArraysMaps, // Primitives, then arrays, then maps.
		MapsLast              // Primitives and arrays in order, then maps.
	}
}