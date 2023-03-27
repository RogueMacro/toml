using System;
using System.Collections;
using System.Reflection;

namespace Toml.Internal
{
	static class Util
	{
		public static bool IsMap(Type type)
		{
			return !(type.IsPrimitive ||
				(type.IsEnum && !type.IsUnion) ||
				type == typeof(String) ||
				type == typeof(DateTime) ||
				(type is SpecializedGenericType &&
				(type as SpecializedGenericType).UnspecializedType == typeof(List<>)));
		}	
	}
}