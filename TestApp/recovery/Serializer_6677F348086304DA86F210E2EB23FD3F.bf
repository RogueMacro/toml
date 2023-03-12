using System;
using System.Collections;
using System.IO;
using System.Reflection;
using Serialize;
using Serialize.Implementation;

namespace Toml.Internal
{
	class TomlSerializer : ISerializer
	{
		public StreamWriter Writer { get; set; }
		public SerializeOrder SerializeOrder { get => .PrimitivesArraysMaps; }

		private String _parent = new .() ~ delete _;

		public void SerializeMapStart(int size) { }

		public void SerializeMapEntry<T>(String key, T value, bool first)
			where T : ISerializable
		{
			if (value == null)
				return;

			let genericType = (typeof(T) as SpecializedGenericType)?.UnspecializedType;

			if (genericType == typeof(Dictionary<>))
			{
				SerializeMap(key, value);
			}
			else if (typeof(T).IsPrimitive ||
				typeof(T) == typeof(String) ||
				genericType == typeof(List<>))
			{
				Writer.Write("{} = ", key);
				value.Serialize(this);
				Writer.WriteLine();
			}
			else
			{
				Writer.WriteLine("\n[{}{}]", _parent, key);
				using (Parent!(key))
					value.Serialize(this);
			}
		}

		public void SerializeMapEnd() { }

		private void SerializeMap<T>(String key, T value)
			where T : ISerializable
		{
			let genericValueArg = (typeof(T) as SpecializedGenericType).GetGenericArg(1);
			if (genericValueArg.IsPrimitive ||
				genericValueArg == typeof(String) ||
				(genericValueArg as SpecializedGenericType)?.UnspecializedType == typeof(List<>))
			{
				Writer.WriteLine("\n[{}{}]", _parent, key);
			}

			using (Parent!(key)) value.Serialize(this);
		}

		public void SerializeList<T>(List<T> list)
			where T : ISerializable
		{
			if (!(typeof(T).IsPrimitive ||
				typeof(T) == typeof(String) ||
				(typeof(T) is SpecializedGenericType &&
				(typeof(T) as SpecializedGenericType).UnspecializedType == typeof(List<>))))
			{
				for (let value in list)
				{
					if (value == null)
						continue;

					Writer.WriteLine("\n[[{}]]", _parent.Substring(0, _parent.Length - 1));
					value.Serialize(this);
				}

				return;
			}

			Writer.Write("[");

			bool first = true;
			for (let value in list)
			{
				if (value == null)
					continue;

				if (!first)
					Writer.Write(", ");
				value.Serialize(this);
				first = false;
			}

			Writer.Write("]");
		}

		public void SerializeString(String string)
		{
			Writer.Write("\"{}\"", string.Escape(.. scope .()));
		}

		public void SerializeInt(int i)
		{
			Writer.Write("{}", i);
		}

		public void SerializeUInt(uint i)
		{
			Writer.Write("{}", i);
		}

		public void SerializeBool(bool b)
		{
			Writer.Write(b ? "true" : "false");
		}

		public void SerializeNull()
		{
			Runtime.FatalError("TOML: Can't serialize null");
		}

		mixin Parent(StringView key)
		{
			Parent(_parent, key)
		}

		struct Parent : IDisposable
		{
			private int _length;
			private String _parent;

			public this(String parent, StringView key)
			{
				_parent = parent;
				_length = parent.Length;
				parent.AppendF("{}.", key);
			}

			public void Dispose()
			{
				_parent.RemoveToEnd(_length);
			}
		}
	}
}