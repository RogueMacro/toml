using Serialize.Implementation;
using System;
using Serialize;
using System.Collections;

namespace Toml.Internal
{
	class TomlDeserializer : IDeserializer
	{
		public Reader Reader { get; set; }

		public DeserializeError Error { get; set; } ~ delete _;
		public void SetError(DeserializeError error)
		{
			if (Error != null)
				delete Error;
			Error = error;
		}

		public Result<void> DeserializeStructStart(int size)
		{
			return .Ok;
		}

		public Result<void> DeserializeStructField(delegate Result<void>(StringView field) deserialize, Span<StringView> fieldsLeft)
		{
			if (ConsumeWhitespace() case .Err)
			{
				// EOF
				// Toml doesn't have `null`, so null-values are left out instead.
				// We don't care about the remaining fields, so we count them as null.
				return .Ok;
			}

			if (Try!(Peek()) == '[')
			{

			}
			else
			{
				let keyPos = Reader.Position;
				String key = scope .();
				char8 next = Try!(Peek());
				if (next == '"')
				{
					key = Try!(DeserializeString());
				}
				else
				{
					char8 current = Try!(Read());
					while (current != '=' && !current.IsWhiteSpace)
					{
						if (!(current.IsLetterOrDigit || current == '-' || current == '_'))
							Error!(new $"Character '{current}' cannot be used in a key");

						key.Append(current);
						current = Try!(Read());
					}
				}

				Try!(ConsumeWhitespace());
				Try!(Expect('='));
				Try!(ConsumeWhitespace());

				if (deserialize(key) case .Err)
				{
					if (Error == null)
						ErrorAt!(keyPos + 1, new $"'{key}' is not a valid member", Math.Max(key.Length, 1));

					// An error happened while deserializing the field.
					return .Err;
				}
			}

			return .Ok;
		}

		public Result<void> DeserializeStructEnd()
		{
			return .Ok;
		}

		public Result<Dictionary<TKey, TValue>> DeserializeMap<TKey, TValue>()
			where TKey : String where TValue : ISerializable
		{
			return .Err;
		}

		public Result<List<T>> DeserializeList<T>() where T : ISerializable
		{
			return .Err;
		}

		public Result<String> DeserializeString()
		{
			String string = scope .();

			Try!(ConsumeChar('"'));
			while (true)
			{
				let char = Try!(Read());
				if (char == '\n')
					Error!(new $"Unescaped newline not allowed in strings");
				else if (char == '"')
					break;

				string.Append(char);
			}

			String escaped = new .();
			if (string.Unescape(escaped) case .Err)
			{
				delete escaped;
				return .Err;
			}

			return escaped;
		}

		// TODO: Support binary and '0o' prefix
		public Result<int> DeserializeInt()
		{
			let pos = Reader.Position;
			String str = scope .();

			char8 next = Try!(Peek());
			if (next == '-' || next == '+')
				str.Append(Try!(Read()));

			bool hex = false;
			if (next == '0' && Peek(1) case .Ok('x'))
			{
				hex = true;
				Try!(Read());
				Try!(Read());
			}

			while (true)
			{
				let current = Try!(Read());

				if (current == '_')
					continue;
				if (hex && !(current.IsDigit ||
					((current >= 'a') && (current <= 'f')) ||
					((current >= 'A') && (current <= 'F'))))
					break;
				if (!hex && !current.IsDigit)
					break;

				str.Append(current);
			}

			if (int.Parse(str) case .Ok(let val))
			{
				return val;
			}

			ErrorAt!(pos, new $"Invalid integer", Reader.Position - pos);
		}

		public Result<void> DeserializeUInt(uint* outValue)
		{
			let pos = Reader.Position;
			String str = scope .();

			char8 next = Try!(Peek());
			if (next == '-')
				Error!(new $"Number must be positive for unsigned integers");
			if (next == '+')
				str.Append(Try!(Read()));

			bool hex = false;
			if (next == '0' && Peek(1) case .Ok('x'))
			{
				hex = true;
				Try!(Read());
				Try!(Read());
			}

			while (true)
			{
				let current = Try!(Read());

				if (current == '_')
					continue;
				if (hex && !(current.IsDigit ||
					((current >= 'a') && (current <= 'f')) ||
					((current >= 'A') && (current <= 'F'))))
					break;
				if (!hex && !current.IsDigit)
					break;

				str.Append(current);
			}

			if (UInt64.Parse(str, .Number | .HexNumber) case .Ok(let val))
			{
				*outValue = val;
				return .Ok;
			}

			ErrorAt!(pos, new $"Invalid integer", Reader.Position - pos);
		}

		public Result<void> DeserializeDouble(double* outValue)
		{
			return .Err;
		}

		public Result<bool> DeserializeBool()
		{
			let char = Try!(Read());
			if (char == 't')
			{
				Expect('r');
				Expect('u');
				Expect('e');
				return true;
			}
			else if (char == 'f')
			{
				Expect('a');
				Expect('l');
				Expect('s');
				Expect('e');
				return false;
			}
			else
			{
				Error!(new $"Expected 'true' or 'false'");
			}

			//return .Ok;
		}

		public bool DeserializeNull()
		{
			return false;
		}

		private Result<void> Expect(char8 char)
		{
			let peek = Try!(Peek());
			if (peek == char)
				return .Ok(Try!(Read()));
			Error!(new $"Unexpected character '{peek}', expected '{char}'");
		}	

		private Result<void> ConsumeChar(char8 char)
		{
			Try!(ConsumeWhitespace());
			return Expect(char);
		}

		private Result<void> ConsumeWhitespace()
		{
			while (Try!(Peek()).IsWhiteSpace)
				Try!(Read());
			return .Ok;
		}

		private Result<bool> Match(StringView match)
		{
			for (int i = 0; i < match.Length; i++)
			{
				if (Try!(Peek(i)) != match[i])
					return false;
			}

			return true;
		}

		private Result<char8> Peek(int offset = 0)
		{
			return AssertEOF!(Reader.Peek(offset));
		}

		private Result<void> Read(int count)
		{
			for (let _ < count)
				Try!(Read());
			return .Ok;
		}

		private Result<char8> Read()
		{
			return AssertEOF!(Reader.Read());
		}

		mixin Error(String message, int length = 1)
		{
			ErrorAt!(-1, message, length);
		}

		mixin ErrorAt(int position, String message, int length = 1)
		{
			SetError(new .(message, this, length, position));
			return .Err;
		}

		mixin AssertEOF(var result)
		{
			if (result case .Err)
				Error!(new $"Unexpected end of file");
			result.Value
		}

	}
}