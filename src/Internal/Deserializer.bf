using System;
using System.Collections;
using Serialize;
using Serialize.Implementation;

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

		private bool _inline => _inlineDepth > 0;
		private uint _inlineDepth = 0;

		private String _parent = new .() ~ delete _;
		private StringView _parentKey => _parent.Substring(0, Math.Max(_parent.Length - 1, 0));

		public Result<void> DeserializeStructStart(int size)
		{
			if (Try!(Peek()) == '{')
			{
				_inlineDepth++;
				Try!(Read());
				Try!(ConsumeWhitespace());
			}

			return .Ok;
		}

		public Result<void> DeserializeStructEnd()
		{
			if (_inline)
			{
				Try!(ConsumeWhitespace());
				Expect!('}');
				_inlineDepth--;
			}

			return .Ok;
		}

		public Result<void> DeserializeStructField(delegate Result<void, FieldDeserializeError>(StringView field) deserialize, Span<StringView> fieldsLeft, bool first)
		{
			if (ConsumeWhitespace() case .Err)
			{
				// In case any fields that are lists of objects are left.
				// Lists of objects can be omitted from the document.
				// Other types will cause an error, but lists of objects
				// can be deserialized with no input -> empty list.
				for (let field in fieldsLeft)
				{
					if (deserialize(field) case .Err)
					{
						if (Reader.EOF)
							return .Ok;
						return .Err;
					}
				}

				// EOF
				// Toml doesn't have `null`, so null-values are left out instead.
				// We don't care about the remaining fields, so we count them as null.
				return .Ok;
			}

			if (!_inline && Try!(Peek()) == '[')
			{
				if (Try!(Peek(1)) == '[')
				{
					let pos = Reader.Position;
					String key = scope .();
					Try!(Read());
					Try!(Read());
					Try!(ReadKey(key));
					Reader.[Friend]Position = pos;

					key.Remove(0, _parent.Length);
					let field = Try!(key.Split('.').GetNext());

					using (Parent!(field))
					{
						if (deserialize(field) case .Err(let err))
						{
							switch (err)
							{
							case .UnknownField:
								ErrorAt!(pos + 2, new $"Unknown member '{field}'", Math.Max(field.Length, 1));
							case .DeserializationError:
								return .Err;
							}
						}
					}

					return .Ok;
				}

				let bracketPos = Reader.Position;
				Try!(Read());
				Try!(ConsumeWhitespace());
				String key = scope .();
				let keyPos = Reader.Position;
				Try!(ReadKey(key));
				Try!(ConsumeWhitespace());
				Expect!(']');
				Try!(ConsumeLine());

				StringView field = key;
				if (key != _parentKey && key.Contains('.'))
				{
					key.Remove(0, _parent.Length);
					field = Try!(key.Split('.').GetNext());
					Reader.[Friend]Position = bracketPos;
				}

				using (Parent!(field))
				{
					if (deserialize(field) case .Err(let err))
					{
						switch (err)
						{
						case .UnknownField:
							ErrorAt!(keyPos, new $"Unknown member '{field}'", Math.Max(field.Length, 1));
						case .DeserializationError:
							return .Err;
						}
					}
				}
			}
			else
			{
				if (_inline && !first)
				{
					Expect!(',');
					Try!(ConsumeWhitespace());
				}

				let keyPos = Reader.Position;
				String key = scope .();
				Try!(ReadKey(key));

				Try!(ConsumeWhitespace());
				Expect!('=');
				Try!(ConsumeWhitespace());

				_inlineDepth++;
				if (deserialize(key) case .Err(let err))
				{
					switch (err)
					{
					case .UnknownField:
						ErrorAt!(keyPos, new $"Unknown member '{key}'", Math.Max(key.Length, 1));
					case .DeserializationError:
						return .Err;
					}
				}

				_inlineDepth--;
				if (!_inline)
					Try!(ConsumeLine());
			}

			return .Ok;
		}

		public Result<Dictionary<TKey, TValue>> DeserializeMap<TKey, TValue>()
			where TKey : String
			where TValue : ISerializable
		{
			Dictionary<TKey, TValue> dict = new .();
			bool ok = false;
			defer { if (!ok) DeleteDictionary!(dict); }

			Try!(ConsumeWhitespace());
			let next = Try!(Peek());
			if (next == '{')
				Try!(DeserializeInlineTable(dict));
			else
				Try!(DeserializeTable(dict));

			ok = true;
			return dict;
		}

		private Result<void> DeserializeInlineTable<TKey, TValue>(Dictionary<TKey, TValue> dict)
			where TKey : String
			where TValue : ISerializable
		{
			Expect!('{');
			Try!(ConsumeWhitespace());

			while (Try!(Peek()) != '}')
			{
				String key = scope .();
				Try!(ReadKey(key));

				Try!(ConsumeWhitespace());
				Expect!('=');
				Try!(ConsumeWhitespace());

				let value = Try!(TValue.Deserialize(this));
				dict.Add(new .(key), (.)value);

				Try!(ConsumeWhitespace());
			}

			Expect!('}');
			return .Ok;
		}

		private Result<void> DeserializeTable<TKey, TValue>(Dictionary<TKey, TValue> dict)
			where TKey : String
			where TValue : ISerializable
		{
			Result<char8> peek = Peek();
			while (peek case .Ok(let next))
			{
				if (next == '[')
				{
					let bracketPos = Reader.Position;
					Expect!('[');
					String key = scope .();
					Try!(ReadKey(key));
					Expect!(']');

					if (key == _parentKey)
					{
						if (ConsumeWhitespace() case .Err)
							return .Ok;
						peek = Peek();
						continue;
					}
					else if (!key.StartsWith(_parent))
					{
						Reader.[Friend]Position = bracketPos;
						return .Ok;
					}
					else
					{
						Try!(ConsumeLine());

						key.Remove(0, _parent.Length);
						if (key.Contains('.'))
						{
							key.RemoveToEnd(key.IndexOf('.'));
							Reader.[Friend]Position = bracketPos;
						}

						using (Parent!(key))
						{
							if (dict.ContainsKey(key))
							{
								TryDeserializeTable!(dict[key]);
							}
							else
							{
								let value = Try!(TValue.Deserialize(this));
								dict.Add(new .(key), (.)value);
							}
						}

						ConsumeWhitespace().IgnoreError();
						peek = Peek();
						continue;
					}
				}

				String key = scope .();
				Try!(ReadKey(key));
				Try!(ConsumeWhitespace());
				Expect!('=');
				Try!(ConsumeWhitespace());

				let value = Try!(TValue.Deserialize(this));
				dict.Add(new .(key), (.)value);
				
				Try!(ConsumeLine());
				peek = Peek();
			}

			return .Ok;
		}

		public Result<List<T>> DeserializeList<T>() where T : ISerializable
		{
			List<T> list = new .();
			bool ok = false;
			defer { if (!ok) DeleteList!(list); }

			if (!_inline && Util.IsMap(typeof(T)))
				Try!(DeserializeListOfObjects<T>(list));
			else
				Try!(DeserializeInlineList<T>(list));
			
			ok = true;
			return list;
		}

		private Result<void> DeserializeInlineList<T>(List<T> list) where T : ISerializable
		{
			Expect!('[');
			Try!(ConsumeWhitespace());

			bool first = true;
			char8 next = Try!(Peek());
			while (next != ']')
			{
				if (!first)
				{
					Expect!(',');
					Try!(ConsumeWhitespace());
				}

				let value = Try!(T.Deserialize(this));
				list.Add((.)value);

				Try!(ConsumeWhitespace());
				first = false;
				next = Try!(Peek());
			}

			Expect!(']');
			return .Ok;
		}

		private Result<void> DeserializeListOfObjects<T>(List<T> list) where T : ISerializable
		{
			String key = scope .();

			while (true)
			{
				if (ConsumeWhitespace() case .Err)
					break;

				if (Try!(Peek()) != '[' ||
					Try!(Peek(1)) != '[')
					break;

				let pos = Reader.Position;
				Expect!('[');
				Expect!('[');
				Try!(ConsumeWhitespace());
				String key2 = scope .();
				if (key.IsEmpty)
					Try!(ReadKey(key));
				else
				{
					Try!(ReadKey(key2));
					if (key2 != key)
					{
						Reader.[Friend]Position = pos;
						break;
					}
				}

				Try!(ConsumeWhitespace());
				Expect!(']');
				Expect!(']');

				let value = Try!(T.Deserialize(this));
				list.Add((.)value);
			}

			return .Ok;
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

		// TODO: Support '0b' and '0o' prefix
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

			while (!Reader.EOF)
			{
				next = Try!(Peek());

				if (next == '_')
				{
					Try!(Read());
					continue;
				}

				if (hex && !(next.IsDigit ||
					((next >= 'a') && (next <= 'f')) ||
					((next >= 'A') && (next <= 'F'))))
					break;
				if (!hex && !next.IsDigit)
					break;

				str.Append(Try!(Read()));
			}

			if (int.Parse(str) case .Ok(let val))
			{
				return val;
			}

			ErrorAt!(pos, new $"Invalid integer", Reader.Position - pos);
		}

		public Result<uint> DeserializeUInt()
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
				return val;

			ErrorAt!(pos, new $"Invalid integer", Reader.Position - pos);
		}

		public Result<double> DeserializeDouble()
		{
			let pos = Reader.Position;
			String str = scope .();

			while (!Reader.EOF)
			{
				let next = Try!(Peek());

				if (next == '_')
					continue;

				if (!next.IsDigit &&
					next != '+' && next != '-' &&
					next != 'e' && next != 'E' &&
					next != '.')
					break;

				str.Append(Try!(Read()));
			}

			if (double.Parse(str) case .Ok(let val))
			{
				return val;
			}

			ErrorAt!(pos, new $"Invalid decimal number", Reader.Position - pos);
		}

		public Result<bool> DeserializeBool()
		{
			if (Match("true"))
				return true;
			if (Match("false"))
				return false;

			Error!(new $"Expected 'true' or 'false'");
		}

		public Result<DateTime> DeserializeDateTime()
		{
			if (Try!(Peek(2)) == ':')
				return DeserializeTime();

			DateTime date = Try!(DeserializeDate());

			if (Peek() case .Ok(let next) && (next == 'T' || next.IsWhiteSpace))
			{
				Try!(Read());
				if (next == 'T' || (!Reader.EOF && Try!(Peek()).IsDigit))
				{
					let time = Try!(DeserializeTime());
					date = .(date.Ticks + time.Ticks, time.Kind);
				}
			}

			return date;
		}

		private Result<DateTime> DeserializeTime()
		{
			let hours = ExpectNumber!() * 10 + ExpectNumber!();
			Expect!(':');
			let minutes = ExpectNumber!() * 10 + ExpectNumber!();
			Expect!(':');
			let seconds = ExpectNumber!() * 10 + ExpectNumber!();

			double milliseconds = 0;
			if (Peek() case .Ok('.'))
			{
				Expect!('.');
				String str = scope .("0.");
				Try!(Peek());
				while (Peek() case .Ok(let next) && next.IsDigit)
					str.Append(Try!(Read()));

				let secs = double.Parse(str).Get();
				milliseconds = secs * 1000;
			}

			DateTime time = DateTime(0, .Local)
				.AddHours(hours)
				.AddMinutes(minutes)
				.AddSeconds(seconds)
				.AddMilliseconds(milliseconds);

			if (Match("Z"))
			{
				time = .(time.Ticks, .Utc);
			}
			else if (Peek() case .Ok('+') || Peek() case .Ok('-'))
			{
				let op = Try!(Read());
				time = .(time.Ticks, .Utc);

				let offsetHours = ExpectNumber!() * 10 + ExpectNumber!();
				Expect!(':');
				let offsetMinutes = ExpectNumber!() * 10 + ExpectNumber!();

				if (op == '+')
					time = time.AddHours(-offsetHours).AddMinutes(-offsetMinutes);
				else if (op == '-')
					time = time.AddHours(offsetHours).AddMinutes(offsetMinutes);
			}

			return time;
		}

		private Result<DateTime> DeserializeDate()
		{
			let year =
				ExpectNumber!() * 1000 +
				ExpectNumber!() * 100 +
				ExpectNumber!() * 10 +
				ExpectNumber!();
			Expect!('-');
			let month = ExpectNumber!() * 10 + ExpectNumber!();
			Expect!('-');
			let day = ExpectNumber!() * 10 + ExpectNumber!();

			return DateTime(year, month, day);
		}	

		public bool DeserializeNull()
		{
			return false;
		}

		private Result<void> ReadKey(String buffer)
		{
			char8 next = Try!(Peek());
			while (next.IsLetterOrDigit || next == '.' ||
				   next == '-' || next == '_')
			{
				buffer.Append(Try!(Read()));
				next = Try!(Peek());
			}

			return .Ok;
		}

		private mixin Expect(char8 char)
		{
			let next = Try!(Read());
			if (next != char)
				ErrorAt!(Reader.Position - 1, new $"Unexpected character '{next}', expected '{char}'");
		}

		private mixin ExpectNumber()
		{
			let next = Try!(Read());
			if (!next.IsDigit)
				ErrorAt!(Reader.Position - 1, new $"Unexpected character '{next}', expected number");
			next - '0'
		}

		private Result<void> ConsumeChar(char8 char)
		{
			Try!(ConsumeWhitespace());
			Expect!(char);
			return .Ok;
		}

		private Result<void> ConsumeLine(bool allowNonWhitespace = false)
		{
			var allowNonWhitespace;

			if (Reader.EOF)
				return .Ok;

			char8 current = Try!(Read());
			while (current != '\n')
			{
				if (current == '#')
					allowNonWhitespace = true;

				if (!allowNonWhitespace && !_inline && !current.IsWhiteSpace)
					ErrorAt!(Reader.Position - 1, new $"Only one entry allowed per line");

				if (Reader.EOF)
					return .Ok;
				current = Try!(Read());
			}

			ConsumeWhitespace().IgnoreError(); // If this fails, we hit EOF. That's OK.

			return .Ok;
		}

		private Result<void> ConsumeWhitespace()
		{
			while (true)
			{
				let next = Try!(Peek());
				if (next == '#')
					Try!(ConsumeLine(true));

				if (!next.IsWhiteSpace)
					break;

				Try!(Read());
			}
			return .Ok;
		}

		private bool Match(StringView match)
		{
			for (int i < match.Length)
			{
				if (!(Peek(i) case .Ok(match[i])))
					return false;
			}

			for (int i < match.Length)
				Read();

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

		mixin DeleteList<T>(List<T> list)
			where T : delete
		{
			DeleteContainerAndItems!(list);
		}

		mixin DeleteList<T>(List<T> list)
		{
			delete list;
		}

		mixin DeleteDictionary<K, V>(Dictionary<K, V> dict)
			where K : String, delete
			where V : delete
		{
			DeleteDictionaryAndKeysAndValues!(dict);
		}

		mixin DeleteDictionary<K, V>(Dictionary<K, V> dict)
			where K : String, delete
		{
			DeleteDictionaryAndKeys!(dict);
		}

		mixin DeleteDictionary(var dict)
		{
			
		}

		mixin TryDeserializeTable<T, TKey, TValue>(T dict)
			where T : Dictionary<TKey, TValue>
			where TKey : String
			where TValue : ISerializable
		{
			Try!(DeserializeTable(dict));
		}

		mixin TryDeserializeTable(var dict)
		{
			Error!("ERROR");
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