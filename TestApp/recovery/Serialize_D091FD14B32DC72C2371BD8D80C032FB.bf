using System;
using System.Collections;
using System.IO;
using Serialize.Implementation;

namespace Serialize
{
	class Serialize<F>
		where F : IFormat, class, new, delete
	{
		private F _format ~ if (_ownsFormat) delete _;
		private bool _ownsFormat;

		public DeserializeError Error { get; private set; } ~ delete _;

		public this()
		{
			_format = new F();
			_ownsFormat = true;
		}

		public this(F provider, bool ownsProvider = false)
		{
			_format = provider;
			_ownsFormat = ownsProvider;
		}

		public void Serialize<T>(T value, String strBuffer)
			where T : ISerializable
		{
			StringStream stream = scope .(strBuffer, .Reference);
			ISerializer serializer = _format.CreateSerializer();
			serializer.Writer = scope .(stream, .UTF8, 0 /* bufferSize is not used. */);
			//serializer.Writer = Console.Out;
			defer delete serializer;

			_format.Serialize(serializer, value);
		}

		public Result<T> Deserialize<T>(StringView str)
			where T : ISerializable
		{
			IDeserializer deserializer = _format.CreateDeserializer();
			deserializer.Reader = scope .(str);
			defer delete deserializer;

			T* value = (.)Internal.Malloc(sizeof(T));
			if (_format.Deserialize<T>(deserializer, value) case .Err)
			{
				if (Error != null)
					delete Error;
				Error = deserializer.Error;
				deserializer.SetError(null);

				Delete!(*value);
				Internal.Free(value);
				return .Err;
			}

			return *value;
		}

		static mixin Delete<T>(T value) where T : delete
		{
			delete value;
		}

		static mixin Delete<T>(T value) where T : IDisposable
		{
			value.Dispose();
		}

		static mixin Delete<T>(T value) {}

	}
}