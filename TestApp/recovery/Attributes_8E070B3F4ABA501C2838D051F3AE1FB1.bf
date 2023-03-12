using System;
using System.Collections;
using System.Reflection;

namespace Serialize
{
	[AttributeUsage(.Types)]
	struct SerializableAttribute : Attribute, IOnTypeInit
	{
		const StringView[?] NO_SERIALIZE_MEMBERS = StringView[] ("mClassVData", "mDbgAllocInfo");

		[Comptime]
		bool IsSerializableField(FieldInfo field)
		{
			let type = field.FieldType;

			if (NO_SERIALIZE_MEMBERS.Contains(field.Name))
				return false;

			if (type.IsPointer)
				return false;

			return true;
		}

		[Comptime]
		void IOnTypeInit.OnTypeInit(Type type, Self* prev)
		{
			Compiler.EmitAddInterface(type, typeof(ISerializable));

			int fieldCount = 0;
			for (let field in type.GetFields())
				if (IsSerializableField(field))
					fieldCount++;

			Compiler.EmitTypeBody(type,
				scope $"""
				public void Serialize<S>(S serializer)
					where S : Serialize.Implementation.ISerializer
				{{
					serializer.SerializeMapStart({fieldCount});

					switch (serializer.SerializeOrder)
					{{
					case .InOrder:
						{{
				""");

			WriteSerializeInOrder(type);

			Compiler.EmitTypeBody(type,
				scope $"""
						}}
					case .PrimitivesArraysMaps:
						{{
				""");

			WriteSerializePrimitivesArraysMaps(type);

			Compiler.EmitTypeBody(type,
				scope $"""
						}}
					case .MapsLast: ThrowUnimplemented();
					}}

				""");
			

			String fieldList = scope .();
			bool f = true;
			for (let field in type.GetFields())
			{
				if (!IsSerializableField(field))
					continue;

				if (!f)
					fieldList.Append(", ");
				fieldList.AppendF("\"{}\"", field.Name);
				f = false;
			}

			Compiler.EmitTypeBody(type,
				scope $"""
				
					serializer.SerializeMapEnd();
				}}

				public static System.Result<Self> Deserialize<S>(S deserializer)
					where S : Serialize.Implementation.IDeserializer
				{{
					Self self = {(type.IsValueType ? "" : "new ")}Self();
					bool ok = false;
					defer {{ if (!ok) delete self; }}

					System.Collections.List<StringView> fieldsLeft = scope .(){{ {fieldList} }};

					Try!(deserializer.DeserializeStructStart({fieldCount}));

					delegate Result<void>(StringView) map_field = scope [&] (field) => {{
						switch (field)
						{{

				""");

			for (let field in type.GetFields())
			{
				if (!IsSerializableField(field))
					continue;

				String valueRef;
				if (field.FieldType.IsInteger)
				{
					String systemType = scope .()..Append(field.FieldType);
					systemType[0] = systemType[0].ToUpper;
					valueRef = scope:: $"(System.{systemType}*)&self.{field.Name}";
				}
				else
					valueRef = scope:: $"&self.{field.Name}";

				if (field.FieldType.IsNullable || field.FieldType.IsObject)
					Compiler.EmitTypeBody(type,
						scope $"""
								case \"{field.Name}\":
									if (!deserializer.DeserializeNull())
										self.{field.Name} = Try!({field.FieldType}.Deserialize(deserializer));
									fieldsLeft.Remove(\"{field.Name}\");
									break;
	
						""");
				else
					Compiler.EmitTypeBody(type,
					scope $"""
							case \"{field.Name}\":
								self.{field.Name} = (.)Try!({field.FieldType}.Deserialize(deserializer));
								fieldsLeft.Remove(\"{field.Name}\");

					""");
			}


			Compiler.EmitTypeBody(type,
				scope $"""
						default:
							return .Err;
						}}

						return .Ok;
					}};

					for (int i in 0..<{fieldCount})
						Try!(deserializer.DeserializeStructField(map_field, fieldsLeft));

					if (!fieldsLeft.IsEmpty)
					{{

					}}

					Try!(deserializer.DeserializeStructEnd());
					ok = true;
					return .Ok(self);
				}}
				""");
		}

		[Comptime]
		void WriteSerializeForField(Type type, FieldInfo field, ref String first)
		{
			if (!IsSerializableField(field))
				return;

			if (field.FieldType.IsNullable || field.FieldType.IsObject)
				Compiler.EmitTypeBody(type,
					scope $"""

								//if ({field.Name} == null) serializer.SerializeNull();
								/*else*/ serializer.SerializeMapEntry("{field.Name}", {field.Name}, {first});

					""");
			else
				Compiler.EmitTypeBody(type,
				scope $"""

							serializer.SerializeMapEntry("{field.Name}", {field.Name}, {first});

				""");

			first = "false";
		}

		[Comptime]
		void WriteSerializeInOrder(Type type)
		{
			String first = "true";
			for (let field in type.GetFields())
			{
				WriteSerializeForField(type, field, ref first);
				first = "false";
			}
		}

		[Comptime]
		void WriteSerializePrimitivesArraysMaps(Type type)
		{
			String first = "true";
			List<StringView> primitives = scope .();
			List<StringView> arrays = scope .();
			List<StringView> maps = scope .();

			for (let field in type.GetFields())
			{
				if (field.FieldType.IsPrimitive || field.FieldType == typeof(String))
					primitives.Add(field.Name);
				else if (field.FieldType.IsArray ||
					(field.FieldType is SpecializedGenericType &&
					(field.FieldType as SpecializedGenericType).UnspecializedType == typeof(List<>)))
					arrays.Add(field.Name);
				else
					maps.Add(field.Name);
			}

			for (let field in type.GetFields())
				if (primitives.Contains(field.Name))
					WriteSerializeForField(type, field, ref first);

			for (let field in type.GetFields())
				if (arrays.Contains(field.Name))
					WriteSerializeForField(type, field, ref first);

			for (let field in type.GetFields())
				if (maps.Contains(field.Name))
					WriteSerializeForField(type, field, ref first);
		}
	}

	struct SerializeFieldAttribute : Attribute
	{
		public this(bool serialize = true)
		{

		}
	}
}