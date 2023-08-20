namespace Toml
{
	enum PrettyLevel
	{
		None = 0,
		LongLists = 1,
		Indentation = 2,

		All = .LongLists | .Indentation
	}
}