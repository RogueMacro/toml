using System;
using Serialize.Implementation;

namespace Serialize
{
	/// Automatically implemented by the [Serializable] attribute.
	interface ISerializable
	{
		void Serialize<S>(S serializer)
			where S : ISerializer;

		static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer;
	}
}

namespace System
{
	using Serialize;

	extension Nullable<T> : ISerializable
		where T : ISerializable
	{
		public void Serialize<S>(S serializer) where S : ISerializer
		{
			if (HasValue)
				Value.Serialize(serializer);
			else
				serializer.SerializeNull();
		}

		public static Result<Self> Deserialize<D>(D deserializer) where D : IDeserializer
		{
			if (deserializer.DeserializeNull())
			{
				return null;
			}
            else
			{
				T val = Try!(T.Deserialize(deserializer));
				return Nullable<T>(val);
			}

			//return .Ok;
		}
	}

	extension String : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeString(this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return deserializer.DeserializeString();
		}
	}

	extension Boolean : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeBool((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeBool());
		}
	}

#region Integers
	extension Int : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeInt((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeInt());
		}
	}

//	extension Int8 : ISerializable
//	{
//		public void Serialize<S>(S serializer)
//			where S : ISerializer
//		{
//			serializer.SerializeInt((.)this);
//		}
//
//		public static Result<Self> Deserialize<D>(D deserializer)
//			where D : IDeserializer
//		{
//			return Try!(deserializer.DeserializeInt8());
//		}
//	}
//
//	extension Int16 : ISerializable
//	{
//		public void Serialize<S>(S serializer)
//			where S : ISerializer
//		{
//			serializer.SerializeInt((.)this);
//		}
//
//		public static Result<Self> Deserialize<D>(D deserializer)
//			where D : IDeserializer
//		{
//			return deserializer.DeserializeInt16((.)outValue);
//		}
//	}
//
//	extension Int32 : ISerializable
//	{
//		public void Serialize<S>(S serializer)
//			where S : ISerializer
//		{
//			serializer.SerializeInt((.)this);
//		}
//
//		public static Result<Self> Deserialize<D>(D deserializer)
//			where D : IDeserializer
//		{
//			return deserializer.DeserializeInt32((.)outValue);
//		}
//	}
//
//	extension Int64 : ISerializable
//	{
//		public void Serialize<S>(S serializer)
//			where S : ISerializer
//		{
//			serializer.SerializeInt((.)this);
//		}
//
//		public static Result<Self> Deserialize<D>(D deserializer)
//			where D : IDeserializer
//		{
//			return deserializer.DeserializeInt64((.)outValue);
//		}
//	}
//
//	extension UInt : ISerializable
//	{
//		public void Serialize<S>(S serializer)
//			where S : ISerializer
//		{
//			serializer.SerializeUInt((.)this);
//		}
//
//		public static Result<Self> Deserialize<D>(D deserializer)
//			where D : IDeserializer
//		{
//			return deserializer.DeserializeUInt((.)outValue);
//		}
//	}
//
//	extension UInt8 : ISerializable
//	{
//		public void Serialize<S>(S serializer)
//			where S : ISerializer
//		{
//			serializer.SerializeUInt8((.)this);
//		}
//
//		public static Result<Self> Deserialize<D>(D deserializer)
//			where D : IDeserializer
//		{
//			return deserializer.DeserializeUInt8((.)outValue);
//		}
//	}
//
//	extension UInt16 : ISerializable
//	{
//		public void Serialize<S>(S serializer)
//			where S : ISerializer
//		{
//			serializer.SerializeUInt16((.)this);
//		}
//
//		public static Result<Self> Deserialize<D>(D deserializer)
//			where D : IDeserializer
//		{
//			return deserializer.DeserializeUInt16((.)outValue);
//		}
//	}
//
//	extension UInt32 : ISerializable
//	{
//		public void Serialize<S>(S serializer)
//			where S : ISerializer
//		{
//			serializer.SerializeUInt32((.)this);
//		}
//
//		public static Result<Self> Deserialize<D>(D deserializer)
//			where D : IDeserializer
//		{
//			return deserializer.DeserializeUInt32((.)outValue);
//		}
//	}
//
//	extension UInt64 : ISerializable
//	{
//		public void Serialize<S>(S serializer)
//			where S : ISerializer
//		{
//			serializer.SerializeUInt64((.)this);
//		}
//
//		public static Result<Self> Deserialize<D>(D deserializer)
//			where D : IDeserializer
//		{
//			return deserializer.DeserializeUInt64((.)outValue);
//		}
//	}
#endregion

	namespace Collections
	{
		extension Dictionary<TKey, TValue> : ISerializable
			where TKey : String
			where TValue : ISerializable
		{
			public void Serialize<S>(S serializer)
				where S : ISerializer
			{
				serializer.SerializeMapStart(Count);
				bool first = true;
				for (let (key, value) in this)
				{
					serializer.SerializeMapEntry(key, value, first);
					first = false;
				}
				serializer.SerializeMapEnd();
			}

			public static Result<Self> Deserialize<D>(D deserializer)
				where D : IDeserializer
			{
				return deserializer.DeserializeMap<TKey, TValue>();
			}
		}

		extension List<T> : ISerializable
			where T : ISerializable
		{
			public void Serialize<S>(S serializer)
				where S : ISerializer
			{
				serializer.SerializeList(this);
			}

			public static Result<Self> Deserialize<D>(D deserializer)
				where D : IDeserializer
			{
				return deserializer.DeserializeList<T>();
			}
		}
	}
}