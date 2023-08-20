using System;
using System.Collections;
using System.IO;
using System.Reflection;
using Serialize;
using Serialize.Implementation;
using Serialize.Util;

namespace Toml.Internal
{
	class TomlSerializer : ISerializer
	{
		public StreamWriter Writer { get; set; }
		public String NumberFormat { get; set; }
		public SerializeOrder SerializeOrder { get => .PrimitivesArraysMaps; }

		private String _parent = new .() ~ delete _;

		private int _depth => _parent.Count('.');
		private int _inlineDepth = 0;
		private bool _inline => _inlineDepth > 0;

		private PrettyLevel _pretty;

		public this(PrettyLevel pretty)
		{
			_pretty = pretty;
		}

		public void SerializeMapStart(int size, Type callerType = Compiler.CallerType)
		{
			if (_inline)
				Write!("{ ");
			else if (!_parent.IsEmpty && (!Util.IsMap(Util.GetInnerType(callerType)) || size != 1))
				WriteLine!("\n[{}]", _parent[...^2]);
		}

		public void SerializeMapEntry<TKey, TValue>(TKey _key, TValue value, bool first)
			where TKey : ISerializableKey
			where TValue : ISerializable
		{
			if (value == null)
				return;

			String key = _key.ToKey(.. scope .());
			if (key.Contains('.'))
				key = key.Quote(.. scope:: .());

			let inner = Util.GetInnerType(typeof(TValue));
			if (Util.IsMap(value) || (inner != null && Util.IsMap(inner)))
			{
				using (Parent!(key))
					value.Serialize(this);
			}
			else
			{
				Write!("{} = ", key);
				value.Serialize(this);
				if (!_inline)
					WriteLine!();
			}
		}

		public void SerializeMapEnd()
		{
			if (_inline)
				Write!(" }");
		}

		public void SerializeList<T>(List<T> list)
			where T : ISerializable
		{
			if (Util.IsMap<T>())
			{
				for (let value in list)
				{
					if (value == null)
						continue;

					WriteLine!("\n[[{}]]", _parent.Substring(0, _parent.Length - 1));
					value.Serialize(this);
				}

				return;
			}

			bool pretty = _pretty.HasFlag(.LongLists) && list.Count > 3;

			Write!("[");
			_inlineDepth++;

			bool first = true;
			for (let value in list)
			{
				if (value == null)
					continue;

				if (!first)
					Write!(", ");

				if (pretty)
					Write!("\n    ");

				value.Serialize(this);
				first = false;
			}

			_inlineDepth--;
			if (pretty)
				WriteLine!();
			Write!("]");
		}

		public void SerializeString(String string)
		{
			Write!("\"{}\"", string.Escape(.. scope .()));
		}

		public void SerializeInt(int i)
		{
			Write!("{}", i);
		}

		public void SerializeUInt(uint i)
		{
			Write!("{}", i);
		}

		public void SerializeDouble(double i)
		{
			Write!("{}", i);
		}

		public void SerializeFloat(float i)
		{
			Write!(i.ToString(.. scope .(), NumberFormat, null));
		}

		public void SerializeDateTime(DateTime date)
		{
			let hasDate = date.Year != 1 || date.Month != 1 || date.Day != 1;
			let hasTime = date.Hour != 0 || date.Minute != 0 || date.Second != 0;

			if (hasDate)
				Write!("{0:yyyy-MM-dd}", date);

			if (hasDate && hasTime)
				Write!(" ");

			if (hasTime)
			{
				if (date.Millisecond != 0)
					Write!("{0:HH:mm:ss.fffK}", date);
				else
					Write!("{0:HH:mm:ssK}", date);
			}
		}

		public void SerializeBool(bool b)
		{
			Write!(b ? "true" : "false");
		}

		public void SerializeNull()
		{
			//Runtime.FatalError("TOML: Can't serialize null");
		}

		mixin WriteInner(String text)
		{
			if (_pretty.HasFlag(.Indentation))
			{
				int i = text.IndexOf('\n');
				while (i != -1)
				{
					text.Insert(i + 1, ' ', 4 * (_depth - 1));
					i = text.IndexOf('\n', i + 1);
				}
			}

			Writer.Write(text);
		}

		mixin Write(StringView fmt)
		{
			WriteInner!(scope String(fmt));
		}

		mixin Write(StringView fmt, Object arg)
		{
			WriteInner!(scope String()..AppendF(fmt, arg));
		}

		mixin WriteLine()
		{
			Write!("\n");
		}

		mixin WriteLine(StringView fmt, Object arg)
		{
			WriteInner!(
				scope String()
				..AppendF(fmt, arg)
				..Append('\n')
			);
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