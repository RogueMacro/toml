using System;
using System.Collections;
using Serialize;
using Serialize.Implementation;
using Serialize.Util;

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

		private Key _parent = new .() ~ delete _;

		private List<State> _state = new .() ~ DeleteContainerAndItems!(_);

		public void PushState()
		{
			_state.Add(new .()
				{
					Parent = _parent, // Don't break existing references to parent
					InlineDepth = _inlineDepth
				});

			// New state requires cloned parent
			_parent = new .(_parent);
		}

		public void PopState()
		{
			let state = _state.PopBack();
			delete _parent;
			_parent = state.Parent;
			_inlineDepth = state.InlineDepth;

			state.Used();
			delete state;
		} 

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
			let structFieldStart = Reader.Position;

			if (ConsumeWhitespace() case .Err)
			{
				// In case any fields that are lists of objects are left.
				// Lists of objects can be omitted from the document.
				// Other types will cause an error, but lists of objects
				// can be deserialized with no input -> empty list.
				// Note: Caller should handle if any fields left.
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
					Key key = scope .();
					Try!(Read());
					Try!(Read());
					Try!(ReadKey(key));
					Reader.Position = pos;

					key.RemoveFromStart(_parent);
					let field = key.First();

					using (Parent!(field))
					{
						if (deserialize(field) case .Err(let err))
						{
							switch (err)
							{
							case .UnknownField:
								//String message = new $"Unknown member '{field}' of {KeyView(_parent, 1)}. Expected ";
								//JoinList(fieldsLeft, message);
								//ErrorAt!(pos + 2, message, Math.Max(field.Length, 1));
								Reader.Position = structFieldStart;
								return .Ok;
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
				Key key = scope .();
				//let keyPos = Reader.Position;
				Try!(ReadKey(key));
				Try!(ConsumeWhitespace());
				Expect!(']');
				Try!(ConsumeLine());

				String field = key.First();
				if (!key.Equals(_parent) && key.Depth > 1)
				{
					key.RemoveFromStart(_parent);
					field = key.First();
					Reader.Position = bracketPos;
				}

				using (Parent!(field))
				{
					if (deserialize(field) case .Err(let err))
					{
						switch (err)
						{
						case .UnknownField:
							//String message = new $"Unknown member '{field}' of {KeyView(_parent, 1)}. Expected ";
							//JoinList(fieldsLeft, message);
							//ErrorAt!(keyPos, message, Math.Max(field.Length, 1));
							Reader.Position = structFieldStart;
							return .Ok;
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

				//let keyPos = Reader.Position;
				Key key = scope .();
				Try!(ReadKey(key));
				if (key.Depth > 1)
					Error!(new $"Dotted keys are not supported");

				let field = key.First();

				Try!(ConsumeWhitespace());
				Expect!('=');
				Try!(ConsumeWhitespace());

				_inlineDepth++;
				if (deserialize(field) case .Err(let err))
				{
					switch (err)
					{
					case .UnknownField:
						//String message = new $"Unknown member '{field}' of {_parent}. Expected ";
						//JoinList(fieldsLeft, message);
						//ErrorAt!(keyPos, message, Math.Max(field.Length, 1));
						Reader.Position = structFieldStart;
						return .Ok;
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
			where TKey : ISerializableKey
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
			where TKey : ISerializableKey
			where TValue : ISerializable
		{
			Expect!('{');
			Try!(ConsumeWhitespace());

			while (Try!(Peek()) != '}')
			{
				Key key = scope .();
				Try!(ReadKey(key));
				if (key.Depth > 1)
					Error!("Dotted keys are not supported");

				Try!(ConsumeWhitespace());
				Expect!('=');
				Try!(ConsumeWhitespace());

				let value = Try!(TValue.Deserialize(this));
				dict.Add(Try!(TKey.Parse(key.First())), (.)value);

				Try!(ConsumeWhitespace());
			}

			Expect!('}');
			return .Ok;
		}

		private Result<void> DeserializeTable<TKey, TValue>(Dictionary<TKey, TValue> dict)
			where TKey : ISerializableKey
			where TValue : ISerializable
		{
			Result<char8> peek = Peek();
			while (peek case .Ok(let next))
			{
				if (next == '[')
				{
					let bracketPos = Reader.Position;
					Expect!('[');
					Key key = scope .();
					Try!(ReadKey(key));
					Expect!(']');

					if (key.Equals(_parent))
					{
						if (ConsumeWhitespace() case .Err)
							return .Ok;
						peek = Peek();
						continue;
					}
					else if (!key.IsChildOf(_parent))
					{
						Reader.Position = bracketPos;
						return .Ok;
					}
					else
					{
						Try!(ConsumeLine());

						key.RemoveFromStart(_parent);
						if (key.Depth > 1)
							Reader.Position = bracketPos;

						let strKey = key.First();
						let parsedKey = Try!(TKey.Parse(strKey));
						bool ok = false;
						defer { if (!ok) Delete!(parsedKey); }

						using (Parent!(strKey))
						{
							if (dict.ContainsKey(parsedKey))
							{
								Try!(DeserializeTable(dict));
							}
							else
							{
								let value = Try!(TValue.Deserialize(this));
								ok = true;
								dict.Add(parsedKey, (.)value);
							}
						}

						ConsumeWhitespace().IgnoreError();
						peek = Peek();
						continue;
					}
				}

				Key key = scope .();
				Try!(ReadKey(key));
				if (key.Depth > 1)
					Error!("Dotted keys are not supported");

				Try!(ConsumeWhitespace());
				Expect!('=');
				Try!(ConsumeWhitespace());

				let value = Try!(TValue.Deserialize(this));
				let parsedKey = Try!(TKey.Parse(key.First()));
				dict.Add(parsedKey, (.)value);
				
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

			if (!_inline && [ConstEval]Util.IsMapStrict<T>())
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
			Key key = scope .();

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
				Key key2 = scope .();
				if (key.Depth == 0)
					Try!(ReadKey(key));
				else
				{
					Try!(ReadKey(key2));
					if (!key2.Equals(key))
					{
						Reader.Position = pos;
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

			Expect!('"');
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

		private Result<void> ReadKey(Key key)
		{
			String buffer = scope .();
			char8 next = Try!(Peek());
			while (true)
			{
				if (next == '"')
				{
					let str = Try!(DeserializeString());
					buffer.Append(str);
					delete str;
				}
				else if (next == '.')
				{
					key.Push(buffer);
					buffer.Clear();
					Try!(Read());
				}
				else if (next.IsLetterOrDigit ||
				   next == '-' || next == '_')
					buffer.Append(Try!(Read()));
				else
					break;
				
				next = Try!(Peek());
			}

			if (buffer.IsEmpty)
				Error!("Expected key after dot");
			
			key.Push(buffer);
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

		void JoinList<T>(Span<T> list, String buffer)
		{
			bool first = true;
			for (let i in 0..<list.Length)
			{
				if (first)
					first = false;
				else if (i == list.Length - 1)
					buffer.Append(" or ");
				else
					buffer.Append(", ");

				list[i].ToString(buffer);
			}
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
			where K : IHashable, delete
			where V : delete
		{
			DeleteDictionaryAndKeysAndValues!(dict);
		}

		mixin DeleteDictionary<K, V>(Dictionary<K, V> dict)
			where K : IHashable, delete
		{
			DeleteDictionaryAndKeys!(dict);
		}

		mixin DeleteDictionary(var dict) {}

		mixin Delete<T>(T value)
			where T : delete
		{
			delete value;
		}

		mixin Delete(var value) {}

		mixin Parent(StringView key)
		{
			Parent(_parent, key)
		}

		struct Parent : IDisposable
		{
			private int _depth;
			private Key _parent;

			public this(Key parent, StringView key)
			{
				_parent = parent;
				_depth = parent.Depth;
				parent.Push(key);
			}

			public void Dispose()
			{
				_parent.RestoreDepth(_depth);
			}
		}

		struct KeyView
		{
			int offset;
			int length;
			Key key;

			public this(Key key, int toEnd)
			{
				this.key = key;
				this.offset = 0;
				this.length = key.Components.Count - toEnd;
			}

			public override void ToString(String strBuffer)
			{
				if (key.Components.IsEmpty || offset >= key.Components.Count)
					return;

				key.Components[offset].ToString(strBuffer);
				for (let c in key.Components[(offset+1)..<(offset+length)])
					strBuffer.AppendF(".{}", c);
			}
		}

		class Key
		{
			public readonly List<String> Components = new .() ~ DeleteContainerAndItems!(_);

			public int Depth => Components.Count;

			public this() {}

			public this(Key key)
			{
				for (let component in key.Components)
					Components.Add(new .(component));
			}

			public void Push(StringView component) => Components.Add(new .(component));
			public void Pop()
			{
				delete Components[Components.Count - 1];
				Components.RemoveAt(Components.Count - 1);
			}

			public String First() => Components[0];

			public void RemoveFromStart(Key key)
			{
				for (let i < key.Depth)
					delete Components[i];
				Components.RemoveRange(0, key.Depth);
			}

			public void RestoreDepth(int depth)
			{
				if (Depth > depth)
				{
					int excessive = Depth - depth;
					for (let i < excessive)
						delete Components[depth + i];
					Components.RemoveRange(depth, excessive);
				}
			}

			public bool IsChildOf(Key other)
			{
				if (Depth <= other.Depth)
					return false;

				for (let i < other.Depth)
					if (Components[i] != other.Components[i])
						return false;

				return true;
			}

			public bool Equals(Key other)
			{
				if (Depth != other.Depth)
					return false;

				for (let i < Components.Count)
					if (Components[i] != other.Components[i])
						return false;

				return true;
			}

			public override void ToString(String strBuffer)
			{
				
			}
		}

		class State
		{
			public Key Parent ~ delete _;
			public uint InlineDepth;

			public void Used()
			{
				Parent = null;
			}
		}
	}
}