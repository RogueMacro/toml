using System;
using System.Collections;
using System.IO;

namespace Serialize.Implementation
{
	interface IDeserializer
	{
		bool AllowMissingFields

		Reader Reader { get; set; }

		DeserializeError Error { get; set; }
		void SetError(DeserializeError error);

		Result<void> DeserializeStructStart(int size);
		Result<void> DeserializeStructField(delegate Result<void>(StringView field) deserialize, Span<StringView> fieldsLeft);
		Result<void> DeserializeStructEnd();

		Result<void> DeserializeMap<TKey, TValue>(Dictionary<TKey, TValue>* outValue)
			where TKey : String
			where TValue : ISerializable;

		Result<void> DeserializeList<T>(List<T>* outValue)
			where T : ISerializable;

		Result<void> DeserializeString(String* outValue);

		Result<void> DeserializeInt(int* outValue);
		Result<void> DeserializeInt8(int8* outValue) => EnsureSize<int8, int>(outValue, scope => DeserializeInt, int8.MinValue, int8.MaxValue);
		Result<void> DeserializeInt16(int16* outValue) => EnsureSize<int16, int>(outValue, scope => DeserializeInt, int16.MinValue, int16.MaxValue);
		Result<void> DeserializeInt32(int32* outValue) => EnsureSize<int32, int>(outValue, scope => DeserializeInt, int32.MinValue, int32.MaxValue);
		Result<void> DeserializeInt64(int64* outValue) => EnsureSize<int64, int>(outValue, scope => DeserializeInt, int64.MinValue, int64.MaxValue);

		Result<void> DeserializeUInt(uint* outValue);
		Result<void> DeserializeUInt8(uint8* outValue) => EnsureSize<uint8, uint>(outValue, scope => DeserializeUInt, uint8.MinValue, uint8.MaxValue);
		Result<void> DeserializeUInt16(uint16* outValue) => EnsureSize<uint16, uint>(outValue, scope => DeserializeUInt, uint16.MinValue, uint16.MaxValue);
		Result<void> DeserializeUInt32(uint32* outValue) => EnsureSize<uint32, uint>(outValue, scope => DeserializeUInt, uint32.MinValue, uint32.MaxValue);
		Result<void> DeserializeUInt64(uint64* outValue) => EnsureSize<uint64, uint>(outValue, scope => DeserializeUInt, uint64.MinValue, uint64.MaxValue);

		Result<void> DeserializeDouble(double* outValue);
		Result<void> DeserializeFloat(float* outValue) => EnsureSize<float, double>(outValue, scope => DeserializeDouble, float.MinValue, float.MaxValue);

		Result<void> DeserializeBool(bool* outValue);

		bool DeserializeNull();

		/// Convert the parsed integer and cast it to the actual target type.
		/// Ensures that the value is not larger than what the target type can hold.
		Result<void> EnsureSize<TTo, TFrom>(TTo* outValue, delegate Result<void>(TFrom*) deserialize, TFrom min, TFrom max)
			where TTo : operator explicit TFrom
			where bool : operator TFrom < TFrom
		{
			int start = Reader.Position;

			TFrom i = default;
			Try!(deserialize(&i));

			if (i < min || i > max)
			{
				int end = Reader.Position;
				SetError(new .(new $"Number is too large for type {typeof(TTo).GetName(.. scope .())}", this, end - start, start));
				return .Err;
			}

			*outValue = (.)i;
			return .Ok;
		}
	}
}